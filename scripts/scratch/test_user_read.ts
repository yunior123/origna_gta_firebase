import { test, expect } from '@playwright/test';
import { FIRESTORE_BASE, signIn, TEST_ACCOUNTS, TEST_UIDS } from './e2e/playwright_ui/api-helpers.ts';

async function main() {
    const auth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    
    // Read BUYER's user doc as ADMIN
    const res = await fetch(`${FIRESTORE_BASE}/users/${TEST_UIDS.BUYER}`, {
        headers: {
            "Authorization": `Bearer ${auth.idToken}`
        }
    });

    console.log("Status reading other user:", res.status);
    const json = await res.json();
    console.log(json.name || json.error);
}

main().catch(console.error);
