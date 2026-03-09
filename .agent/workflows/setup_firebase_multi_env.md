---
description: How to set up and deploy a multi-environment Firebase backend (Dev/Staging/Prod)
---

This workflow automates the setup, configuration, and deployment of the `orignagta` backend across multiple environments.

# Prerequisites
-   Firebase CLI installed and logged in (`firebase login`).
-   Google Cloud SDK (`gcloud`) installed and authorized (`gcloud auth login`, `gcloud auth application-default login`).
-   Python installed.
-   `functions/.env` populated with required secrets.

# Steps

1.  **Verify Environment Variables**
    Ensure `functions/.env` contains all necessary keys (`STRIPE_SECRET_KEY`, `ALGOLIA_API_KEY`, `MAILJET_API_KEY`, etc.). This file is the source of truth for secret population.

2.  **Upload Secrets to Google Cloud**
    This script reads from `functions/.env` and populates/updates secrets in Google Secret Manager for `orignagta-dev` and `orignagta-staging`.
    ```bash
    // turbo
    python3 scripts/setup_secrets.py
    ```

3.  **Update Remote Config**
    This script pushes the latest Remote Config templates (including Algolia keys and API endpoints) to `orignagta-dev` and `orignagta-staging`.
    ```bash
    // turbo
    python3 scripts/update_remote_config.py
    ```

4.  **Deploy Cloud Functions (Dev)**
    Deploy backend functions to the Development environment.
    ```bash
    firebase use dev
    firebase deploy --only functions
    ```

5.  **Deploy Cloud Functions (Staging)**
    Deploy backend functions to the Staging environment.
    ```bash
    firebase use staging
    firebase deploy --only functions
    ```

6.  **Seed Development Database**
    Populate `orignagta-dev` Firestore with test users and products.
    ```bash
    // turbo
    python3 scripts/seed_dev_db.py
    ```

7.  **Verify Deployment**
    Run the Flutter app in the desired environment to verify connectivity.
    ```bash
    # Dev
    flutter run -d chrome --dart-define=ENVIRONMENT=dev

    # Staging
    flutter run -d chrome --dart-define=ENVIRONMENT=staging
    ```
