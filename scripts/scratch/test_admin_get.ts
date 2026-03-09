import { test, expect } from '@playwright/test';
import { getDoc, signIn, TEST_ACCOUNTS, TEST_UIDS } from './e2e/playwright_ui/api-helpers.ts';

async function main() {
    const auth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    
    // Test get single doc
    const res = await fetch(`https://firestore.googleapis.com/v1/projects/orignagta-dev/databases/(default)/documents/_mail_logs/testDoc`, {
        headers: {
            "Authorization": `Bearer ${auth.idToken}`
        }
    });

    console.log("Get status:", res.status);
    const json = await res.json();
    console.log(JSON.stringify(json, null, 2));
}

main().catch(console.error);
