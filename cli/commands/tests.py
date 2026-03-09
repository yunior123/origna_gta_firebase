"""Test runner — backend, E2E, integration, all."""
import subprocess
import os
import click
from cli.utils.output import header, success, error, console

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


@click.group()
def tests():
    """Run test suites."""
    pass


@tests.command()
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
@click.option("--path", default="functions/tests/", help="Test path or file")
@click.option("-k", default=None, help="pytest -k filter")
def backend(env: str, path: str, k: str | None):
    """Run pytest backend tests."""
    header("Backend Tests", env)
    cmd = ["pytest", path, "-v", "--tb=short"]
    if k:
        cmd += ["-k", k]
    rc = subprocess.call(cmd, cwd=REPO_ROOT)
    success("Backend tests passed") if rc == 0 else error(f"Backend tests failed (exit {rc})")


@tests.command()
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
@click.option("--config", default=None, help="Playwright config file (auto-selected if omitted)")
def e2e(env: str, config: str | None):
    """Run Playwright E2E tests."""
    header("E2E Tests (Playwright)", env)
    if env == "prod":
        error("E2E tests are not run against prod.")
        return
    config_file = config or (
        "playwright.config.dev.ts" if env == "dev" else "playwright.config.staging.ts"
    )
    cmd = ["npx", "playwright", "test", f"--config={config_file}"]
    rc = subprocess.call(cmd, cwd=os.path.join(REPO_ROOT, "e2e"))
    success("E2E tests passed") if rc == 0 else error(f"E2E tests failed (exit {rc})")


@tests.command(name="integration")
@click.option("--env", required=True, type=click.Choice(["dev"]))
@click.option("--index", default=-1, help="Test index 0-4 (-1 = random)")
def integration_tests(env: str, index: int):
    """Run Flutter integration tests (dev only)."""
    header("Flutter Integration Tests", env)
    defines = "--dart-define=ENVIRONMENT=dev --dart-define=IS_TEST=true"
    if index >= 0:
        defines += f" --dart-define=INTEGRATION_TEST_INDEX={index}"
    cmd = (
        f"flutter drive "
        f"--driver=test_driver/integration_test.dart "
        f"--target=integration_test/all_tests.dart "
        f"-d chrome {defines}"
    )
    console.print(f"[dim]$ {cmd}[/dim]")
    rc = subprocess.call(cmd, shell=True, cwd=os.path.join(REPO_ROOT, "origna_gta"))
    success("Integration tests passed") if rc == 0 else error(f"Integration tests failed (exit {rc})")


@tests.command(name="all")
@click.option("--env", required=True, type=click.Choice(["dev", "staging"]))
def all_tests(env: str):
    """Run backend + E2E tests."""
    header("All Tests", env)
    cmds = [
        (["pytest", "functions/tests/", "-v", "--tb=short"], REPO_ROOT),
        (["npx", "playwright", "test", f"--config=playwright.config.{env}.ts"], os.path.join(REPO_ROOT, "e2e")),
    ]
    for cmd, cwd in cmds:
        rc = subprocess.call(cmd, cwd=cwd)
        if rc != 0:
            error(f"Tests failed: {' '.join(cmd)}")
            raise SystemExit(1)
    success("All tests passed")
