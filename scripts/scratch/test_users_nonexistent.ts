import { test, expect } from '@playwright/test';
import { FIRESTORE_BASE, signIn, TEST_ACCOUNTS, TEST_UIDS } from './e2e/playwright_ui/api-helpers.ts';

async function main() {
    const auth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    
    const res = await fetch(`${FIRESTORE_BASE}/users/nonexistent123`, {
        headers: {
            "Authorization": `Bearer ${auth.idToken}`
        }
    });

    console.log("Status reading nonexistent user:", res.status);
    const json = await res.json();
    console.log(JSON.stringify(json, null, 2));
}

main().catch(console.error);
