/**
 * OrignaGTA — Shared E2E API Helpers
 * ===================================
 * Single source of truth for all E2E test utilities.
 * Every spec file MUST import from here — no copy-paste allowed.
 *
 * Covers:
 *   - Firebase Auth sign-in (Cloud Auth for dev/staging/production)
 *   - Firebase Functions callable invocation
 *   - Firestore REST API (read, write, patch, delete, list)
 *   - Firestore value conversion (toFsVal / parseVal / parseDoc)
 *   - Checkout payload builders
 *   - Order lifecycle helpers
 *   - Infrastructure & seed validation
 *   - Stripe Checkout page helpers (headless-safe)
 *
 * @module api-helpers
 */

// ════════════════════════════════════════════════════════════════════
// CONFIGURATION — Environment-aware URLs
// ════════════════════════════════════════════════════════════════════

// Detect test environment: 'dev' (default), 'staging', 'production'
const TEST_ENV = (process.env.TEST_ENVIRONMENT || 'dev').toLowerCase();

// Build environment-specific URLs
const getEnvironmentConfig = () => {
  switch (TEST_ENV) {
    case 'staging':
      return {
        auth: 'https://identitytoolkit.googleapis.com',
        firestore: 'https://firestore.googleapis.com',
        functions: 'https://northamerica-northeast1-orignagta-staging.cloudfunctions.net',
        webApp: 'https://orignagta-staging.web.app',
        projectId: 'orignagta-staging',
      };
    case 'production':
      return {
        auth: 'https://identitytoolkit.googleapis.com',
        firestore: 'https://firestore.googleapis.com',
        functions: 'https://northamerica-northeast1-orignagta.cloudfunctions.net',
        webApp: 'https://orignagta.web.app',
        projectId: 'orignagta',
      };
    case 'dev':
    default:
      return {
        auth: 'https://identitytoolkit.googleapis.com',
        firestore: 'https://firestore.googleapis.com',
        functions: 'https://northamerica-northeast1-orignagta-dev.cloudfunctions.net',
        webApp: 'https://orignagta-dev.web.app',
        projectId: 'orignagta-dev',
      };
  }
};

const envConfig = getEnvironmentConfig();

export const AUTH_EMULATOR = envConfig.auth;
export const FIRESTORE_EMULATOR = envConfig.firestore;
export const FUNCTIONS_EMULATOR = envConfig.functions;
export const WEB_APP_URL = envConfig.webApp;
export const PROJECT_ID = envConfig.projectId;
export const TEST_ENVIRONMENT = TEST_ENV;

/** Firestore REST API base path */
export const FIRESTORE_BASE = `${FIRESTORE_EMULATOR}/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

/** Default test password used by mega-seed.ts / seed-emulator.ts */
export const DEFAULT_PASS = 'REDACTED_TEST_PASSWORD';

/** Stripe test card that does NOT trigger 3DS */
export const STRIPE_CARD = {
  number: '4242424242424242',
  exp: '12/30',
  cvc: '123',
  name: 'Test Buyer',
  postalCode: 'M5V 3A8',
};

// Test accounts (from mega-seed.ts)
export const TEST_ACCOUNTS = {
  ADMIN_EMAIL: 'yr62813@gmail.com',
  ADMIN_PASS: 'REDACTED_TEST_PASSWORD',
  SELLER1_EMAIL: 'seller1@test.origna.ca',
  SELLER2_EMAIL: 'seller2@test.origna.ca',
  BUYER1_EMAIL: 'buyer1@test.origna.ca',
  BUYER2_EMAIL: 'buyer2@test.origna.ca',
  BUYER3_EMAIL: 'buyer3@test.origna.ca',
  SUSPENDED_EMAIL: 'suspended@test.origna.ca',
  NON_ONBOARDED_SELLER: 'seller9@test.origna.ca',
  // Convenience aliases used by many spec files
  SELLER_EMAIL: 'seller1@test.origna.ca',
  BUYER_EMAIL: 'buyer1@test.origna.ca',
  // Password aliases (all test accounts use the same password)
  BUYER_PASS: 'REDACTED_TEST_PASSWORD',
  BUYER2_PASS: 'REDACTED_TEST_PASSWORD',
  SELLER_PASS: 'REDACTED_TEST_PASSWORD',
};

// Products with good stock for parallel tests
export const TEST_PRODUCTS = {
  HIGH_STOCK: 'product_024',   // Budget Sticker Pack, ~500 stock, seller1
  DIGITAL: 'product_010',      // Digital product (if seeded)
  SELLER2: 'product_004',      // BC Cedar Incense Set, seller2
};

// ════════════════════════════════════════════════════════════════════
// INFRASTRUCTURE CHECK
// ════════════════════════════════════════════════════════════════════

export interface InfraStatus {
  auth: boolean | null;
  firestore: boolean | null;
  functions: boolean | null;
}

let infraCache: InfraStatus = { auth: null, firestore: null, functions: null };

/** Check if emulator infrastructure is available. Caches result. */
export async function checkInfrastructure(request: any): Promise<InfraStatus> {
  if (infraCache.auth === null) {
    const [authRes, firestoreRes, functionsRes] = await Promise.all([
      request.get(`${AUTH_EMULATOR}/`).catch(() => null),
      request.get(`${FIRESTORE_EMULATOR}/`).catch(() => null),
      request.get(`${FUNCTIONS_EMULATOR}/`).catch(() => null),
    ]);
    infraCache = {
      auth: !!authRes,
      firestore: !!firestoreRes,
      functions: !!functionsRes,
    };
    if (Object.values(infraCache).some(v => !v)) {
      console.log('⚠️  Some infrastructure is unavailable:');
      console.log(`   Auth: ${infraCache.auth ? '✅' : '❌'}`);
      console.log(`   Firestore: ${infraCache.firestore ? '✅' : '❌'}`);
      console.log(`   Functions: ${infraCache.functions ? '✅' : '❌'}`);
    }
  }
  return infraCache;
}

/** Reset infra cache (useful for test isolation) */
export function resetInfraCache() {
  infraCache = { auth: null, firestore: null, functions: null };
}

// ════════════════════════════════════════════════════════════════════
// SEED VALIDATION
// ════════════════════════════════════════════════════════════════════

let seedValidated = false;

/**
 * Verify that seed data exists in the Auth Emulator.
 * Call in beforeAll to fail-fast if seeds are missing.
 * @throws Error if no users found in Auth Emulator
 */
export async function ensureSeedData(): Promise<void> {
  if (seedValidated) return;

  // Try to sign in with a known seed account to verify users exist
  try {
    const res = await fetch(
      `${AUTH_EMULATOR}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: TEST_ACCOUNTS.BUYER1_EMAIL,
          password: DEFAULT_PASS,
          returnSecureToken: true,
        }),
      }
    );
    const data = await res.json();
    if (!data.idToken) {
      // Try seller1 as fallback (different seed scripts create different users)
      const res2 = await fetch(
        `${AUTH_EMULATOR}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            email: TEST_ACCOUNTS.SELLER1_EMAIL,
            password: DEFAULT_PASS,
            returnSecureToken: true,
          }),
        }
      );
      const data2 = await res2.json();
      if (!data2.idToken) {
        throw new Error(
          'NO SEED DATA: Auth Emulator has no test users.\n' +
          'Run: cd e2e && npx ts-node mega-seed.ts\n' +
          'Or:  cd e2e && npx ts-node seed-emulator.ts'
        );
      }
    }
    seedValidated = true;
  } catch (e) {
    if (e instanceof Error && e.message.startsWith('NO SEED DATA')) throw e;
    throw new Error(`Auth Emulator unreachable at ${AUTH_EMULATOR}: ${e}`);
  }
}

// ════════════════════════════════════════════════════════════════════
// FIREBASE AUTH — Sign In (with fail-fast)
// ════════════════════════════════════════════════════════════════════

export interface AuthData {
  idToken: string;
  refreshToken: string;
  localId: string;
  email: string;
  [key: string]: any;
}

/**
 * Sign in to Firebase Auth Emulator and return auth data with idToken.
 *
 * FAIL-FAST: Throws immediately if sign-in fails (no token returned).
 * This prevents the cascade of "Unauthenticated" errors that happen when
 * `Bearer undefined` is sent to the Functions Emulator.
 *
 * @param email - User email
 * @param password - User password (defaults to DEFAULT_PASS)
 * @returns Auth data including idToken, localId, refreshToken
 * @throws Error if sign-in fails (user doesn't exist, wrong password, etc.)
 */
export async function signIn(email: string, password: string = DEFAULT_PASS): Promise<AuthData> {
  const res = await fetch(
    `${AUTH_EMULATOR}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fake-api-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    }
  );
  const data = await res.json();

  // ═══ FAIL-FAST: No silent failures ═══
  if (!data.idToken) {
    const errMsg = data.error?.message || 'Unknown error';
    throw new Error(
      `signIn FAILED for ${email}: ${errMsg}.\n` +
      `Ensure seed data exists. Run: cd e2e && npx ts-node mega-seed.ts`
    );
  }

  // Force emailVerified=true (emulator tokens may not have it)
  try {
    const upd = await fetch(
      `${AUTH_EMULATOR}/identitytoolkit.googleapis.com/v1/accounts:update?key=fake-api-key`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ idToken: data.idToken, emailVerified: true, returnSecureToken: true }),
      }
    );
    const u = await upd.json();
    if (u.idToken) {
      data.idToken = u.idToken;
      data.refreshToken = u.refreshToken || data.refreshToken;
    }
  } catch {
    // emailVerified update failed — non-critical, continue with original token
  }

  return data as AuthData;
}

// ════════════════════════════════════════════════════════════════════
// FIREBASE AUTH — Create User
// ════════════════════════════════════════════════════════════════════

/**
 * Create a new user in the Auth Emulator and optionally write a Firestore user doc.
 * If user already exists (EMAIL_EXISTS), signs in instead.
 */
export async function createTestUser(
  email: string,
  password: string,
  displayName: string,
  roles: string[] = ['buyer'],
  writeFirestoreDoc = true
): Promise<{ uid: string; idToken: string; [key: string]: any }> {
  const signUpRes = await fetch(
    `${AUTH_EMULATOR}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, displayName, returnSecureToken: true }),
    }
  );
  const signUpData = await signUpRes.json();

  if (signUpData.error) {
    // User already exists — just sign in
    if (signUpData.error.message?.includes('EMAIL_EXISTS')) {
      const authData = await signIn(email, password);
      return { ...authData, uid: authData.localId };
    }
    throw new Error(`createTestUser: ${signUpData.error.message}`);
  }

  const uid = signUpData.localId;

  // Mark email verified
  if (signUpData.idToken) {
    await fetch(
      `${AUTH_EMULATOR}/identitytoolkit.googleapis.com/v1/accounts:update?key=fake-api-key`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ idToken: signUpData.idToken, emailVerified: true, returnSecureToken: true }),
      }
    );
  }

  // Write Firestore user doc
  if (writeFirestoreDoc) {
    await writeDoc(`users/${uid}`, {
      uid,
      email,
      name: displayName,
      roles,
      address: {
        street: '100 Test St',
        apartment: '',
        city: 'Toronto',
        state: 'ON',
        postalCode: 'M5V 3A8',
        country: 'Canada',
        phoneNumber: '+14165550099',
        isDefault: true,
        label: 'Home',
      },
      createdAt: new Date().toISOString(),
    });
  }

  return { uid, idToken: signUpData.idToken, ...signUpData };
}

// ════════════════════════════════════════════════════════════════════
// FIREBASE FUNCTIONS — Callable Invocation
// ════════════════════════════════════════════════════════════════════

/**
 * Call a Firebase Callable Function via the Functions Emulator.
 * Returns the raw response body (may contain .error or .result).
 */
export async function callCallable(fn: string, data: any, token: string): Promise<any> {
  const res = await fetch(`${FUNCTIONS_EMULATOR}/${fn}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
    },
    body: JSON.stringify({ data }),
  });
  return res.json();
}

/**
 * Call a callable function and throw if it returns an error.
 * @returns The result (unwrapped from body.result)
 * @throws Error with function name and error message
 */
export async function callOk(fn: string, data: any, token: string): Promise<any> {
  const body = await callCallable(fn, data, token);
  if (body.error) {
    throw new Error(`${fn} failed: ${body.error.message || JSON.stringify(body.error)}`);
  }
  return body.result || body;
}

/**
 * Normalize a Firebase/gRPC error status to a Firebase callable error code.
 * Firebase Functions Emulator returns { status: "PERMISSION_DENIED" } (gRPC style)
 * but tests expect { code: "permission-denied" } (Firebase SDK style).
 */
function normalizeErrorCode(error: any): { code: string; message: string } {
  const STATUS_TO_CODE: Record<string, string> = {
    'PERMISSION_DENIED': 'permission-denied',
    'FAILED_PRECONDITION': 'failed-precondition',
    'NOT_FOUND': 'not-found',
    'UNAUTHENTICATED': 'unauthenticated',
    'INVALID_ARGUMENT': 'invalid-argument',
    'ALREADY_EXISTS': 'already-exists',
    'RESOURCE_EXHAUSTED': 'resource-exhausted',
    'CANCELLED': 'cancelled',
    'UNAVAILABLE': 'unavailable',
    'INTERNAL': 'internal',
    'DEADLINE_EXCEEDED': 'deadline-exceeded',
    'UNIMPLEMENTED': 'unimplemented',
    'OUT_OF_RANGE': 'out-of-range',
    'DATA_LOSS': 'data-loss',
    'ABORTED': 'aborted',
  };
  const code = error.code || STATUS_TO_CODE[error.status] || error.status?.toLowerCase()?.replace(/_/g, '-') || 'unknown';
  return { code, message: error.message || error.details || '' };
}

/**
 * Call a callable function expecting it to fail.
 * @returns The error object { code, message } — code is always Firebase-style (e.g. "permission-denied")
 */
export async function callExpectError(
  fn: string,
  data: any,
  token: string
): Promise<{ code: string; message: string }> {
  const body = await callCallable(fn, data, token);
  if (body.error) return normalizeErrorCode(body.error);
  if (body.result?.error) return normalizeErrorCode(body.result.error);
  return {
    code: 'unexpected-success',
    message: `Expected ${fn} to fail but it succeeded: ${JSON.stringify(body)}`,
  };
}

// ════════════════════════════════════════════════════════════════════
// FIRESTORE REST API — CRUD Operations
// ════════════════════════════════════════════════════════════════════

/**
 * Read a Firestore document by its full path (e.g. "orders/order123").
 * Returns raw Firestore REST response, or null if not found.
 */
export async function readDoc(path: string): Promise<any> {
  const res = await fetch(`${FIRESTORE_BASE}/${path}`, {
    headers: { 'Authorization': 'Bearer owner' },
  });
  if (!res.ok) return null;
  return res.json();
}

/**
 * Write/merge fields into a Firestore document.
 * Uses updateMask to perform partial updates (not replace).
 * Values are auto-converted to Firestore format via toFirestoreFields.
 */
export async function writeDoc(path: string, fields: Record<string, any>): Promise<boolean> {
  const fieldPaths = Object.keys(fields).map(k => `updateMask.fieldPaths=${k}`).join('&');
  const res = await fetch(`${FIRESTORE_BASE}/${path}?${fieldPaths}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer owner' },
    body: JSON.stringify({ fields: toFirestoreFields(fields) }),
  });
  return res.ok;
}

/**
 * Patch a Firestore document with RAW Firestore-format fields.
 * Use this when you already have fields in { stringValue: "x" } format.
 * For auto-conversion, use writeDoc() instead.
 */
export async function patchDoc(
  collectionOrPath: string,
  docIdOrFields: string | any,
  fieldsOrUndefined?: any
): Promise<boolean> {
  let path: string;
  let fields: any;

  if (fieldsOrUndefined !== undefined) {
    // patchDoc(collection, docId, fields) — 3-arg form
    path = `${collectionOrPath}/${docIdOrFields}`;
    fields = fieldsOrUndefined;
  } else {
    // patchDoc(path, fields) — 2-arg form
    path = collectionOrPath;
    fields = docIdOrFields;
  }

  const fieldPaths = Object.keys(fields).map(f => `updateMask.fieldPaths=${f}`).join('&');
  const res = await fetch(`${FIRESTORE_BASE}/${path}?${fieldPaths}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer owner' },
    body: JSON.stringify({ fields }),
  });
  return res.ok;
}

/** Delete a Firestore document by path */
export async function deleteDoc(path: string): Promise<boolean> {
  const res = await fetch(`${FIRESTORE_BASE}/${path}`, {
    method: 'DELETE',
    headers: { 'Authorization': 'Bearer owner' },
  });
  return res.ok;
}

/** List documents in a collection */
export async function listDocs(collectionPath: string, pageSize = 100): Promise<any[]> {
  const res = await fetch(`${FIRESTORE_BASE}/${collectionPath}?pageSize=${pageSize}`, {
    headers: { 'Authorization': 'Bearer owner' },
  });
  if (!res.ok) return [];
  const body = await res.json();
  return (body.documents || []).map(parseDoc);
}

/** List subcollection documents */
export async function listSubcollection(
  parentPath: string,
  subcollection: string
): Promise<Array<{ id: string; [key: string]: any }>> {
  const res = await fetch(`${FIRESTORE_BASE}/${parentPath}/${subcollection}?pageSize=100`, {
    headers: { 'Authorization': 'Bearer owner' },
  });
  if (!res.ok) return [];
  const body = await res.json();
  return (body.documents || []).map((doc: any) => ({
    id: doc.name?.split('/').pop(),
    ...parseDoc(doc),
  }));
}

// ════════════════════════════════════════════════════════════════════
// FIRESTORE VALUE CONVERSION
// ════════════════════════════════════════════════════════════════════

/** Convert a JS object to Firestore REST fields format */
export function toFirestoreFields(obj: any): any {
  const f: any = {};
  for (const [k, v] of Object.entries(obj)) f[k] = toFsVal(v);
  return f;
}

/** Convert a single JS value to Firestore REST value format */
export function toFsVal(v: any): any {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toFsVal) } };
  if (typeof v === 'object') return { mapValue: { fields: toFirestoreFields(v) } };
  return { stringValue: String(v) };
}

/** Shorthand: create a Firestore stringValue */
export function sv(val: string) { return { stringValue: val }; }
/** Shorthand: create a Firestore integerValue */
export function iv(val: number) { return { integerValue: String(val) }; }
/** Shorthand: create a Firestore booleanValue */
export function bv(val: boolean) { return { booleanValue: val }; }

/** Parse a single Firestore REST value back to JS */
export function parseVal(v: any): any {
  if (!v) return null;
  if (v.stringValue !== undefined) return v.stringValue;
  if (v.integerValue !== undefined) return parseInt(v.integerValue);
  if (v.doubleValue !== undefined) return v.doubleValue;
  if (v.booleanValue !== undefined) return v.booleanValue;
  if (v.nullValue !== undefined) return null;
  if (v.timestampValue) return v.timestampValue;
  if (v.arrayValue) return (v.arrayValue.values || []).map(parseVal);
  if (v.mapValue) {
    const o: any = {};
    for (const [k, val] of Object.entries(v.mapValue.fields || {})) o[k] = parseVal(val);
    return o;
  }
  return v;
}

/** Parse a full Firestore REST document to a plain JS object */
export function parseDoc(doc: any): any {
  if (!doc?.fields) return null;
  const r: any = {};
  for (const [k, v] of Object.entries(doc.fields)) r[k] = parseVal(v);
  return r;
}

// ════════════════════════════════════════════════════════════════════
// CHECKOUT & ORDER HELPERS
// ════════════════════════════════════════════════════════════════════

/** Build a valid checkout payload from live Firestore product + buyer data */
export async function buildCheckoutPayload(
  buyerUid: string,
  productId: string,
  quantity = 1
): Promise<{ data: any; product: any; buyer: any }> {
  const prodDoc = await readDoc(`products/${productId}`);
  const product = parseDoc(prodDoc);
  if (!product) throw new Error(`Product ${productId} not found in Firestore. Ensure seed data exists.`);

  const buyerDoc = await readDoc(`users/${buyerUid}`);
  const buyer = parseDoc(buyerDoc);
  const address = buyer?.address || {};

  const data = {
    userId: buyerUid,
    items: [{
      productId,
      name: product.name,
      price: product.price,
      quantity,
      sellerId: product.sellerId,
      imageUrls: product.imageUrls || [`https://picsum.photos/seed/${product.id ?? 'default'}/400/400`],
    }],
    subtotal: +(product.price * quantity).toFixed(2),
    shippingAddress: {
      street: address.street || '100 King St W',
      apartment: address.apartment || '',
      city: address.city || 'Toronto',
      state: address.state || 'ON',
      postalCode: address.postalCode || 'M5X 1A9',
      country: address.country || 'CA',
      phoneNumber: address.phoneNumber || '+14165550000',
    },
  };
  return { data, product, buyer };
}

/** Build multi-seller checkout payload */
export async function buildMultiSellerPayload(
  buyerUid: string,
  items: { productId: string; quantity: number }[]
): Promise<any> {
  const buyerDoc = await readDoc(`users/${buyerUid}`);
  const buyer = parseDoc(buyerDoc);
  const address = buyer?.address || {};

  const cartItems: any[] = [];
  let subtotal = 0;
  for (const { productId, quantity } of items) {
    const prodDoc = await readDoc(`products/${productId}`);
    const product = parseDoc(prodDoc);
    if (!product) throw new Error(`Product ${productId} not found in Firestore.`);
    cartItems.push({
      productId,
      name: product.name,
      price: product.price,
      quantity,
      sellerId: product.sellerId,
      imageUrls: product.imageUrls || [`https://picsum.photos/seed/${product.id ?? 'default'}/400/400`],
    });
    subtotal += product.price * quantity;
  }

  return {
    userId: buyerUid,
    items: cartItems,
    subtotal: +subtotal.toFixed(2),
    shippingAddress: {
      street: address.street || '100 King St W',
      apartment: address.apartment || '',
      city: address.city || 'Toronto',
      state: address.state || 'ON',
      postalCode: address.postalCode || 'M5X 1A9',
      country: address.country || 'CA',
      phoneNumber: address.phoneNumber || '+14165550000',
    },
  };
}

/** Create an order via checkout (API only, no Stripe payment) */
export async function createOrder(
  buyerEmail: string,
  productId: string,
  quantity = 1,
  password = DEFAULT_PASS
): Promise<{ orderId: string; auth: AuthData; checkoutUrl: string }> {
  const auth = await signIn(buyerEmail, password);
  const { data } = await buildCheckoutPayload(auth.localId, productId, quantity);
  const result = await callOk('create_checkout_session', data, auth.idToken);
  return { orderId: result.orderId as string, auth, checkoutUrl: result.checkoutUrl };
}

/** Force an order to a specific status via direct Firestore write (test setup only) */
export async function forceOrderStatus(
  orderId: string,
  status: string,
  extraFields: Record<string, any> = {}
): Promise<void> {
  await writeDoc(`orders/${orderId}`, { orderStatus: status, ...extraFields });
}

/** Poll until a Firestore doc field matches expected value */
export async function pollDocField(
  path: string,
  field: string,
  expected: any,
  maxMs = 15_000
): Promise<any> {
  const start = Date.now();
  while (Date.now() - start < maxMs) {
    const doc = await readDoc(path);
    if (doc) {
      const parsed = parseDoc(doc);
      if (parsed?.[field] === expected) return parsed;
    }
    await new Promise(r => setTimeout(r, 1_000));
  }
  const doc = await readDoc(path);
  return doc ? parseDoc(doc) : null;
}

/** Wait for order to reach a target status — polls Firestore */
export async function waitForOrderStatus(
  orderId: string,
  targetStatuses: string[],
  fieldOrMaxMs: string | number = 'orderStatus',
  maxWaitMs = 60_000
): Promise<any> {
  const field = typeof fieldOrMaxMs === 'string' ? fieldOrMaxMs : 'orderStatus';
  const timeout = typeof fieldOrMaxMs === 'number' ? fieldOrMaxMs : maxWaitMs;

  const start = Date.now();
  let lastOrder: any = null;
  while (Date.now() - start < timeout) {
    const doc = await readDoc(`orders/${orderId}`);
    if (doc) {
      const order = parseDoc(doc);
      lastOrder = order;
      if (order && targetStatuses.includes(order[field])) return order;
    }
    await new Promise(r => setTimeout(r, 2_000));
  }
  // Throw on timeout — callers must handle this explicitly
  const currentStatus = lastOrder ? lastOrder[field] : 'unknown';
  throw new Error(
    `waitForOrderStatus timeout: order ${orderId} expected ${field} in [${targetStatuses}] but got "${currentStatus}" after ${timeout}ms`
  );
}

// ════════════════════════════════════════════════════════════════════
// STRIPE CHECKOUT — Headless-safe page interaction
// ════════════════════════════════════════════════════════════════════

/**
 * Fill and submit Stripe Checkout hosted page.
 * Handles:
 * - Email field (if visible)
 * - Card number, expiry, CVC
 * - Billing name and postal code (if visible)
 * - Link / verification modal dismissal (headless-safe)
 * - Pay button click
 *
 * @param page - Playwright Page object
 * @param email - Buyer email for Stripe Checkout
 * @param card - Card details (defaults to STRIPE_CARD)
 */
export async function fillStripeCheckout(
  page: any,
  email: string,
  card = STRIPE_CARD
): Promise<void> {
  await page.waitForLoadState('networkidle', { timeout: 30_000 }).catch(() => {});

  // Dismiss any Link login / verification modal overlay
  // Stripe sometimes shows a "Log in to Link" popup that blocks the form
  await dismissStripeModals(page);

  // Fill email if visible (Stripe Checkout may or may not show this)
  const emailInput = page.locator('#email, input[name="email"]').first();
  if (await emailInput.isVisible({ timeout: 5_000 }).catch(() => false)) {
    // Use a random email that Stripe Link won't recognize
    // Stripe Link intercepts known emails and shows SMS verification, blocking the form
    const safeEmail = `test-${Date.now()}-${Math.random().toString(36).slice(2, 8)}@origna-test.ca`;
    await emailInput.fill(safeEmail);
    await page.waitForTimeout(1_500);
    
    // Check if Stripe Link SMS verification appeared — if so, dismiss it
    const smsInput = page.locator('[data-testid="sms-code-input-0"]').first();
    const smsVisible = await smsInput.isVisible({ timeout: 3_000 }).catch(() => false);
    if (smsVisible) {
      console.log('⚠️ Stripe Link SMS verification detected — dismissing...');
      // Try dismiss buttons for Stripe Link
      const dismissSelectors = [
        'button:has-text("Pay another way")',
        'button:has-text("Not now")',
        'button:has-text("Cancel")',
        '[data-testid="link-dismiss"]',
        '[aria-label="Close"]',
        'button:has-text("Send code to email instead")',
      ];
      for (const sel of dismissSelectors) {
        const el = page.locator(sel).first();
        if (await el.isVisible({ timeout: 1_000 }).catch(() => false)) {
          console.log(`   → Clicking: ${sel}`);
          await el.click().catch(() => {});
          await page.waitForTimeout(1_500);
          break;
        }
      }
      // If still on SMS screen, navigate back
      const stillSms = await page.locator('[data-testid="sms-code-input-0"]').first().isVisible({ timeout: 2_000 }).catch(() => false);
      if (stillSms) {
        console.log('   → SMS screen persists — pressing Escape and going back');
        await page.keyboard.press('Escape').catch(() => {});
        await page.waitForTimeout(1_000);
        await page.goBack().catch(() => {});
        await page.waitForTimeout(2_000);
        // Re-navigate to checkout URL
        const url = page.url();
        if (url.includes('checkout.stripe.com')) {
          await page.reload();
          await page.waitForLoadState('networkidle', { timeout: 15_000 }).catch(() => {});
        }
        // Re-fill with safe email
        const emailField2 = page.locator('#email, input[name="email"]').first();
        if (await emailField2.isVisible({ timeout: 5_000 }).catch(() => false)) {
          await emailField2.fill(safeEmail);
          await page.waitForTimeout(1_500);
        }
      }
    }
    
    // After filling email, Stripe may show a Link modal — dismiss it
    await dismissStripeModals(page);
  }

  // Stripe's new checkout UI may require selecting "Card" payment method
  // The card fields are hidden behind a radio/tab/accordion until "Card" is clicked
  const cardField = page.locator('#cardNumber, input[name="cardNumber"]').first();
  const cardVisible = await cardField.isVisible({ timeout: 3_000 }).catch(() => false);
  if (!cardVisible) {
    // Click the Card radio/accordion to expand card form
    // Stripe 2025+ uses radio button: #payment-method-accordion-item-title-card
    const cardRadio = page.locator('#payment-method-accordion-item-title-card').first();
    if (await cardRadio.isVisible({ timeout: 3_000 }).catch(() => false)) {
      console.log('   → Clicking Card radio accordion item');
      // Click the label/parent rather than the radio itself for better interaction
      const cardLabel = page.locator('label[for="payment-method-accordion-item-title-card"], #payment-method-accordion-item-title-card').first();
      await cardLabel.click({ force: true }).catch(() => {});
      await page.waitForTimeout(3_000);
    } else {
      // Fallback to other selectors
      const cardSelectors = [
        '[data-testid="card-accordion-item-button"]',
        'button:has-text("Card")',
        'button:has-text("Pay with card")',
        '[data-testid="card-tab"]',
        'input[value="card"]',
        'div[data-testid="card-accordion-item"]',
        'text=Card >> nth=0',
      ];
      for (const sel of cardSelectors) {
        const el = page.locator(sel).first();
        if (await el.isVisible({ timeout: 1_500 }).catch(() => false)) {
          console.log(`   → Clicking Card payment method: ${sel}`);
          await el.click().catch(() => {});
          await page.waitForTimeout(2_000);
          break;
        }
      }
    }
    // Try dismiss modals again after clicking
    await dismissStripeModals(page);
  }

  // Wait for card number field to become visible (with extended timeout)
  const cardReady = await cardField.isVisible({ timeout: 20_000 }).catch(() => false);
  if (!cardReady) {
    // Fallback: try iframe-based Stripe Elements (PCI compliance iframes)
    const allFrames = page.frames();
    let foundInFrame = false;
    for (let i = 0; i < allFrames.length; i++) {
      const f = allFrames[i];
      try {
        const cardInput = f.locator('input[name="cardnumber"], input[autocomplete="cc-number"], input[name="number"], input[data-elements-stable-field-name="cardNumber"]').first();
        if (await cardInput.isVisible({ timeout: 2_000 }).catch(() => false)) {
          await cardInput.fill(card.number);
          // Find expiry and CVC in sibling frames
          for (let j = 0; j < allFrames.length; j++) {
            if (j === i) continue;
            const expInput = allFrames[j].locator('input[name="exp-date"], input[autocomplete="cc-exp"]').first();
            if (await expInput.isVisible({ timeout: 1_000 }).catch(() => false)) await expInput.fill(card.exp);
            const cvcInput = allFrames[j].locator('input[name="cvc"], input[autocomplete="cc-csc"]').first();
            if (await cvcInput.isVisible({ timeout: 1_000 }).catch(() => false)) await cvcInput.fill(card.cvc);
          }
          foundInFrame = true;
          return await submitStripePayment(page, card);
        }
      } catch { /* frame not accessible */ }
    }
    if (!foundInFrame) {
      await page.screenshot({ path: '/tmp/stripe-checkout-debug.png', fullPage: true }).catch(() => {});
      throw new Error(`Stripe card field not found. URL: ${page.url()}`);
    }
  } else {
    await cardField.fill(card.number);
  }

  // Fill expiry
  await page.locator('#cardExpiry, input[name="cardExpiry"]').first().fill(card.exp);

  // Fill CVC
  await page.locator('#cardCvc, input[name="cardCvc"]').first().fill(card.cvc);

  // Fill billing name if visible
  const nameField = page.locator('#billingName, input[name="billingName"]').first();
  if (await nameField.isVisible({ timeout: 2_000 }).catch(() => false)) {
    await nameField.fill(card.name);
  }

  // Fill phone number if visible (Stripe sometimes requires it)
  const phoneField = page.locator('#phoneNumber, input[name="phoneNumber"]').first();
  if (await phoneField.isVisible({ timeout: 1_000 }).catch(() => false)) {
    await phoneField.fill('+14165550000');
  }

  // Fill postal code if visible
  const postalField = page.locator('#billingPostalCode, input[name="billingPostalCode"]').first();
  if (await postalField.isVisible({ timeout: 2_000 }).catch(() => false)) {
    await postalField.fill(card.postalCode);
  }

  // Dismiss any modals that appeared during form fill
  await dismissStripeModals(page);

  // Click Pay button and wait for Stripe to process the payment
  const payBtn = page.locator(
    '[data-testid="hosted-payment-submit-button"], .SubmitButton, button[type="submit"]'
  ).first();
  await payBtn.waitFor({ state: 'visible', timeout: 10_000 });
  await payBtn.click();

  // Wait for navigation away from Stripe Checkout (payment processed + redirect)
  // This is CRITICAL — without this, the webhook may never fire
  try {
    await page.waitForURL(
      (url: URL) => !url.hostname.includes('checkout.stripe.com'),
      { timeout: 45_000 }
    );
  } catch {
    // Check if there's an error on the Stripe page
    const errorEl = page.locator('.FieldError, [data-testid="error-message"], .p-Alert, [role="alert"]').first();
    const hasError = await errorEl.isVisible({ timeout: 2_000 }).catch(() => false);
    if (hasError) {
      const text = await errorEl.textContent().catch(() => 'unknown');
      throw new Error(`Stripe payment failed on checkout page: ${text}`);
    }
    console.log('⚠️ Still on Stripe Checkout after 45s — payment may still be processing');
  }
}

/**
 * Submit Stripe payment — fill name, postal, and click Pay.
 * Used when card details were filled through iframe path.
 */
async function submitStripePayment(page: any, card: any): Promise<void> {
  const nameField = page.locator('#billingName, input[name="billingName"]').first();
  if (await nameField.isVisible({ timeout: 2_000 }).catch(() => false)) {
    await nameField.fill(card.name);
  }
  const postalField = page.locator('#billingPostalCode, input[name="billingPostalCode"]').first();
  if (await postalField.isVisible({ timeout: 2_000 }).catch(() => false)) {
    await postalField.fill(card.postalCode);
  }
  await dismissStripeModals(page);
  const payBtn = page.locator(
    '[data-testid="hosted-payment-submit-button"], .SubmitButton, button[type="submit"]'
  ).first();
  await payBtn.waitFor({ state: 'visible', timeout: 10_000 });
  await payBtn.click();
}

/**
 * Dismiss Stripe modals that may block the checkout form in headless mode.
 * Handles:
 * - Link login modal ("Log in to Link")
 * - Verification modal (VerificationModal)
 * - 3DS authentication iframe (approve automatically)
 * - CAPTCHA / phone verification
 */
export async function dismissStripeModals(page: any): Promise<void> {
  // 1. Dismiss "Link" login popup — click "Not now" or close button
  const linkDismiss = page.locator(
    'button:has-text("Not now"), ' +
    'button:has-text("Pay another way"), ' +
    'button:has-text("Cancel"), ' +
    '[data-testid="link-dismiss"], ' +
    '.LinkModal--close, ' +
    '[aria-label="Close"]'
  ).first();
  if (await linkDismiss.isVisible({ timeout: 2_000 }).catch(() => false)) {
    await linkDismiss.click().catch(() => {});
    await page.waitForTimeout(500);
  }

  // 2. Handle 3DS authentication test iframe — click "Complete" or "Approve"
  const threeDSFrame = page.frameLocator('iframe[name*="stripe-challenge"], iframe[name*="__privateStripeFrame"]').first();
  try {
    const completeBtn = threeDSFrame.locator(
      'button:has-text("Complete"), button:has-text("Approve"), #test-source-authorize-3ds'
    ).first();
    if (await completeBtn.isVisible({ timeout: 1_000 }).catch(() => false)) {
      await completeBtn.click().catch(() => {});
      await page.waitForTimeout(1_000);
    }
  } catch {
    // No 3DS frame — expected for 4242 card
  }

  // 3. Dismiss generic overlays / modal backdrops
  const overlay = page.locator('.Modal-overlay, .VerificationModal, [data-testid="modal-overlay"]').first();
  if (await overlay.isVisible({ timeout: 500 }).catch(() => false)) {
    // Press Escape to dismiss modal
    await page.keyboard.press('Escape').catch(() => {});
    await page.waitForTimeout(300);
  }
}

/**
 * Full checkout + pay flow: create checkout session → navigate to Stripe → fill & submit.
 * Returns orderId and checkoutUrl.
 */
export async function fullCheckoutAndPay(
  page: any,
  buyerEmail: string,
  productId: string,
  quantity = 1,
  password = DEFAULT_PASS
): Promise<{ orderId: string; checkoutUrl: string }> {
  const auth = await signIn(buyerEmail, password);
  const { data } = await buildCheckoutPayload(auth.localId, productId, quantity);
  const result = await callOk('create_checkout_session', data, auth.idToken);

  if (!result.orderId) throw new Error(`Checkout failed: no orderId returned`);
  if (!result.checkoutUrl) throw new Error(`Checkout failed: no checkoutUrl returned`);

  // Navigate to Stripe Checkout and fill the form
  await page.goto(result.checkoutUrl);
  await fillStripeCheckout(page, buyerEmail);

  // Wait a bit for webhook processing
  await page.waitForTimeout(5_000);

  return { orderId: result.orderId, checkoutUrl: result.checkoutUrl };
}

/**
 * Full multi-seller checkout + pay flow.
 */
export async function fullMultiSellerCheckoutAndPay(
  page: any,
  buyerEmail: string,
  items: { productId: string; quantity: number }[],
  password = DEFAULT_PASS
): Promise<{ orderId: string }> {
  const auth = await signIn(buyerEmail, password);
  const payload = await buildMultiSellerPayload(auth.localId, items);
  const result = await callOk('create_checkout_session', payload, auth.idToken);

  if (!result.orderId) throw new Error(`Multi-seller checkout failed: no orderId`);

  await page.goto(result.checkoutUrl);
  await fillStripeCheckout(page, buyerEmail);
  await page.waitForTimeout(5_000);

  return { orderId: result.orderId };
}

// ════════════════════════════════════════════════════════════════════
// CONVENIENCE HELPERS — Common patterns used across spec files
// ════════════════════════════════════════════════════════════════════

/** Read and parse an order document. Returns null if not found. */
export async function getOrder(orderId: string): Promise<any> {
  const doc = await readDoc(`orders/${orderId}`);
  return doc ? parseDoc(doc) : null;
}

/** Read product stock quantity. Returns 0 if product not found. */
export async function getProductStock(productId: string): Promise<number> {
  const doc = await readDoc(`products/${productId}`);
  return doc ? (parseDoc(doc)?.stockQuantity ?? 0) : 0;
}

/** Generate a unique suffix for parallel test isolation */
export function uid(): string {
  return `${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
}

/**
 * Run a Firestore structured query (REST API).
 * @param structuredQuery — Firestore REST structured query object
 * @returns Array of parsed documents
 */
export async function queryFirestore(structuredQuery: any): Promise<any[]> {
  const res = await fetch(
    `${FIRESTORE_EMULATOR}/v1/projects/${PROJECT_ID}/databases/(default)/documents:runQuery`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer owner' },
      body: JSON.stringify({ structuredQuery }),
    }
  );
  if (!res.ok) return [];
  const results = await res.json();
  return (Array.isArray(results) ? results : [])
    .filter((r: any) => r.document)
    .map((r: any) => ({
      id: r.document.name?.split('/').pop(),
      ...parseDoc(r.document),
    }));
}

// ════════════════════════════════════════════════════════════════════
// MISSING UTILITIES — Referenced by multiple spec files
// Added to fix import errors in:
//   warehouse-multi-location, stock-notif, order-cancellation-refund,
//   shipping-approval, multi-seller-orders, order-lifecycle,
//   edge-cases-security, shipping-calculation, rate-limiting
// ════════════════════════════════════════════════════════════════════

/** Hardcoded UIDs for stable test accounts (from mega-seed.ts) */
export const TEST_UIDS = {
  ADMIN: 'admin_uid_placeholder',
  SELLER: 'seller1_uid_placeholder',
  SELLER2: 'seller2_uid_placeholder',
  BUYER: 'buyer1_uid_placeholder',
  BUYER2: 'buyer2_uid_placeholder',
};

// Resolve UIDs lazily on first call (sign in to get localId)
let _uidsResolved = false;
async function resolveTestUids(): Promise<void> {
  if (_uidsResolved) return;
  try {
    const [admin, seller, seller2, buyer, buyer2] = await Promise.all([
      signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS),
      signIn(TEST_ACCOUNTS.SELLER1_EMAIL, DEFAULT_PASS),
      signIn(TEST_ACCOUNTS.SELLER2_EMAIL, DEFAULT_PASS),
      signIn(TEST_ACCOUNTS.BUYER1_EMAIL, DEFAULT_PASS),
      signIn(TEST_ACCOUNTS.BUYER2_EMAIL, DEFAULT_PASS),
    ]);
    TEST_UIDS.ADMIN = admin.localId;
    TEST_UIDS.SELLER = seller.localId;
    TEST_UIDS.SELLER2 = seller2.localId;
    TEST_UIDS.BUYER = buyer.localId;
    TEST_UIDS.BUYER2 = buyer2.localId;
    _uidsResolved = true;
  } catch (e) {
    console.warn('resolveTestUids failed:', e);
  }
}

/**
 * Read a Firestore document and return parsed result (with optional auth token).
 * Unlike readDoc which returns raw Firestore format, this returns parsed JS object.
 * @param path - Full document path (e.g. "products/product_001")
 * @param token - Optional auth token for documents with security rules
 */
export async function getDoc(path: string, token?: string): Promise<any> {
  const headers: Record<string, string> = {};
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  } else {
    headers['Authorization'] = 'Bearer owner';
  }
  const res = await fetch(`${FIRESTORE_BASE}/${path}`, { headers });
  if (!res.ok) return null;
  const doc = await res.json();
  return parseDoc(doc);
}

/**
 * Sign in as the seller who owns a given product (by seller UID).
 * Resolves the seller's email from their Firestore user doc, then signs in.
 */
export async function getSellerAuth(sellerId: string): Promise<AuthData> {
  await resolveTestUids();

  // Map known seller UIDs to their emails
  if (sellerId === TEST_UIDS.SELLER) return signIn(TEST_ACCOUNTS.SELLER1_EMAIL, DEFAULT_PASS);
  if (sellerId === TEST_UIDS.SELLER2) return signIn(TEST_ACCOUNTS.SELLER2_EMAIL, DEFAULT_PASS);
  if (sellerId === TEST_UIDS.ADMIN) return signIn(TEST_ACCOUNTS.ADMIN_EMAIL, TEST_ACCOUNTS.ADMIN_PASS);

  // Fallback: read user doc to find email
  const userDoc = await getDoc(`users/${sellerId}`);
  if (userDoc?.email) return signIn(userDoc.email, DEFAULT_PASS);

  throw new Error(`getSellerAuth: cannot resolve seller email for UID ${sellerId}`);
}

/**
 * Create a dummy product in Firestore for testing.
 * @param sellerId - Seller UID
 * @param prefix - Prefix for product name (e.g. 'A', 'B')
 * @param productId - Document ID for the product
 */
export async function createDummyProduct(
  sellerId: string,
  prefix: string,
  productId: string,
): Promise<void> {
  await writeDoc(`products/${productId}`, {
    sellerId,
    name: `E2E ${prefix} Product ${productId}`,
    description: 'Auto-created for E2E testing',
    price: 19.99,
    stockQuantity: 200,
    categoryId: '1',
    imageUrls: ['https://picsum.photos/400'],
    keywords: ['e2e', 'test'],
    isActive: true,
    lifecycleStatus: 'active',
    dateCreated: new Date().toISOString(),
    shippingConfig: {
      standardDelivery: true,
      expressDelivery: false,
      weightKg: 0.5,
    },
    shipFromCity: 'Toronto',
    shipFromProvince: 'ON',
  });
}

/** Cache for discovered products */
let _productCache: any[] | null = null;

/**
 * Discover available products from Firestore (cached).
 * Returns an array of parsed product objects with their IDs.
 */
export async function discoverProducts(token?: string): Promise<any[]> {
  if (_productCache) return _productCache;

  const results = await queryFirestore({
    from: [{ collectionId: 'products' }],
    where: {
      fieldFilter: {
        field: { fieldPath: 'isActive' },
        op: 'EQUAL',
        value: { booleanValue: true },
      },
    },
    limit: 30,
  });

  _productCache = results;
  return results;
}

/** Invalidate the product discovery cache */
export function invalidateProductCache(): void {
  _productCache = null;
}

/**
 * Get a test product suitable for checkout/testing.
 * Returns a product with stock > 0 that the given buyer can purchase.
 * @param token - Auth token
 * @param buyerUid - Buyer UID (to avoid self-purchase)
 */
export async function getTestProduct(token: string, buyerUid: string): Promise<any> {
  const products = await discoverProducts(token);

  // Find a product NOT owned by the buyer with stock > 0
  const suitable = products.find(
    (p: any) => p.sellerId !== buyerUid && (p.stockQuantity ?? 0) > 0
  );

  if (suitable) return suitable;

  // Fallback to HIGH_STOCK product
  const fallback = await getDoc(`products/${TEST_PRODUCTS.HIGH_STOCK}`);
  if (fallback) return { ...fallback, id: TEST_PRODUCTS.HIGH_STOCK };

  throw new Error('getTestProduct: no suitable product found');
}

/**
 * Ensure two products from different sellers exist and are available.
 * Returns [productA, productB] from different sellers.
 */
export async function ensureTwoSellerProducts(token: string): Promise<[any, any]> {
  const products = await discoverProducts(token);

  // Group by sellerId and pick one from each
  const bySeller = new Map<string, any>();
  for (const p of products) {
    if (p.sellerId && (p.stockQuantity ?? 0) > 0) {
      bySeller.set(p.sellerId, p);
    }
    if (bySeller.size >= 2) break;
  }

  const sellers = Array.from(bySeller.values());
  if (sellers.length < 2) {
    throw new Error('ensureTwoSellerProducts: need products from at least 2 different sellers');
  }

  return [sellers[0], sellers[1]];
}
