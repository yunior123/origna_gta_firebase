"""Deploy commands — functions, rules, indexes, hosting, all."""
import os
import subprocess
import click
from cli.utils.output import console, success, error, header, confirm_prod

ENV_TO_PROJECT = {
    "dev": "orignagta-dev",
    "staging": "orignagta-staging",
    "prod": "orignagta",
}


def _repo_root() -> str:
    return os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _firebase(args: list[str], env: str) -> int:
    project = ENV_TO_PROJECT[env]
    cmd = ["firebase"] + args + ["--project", project]
    console.print(f"[dim]$ {' '.join(cmd)}[/dim]")
    return subprocess.call(cmd)


@click.group()
def deploy():
    """Deploy Firebase resources to an environment."""
    pass


@deploy.command()
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
@click.option("--only", default=None, help="Comma-separated function names")
def functions(env: str, only: str | None):
    """Deploy Cloud Functions."""
    header("Deploy Functions", env)
    if env == "prod" and not confirm_prod("deploy functions to PRODUCTION"):
        return
    targets = ["functions"] if not only else [f"functions:{only}"]
    rc = _firebase(["deploy", "--only", ",".join(targets)], env)
    success("Functions deployed") if rc == 0 else error(f"Deploy failed (exit {rc})")


@deploy.command()
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
def rules(env: str):
    """Deploy Firestore + Storage rules."""
    header("Deploy Rules", env)
    if env == "prod" and not confirm_prod("deploy rules to PRODUCTION"):
        return
    rc = _firebase(["deploy", "--only", "firestore:rules,storage"], env)
    success("Rules deployed") if rc == 0 else error(f"Deploy failed (exit {rc})")


@deploy.command()
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
def indexes(env: str):
    """Deploy Firestore indexes."""
    header("Deploy Indexes", env)
    rc = _firebase(["deploy", "--only", "firestore:indexes"], env)
    success("Indexes deployed") if rc == 0 else error(f"Deploy failed (exit {rc})")


@deploy.command()
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
def hosting(env: str):
    """Deploy Firebase Hosting (requires web build first)."""
    header("Deploy Hosting", env)
    if env == "prod" and not confirm_prod("deploy hosting to PRODUCTION"):
        return
    rc = _firebase(["deploy", "--only", "hosting"], env)
    success("Hosting deployed") if rc == 0 else error(f"Deploy failed (exit {rc})")


@deploy.command(name="all")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
@click.option("--skip-tests", is_flag=True, default=False)
def deploy_all(env: str, skip_tests: bool):
    """Deploy everything: validate schema → run tests → build → deploy all."""
    repo_root = _repo_root()
    header("Full Deploy", env)
    if env == "prod" and not confirm_prod("FULL deploy to PRODUCTION"):
        return

    steps: list[tuple[str, list[str]]] = []
    if not skip_tests:
        steps.append(("Backend tests", ["pytest", f"{repo_root}/functions/tests/", "-v", "--tb=short"]))

    build_script = {
        "dev": f"{repo_root}/scripts/build/build_dev.sh",
        "staging": f"{repo_root}/scripts/build/build_staging.sh",
        "prod": f"{repo_root}/scripts/build/build_prod.sh",
    }[env]
    steps.append(("Flutter web build", ["bash", build_script, "web"]))

    for step_name, cmd in steps:
        console.print(f"\n[bold]→ {step_name}[/bold]")
        rc = subprocess.call(cmd)
        if rc != 0:
            error(f"{step_name} failed — aborting deploy")
            raise SystemExit(1)

    for target in ["functions", "firestore:rules,storage", "firestore:indexes", "hosting"]:
        rc = _firebase(["deploy", "--only", target], env)
        if rc != 0:
            error(f"Deploy {target} failed")
            raise SystemExit(1)

    success(f"Full deploy to {env} complete")
