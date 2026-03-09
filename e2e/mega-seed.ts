/**
 * Mega Seed Script — 76 Users, 30 Products, Multi-Seller Carts, 16 Orders
 * ======================================================================
 * Extends the original seed with 50 additional randomized users.
 * Run AFTER emulators are started: cd e2e && npx ts-node mega-seed.ts
 *
 * User breakdown:
 *  - 1 admin (yr62813@gmail.com)
 *  - 10 sellers (with Stripe accounts, various onboarding states)
 *  - 50 buyers (random provinces, some with carts)
 *  - 10 buyer+seller combos
 *  - 5 edge-case users (suspended, unverified, no address, etc.)
 *  = 76 total
 *
 * Products: 30 across 15+ categories, various price tiers & shipping configs.
 * Cart items: ~20 buyers get cart items (some multi-seller carts).
 * Pre-created orders: 16 orders at various statuses for lifecycle/regression tests.
 */

const AUTH_EMULATOR = 'http://localhost:9099';
const FIRESTORE_EMULATOR = 'http://localhost:8080';
const PROJECT_ID = 'orignagta';

// ════════════════════════════════════════════════════════════════════
// CANADIAN ADDRESSES — 75 unique addresses across all provinces/territories
// ════════════════════════════════════════════════════════════════════

interface SeedAddress {
  street: string;
  apartment: string;
  city: string;
  state: string;
  postalCode: string;
  country: string;
  phoneNumber: string;
  isDefault: boolean;
  label: string;
  latitude: number;
  longitude: number;
}

const PROVINCES = ['ON', 'QC', 'BC', 'AB', 'MB', 'SK', 'NS', 'NB', 'NL', 'PE', 'NT', 'YT', 'NU'];

function randomProvince(): string { return PROVINCES[Math.floor(Math.random() * PROVINCES.length)]; }
function randomPostalCode(prov: string): string {
  const prefixes: Record<string, string[]> = {
    ON: ['M5V','K1P','L8R','N2L','P3E'], QC: ['H3B','G1R','J4W','H2X','H4R'],
    BC: ['V6C','V8W','V5K','V6B','V6Z'], AB: ['T2P','T5J','T6H','T3H','T4N'],
    MB: ['R3C','R2C','R3B','R3T','R3L'], SK: ['S4P','S7K','S7N','S4S','S7H'],
    NS: ['B3J','B3H','B3K','B3L','B3M'], NB: ['E2L','E1C','E3B','E1A','E2K'],
    NL: ['A1C','A1B','A1A','A1E','A1G'], PE: ['C1A','C1B','C1E','C0A','C0B'],
    NT: ['X1A','X0E','X0G'], YT: ['Y1A','Y0B'], NU: ['X0A','X0C'],
  };
  const pre = prefixes[prov] || prefixes.ON;
  const p = pre[Math.floor(Math.random() * pre.length)];
  const d1 = Math.floor(Math.random() * 10);
  const l1 = String.fromCharCode(65 + Math.floor(Math.random() * 26));
  const d2 = Math.floor(Math.random() * 10);
  return `${p} ${d1}${l1}${d2}`;
}

const CITY_MAP: Record<string, string[]> = {
  ON: ['Toronto','Ottawa','Hamilton','London','Kitchener','Mississauga','Brampton','Markham'],
  QC: ['Montreal','Quebec City','Laval','Gatineau','Sherbrooke','Saint-Laurent','Longueuil'],
  BC: ['Vancouver','Victoria','Burnaby','Surrey','Richmond','Kelowna','Nanaimo'],
  AB: ['Calgary','Edmonton','Red Deer','Lethbridge','Medicine Hat','Fort McMurray'],
  MB: ['Winnipeg','Brandon','Steinbach','Thompson'],
  SK: ['Regina','Saskatoon','Moose Jaw','Prince Albert'],
  NS: ['Halifax','Dartmouth','Sydney','Truro'],
  NB: ['Saint John','Moncton','Fredericton','Bathurst'],
  NL: ["St. John's",'Corner Brook','Mount Pearl'],
  PE: ['Charlottetown','Summerside','Stratford'],
  NT: ['Yellowknife','Hay River','Inuvik'],
  YT: ['Whitehorse','Dawson City'],
  NU: ['Iqaluit','Rankin Inlet'],
};

function randomCity(prov: string): string {
  const cities = CITY_MAP[prov] || CITY_MAP.ON;
  return cities[Math.floor(Math.random() * cities.length)];
}

const STREET_NAMES = [
  'Maple St','King St','Queen St','Main St','Elm Ave','Cedar Blvd','Oak Dr','Pine Rd',
  'Victoria Ave','Wellington St','Laurier Blvd','Parliament Dr','Rideau St','Bloor St',
  'Yonge St','Dundas St','Granville St','Robson St','Hastings St','Broadway Ave',
  'Portage Ave','Albert St','Jasper Ave','Stephen Ave','Rue Sainte-Catherine',
  'Boulevard René-Lévesque','Rue Saint-Denis','Avenue du Parc','Rue Sherbrooke',
  'Rue Notre-Dame','Rue de la Montagne','Chemin de la Côte-des-Neiges',
];

function makeAddress(prov?: string): SeedAddress {
  const p = prov || randomProvince();
  const city = randomCity(p);
  const num = Math.floor(10 + Math.random() * 9990);
  const street = `${num} ${STREET_NAMES[Math.floor(Math.random() * STREET_NAMES.length)]}`;
  const apt = Math.random() > 0.65 ? `Apt ${Math.floor(1 + Math.random() * 30)}` : '';
  return {
    street, apartment: apt, city, state: p,
    postalCode: randomPostalCode(p), country: 'Canada',
    phoneNumber: `+1${Math.floor(2000000000 + Math.random() * 8000000000)}`,
    isDefault: true, label: Math.random() > 0.5 ? 'Home' : 'Work',
    latitude: 43 + Math.random() * 20, longitude: -(60 + Math.random() * 80),
  };
}

// ════════════════════════════════════════════════════════════════════
// USER DEFINITIONS — 75 users
// ════════════════════════════════════════════════════════════════════

interface SellerProfile {
  businessName: string;
  businessAddress: SeedAddress;
  stripeAccountId: string;
  payoutsEnabled: boolean;
  chargesEnabled: boolean;
  onboardingCompleted: boolean;
}

interface SeedUser {
  email: string;
  password: string;
  displayName: string;
  roles: string[];
  address: SeedAddress;
  sellerProfile?: SellerProfile;
  suspended?: boolean;
  noAddress?: boolean;
}

const FIRST_NAMES = [
  'Liam','Noah','Oliver','James','Elijah','William','Henry','Lucas',
  'Benjamin','Theodore','Jack','Levi','Alexander','Mason','Ethan',
  'Emma','Olivia','Ava','Sophia','Isabella','Mia','Charlotte','Amelia',
  'Harper','Evelyn','Abigail','Emily','Ella','Scarlett','Grace',
  'Fatima','Aisha','Priya','Wei','Yuki','Sven','Lars','Olga',
  'Chloé','Étienne','Marie','Jean','Pierre','François','André',
  'Hiroshi','Mei','Raj','Ananya','Zara','Diego','Carlos','Sofia',
];

const LAST_NAMES = [
  'Tremblay','Gagnon','Roy','Bouchard','Gauthier','Morin','Lavoie','Fortin',
  'Bergeron','Pelletier','Smith','Johnson','Williams','Brown','Jones','Garcia',
  'Miller','Davis','Rodriguez','Martinez','Anderson','Taylor','Thomas','Jackson',
  'White','Harris','Martin','Thompson','Moore','Clark','Lewis','Lee',
  'Singh','Patel','Kim','Chen','Nguyen','Mohammed','Hassan','Murphy',
  "O'Brien",'MacDonald','Campbell','Stewart','Wilson','Fraser','Scott','Reid',
];

function randomName(): string {
  return `${FIRST_NAMES[Math.floor(Math.random() * FIRST_NAMES.length)]} ${LAST_NAMES[Math.floor(Math.random() * LAST_NAMES.length)]}`;
}

function makeSellerProfile(name: string, prov: string, idx: number, onboarded = true): SellerProfile {
  return {
    businessName: `${name.split(' ')[0]}'s ${randomCity(prov)} Shop`,
    businessAddress: makeAddress(prov),
    stripeAccountId: `acct_test_${String(idx).padStart(3, '0')}`,
    payoutsEnabled: onboarded,
    chargesEnabled: onboarded,
    onboardingCompleted: onboarded,
  };
}

// Build the 75 users
const USERS: SeedUser[] = [];
let emailCounter = 0;
const nextEmail = (prefix: string) => `${prefix}${++emailCounter}@test.origna.ca`;

// 1. ADMIN
USERS.push({
  email: 'yr62813@gmail.com', password: 'REDACTED_TEST_PASSWORD', displayName: 'Admin Yunior',
  roles: ['admin', 'seller', 'buyer'], address: makeAddress('ON'),
  sellerProfile: makeSellerProfile('Admin', 'ON', 0),
});

// 2. SELLERS (10) — various provinces & onboarding states
const SELLER_CONFIGS = [
  { prov: 'QC', onboarded: true },  { prov: 'BC', onboarded: true },
  { prov: 'AB', onboarded: true },  { prov: 'ON', onboarded: true },
  { prov: 'MB', onboarded: true },  { prov: 'SK', onboarded: true },
  { prov: 'NS', onboarded: true },  { prov: 'NB', onboarded: true },
  { prov: 'BC', onboarded: false }, // seller not onboarded
  { prov: 'QC', onboarded: false }, // seller not onboarded
];

for (let i = 0; i < SELLER_CONFIGS.length; i++) {
  const cfg = SELLER_CONFIGS[i];
  const name = randomName();
  USERS.push({
    email: `seller${i + 1}@test.origna.ca`, password: 'REDACTED_TEST_PASSWORD', displayName: name,
    roles: ['seller', 'buyer'], address: makeAddress(cfg.prov),
    sellerProfile: makeSellerProfile(name, cfg.prov, i + 1, cfg.onboarded),
  });
}

// 3. BUYERS (50) — random provinces
for (let i = 0; i < 50; i++) {
  USERS.push({
    email: `buyer${i + 1}@test.origna.ca`, password: 'REDACTED_TEST_PASSWORD', displayName: randomName(),
    roles: ['buyer'], address: makeAddress(),
  });
}

// 4. BUYER+SELLER COMBOS (10)
for (let i = 0; i < 10; i++) {
  const name = randomName();
  const prov = randomProvince();
  USERS.push({
    email: `combo${i + 1}@test.origna.ca`, password: 'REDACTED_TEST_PASSWORD', displayName: name,
    roles: ['buyer', 'seller'], address: makeAddress(prov),
    sellerProfile: makeSellerProfile(name, prov, 100 + i),
  });
}

// 5. EDGE-CASE USERS (4)
USERS.push({
  email: 'suspended@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Suspended User',
  roles: ['buyer'], address: makeAddress('ON'), suspended: true,
});
USERS.push({
  email: 'no-address@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'No Address User',
  roles: ['buyer'], address: makeAddress('ON'), noAddress: true,
});
USERS.push({
  email: 'seller-suspended@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Suspended Seller',
  roles: ['seller', 'buyer'], address: makeAddress('QC'),
  sellerProfile: makeSellerProfile('Suspended', 'QC', 999), suspended: true,
});
USERS.push({
  email: 'buyer-only-fresh@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Fresh Buyer',
  roles: ['buyer'], address: makeAddress('AB'),
});
// Real email used in regression + payment tests
USERS.push({
  email: 'yuniorrodriguezo460@gmail.com', password: 'REDACTED_TEST_PASSWORD', displayName: 'Yunior Buyer',
  roles: ['buyer'], address: makeAddress('ON'),
});

// ════════════════════════════════════════════════════════════════════
// PRODUCTS — 30 products across all active sellers
// ════════════════════════════════════════════════════════════════════

interface SeedProduct {
  id: string;
  name: string;
  price: number;
  description: string;
  categoryId: number;
  stockQuantity: number;
  sellerEmail: string;
  imageUrls: string[];
  keywords: string[];
  freeShipping: boolean;
  isDigital: boolean;
  isLocalDeliveryOnly: boolean;
  isPerishable: boolean;
  estimatedShipDays: number;
  weightKg: number;
  deliveryOptions: any[];
  videoUrl?: string;
  // Digital-only fields (optional)
  digitalType?: 'software' | 'book';
  digitalBuilds?: { macos?: string; windows?: string; linux?: string };
  bookSourceUrl?: string;
  supportedPlatforms?: string[];
  deviceLimit?: number | null;
}

const PRODUCTS: SeedProduct[] = [
  // ── Seller 1 (QC) ──────────────────
  { id: 'product_001', name: 'Handmade Quebec Scarf', price: 45.99, description: 'Beautiful handwoven scarf made with Quebec alpaca wool.', categoryId: 5, stockQuantity: 25, sellerEmail: 'seller1@test.origna.ca', imageUrls: ['https://picsum.photos/seed/scarf1/400/400', 'https://picsum.photos/seed/scarf2/400/400', 'https://picsum.photos/seed/scarf3/400/400'], videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4', keywords: ['scarf','wool','quebec'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 3, weightKg: 0.3, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 5, price: 0 }, { speed: 'express', isEnabled: true, estimatedDays: 2, price: 9.99 }] },
  { id: 'product_002', name: 'Montreal Artisan Leather Bag', price: 189.99, description: 'Premium leather messenger bag crafted in Mile End, Montreal.', categoryId: 6, stockQuantity: 10, sellerEmail: 'seller1@test.origna.ca', imageUrls: ['https://picsum.photos/seed/bag/400/400'], keywords: ['bag','leather','montreal'], freeShipping: true, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 3, weightKg: 1.2, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 5, price: 0 }] },
  { id: 'product_003', name: 'Quebec Tourtière Spice Kit', price: 12.99, description: 'Authentic spice blend for traditional Quebec tourtière.', categoryId: 19, stockQuantity: 100, sellerEmail: 'seller1@test.origna.ca', imageUrls: ['https://picsum.photos/seed/spice/400/400'], keywords: ['spice','food','quebec'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 4, weightKg: 0.15, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 5, price: 0 }] },

  // ── Seller 2 (BC) ──────────────────
  { id: 'product_004', name: 'BC Cedar Incense Set', price: 24.99, description: 'Hand-harvested BC red cedar incense sticks.', categoryId: 8, stockQuantity: 50, sellerEmail: 'seller2@test.origna.ca', imageUrls: ['https://picsum.photos/seed/incense/400/400'], keywords: ['incense','cedar','bc'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 4, weightKg: 0.2, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 5, price: 0 }] },
  { id: 'product_005', name: 'Pacific Coast Trail Running Shoes', price: 129.99, description: 'Lightweight trail runners designed for BC mountains.', categoryId: 6, stockQuantity: 30, sellerEmail: 'seller2@test.origna.ca', imageUrls: ['https://picsum.photos/seed/shoes1/400/400', 'https://picsum.photos/seed/shoes2/400/400'], videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Subaru_Outback.mp4', keywords: ['shoes','running','trail'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 3, weightKg: 0.8, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 5, price: 0 }, { speed: 'express', isEnabled: true, estimatedDays: 2, price: 12.99 }] },
  { id: 'product_006', name: 'Vancouver Island Honey (500g)', price: 18.99, description: 'Raw wildflower honey from Vancouver Island.', categoryId: 19, stockQuantity: 40, sellerEmail: 'seller2@test.origna.ca', imageUrls: ['https://picsum.photos/seed/honey/400/400'], keywords: ['honey','organic','vancouver'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: true, isPerishable: true, estimatedShipDays: 1, weightKg: 0.6, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 3, price: 5.99 }] },

  // ── Seller 3 (AB) ──────────────────
  { id: 'product_007', name: 'Alberta Beef Jerky Gift Box', price: 34.99, description: 'Premium Alberta beef jerky in 3 flavours. 300g total.', categoryId: 19, stockQuantity: 60, sellerEmail: 'seller3@test.origna.ca', imageUrls: ['https://picsum.photos/seed/jerky/400/400'], keywords: ['beef','jerky','alberta'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 3, weightKg: 0.4, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 5, price: 0 }] },
  { id: 'product_008', name: 'Calgary Stampede Poster Print', price: 29.99, description: 'Limited edition art print. 18x24 archival quality.', categoryId: 20, stockQuantity: 100, sellerEmail: 'seller3@test.origna.ca', imageUrls: ['https://picsum.photos/seed/poster/400/400'], keywords: ['art','poster','calgary'], freeShipping: true, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 5, weightKg: 0.3, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 7, price: 0 }] },
  { id: 'product_009', name: 'Wireless Bluetooth Earbuds Pro', price: 79.99, description: 'ANC earbuds with 30hr battery life. IPX5 waterproof.', categoryId: 1, stockQuantity: 45, sellerEmail: 'seller3@test.origna.ca', imageUrls: ['https://picsum.photos/seed/earbuds1/400/400', 'https://picsum.photos/seed/earbuds2/400/400', 'https://picsum.photos/seed/earbuds3/400/400'], videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', keywords: ['earbuds','bluetooth','wireless'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 2, weightKg: 0.1, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 4, price: 0 }] },

  // ── Seller 4 (ON) ──────────────────
  { id: 'product_010', name: 'Canadian History eBook Bundle', price: 14.99, description: 'Digital collection of 5 eBooks covering Canadian history.', categoryId: 21, stockQuantity: 999, sellerEmail: 'seller4@test.origna.ca', imageUrls: ['https://picsum.photos/seed/ebook/400/400'], keywords: ['ebook','history','digital'], freeShipping: true, isDigital: true, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 0, weightKg: 0, deliveryOptions: [], digitalType: 'book', bookSourceUrl: 'https://r2.origna.com/emulator/books/canadian-history-bundle.pdf', deviceLimit: null },
  { id: 'product_011', name: 'Ottawa Parliament Puzzle 1000pc', price: 39.99, description: '1000-piece jigsaw puzzle. Made in Canada.', categoryId: 16, stockQuantity: 35, sellerEmail: 'seller4@test.origna.ca', imageUrls: ['https://picsum.photos/seed/puzzle/400/400'], keywords: ['puzzle','ottawa','game'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 3, weightKg: 0.8, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 5, price: 0 }] },
  { id: 'product_012', name: 'Organic Maple Syrup (1L)', price: 22.50, description: 'Grade A amber organic maple syrup from Eastern Ontario.', categoryId: 19, stockQuantity: 80, sellerEmail: 'seller4@test.origna.ca', imageUrls: ['https://picsum.photos/seed/maple/400/400'], keywords: ['maple','syrup','organic'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 3, weightKg: 1.1, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 5, price: 0 }] },

  // ── Seller 5 (MB) ──────────────────
  { id: 'product_013', name: 'Manitoba Wild Rice (2kg)', price: 16.99, description: 'Wild-harvested rice from Northern Manitoba lakes.', categoryId: 19, stockQuantity: 70, sellerEmail: 'seller5@test.origna.ca', imageUrls: ['https://picsum.photos/seed/rice/400/400'], keywords: ['rice','manitoba','organic'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 4, weightKg: 2.1, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 6, price: 0 }] },
  { id: 'product_014', name: 'Bison Leather Wallet', price: 89.99, description: 'Handcrafted bison leather bifold wallet.', categoryId: 6, stockQuantity: 20, sellerEmail: 'seller5@test.origna.ca', imageUrls: ['https://picsum.photos/seed/wallet/400/400'], keywords: ['wallet','leather','bison'], freeShipping: true, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 3, weightKg: 0.15, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 5, price: 0 }] },

  // ── Seller 6 (SK) ──────────────────
  { id: 'product_015', name: 'Prairie Sunset Canvas Print', price: 55.00, description: '24x36 gallery-wrapped canvas of Saskatchewan prairies.', categoryId: 20, stockQuantity: 40, sellerEmail: 'seller6@test.origna.ca', imageUrls: ['https://picsum.photos/seed/canvas/400/400'], keywords: ['art','canvas','prairie'], freeShipping: true, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 5, weightKg: 1.5, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 7, price: 0 }] },
  { id: 'product_016', name: 'Saskatoon Berry Jam (3-pack)', price: 19.99, description: 'Wild Saskatoon berry jam. 250ml jars, set of 3.', categoryId: 19, stockQuantity: 55, sellerEmail: 'seller6@test.origna.ca', imageUrls: ['https://picsum.photos/seed/jam/400/400'], keywords: ['jam','saskatoon','berry'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 4, weightKg: 0.9, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 5, price: 0 }] },

  // ── Seller 7 (NS) ──────────────────
  { id: 'product_017', name: 'Halifax Lobster Trap Decor', price: 65.00, description: 'Authentic miniature lobster trap from Nova Scotia.', categoryId: 4, stockQuantity: 15, sellerEmail: 'seller7@test.origna.ca', imageUrls: ['https://picsum.photos/seed/lobster/400/400'], keywords: ['lobster','decor','nova-scotia'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 5, weightKg: 2.5, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 7, price: 0 }] },
  { id: 'product_018', name: 'Nova Scotia Tartan Blanket', price: 110.00, description: 'Premium wool throw blanket in Nova Scotia tartan.', categoryId: 5, stockQuantity: 12, sellerEmail: 'seller7@test.origna.ca', imageUrls: ['https://picsum.photos/seed/blanket/400/400'], keywords: ['blanket','tartan','wool'], freeShipping: true, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 4, weightKg: 1.8, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 5, price: 0 }] },

  // ── Seller 8 (NB) ──────────────────
  { id: 'product_019', name: 'Fundy Tide Watch', price: 245.00, description: 'Stainless steel watch with Bay of Fundy tide chart.', categoryId: 7, stockQuantity: 8, sellerEmail: 'seller8@test.origna.ca', imageUrls: ['https://picsum.photos/seed/watch1/400/400', 'https://picsum.photos/seed/watch2/400/400'], videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', keywords: ['watch','fundy','jewelry'], freeShipping: true, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 3, weightKg: 0.2, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 5, price: 0 }, { speed: 'express', isEnabled: true, estimatedDays: 2, price: 14.99 }] },
  { id: 'product_020', name: 'Dulse Seaweed Snack Pack', price: 8.99, description: 'Dried dulse from the Bay of Fundy. 100g pack.', categoryId: 19, stockQuantity: 200, sellerEmail: 'seller8@test.origna.ca', imageUrls: ['https://picsum.photos/seed/dulse/400/400'], keywords: ['seaweed','dulse','snack'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 3, weightKg: 0.12, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 5, price: 0 }] },

  // ── Combo Sellers ──────────────────
  { id: 'product_021', name: 'Quebec Pottery Mug Set (4)', price: 59.99, description: 'Hand-thrown ceramic mugs from a Quebec artisan.', categoryId: 4, stockQuantity: 15, sellerEmail: 'combo1@test.origna.ca', imageUrls: ['https://picsum.photos/seed/mugs/400/400'], keywords: ['mug','pottery','quebec'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 5, weightKg: 2.0, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 7, price: 0 }] },
  { id: 'product_022', name: 'Handmade Silver Necklace', price: 149.99, description: 'Sterling silver necklace with Canadian jade pendant.', categoryId: 7, stockQuantity: 8, sellerEmail: 'combo3@test.origna.ca', imageUrls: ['https://picsum.photos/seed/necklace/400/400'], keywords: ['necklace','silver','jewelry'], freeShipping: true, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 3, weightKg: 0.05, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 5, price: 0 }] },
  { id: 'product_023', name: 'Hamilton Steel City T-Shirt', price: 28.99, description: 'Premium cotton t-shirt featuring Hamilton skyline.', categoryId: 5, stockQuantity: 75, sellerEmail: 'combo4@test.origna.ca', imageUrls: ['https://picsum.photos/seed/tshirt/400/400'], keywords: ['tshirt','hamilton','clothing'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 3, weightKg: 0.2, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 5, price: 0 }] },

  // ── SPECIAL PRODUCTS for edge-case testing ──────────────────
  { id: 'product_024', name: 'Budget Sticker Pack', price: 1.99, description: 'Minimum-price sticker pack for edge-case testing.', categoryId: 13, stockQuantity: 500, sellerEmail: 'seller1@test.origna.ca', imageUrls: ['https://picsum.photos/seed/sticker/400/400'], keywords: ['sticker','cheap','budget'], freeShipping: true, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 5, weightKg: 0.01, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 7, price: 0 }] },
  { id: 'product_025', name: 'Luxury Diamond Earrings', price: 4999.99, description: 'High-value item for payment testing.', categoryId: 7, stockQuantity: 2, sellerEmail: 'seller3@test.origna.ca', imageUrls: ['https://picsum.photos/seed/diamond/400/400'], keywords: ['diamond','luxury','earrings'], freeShipping: true, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 1, weightKg: 0.02, deliveryOptions: [{ speed: 'express', isEnabled: true, estimatedDays: 1, price: 0 }] },
  { id: 'product_026', name: 'Digital Photography Course', price: 49.99, description: 'Online course — digital product, no shipping.', categoryId: 21, stockQuantity: 9999, sellerEmail: 'seller4@test.origna.ca', imageUrls: ['https://picsum.photos/seed/course/400/400'], keywords: ['course','digital','photography'], freeShipping: true, isDigital: true, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 0, weightKg: 0, deliveryOptions: [], digitalType: 'book', bookSourceUrl: 'https://r2.origna.com/emulator/books/photography-course.pdf', deviceLimit: null },
  { id: 'product_031', name: 'FXCleaner — Mac Disk Cleaner', price: 29.99, description: 'Native macOS disk cleaner, privacy sweeper and system optimizer. License key delivered instantly after purchase.', categoryId: 21, stockQuantity: 9999, sellerEmail: 'seller4@test.origna.ca', imageUrls: ['https://picsum.photos/seed/fxcleaner/400/400'], keywords: ['macos','cleaner','software','disk','utility'], freeShipping: true, isDigital: true, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 0, weightKg: 0, deliveryOptions: [], digitalType: 'software', digitalBuilds: { macos: 'https://github.com/yunior123/fxcleaner/releases/download/v1.0.0/FXCleaner-1.0.0.dmg' }, supportedPlatforms: ['macos'], deviceLimit: 3 },
  { id: 'product_027', name: 'Zero Stock Product', price: 25.00, description: 'This product is out of stock for testing.', categoryId: 5, stockQuantity: 0, sellerEmail: 'seller2@test.origna.ca', imageUrls: ['https://picsum.photos/seed/empty/400/400'], keywords: ['out-of-stock','test'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 5, weightKg: 0.5, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 5, price: 0 }] },
  { id: 'product_028', name: 'Local-Only Fresh Salmon', price: 32.99, description: 'Wild salmon. Local delivery only — perishable.', categoryId: 19, stockQuantity: 20, sellerEmail: 'seller2@test.origna.ca', imageUrls: ['https://picsum.photos/seed/salmon/400/400'], keywords: ['salmon','fish','perishable'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: true, isPerishable: true, estimatedShipDays: 0, weightKg: 1.1, deliveryOptions: [{ speed: 'same_day', isEnabled: true, estimatedDays: 0, price: 14.99, maxRadiusKm: 30 }] },
  { id: 'product_029', name: 'Inuit Soapstone Carving', price: 350.00, description: 'Hand-carved soapstone bear by Inuit artist.', categoryId: 20, stockQuantity: 3, sellerEmail: 'combo2@test.origna.ca', imageUrls: ['https://picsum.photos/seed/carving/400/400'], keywords: ['inuit','carving','art'], freeShipping: true, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 5, weightKg: 3.0, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 7, price: 0 }] },
  { id: 'product_030', name: 'Suspended Seller Product', price: 19.99, description: 'Product by suspended seller — should fail checkout.', categoryId: 5, stockQuantity: 50, sellerEmail: 'seller-suspended@test.origna.ca', imageUrls: ['https://picsum.photos/seed/suspended/400/400'], keywords: ['suspended','test'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 5, weightKg: 0.5, deliveryOptions: [{ speed: 'standard', isEnabled: true, estimatedDays: 5, price: 0 }] },
];

// ════════════════════════════════════════════════════════════════════
// FIRESTORE HELPERS
// ════════════════════════════════════════════════════════════════════

function toFirestoreFields(obj: any): any {
  const fields: any = {};
  for (const [key, value] of Object.entries(obj)) {
    fields[key] = toFirestoreValue(value);
  }
  return fields;
}

function toFirestoreValue(value: any): any {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (typeof value === 'boolean') return { booleanValue: value };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(v => toFirestoreValue(v)) } };
  if (typeof value === 'object') return { mapValue: { fields: toFirestoreFields(value) } };
  return { stringValue: String(value) };
}

async function clearEmulatorData() {
  console.log('🗑️  Clearing existing emulator data...');
  await fetch(`${AUTH_EMULATOR}/emulator/v1/projects/${PROJECT_ID}/accounts`, { method: 'DELETE' }).catch(() => {});
  await fetch(`${FIRESTORE_EMULATOR}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`, { method: 'DELETE' }).catch(() => {});
  console.log('  ✅ Cleared');
}

async function createAuthUser(email: string, password: string, displayName: string): Promise<string | null> {
  try {
    const res = await fetch(
      `${AUTH_EMULATOR}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`,
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password, displayName, returnSecureToken: true }) }
    );
    const data = await res.json();
    if (data.error) { console.error(`  ❌ ${email}: ${data.error.message}`); return null; }
    const uid = data.localId;
    // Mark email as verified in emulator
    await fetch(`${AUTH_EMULATOR}/emulator/v1/projects/${PROJECT_ID}/accounts`, {
      method: 'PATCH', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ localId: uid, emailVerified: true }),
    });
    return uid;
  } catch (e) { console.error(`  ❌ ${email}: ${e}`); return null; }
}

async function writeFirestoreDoc(path: string, data: any): Promise<boolean> {
  const fields = toFirestoreFields(data);
  const url = `${FIRESTORE_EMULATOR}/v1/projects/${PROJECT_ID}/databases/(default)/documents/${path}`;
  const res = await fetch(url, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer owner' },
    body: JSON.stringify({ fields }),
  });
  return res.ok;
}

// ════════════════════════════════════════════════════════════════════
// SEED FUNCTIONS
// ════════════════════════════════════════════════════════════════════

async function seedUsers(): Promise<Map<string, string>> {
  console.log(`\n👤 Creating ${USERS.length} users...`);
  const uidMap = new Map<string, string>();
  let count = 0;

  for (const user of USERS) {
    const uid = await createAuthUser(user.email, user.password, user.displayName);
    if (!uid) continue;
    uidMap.set(user.email, uid);

    const doc: any = {
      uid, email: user.email, name: user.displayName, roles: user.roles,
      createdAt: new Date(), suspended: user.suspended || false,
      paymentProvider: 'stripe', commissionRate: 0.025,
      verified: user.roles.includes('seller'), payoutHoldDays: 7,
      payoutsEnabled: user.sellerProfile?.payoutsEnabled ?? false,
      chargesEnabled: user.sellerProfile?.chargesEnabled ?? false,
      onboardingCompleted: user.sellerProfile?.onboardingCompleted ?? false,
    };

    if (!user.noAddress) {
      doc.address = user.address;
    }

    if (user.sellerProfile) {
      doc.stripeAccountId = user.sellerProfile.stripeAccountId;
      doc.sellerProfile = {
        businessName: user.sellerProfile.businessName,
        businessAddress: user.sellerProfile.businessAddress,
      };
      doc.businessName = user.sellerProfile.businessName;
    }

    if (await writeFirestoreDoc(`users/${uid}`, doc)) {
      count++;
      if (count % 10 === 0 || count <= 5) {
        console.log(`  ✅ [${count}] ${user.displayName} (${user.roles.join('+')}) — ${user.email}`);
      }
    }
  }
  console.log(`  📊 ${count}/${USERS.length} users created`);
  return uidMap;
}

async function seedProducts(uidMap: Map<string, string>) {
  console.log(`\n📦 Creating ${PRODUCTS.length} products...`);
  let count = 0;

  for (const product of PRODUCTS) {
    const sellerId = uidMap.get(product.sellerEmail);
    if (!sellerId) { console.log(`  ⚠️ Skip "${product.name}" — seller not found`); continue; }
    const sellerUser = USERS.find(u => u.email === product.sellerEmail)!;

    const doc: any = {
      name: product.name, price: product.price, description: product.description,
      sellerId, sellerAddress: sellerUser.address,
      categoryId: product.categoryId, stockQuantity: product.stockQuantity,
      imageUrls: product.imageUrls, keywords: product.keywords,
      rating: Math.round((3 + Math.random() * 2) * 10) / 10,
      ratingCount: Math.floor(Math.random() * 50),
      createdAt: new Date(), isActive: true,
      isDigital: product.isDigital, freeShipping: product.freeShipping,
      isLocalDeliveryOnly: product.isLocalDeliveryOnly,
      isPerishable: product.isPerishable,
      estimatedShipDays: product.estimatedShipDays,
      deliveryOptions: product.deliveryOptions, minimumOrderQuantity: 1,
    };
    if (product.weightKg) doc.weightKg = product.weightKg;
    if (product.videoUrl) doc.videoUrl = product.videoUrl;
    // Write digital product fields when present
    if (product.isDigital) {
      if (product.digitalType) doc.digitalType = product.digitalType;
      if (product.digitalBuilds) doc.digitalBuilds = product.digitalBuilds;
      if (product.bookSourceUrl) doc.bookSourceUrl = product.bookSourceUrl;
      if (product.supportedPlatforms) doc.supportedPlatforms = product.supportedPlatforms;
      doc.deviceLimit = product.deviceLimit ?? null;
    }

    if (await writeFirestoreDoc(`products/${product.id}`, doc)) {
      count++;
      if (count % 5 === 0 || count <= 3) {
        console.log(`  ✅ [${count}] "${product.name}" ($${product.price}) by ${sellerUser.displayName}`);
      }
    }
  }
  console.log(`  📊 ${count}/${PRODUCTS.length} products created`);
}

async function seedCartItems(uidMap: Map<string, string>) {
  console.log('\n🛒 Populating buyer carts...');
  let count = 0;

  // Give ~20 buyers various cart items (some multi-seller)
  const cartAssignments: { buyerEmail: string; items: { productId: string; quantity: number }[] }[] = [
    // Single-item carts
    { buyerEmail: 'yuniorrodriguezo460@gmail.com', items: [{ productId: 'product_001', quantity: 1 }] },
    { buyerEmail: 'buyer2@test.origna.ca', items: [{ productId: 'product_004', quantity: 2 }] },
    { buyerEmail: 'buyer3@test.origna.ca', items: [{ productId: 'product_009', quantity: 1 }] },
    { buyerEmail: 'buyer4@test.origna.ca', items: [{ productId: 'product_012', quantity: 3 }] },
    { buyerEmail: 'buyer5@test.origna.ca', items: [{ productId: 'product_015', quantity: 1 }] },
    // Multi-item, single seller
    { buyerEmail: 'buyer6@test.origna.ca', items: [
      { productId: 'product_001', quantity: 1 }, { productId: 'product_002', quantity: 1 }, { productId: 'product_003', quantity: 2 },
    ]},
    { buyerEmail: 'buyer7@test.origna.ca', items: [
      { productId: 'product_007', quantity: 1 }, { productId: 'product_008', quantity: 1 },
    ]},
    // Multi-seller carts (crucial for multi-seller payout testing)
    { buyerEmail: 'buyer8@test.origna.ca', items: [
      { productId: 'product_001', quantity: 1 }, // seller1 (QC)
      { productId: 'product_004', quantity: 1 }, // seller2 (BC)
      { productId: 'product_007', quantity: 1 }, // seller3 (AB)
    ]},
    { buyerEmail: 'buyer9@test.origna.ca', items: [
      { productId: 'product_011', quantity: 1 }, // seller4 (ON)
      { productId: 'product_017', quantity: 1 }, // seller7 (NS)
    ]},
    { buyerEmail: 'buyer10@test.origna.ca', items: [
      { productId: 'product_005', quantity: 1 }, // seller2 (BC)
      { productId: 'product_014', quantity: 1 }, // seller5 (MB)
      { productId: 'product_019', quantity: 1 }, // seller8 (NB)
    ]},
    // High-value cart
    { buyerEmail: 'buyer11@test.origna.ca', items: [{ productId: 'product_025', quantity: 1 }] },
    // Digital-only cart
    { buyerEmail: 'buyer12@test.origna.ca', items: [{ productId: 'product_010', quantity: 1 }, { productId: 'product_026', quantity: 1 }] },
    // Budget cart
    { buyerEmail: 'buyer13@test.origna.ca', items: [{ productId: 'product_024', quantity: 5 }] },
    // More random carts
    { buyerEmail: 'buyer14@test.origna.ca', items: [{ productId: 'product_016', quantity: 2 }] },
    { buyerEmail: 'buyer15@test.origna.ca', items: [{ productId: 'product_018', quantity: 1 }] },
    { buyerEmail: 'buyer16@test.origna.ca', items: [{ productId: 'product_020', quantity: 3 }] },
    { buyerEmail: 'buyer17@test.origna.ca', items: [{ productId: 'product_021', quantity: 1 }] },
    { buyerEmail: 'buyer18@test.origna.ca', items: [{ productId: 'product_022', quantity: 1 }] },
    { buyerEmail: 'buyer19@test.origna.ca', items: [{ productId: 'product_023', quantity: 2 }] },
    { buyerEmail: 'buyer20@test.origna.ca', items: [{ productId: 'product_008', quantity: 1 }, { productId: 'product_013', quantity: 1 }] },
  ];

  for (const assignment of cartAssignments) {
    const uid = uidMap.get(assignment.buyerEmail);
    if (!uid) continue;
    for (const item of assignment.items) {
      const cartDoc = { productId: item.productId, quantity: item.quantity, createdAt: new Date() };
      if (await writeFirestoreDoc(`users/${uid}/cart/${item.productId}`, cartDoc)) count++;
    }
  }
  console.log(`  📊 ${count} cart items added across ${cartAssignments.length} buyers`);
}

// ════════════════════════════════════════════════════════════════════
// SEED ORDERS — 16 orders for regression-e2e tests
// ════════════════════════════════════════════════════════════════════

async function seedOrders(uidMap: Map<string, string>) {
  console.log('\n📋 Creating 16 test orders for regression tests...');
  let count = 0;

  const buyerUid = uidMap.get('buyer1@test.origna.ca') || 'buyer1_uid';
  const buyer2Uid = uidMap.get('buyer2@test.origna.ca') || 'buyer2_uid';
  const buyer3Uid = uidMap.get('buyer3@test.origna.ca') || 'buyer3_uid';
  const adminUid = uidMap.get('yr62813@gmail.com') || 'admin_uid';
  const combo1Uid = uidMap.get('combo1@test.origna.ca') || 'combo1_uid';
  const seller1Uid = uidMap.get('seller1@test.origna.ca') || 'seller1_uid';
  const seller2Uid = uidMap.get('seller2@test.origna.ca') || 'seller2_uid';
  const seller3Uid = uidMap.get('seller3@test.origna.ca') || 'seller3_uid';
  const seller4Uid = uidMap.get('seller4@test.origna.ca') || 'seller4_uid';
  const seller5Uid = uidMap.get('seller5@test.origna.ca') || 'seller5_uid';
  const buyerAddress = {
    street: '123 Test Street', apartment: '', city: 'Toronto',
    state: 'ON', postalCode: 'M5V 3A8', country: 'Canada',
  };
  const seller1Address = {
    street: '456 Seller St', city: 'Montreal', state: 'QC',
    postalCode: 'H2X 1Y4', country: 'Canada',
  };
  const seller2Address = {
    street: '789 Pacific Rd', city: 'Vancouver', state: 'BC',
    postalCode: 'V6B 1H7', country: 'Canada',
  };
  const seller3Address = {
    street: '321 Prairie Ave', city: 'Calgary', state: 'AB',
    postalCode: 'T2P 1J9', country: 'Canada',
  };

  const makeItem = (productId: string, name: string, price: number, qty: number, sellerId: string, status: string, sellerAddr?: any, tracking?: boolean) => {
    const item: any = {
      productId, name, price, quantity: qty, sellerId, status,
      imageUrls: [`https://picsum.photos/seed/${productId}/400/400`],
    };
    if (sellerAddr) item.sellerAddress = sellerAddr;
    if (tracking) { item.trackingNumber = `TRK${Date.now()}`; item.carrier = 'Canada Post'; }
    return item;
  };

  const now = new Date();

  const orders = [
    // order_test_001 — pending
    {
      id: 'order_test_001', orderStatus: 'pending', paymentStatus: 'awaiting_payment', paymentProvider: 'stripe',
      buyerUid, customerEmail: 'buyer1@test.origna.ca', sellerIds: [seller1Uid],
      subtotalCents: 4599, shippingCostCents: 999, taxAmountCents: 728, totalAmountCents: 4599 + 999 + 728,
      shippingAddress: buyerAddress, createdAt: now,
      items: [makeItem('product_001', 'Handmade Quebec Scarf', 4599, 1, seller1Uid, 'pending')],
    },
    // order_test_002 — confirmed
    {
      id: 'order_test_002', orderStatus: 'confirmed', paymentStatus: 'authorized', paymentProvider: 'stripe',
      buyerUid, customerEmail: 'buyer1@test.origna.ca', sellerIds: [seller1Uid],
      stripePaymentIntentId: 'pi_test_confirmed_002',
      subtotalCents: 18999, shippingCostCents: 1500, taxAmountCents: 2665, totalAmountCents: 18999 + 1500 + 2665,
      shippingAddress: buyerAddress, createdAt: now,
      items: [makeItem('product_002', 'Montreal Artisan Leather Bag', 18999, 1, seller1Uid, 'confirmed')],
    },
    // order_test_003 — processing
    {
      id: 'order_test_003', orderStatus: 'processing', paymentStatus: 'authorized', paymentProvider: 'stripe',
      buyerUid, customerEmail: 'buyer1@test.origna.ca', sellerIds: [seller2Uid],
      stripePaymentIntentId: 'pi_test_processing_003',
      subtotalCents: 12999, shippingCostCents: 1200, taxAmountCents: 1846, totalAmountCents: 12999 + 1200 + 1846,
      shippingAddress: buyerAddress, createdAt: now,
      items: [makeItem('product_005', 'Pacific Coast Trail Running Shoes', 12999, 1, seller2Uid, 'processing')],
    },
    // order_test_004 — shipped (with tracking, captured payment, pi_test_ prefix)
    {
      id: 'order_test_004', orderStatus: 'shipped', paymentStatus: 'captured', paymentProvider: 'stripe',
      buyerUid, customerEmail: 'buyer1@test.origna.ca', sellerIds: [seller1Uid],
      stripePaymentIntentId: 'pi_test_shipped_004',
      subtotalCents: 4599, shippingCostCents: 999, taxAmountCents: 728, totalAmountCents: 4599 + 999 + 728,
      shippingAddress: buyerAddress, createdAt: now,
      items: [makeItem('product_001', 'Handmade Quebec Scarf', 4599, 1, seller1Uid, 'shipped', undefined, true)],
    },
    // order_test_005 — in_transit (captured)
    {
      id: 'order_test_005', orderStatus: 'in_transit', paymentStatus: 'captured', paymentProvider: 'stripe',
      buyerUid, customerEmail: 'buyer1@test.origna.ca', sellerIds: [seller2Uid],
      stripePaymentIntentId: 'pi_test_intransit_005',
      subtotalCents: 12999, shippingCostCents: 1200, taxAmountCents: 1846, totalAmountCents: 12999 + 1200 + 1846,
      shippingAddress: buyerAddress, createdAt: now,
      items: [makeItem('product_005', 'Running Shoes', 12999, 1, seller2Uid, 'in_transit', undefined, true)],
    },
    // order_test_006 — delivered (captured, pi_test_ prefix)
    {
      id: 'order_test_006', orderStatus: 'delivered', paymentStatus: 'captured', paymentProvider: 'stripe',
      buyerUid, customerEmail: 'buyer1@test.origna.ca', sellerIds: [seller1Uid],
      stripePaymentIntentId: 'pi_test_delivered_006',
      subtotalCents: 1299, shippingCostCents: 599, taxAmountCents: 247, totalAmountCents: 1299 + 599 + 247,
      shippingAddress: buyerAddress, createdAt: now,
      items: [makeItem('product_003', 'Quebec Tourtière Spice Kit', 1299, 1, seller1Uid, 'delivered', undefined, true)],
    },
    // order_test_007 — cancelled
    {
      id: 'order_test_007', orderStatus: 'cancelled', paymentStatus: 'awaiting_payment', paymentProvider: 'stripe',
      buyerUid, customerEmail: 'buyer1@test.origna.ca', sellerIds: [seller1Uid],
      subtotalCents: 4599, shippingCostCents: 999, taxAmountCents: 728, totalAmountCents: 4599 + 999 + 728,
      shippingAddress: buyerAddress, createdAt: now,
      items: [makeItem('product_001', 'Handmade Quebec Scarf', 4599, 1, seller1Uid, 'cancelled')],
    },
    // order_test_008 — multi-seller (3 sellers)
    {
      id: 'order_test_008', orderStatus: 'confirmed', paymentStatus: 'authorized', paymentProvider: 'stripe',
      buyerUid, customerEmail: 'buyer1@test.origna.ca', sellerIds: [seller1Uid, seller2Uid, seller3Uid],
      stripePaymentIntentId: 'pi_test_multiseller_008',
      subtotalCents: 4599 + 12999 + 4200, shippingCostCents: 2500, taxAmountCents: 2834,
      totalAmountCents: 4599 + 12999 + 4200 + 2500 + 2834,
      shippingAddress: buyerAddress, createdAt: now,
      items: [
        makeItem('product_001', 'Handmade Quebec Scarf', 4599, 1, seller1Uid, 'confirmed', seller1Address),
        makeItem('product_005', 'Pacific Coast Trail Running Shoes', 12999, 1, seller2Uid, 'confirmed', seller2Address),
        makeItem('product_008', 'Alberta Wildflower Honey', 4200, 1, seller3Uid, 'confirmed', seller3Address),
      ],
    },
    // order_test_009 — failed payment (regression for failure handling)
    {
      id: 'order_test_009', orderStatus: 'failed', paymentStatus: 'payment_failed', paymentProvider: 'stripe',
      buyerUid: buyer2Uid, customerEmail: 'buyer2@test.origna.ca', sellerIds: [seller4Uid],
      stripePaymentIntentId: 'pi_test_failed_009',
      subtotalCents: 2399, shippingCostCents: 899, taxAmountCents: 430, totalAmountCents: 2399 + 899 + 430,
      shippingAddress: buyerAddress, createdAt: now,
      items: [makeItem('product_012', 'Organic Manitoba Oats', 2399, 1, seller4Uid, 'failed')],
    },
    // order_test_010 — expired authorization
    {
      id: 'order_test_010', orderStatus: 'expired', paymentStatus: 'authorization_expired', paymentProvider: 'stripe',
      buyerUid: buyer2Uid, customerEmail: 'buyer2@test.origna.ca', sellerIds: [seller2Uid],
      stripePaymentIntentId: 'pi_test_expired_010',
      subtotalCents: 8400, shippingCostCents: 1500, taxAmountCents: 1485, totalAmountCents: 8400 + 1500 + 1485,
      shippingAddress: buyerAddress, createdAt: now,
      items: [makeItem('product_007', 'Alberta Cedar Cutting Board', 8400, 1, seller2Uid, 'expired')],
    },
    // order_test_011 — refunded delivered order
    {
      id: 'order_test_011', orderStatus: 'refunded', paymentStatus: 'refunded', paymentProvider: 'stripe',
      buyerUid: buyer3Uid, customerEmail: 'buyer3@test.origna.ca', sellerIds: [seller1Uid],
      stripePaymentIntentId: 'pi_test_refunded_011',
      subtotalCents: 6900, shippingCostCents: 1000, taxAmountCents: 1027, totalAmountCents: 6900 + 1000 + 1027,
      shippingAddress: buyerAddress, createdAt: now,
      items: [makeItem('product_004', 'BC Artisan Coffee Set', 6900, 1, seller1Uid, 'refunded', undefined, true)],
    },
    // order_test_012 — partially refunded order
    {
      id: 'order_test_012', orderStatus: 'partially_refunded', paymentStatus: 'captured', paymentProvider: 'stripe',
      buyerUid: buyer3Uid, customerEmail: 'buyer3@test.origna.ca', sellerIds: [seller5Uid],
      stripePaymentIntentId: 'pi_test_partial_refund_012',
      subtotalCents: 15499, shippingCostCents: 1200, taxAmountCents: 2542, totalAmountCents: 15499 + 1200 + 2542,
      shippingAddress: buyerAddress, createdAt: now,
      items: [makeItem('product_017', 'Nova Scotia Lobster Kit', 15499, 1, seller5Uid, 'partially_refunded', undefined, true)],
    },
    // order_test_013 — admin as buyer for admin dashboard visibility
    {
      id: 'order_test_013', orderStatus: 'processing', paymentStatus: 'authorized', paymentProvider: 'stripe',
      buyerUid: adminUid, customerEmail: 'yr62813@gmail.com', sellerIds: [seller3Uid],
      stripePaymentIntentId: 'pi_test_adminbuyer_013',
      subtotalCents: 11200, shippingCostCents: 1400, taxAmountCents: 1638, totalAmountCents: 11200 + 1400 + 1638,
      shippingAddress: buyerAddress, createdAt: now,
      items: [makeItem('product_008', 'Alberta Wildflower Honey', 11200, 2, seller3Uid, 'processing')],
    },
    // order_test_014 — combo account as buyer
    {
      id: 'order_test_014', orderStatus: 'confirmed', paymentStatus: 'authorized', paymentProvider: 'stripe',
      buyerUid: combo1Uid, customerEmail: 'combo1@test.origna.ca', sellerIds: [seller2Uid],
      stripePaymentIntentId: 'pi_test_combo_014',
      subtotalCents: 9999, shippingCostCents: 1100, taxAmountCents: 1443, totalAmountCents: 9999 + 1100 + 1443,
      shippingAddress: buyerAddress, createdAt: now,
      items: [makeItem('product_006', 'Vancouver Glass Terrarium', 9999, 1, seller2Uid, 'confirmed')],
    },
    // order_test_015 — session expired before payment completion
    {
      id: 'order_test_015', orderStatus: 'pending', paymentStatus: 'session_expired', paymentProvider: 'stripe',
      buyerUid: buyer2Uid, customerEmail: 'buyer2@test.origna.ca', sellerIds: [seller1Uid],
      stripePaymentIntentId: 'pi_test_session_expired_015',
      subtotalCents: 3300, shippingCostCents: 800, taxAmountCents: 533, totalAmountCents: 3300 + 800 + 533,
      shippingAddress: buyerAddress, createdAt: now,
      items: [makeItem('product_003', 'Quebec Tourtière Spice Kit', 3300, 3, seller1Uid, 'pending')],
    },
    // order_test_016 — cancelled after authorization
    {
      id: 'order_test_016', orderStatus: 'cancelled', paymentStatus: 'authorized', paymentProvider: 'stripe',
      buyerUid: buyer3Uid, customerEmail: 'buyer3@test.origna.ca', sellerIds: [seller4Uid],
      stripePaymentIntentId: 'pi_test_cancelled_auth_016',
      subtotalCents: 4700, shippingCostCents: 900, taxAmountCents: 728, totalAmountCents: 4700 + 900 + 728,
      shippingAddress: buyerAddress, createdAt: now,
      items: [makeItem('product_014', 'Prairie Chia Bundle', 4700, 1, seller4Uid, 'cancelled')],
    },
  ];

  for (const order of orders) {
    const { id, ...data } = order;
    if (await writeFirestoreDoc(`orders/${id}`, data)) {
      count++;
      console.log(`  ✅ ${id} (${data.orderStatus})`);
    } else {
      console.error(`  ❌ ${id} FAILED`);
    }
  }

  console.log(`  📊 ${count}/${orders.length} orders created`);
}

// ════════════════════════════════════════════════════════════════════
// MAIN
// ════════════════════════════════════════════════════════════════════

async function main() {
  console.log('🌱 OrignaGTA MEGA Seed Script');
  console.log('═══════════════════════════════════════════════');
  console.log(`  Auth: ${AUTH_EMULATOR} | Firestore: ${FIRESTORE_EMULATOR}`);
  console.log(`  Project: ${PROJECT_ID}`);

  // Verify emulators
  try { const r = await fetch(`${AUTH_EMULATOR}/`); if (!r.ok) throw 0; }
  catch { console.error('❌ Auth emulator not running!'); process.exit(1); }
  try { const r = await fetch(`${FIRESTORE_EMULATOR}/`); if (!r.ok) throw 0; }
  catch { console.error('❌ Firestore emulator not running!'); process.exit(1); }

  await clearEmulatorData();
  const uidMap = await seedUsers();
  await seedProducts(uidMap);
  await seedCartItems(uidMap);
  await seedOrders(uidMap);

  // Export the UID map as a JSON for the test suite to consume
  const mapObj: Record<string, string> = {};
  uidMap.forEach((v, k) => mapObj[k] = v);
  const fs = require('fs');
  fs.writeFileSync('seed-uid-map.json', JSON.stringify(mapObj, null, 2));

  console.log('\n═══════════════════════════════════════════════');
  console.log('✅ MEGA SEED COMPLETE!');
  console.log(`  👤 Users: ${uidMap.size} (of ${USERS.length})`);
  console.log(`  📦 Products: ${PRODUCTS.length}`);
  console.log(`  🛒 Carts populated: ~20 buyers`);
  console.log(`  � Orders: 8 (for regression tests)`);
  console.log(`  �📧 Admin: yr62813@gmail.com`);
  console.log(`  📁 UID map exported to seed-uid-map.json`);
  console.log('═══════════════════════════════════════════════');
}

main().catch(e => { console.error('Seed failed:', e); process.exit(1); });

// Make this file an ES module to avoid variable conflicts with seed-emulator.ts
export {};
