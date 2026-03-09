#!/usr/bin/env python3
"""OrignaGTA Admin CLI — single entry point for all admin operations."""
import click
from cli.commands import deploy, db, secrets, tests, users, orders, payments, products, webhooks, reviews


@click.group()
@click.version_option("1.0.0")
def cli():
    """OrignaGTA Admin CLI\n\nManage dev, staging, and prod environments."""
    pass


cli.add_command(deploy.deploy)
cli.add_command(db.db)
cli.add_command(secrets.secrets)
cli.add_command(tests.tests)
cli.add_command(users.users)
cli.add_command(orders.orders)
cli.add_command(payments.payments)
cli.add_command(products.products)
cli.add_command(webhooks.webhooks)
cli.add_command(reviews.reviews)

if __name__ == "__main__":
    cli()
