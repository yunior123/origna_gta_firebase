"""Module configure_algolia_indices.py."""
import os
import ssl
import sys

import aiohttp

# Strongly bypass SSL verification by patching aiohttp (for local proxy envs)
ssl._create_default_https_context = ssl._create_unverified_context

original_init = aiohttp.TCPConnector.__init__


def new_init(self, *args, **kwargs):
    """Function new_init."""
    kwargs["ssl"] = False
    original_init(self, *args, **kwargs)


aiohttp.TCPConnector.__init__ = new_init

# Add current directory to path so imports work
current_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(current_dir)

from dotenv import load_dotenv

load_dotenv()  # Load .env variables (API keys)

# Force re-evaluation removed to avoid duplicate param registration error
import config
from services.algolia_service import configure_algolia_index

if __name__ == "__main__":
    print(f"🔧 Configuring Algolia for environment: {config.CURRENT_ENV.value}")
    print(f"   Project ID: {os.environ.get('GCP_PROJECT')}")

    success = configure_algolia_index()

    if success:
        print("✅ Configuration successful!")
    else:
        print("❌ Configuration failed.")
        sys.exit(1)
