"""User management — list, ban, unban, delete, view."""
import click
from cli.utils.output import header, success, error, console, make_table, confirm_prod
from cli.utils.firebase_client import get_firestore, get_auth


@click.group()
def users():
    """Manage platform users."""
    pass


@users.command(name="list")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
@click.option("--role", default=None, type=click.Choice(["buyer", "seller", "admin"]))
@click.option("--limit", default=20)
def list_users(env: str, role: str | None, limit: int):
    """List users, optionally filtered by role."""
    header("Users", env)
    db = get_firestore(env)
    query = db.collection("users").limit(limit)
    if role:
        query = query.where("role", "==", role)
    docs = query.stream()
    t = make_table(f"Users ({env})", ["UID", "Email", "Role", "Status", "Created"])
    count = 0
    for doc in docs:
        d = doc.to_dict()
        t.add_row(
            doc.id[:20],
            d.get("email", "—"),
            d.get("role", "—"),
            d.get("status", "active"),
            str(d.get("createdAt", "—"))[:19],
        )
        count += 1
    console.print(t)
    console.print(f"[dim]Showing {count} users[/dim]")


@users.command()
@click.argument("uid")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
@click.option("--reason", required=True, help="Reason for ban")
def ban(uid: str, env: str, reason: str):
    """Ban a user by UID."""
    header(f"Ban User {uid[:12]}...", env)
    if env == "prod" and not confirm_prod(f"ban user {uid}"):
        return
    db = get_firestore(env)
    db.collection("users").document(uid).update({"status": "banned", "banReason": reason})
    auth = get_auth(env)
    auth.update_user(uid, disabled=True)
    success(f"User {uid} banned: {reason}")


@users.command()
@click.argument("uid")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
def unban(uid: str, env: str):
    """Unban a user by UID."""
    header(f"Unban User {uid[:12]}...", env)
    if env == "prod" and not confirm_prod(f"unban user {uid}"):
        return
    db = get_firestore(env)
    db.collection("users").document(uid).update({"status": "active", "banReason": None})
    auth = get_auth(env)
    auth.update_user(uid, disabled=False)
    success(f"User {uid} unbanned")


@users.command()
@click.argument("uid")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
@click.confirmation_option(prompt="Permanently delete this user?")
def delete(uid: str, env: str):
    """Permanently delete a user and their Auth account."""
    header(f"Delete User {uid[:12]}...", env)
    if env == "prod" and not confirm_prod(f"delete user {uid}"):
        return
    db = get_firestore(env)
    db.collection("users").document(uid).delete()
    auth = get_auth(env)
    auth.delete_user(uid)
    success(f"User {uid} deleted")


@users.command()
@click.argument("uid")
@click.option("--env", required=True, type=click.Choice(["dev", "staging", "prod"]))
def view(uid: str, env: str):
    """View full user profile."""
    header(f"User {uid[:12]}...", env)
    db = get_firestore(env)
    doc = db.collection("users").document(uid).get()
    if not doc.exists:
        error(f"User {uid} not found")
        return
    from rich.pretty import pprint
    pprint(doc.to_dict())
