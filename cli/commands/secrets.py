"""Secrets management — upload, sync Remote Config."""
import subprocess
import os
import click
from cli.utils.output import header, success, error


def _repo_root() -> str:
    return os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


@click.group()
def secrets():
    """Manage secrets (Secret Manager, Remote Config)."""
    pass


@secrets.command()
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
def upload(env: str):
    """Upload secrets from .env to Secret Manager."""
    header("Upload Secrets", env)
    script = os.path.join(_repo_root(), "scripts", "upload_secrets.py")
    rc = subprocess.call(["python", script, "--env", env])
    success("Secrets uploaded") if rc == 0 else error(f"Upload failed (exit {rc})")


@secrets.command(name="sync-remote-config")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
def sync_remote_config(env: str):
    """Push Remote Config values for an environment."""
    header("Sync Remote Config", env)
    script = os.path.join(_repo_root(), "scripts", "update_remote_config.py")
    rc = subprocess.call(["python", script, "--env", env])
    success("Remote Config synced") if rc == 0 else error(f"Sync failed (exit {rc})")
