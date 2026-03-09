"""Firebase Admin SDK client — initializes per environment."""
import os
import firebase_admin
from firebase_admin import credentials, firestore, auth as fb_auth
from dotenv import load_dotenv

_apps: dict[str, firebase_admin.App] = {}

ENV_TO_PROJECT = {
    "dev": "orignagta-dev",
    "staging": "orignagta-staging",
    "prod": "orignagta",
}


def _load_env(env: str) -> None:
    env_file = os.path.join(os.path.dirname(__file__), f"../.env.{env}")
    if os.path.exists(env_file):
        load_dotenv(env_file, override=True)


def get_app(env: str) -> firebase_admin.App:
    """Function get_app."""
    if env not in _apps:
        _load_env(env)
        project_id = ENV_TO_PROJECT.get(env)
        if not project_id:
            raise ValueError(f"Unknown env: {env}. Use dev|staging|prod.")
        cred = credentials.ApplicationDefault()
        _apps[env] = firebase_admin.initialize_app(
            cred,
            {"projectId": project_id},
            name=f"app_{env}",
        )
    return _apps[env]


def get_firestore(env: str):
    """Function get_firestore."""
    app = get_app(env)
    return firestore.client(app=app)


def get_auth(env: str):
    """Function get_auth."""
    get_app(env)
    return fb_auth
