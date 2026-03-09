import { test, expect } from '@playwright/test';
import { FIRESTORE_BASE, parseDoc, signIn, TEST_ACCOUNTS } from './e2e/playwright_ui/api-helpers.ts';

async function main() {
    const auth = await signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);
    
    const body = {
        structuredQuery: {
            from: [{ collectionId: "_mail_logs" }],
            where: {
                fieldFilter: {
                    field: { fieldPath: "to" },
                    op: "EQUAL",
                    value: { stringValue: "yuniorrodriguezo460@gmail.com" }
                }
            },
            limit: 10
        }
    };

    const res = await fetch(`${FIRESTORE_BASE}:runQuery`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${auth.idToken}`
        },
        body: JSON.stringify(body)
    });

    console.log("Status:", res.status);
    const json = await res.json();
    console.log(JSON.stringify(json, null, 2));
}

main().catch(console.error);
