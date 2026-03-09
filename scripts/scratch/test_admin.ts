import { test, expect } from '@playwright/test';
import { getDoc, signIn, TEST_ACCOUNTS, TEST_UIDS } from './e2e/playwright_ui/api-helpers.ts';

async function main() {
    const auth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    console.log("Admin auth:", !!auth.idToken);
    
    // check if admin has role 'admin'
    const adminDoc = await getDoc(`users/${TEST_UIDS.ADMIN}`, auth.idToken);
    console.log("Admin roles:", adminDoc?.roles);

    // Try a simple read instead of a query
    const res = await fetch(`https://firestore.googleapis.com/v1/projects/orignagta-dev/databases/(default)/documents/_mail_logs?pageSize=1`, {
        headers: {
            "Authorization": `Bearer ${auth.idToken}`
        }
    });

    console.log("List status:", res.status);
    const json = await res.json();
    console.log(JSON.stringify(json, null, 2));
}

main().catch(console.error);
