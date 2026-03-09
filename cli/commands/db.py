"""DB commands — seed, reset, verify, algolia-sync."""
import subprocess
import os
import click
from cli.utils.output import success, error, header


def _repo_root() -> str:
    return os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


@click.group()
def db():
    """Database management (seed, reset, verify)."""
    pass


@db.command()
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
def seed(env: str):
    """Seed test data (dev/staging only)."""
    header("Seed DB", env)
    if env == "prod":
        error("Seeding is not allowed in prod.")
        return
    script = os.path.join(_repo_root(), "scripts", "seed_dev_db.py")
    rc = subprocess.call(["python", script])
    success("Seed complete") if rc == 0 else error(f"Seed failed (exit {rc})")


@db.command()
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
def verify(env: str):
    """Verify DB integrity and data consistency."""
    header("Verify DB", env)
    script = os.path.join(_repo_root(), "scripts", "verify_dev_data.py")
    rc = subprocess.call(["python", script])
    success("Verify complete") if rc == 0 else error(f"Verify failed (exit {rc})")


@db.command()
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
@click.confirmation_option(prompt="This will DELETE all test data. Are you sure?")
def reset(env: str):
    """Delete all test/seed data (dev/staging only)."""
    header("Reset DB", env)
    if env == "prod":
        error("Reset is not allowed in prod.")
        return
    script = os.path.join(_repo_root(), "scripts", "delete_dev_products.py")
    rc = subprocess.call(["python", script])
    success("Reset complete") if rc == 0 else error(f"Reset failed (exit {rc})")


@db.command(name="algolia-sync")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
def algolia_sync(env: str):
    """Sync Firestore products to Algolia index."""
    header("Algolia Sync", env)
    script = os.path.join(_repo_root(), "scripts", "sync_emulator_to_algolia.py")
    rc = subprocess.call(["python", script])
    success("Algolia sync complete") if rc == 0 else error(f"Sync failed (exit {rc})")
