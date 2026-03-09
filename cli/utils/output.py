"""Rich output helpers for the admin CLI."""
from rich.console import Console
from rich.table import Table
from rich.panel import Panel

console = Console()


def success(msg: str) -> None:
    """Function success."""
    console.print(f"[bold green]✅ {msg}[/bold green]")


def error(msg: str) -> None:
    """Function error."""
    console.print(f"[bold red]❌ {msg}[/bold red]")


def warn(msg: str) -> None:
    """Function warn."""
    console.print(f"[bold yellow]⚠️  {msg}[/bold yellow]")


def info(msg: str) -> None:
    """Function info."""
    console.print(f"[cyan]ℹ️  {msg}[/cyan]")


def header(title: str, env: str) -> None:
    """Function header."""
    env_colors = {"dev": "green", "staging": "yellow", "prod": "bold red"}
    color = env_colors.get(env, "white")
    console.print(Panel(f"[{color}]{title}[/{color}]  env=[{color}]{env}[/{color}]"))


def confirm_prod(action: str) -> bool:
    """Require explicit confirmation for prod destructive actions."""
    console.print(f"\n[bold red]⚠️  PRODUCTION ACTION: {action}[/bold red]")
    answer = console.input("[bold red]Type 'yes' to confirm: [/bold red]")
    return answer.strip().lower() == "yes"


def make_table(title: str, columns: list[str]) -> Table:
    """Function make_table."""
    t = Table(title=title, show_header=True, header_style="bold cyan")
    for col in columns:
        t.add_column(col)
    return t
