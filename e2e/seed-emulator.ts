/**
 * Emulator Seed Script
 * ====================
 * Creates 25+ users with random roles and products in the Firebase emulator.
 * Run AFTER emulators are started: npx ts-node seed-emulator.ts
 * 
 * Users created:
 * - 1 admin (yr62813@gmail.com) - receives all email notifications
 * - 5 sellers (with addresses, seller profiles, Stripe-like IDs)
 * - 15 buyers (with addresses in various Canadian provinces)
 * - 4 buyer+seller combo accounts
 * - 25+ total users
 * 
 * Products created:
 * - 15+ products across various categories with different sellers
 * - Different shipping configs (free, local-only, perishable, digital)
 */

const AUTH_EMULATOR = 'http://127.0.0.1:9099';
const FIRESTORE_EMULATOR = 'http://127.0.0.1:8080';
const PROJECT_ID = 'orignagta';

// ============================================================================
// CANADIAN ADDRESSES
// ============================================================================

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

const CANADIAN_ADDRESSES: SeedAddress[] = [
  { street: '100 Queen St W', apartment: '', city: 'Toronto', state: 'ON', postalCode: 'M5H 2N2', country: 'Canada', phoneNumber: '+14165551001', isDefault: true, label: 'Home', latitude: 43.6532, longitude: -79.3832 },
  { street: '275 Slater St', apartment: 'Suite 900', city: 'Ottawa', state: 'ON', postalCode: 'K1P 5H9', country: 'Canada', phoneNumber: '+16135551002', isDefault: true, label: 'Work', latitude: 45.4215, longitude: -75.6972 },
  { street: '1000 De La Gauchetière W', apartment: '', city: 'Montreal', state: 'QC', postalCode: 'H3B 4W5', country: 'Canada', phoneNumber: '+15145551003', isDefault: true, label: 'Home', latitude: 45.5017, longitude: -73.5673 },
  { street: '200 Burrard St', apartment: 'Unit 12', city: 'Vancouver', state: 'BC', postalCode: 'V6C 3L6', country: 'Canada', phoneNumber: '+16045551004', isDefault: true, label: 'Home', latitude: 49.2827, longitude: -123.1207 },
  { street: '101 9 Ave SW', apartment: '', city: 'Calgary', state: 'AB', postalCode: 'T2P 1J9', country: 'Canada', phoneNumber: '+14035551005', isDefault: true, label: 'Home', latitude: 51.0447, longitude: -114.0719 },
  { street: '10060 Jasper Ave', apartment: 'Apt 305', city: 'Edmonton', state: 'AB', postalCode: 'T5J 3R8', country: 'Canada', phoneNumber: '+17805551006', isDefault: true, label: 'Work', latitude: 53.5461, longitude: -113.4938 },
  { street: '360 Main St', apartment: '', city: 'Winnipeg', state: 'MB', postalCode: 'R3C 3Z3', country: 'Canada', phoneNumber: '+12045551007', isDefault: true, label: 'Home', latitude: 49.8951, longitude: -97.1384 },
  { street: '1 Market Sq', apartment: '', city: 'Saint John', state: 'NB', postalCode: 'E2L 4Z6', country: 'Canada', phoneNumber: '+15065551008', isDefault: true, label: 'Home', latitude: 45.2733, longitude: -66.0633 },
  { street: '1726 Argyle St', apartment: '', city: 'Halifax', state: 'NS', postalCode: 'B3J 3N6', country: 'Canada', phoneNumber: '+19025551009', isDefault: true, label: 'Home', latitude: 44.6488, longitude: -63.5752 },
  { street: '137 Queen St', apartment: '', city: 'Charlottetown', state: 'PE', postalCode: 'C1A 4B3', country: 'Canada', phoneNumber: '+19025551010', isDefault: true, label: 'Home', latitude: 46.2382, longitude: -63.1311 },
  { street: '189 Water St', apartment: '', city: "St. John's", state: 'NL', postalCode: 'A1C 1B4', country: 'Canada', phoneNumber: '+17095551011', isDefault: true, label: 'Home', latitude: 47.5615, longitude: -52.7126 },
  { street: '2100 2nd Ave', apartment: '', city: 'Whitehorse', state: 'YT', postalCode: 'Y1A 1C2', country: 'Canada', phoneNumber: '+18675551012', isDefault: true, label: 'Home', latitude: 60.7212, longitude: -135.0568 },
  { street: '4807 49 St', apartment: '', city: 'Yellowknife', state: 'NT', postalCode: 'X1A 3T5', country: 'Canada', phoneNumber: '+18675551013', isDefault: true, label: 'Home', latitude: 62.4540, longitude: -114.3718 },
  { street: '979 Federal Rd', apartment: '', city: 'Iqaluit', state: 'NU', postalCode: 'X0A 0H0', country: 'Canada', phoneNumber: '+18675551014', isDefault: true, label: 'Home', latitude: 63.7467, longitude: -68.5170 },
  { street: '2025 Albert St', apartment: 'Floor 2', city: 'Regina', state: 'SK', postalCode: 'S4P 2T9', country: 'Canada', phoneNumber: '+13065551015', isDefault: true, label: 'Work', latitude: 50.4452, longitude: -104.6189 },
  { street: '123 Yonge St', apartment: 'Apt 1502', city: 'Toronto', state: 'ON', postalCode: 'M5C 1W4', country: 'Canada', phoneNumber: '+14165551016', isDefault: true, label: 'Home', latitude: 43.6510, longitude: -79.3780 },
  { street: '555 Seymour St', apartment: 'Unit 8B', city: 'Vancouver', state: 'BC', postalCode: 'V6B 3H6', country: 'Canada', phoneNumber: '+16045551017', isDefault: true, label: 'Home', latitude: 49.2835, longitude: -123.1153 },
  { street: '85 Rue Sainte-Catherine E', apartment: '', city: 'Montreal', state: 'QC', postalCode: 'H2X 3P4', country: 'Canada', phoneNumber: '+15145551018', isDefault: true, label: 'Home', latitude: 45.5100, longitude: -73.5600 },
  { street: '75 Sparks St', apartment: 'Suite 200', city: 'Ottawa', state: 'ON', postalCode: 'K1P 5A5', country: 'Canada', phoneNumber: '+16135551019', isDefault: true, label: 'Work', latitude: 45.4230, longitude: -75.6990 },
  { street: '400 Portage Ave', apartment: '', city: 'Winnipeg', state: 'MB', postalCode: 'R3C 0C4', country: 'Canada', phoneNumber: '+12045551020', isDefault: true, label: 'Home', latitude: 49.8900, longitude: -97.1500 },
  { street: '100 Sussex Dr', apartment: '', city: 'Ottawa', state: 'ON', postalCode: 'K1N 1K4', country: 'Canada', phoneNumber: '+16135551021', isDefault: true, label: 'Home', latitude: 45.4380, longitude: -75.6950 },
  { street: '3600 Blvd de la Côte-Vertu', apartment: 'App 10', city: 'Saint-Laurent', state: 'QC', postalCode: 'H4R 1P8', country: 'Canada', phoneNumber: '+15145551022', isDefault: true, label: 'Home', latitude: 45.5088, longitude: -73.6830 },
  { street: '888 Nelson St', apartment: '', city: 'Vancouver', state: 'BC', postalCode: 'V6Z 2H1', country: 'Canada', phoneNumber: '+16045551023', isDefault: true, label: 'Work', latitude: 49.2820, longitude: -123.1240 },
  { street: '220 4th Ave SE', apartment: 'Floor 3', city: 'Calgary', state: 'AB', postalCode: 'T2G 4X3', country: 'Canada', phoneNumber: '+14035551024', isDefault: true, label: 'Home', latitude: 51.0400, longitude: -114.0600 },
  { street: '45 King William St', apartment: '', city: 'Hamilton', state: 'ON', postalCode: 'L8R 1A2', country: 'Canada', phoneNumber: '+19055551025', isDefault: true, label: 'Home', latitude: 43.2557, longitude: -79.8711 },
];

// ============================================================================
// ============================================================================

interface SeedUser {
  email: string;
  password: string;
  displayName: string;
  roles: string[];
  addressIndex: number;
  sellerProfile?: {
    businessName: string;
    businessAddress: SeedAddress;
    stripeAccountId: string;
    payoutsEnabled: boolean;
    chargesEnabled: boolean;
    onboardingCompleted: boolean;
  };
}

const USERS: SeedUser[] = [
  // ADMIN (1) - receives all email notifications
  {
    email: 'yr62813@gmail.com', password: 'REDACTED_TEST_PASSWORD', displayName: 'Admin Yunior', roles: ['admin', 'seller', 'buyer'], addressIndex: 0,
    sellerProfile: { businessName: 'Origna Admin Store', businessAddress: CANADIAN_ADDRESSES[0], stripeAccountId: 'acct_test_admin001', payoutsEnabled: true, chargesEnabled: true, onboardingCompleted: true }
  },

  // SELLERS (5)
  {
    email: 'seller1@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Marie Tremblay', roles: ['seller', 'buyer'], addressIndex: 2,
    sellerProfile: { businessName: 'Mode Montréal', businessAddress: CANADIAN_ADDRESSES[2], stripeAccountId: 'acct_test_seller001', payoutsEnabled: true, chargesEnabled: true, onboardingCompleted: true }
  },
  {
    email: 'seller2@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'James Wilson', roles: ['seller', 'buyer'], addressIndex: 3,
    sellerProfile: { businessName: 'Pacific Goods', businessAddress: CANADIAN_ADDRESSES[3], stripeAccountId: 'acct_test_seller002', payoutsEnabled: true, chargesEnabled: true, onboardingCompleted: true }
  },
  {
    email: 'seller3@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Priya Sharma', roles: ['seller', 'buyer'], addressIndex: 4,
    sellerProfile: { businessName: 'Calgary Crafts', businessAddress: CANADIAN_ADDRESSES[4], stripeAccountId: 'acct_test_seller003', payoutsEnabled: true, chargesEnabled: true, onboardingCompleted: true }
  },
  {
    email: 'seller4@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Lucas Gagnon', roles: ['seller', 'buyer'], addressIndex: 1,
    sellerProfile: { businessName: 'Ottawa Artisan', businessAddress: CANADIAN_ADDRESSES[1], stripeAccountId: 'acct_test_seller004', payoutsEnabled: true, chargesEnabled: true, onboardingCompleted: true }
  },
  {
    email: 'seller5@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Sophie Chen', roles: ['seller'], addressIndex: 16,
    sellerProfile: { businessName: 'West Coast Wares', businessAddress: CANADIAN_ADDRESSES[16], stripeAccountId: 'acct_test_seller005', payoutsEnabled: false, chargesEnabled: false, onboardingCompleted: false }
  },

  // BUYERS (15) - across various provinces
  { email: 'yuniorrodriguezo460@gmail.com', password: 'REDACTED_TEST_PASSWORD', displayName: 'David Brown', roles: ['buyer'], addressIndex: 5 },
  { email: 'buyer2@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Emma Davis', roles: ['buyer'], addressIndex: 6 },
  { email: 'buyer3@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Oliver Martin', roles: ['buyer'], addressIndex: 7 },
  { email: 'buyer4@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Chloé Dubois', roles: ['buyer'], addressIndex: 8 },
  { email: 'buyer5@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Liam Murphy', roles: ['buyer'], addressIndex: 9 },
  { email: 'buyer6@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Ava O\'Brien', roles: ['buyer'], addressIndex: 10 },
  { email: 'buyer7@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Noah Taylor', roles: ['buyer'], addressIndex: 11 },
  { email: 'buyer8@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Sophia Makivik', roles: ['buyer'], addressIndex: 12 },
  { email: 'buyer9@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Étienne Lavoie', roles: ['buyer'], addressIndex: 13 },
  { email: 'buyer10@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Isabella Singh', roles: ['buyer'], addressIndex: 14 },
  { email: 'buyer11@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Benjamin Kim', roles: ['buyer'], addressIndex: 15 },
  { email: 'buyer12@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Mia Johnson', roles: ['buyer'], addressIndex: 17 },
  { email: 'buyer13@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Alexander Patel', roles: ['buyer'], addressIndex: 18 },
  { email: 'buyer14@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Charlotte White', roles: ['buyer'], addressIndex: 19 },
  { email: 'buyer15@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'William Lee', roles: ['buyer'], addressIndex: 20 },

  // BUYER+SELLER COMBO (4)
  {
    email: 'combo1@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Fatima Hassan', roles: ['buyer', 'seller'], addressIndex: 21,
    sellerProfile: { businessName: 'Fatima Crafts QC', businessAddress: CANADIAN_ADDRESSES[21], stripeAccountId: 'acct_test_combo001', payoutsEnabled: true, chargesEnabled: true, onboardingCompleted: true }
  },
  {
    email: 'combo2@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Ryan MacDonald', roles: ['buyer', 'seller'], addressIndex: 22,
    sellerProfile: { businessName: 'Ryan\'s BC Goods', businessAddress: CANADIAN_ADDRESSES[22], stripeAccountId: 'acct_test_combo002', payoutsEnabled: true, chargesEnabled: true, onboardingCompleted: true }
  },
  {
    email: 'combo3@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Aisha Mohammed', roles: ['buyer', 'seller'], addressIndex: 23,
    sellerProfile: { businessName: 'Aisha Style AB', businessAddress: CANADIAN_ADDRESSES[23], stripeAccountId: 'acct_test_combo003', payoutsEnabled: true, chargesEnabled: true, onboardingCompleted: true }
  },
  {
    email: 'combo4@test.origna.ca', password: 'REDACTED_TEST_PASSWORD', displayName: 'Daniel Thompson', roles: ['buyer', 'seller'], addressIndex: 24,
    sellerProfile: { businessName: 'Dan\'s Hamilton Hub', businessAddress: CANADIAN_ADDRESSES[24], stripeAccountId: 'acct_test_combo004', payoutsEnabled: true, chargesEnabled: true, onboardingCompleted: true }
  },
];

// ============================================================================
// PRODUCT DEFINITIONS
// ============================================================================

interface SeedProduct {
  name: string;
  price: number;
  description: string;
  categoryId: number;
  stockQuantity: number;
  sellerIndex: number; // index into USERS array (sellers only)
  imageUrls: string[];
  keywords: string[];
  freeShipping: boolean;
  isDigital: boolean;
  isLocalDeliveryOnly: boolean;
  isPerishable: boolean;
  estimatedShipDays: number;
  weightKg?: number;
  deliveryOptions: any[];
}

// Category IDs from the app:
// 1=Electronics, 2=Clothing, 3=Home, 4=Sports, 5=Books, 6=Toys, 
// 7=Beauty, 8=Automotive, 9=Garden, 10=Health, 11=Jewelry,
// 12=Pet, 13=Food, 14=Art, 15=Music, 16=Office, 17=Kids, 18=Vintage,
// 19=Groceries, 20=Services, 21=Other

const PRODUCTS: SeedProduct[] = [
  // Seller 1 (Marie Tremblay - Montreal)
  { name: 'Handmade Quebec Scarf', price: 45.99, description: 'Beautiful handwoven scarf made with Quebec alpaca wool. Perfect for Canadian winters.', categoryId: 2, stockQuantity: 25, sellerIndex: 1, imageUrls: ['https://picsum.photos/seed/scarf/400/400'], keywords: ['scarf', 'quebec', 'handmade', 'wool', 'winter', 'clothing'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 3, weightKg: 0.3, deliveryOptions: [{ type: 'standard', description: 'Standard shipping', cost: 0, estimatedDays: 5 }, { type: 'express', description: 'Express shipping', cost: 9.99, estimatedDays: 2 }] },
  { name: 'Montreal Artisan Leather Bag', price: 189.99, description: 'Premium leather messenger bag crafted in Mile End, Montreal. Full-grain Canadian leather.', categoryId: 2, stockQuantity: 10, sellerIndex: 1, imageUrls: ['https://picsum.photos/seed/bag/400/400'], keywords: ['bag', 'leather', 'montreal', 'artisan', 'messenger'], freeShipping: true, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 3, weightKg: 1.2, deliveryOptions: [{ type: 'standard', description: 'Free standard shipping', cost: 0, estimatedDays: 5 }] },

  // Seller 2 (James Wilson - Vancouver)
  { name: 'BC Cedar Incense Set', price: 24.99, description: 'Hand-harvested BC red cedar incense sticks. Natural aromatherapy from the Pacific Northwest.', categoryId: 3, stockQuantity: 50, sellerIndex: 2, imageUrls: ['https://picsum.photos/seed/incense/400/400'], keywords: ['incense', 'cedar', 'bc', 'natural', 'aromatherapy', 'home'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 4, weightKg: 0.2, deliveryOptions: [{ type: 'standard', description: 'Standard shipping', cost: 0, estimatedDays: 5 }, { type: 'express', description: 'Express shipping', cost: 7.99, estimatedDays: 2 }] },
  { name: 'Pacific Coast Trail Running Shoes', price: 129.99, description: 'Lightweight trail running shoes designed for BC mountain trails. Waterproof Gore-Tex upper.', categoryId: 4, stockQuantity: 30, sellerIndex: 2, imageUrls: ['https://picsum.photos/seed/shoes/400/400'], keywords: ['shoes', 'running', 'trail', 'sports', 'waterproof', 'hiking'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 3, weightKg: 0.8, deliveryOptions: [{ type: 'standard', description: 'Standard shipping', cost: 0, estimatedDays: 5 }, { type: 'express', description: 'Express shipping', cost: 12.99, estimatedDays: 2 }] },
  { name: 'Vancouver Island Honey (500g)', price: 18.99, description: 'Raw wildflower honey from Vancouver Island apiaries. Unpasteurized and unfiltered.', categoryId: 19, stockQuantity: 40, sellerIndex: 2, imageUrls: ['https://picsum.photos/seed/honey/400/400'], keywords: ['honey', 'food', 'organic', 'vancouver', 'raw', 'natural'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: true, isPerishable: true, estimatedShipDays: 1, weightKg: 0.6, deliveryOptions: [{ type: 'standard', description: 'Standard shipping', cost: 5.99, estimatedDays: 3 }, { type: 'same_day', description: 'Same day delivery', cost: 14.99, estimatedDays: 0 }] },

  // Seller 3 (Priya Sharma - Calgary)
  { name: 'Alberta Beef Jerky Gift Box', price: 34.99, description: 'Premium Alberta beef jerky in 3 flavours: Original, Maple, and Smoked Pepper. 300g total.', categoryId: 13, stockQuantity: 60, sellerIndex: 3, imageUrls: ['https://picsum.photos/seed/jerky/400/400'], keywords: ['beef', 'jerky', 'alberta', 'snack', 'gift', 'food'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 3, weightKg: 0.4, deliveryOptions: [{ type: 'standard', description: 'Standard shipping', cost: 0, estimatedDays: 5 }] },
  { name: 'Calgary Stampede Poster Print', price: 29.99, description: 'Limited edition art print inspired by the Calgary Stampede. 18"x24" archival quality.', categoryId: 14, stockQuantity: 100, sellerIndex: 3, imageUrls: ['https://picsum.photos/seed/poster/400/400'], keywords: ['poster', 'art', 'calgary', 'stampede', 'print', 'western'], freeShipping: true, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 5, weightKg: 0.3, deliveryOptions: [{ type: 'standard', description: 'Free standard shipping', cost: 0, estimatedDays: 7 }] },
  { name: 'Wireless Bluetooth Earbuds Pro', price: 79.99, description: 'Active noise cancelling earbuds with 30hr battery life. IPX5 waterproof for Canadian weather.', categoryId: 1, stockQuantity: 45, sellerIndex: 3, imageUrls: ['https://picsum.photos/seed/earbuds/400/400'], keywords: ['earbuds', 'bluetooth', 'wireless', 'audio', 'electronics', 'anc'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 2, weightKg: 0.1, deliveryOptions: [{ type: 'standard', description: 'Standard shipping', cost: 0, estimatedDays: 4 }, { type: 'express', description: 'Express shipping', cost: 9.99, estimatedDays: 1 }] },

  // Seller 4 (Lucas Gagnon - Ottawa)
  { name: 'Canadian History eBook Bundle', price: 14.99, description: 'Digital collection of 5 eBooks covering Canadian history from Confederation to present.', categoryId: 5, stockQuantity: 999, sellerIndex: 4, imageUrls: ['https://picsum.photos/seed/ebook/400/400'], keywords: ['ebook', 'history', 'canada', 'digital', 'education', 'books'], freeShipping: true, isDigital: true, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 0, deliveryOptions: [] },
  { name: 'Ottawa Parliament Puzzle 1000pc', price: 39.99, description: '1000-piece jigsaw puzzle featuring the Parliament Buildings during autumn. Made in Canada.', categoryId: 6, stockQuantity: 35, sellerIndex: 4, imageUrls: ['https://picsum.photos/seed/puzzle/400/400'], keywords: ['puzzle', 'ottawa', 'parliament', 'jigsaw', 'toy', 'game'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 3, weightKg: 0.8, deliveryOptions: [{ type: 'standard', description: 'Standard shipping', cost: 0, estimatedDays: 5 }] },
  { name: 'Organic Maple Syrup (1L)', price: 22.50, description: 'Grade A amber organic maple syrup from Eastern Ontario sugar bush. 100% pure.', categoryId: 19, stockQuantity: 80, sellerIndex: 4, imageUrls: ['https://picsum.photos/seed/maple/400/400'], keywords: ['maple', 'syrup', 'organic', 'ontario', 'food', 'canadian'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 3, weightKg: 1.1, deliveryOptions: [{ type: 'standard', description: 'Standard shipping', cost: 0, estimatedDays: 5 }, { type: 'express', description: 'Express shipping', cost: 11.99, estimatedDays: 2 }] },

  // Combo sellers (indices 21-24 in USERS array)
  { name: 'Quebec Pottery Mug Set (4)', price: 59.99, description: 'Set of 4 hand-thrown ceramic mugs from a Quebec artisan workshop. Dishwasher safe.', categoryId: 3, stockQuantity: 15, sellerIndex: 21, imageUrls: ['https://picsum.photos/seed/mugs/400/400'], keywords: ['mug', 'pottery', 'ceramic', 'quebec', 'kitchen', 'handmade'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 5, weightKg: 2.0, deliveryOptions: [{ type: 'standard', description: 'Standard shipping', cost: 0, estimatedDays: 7 }] },
  { name: 'BC Fresh Salmon Fillet (1kg)', price: 32.99, description: 'Wild Pacific sockeye salmon fillet, freshly caught from BC waters. Flash frozen for freshness.', categoryId: 13, stockQuantity: 20, sellerIndex: 22, imageUrls: ['https://picsum.photos/seed/salmon/400/400'], keywords: ['salmon', 'fish', 'bc', 'seafood', 'fresh', 'food'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: true, isPerishable: true, estimatedShipDays: 0, weightKg: 1.1, deliveryOptions: [{ type: 'same_day', description: 'Same day delivery', cost: 14.99, estimatedDays: 0 }] },
  { name: 'Handmade Silver Necklace', price: 149.99, description: 'Sterling silver necklace with Canadian jade pendant. Handcrafted in Calgary, Alberta.', categoryId: 11, stockQuantity: 8, sellerIndex: 23, imageUrls: ['https://picsum.photos/seed/necklace/400/400'], keywords: ['necklace', 'silver', 'jewelry', 'jade', 'handmade', 'gift'], freeShipping: true, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 3, weightKg: 0.05, deliveryOptions: [{ type: 'standard', description: 'Free standard shipping', cost: 0, estimatedDays: 5 }, { type: 'express', description: 'Express shipping', cost: 9.99, estimatedDays: 2 }] },
  { name: 'Hamilton Steel City T-Shirt', price: 28.99, description: 'Premium cotton t-shirt featuring Hamilton skyline design. Available in S-XXL.', categoryId: 2, stockQuantity: 75, sellerIndex: 24, imageUrls: ['https://picsum.photos/seed/tshirt/400/400'], keywords: ['tshirt', 'hamilton', 'clothing', 'cotton', 'design', 'apparel'], freeShipping: false, isDigital: false, isLocalDeliveryOnly: false, isPerishable: false, estimatedShipDays: 3, weightKg: 0.2, deliveryOptions: [{ type: 'standard', description: 'Standard shipping', cost: 0, estimatedDays: 5 }] },
];

// ============================================================================
// SEED FUNCTIONS
// ============================================================================

async function clearEmulatorData() {
  console.log('🗑️  Clearing existing emulator data...');

  // Clear Auth
  try {
    await fetch(`${AUTH_EMULATOR}/emulator/v1/projects/${PROJECT_ID}/accounts`, { method: 'DELETE' });
    console.log('  ✅ Auth cleared');
  } catch (e) {
    console.log(`  ⚠️ Auth clear failed: ${e}`);
  }

  // Clear Firestore
  try {
    await fetch(`${FIRESTORE_EMULATOR}/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`, { method: 'DELETE' });
    console.log('  ✅ Firestore cleared');
  } catch (e) {
    console.log(`  ⚠️ Firestore clear failed: ${e}`);
  }
}

async function createAuthUser(email: string, password: string, displayName: string): Promise<string | null> {
  try {
    const response = await fetch(
      `${AUTH_EMULATOR}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, displayName, returnSecureToken: true }),
      }
    );
    const data = await response.json();
    if (data.error) {
      console.error(`  ❌ Auth user ${email}: ${data.error.message}`);
      return null;
    }

    // Verify email in emulator
    const uid = data.localId;
    const verifyRes = await fetch(
      `${AUTH_EMULATOR}/identitytoolkit.googleapis.com/v1/accounts:update?key=fake-api-key`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer owner',
        },
        body: JSON.stringify({ localId: uid, emailVerified: true }),
      }
    );

    if (!verifyRes.ok) {
      const err = await verifyRes.text();
      console.error(`  ⚠️ Verification failed for ${email}: ${err}`);
    }

    return uid;
  } catch (e) {
    console.error(`  ❌ Auth create failed for ${email}: ${e}`);
    return null;
  }
}

async function createFirestoreDoc(collection: string, docId: string, data: any) {
  // Convert to Firestore REST format
  const fields = toFirestoreFields(data);

  try {
    const url = `${FIRESTORE_EMULATOR}/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}/${docId}`;
    const response = await fetch(url, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer owner',  // Bypass Firestore Security Rules in emulator
      },
      body: JSON.stringify({ fields }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`  ❌ Firestore ${collection}/${docId}: ${errorText}`);
      return false;
    }
    return true;
  } catch (e) {
    console.error(`  ❌ Firestore write failed: ${e}`);
    return false;
  }
}

// Convert JS object to Firestore REST API field format
function toFirestoreFields(obj: any): any {
  const fields: any = {};
  for (const [key, value] of Object.entries(obj)) {
    fields[key] = toFirestoreValue(value);
  }
  return fields;
}

function toFirestoreValue(value: any): any {
  if (value === null || value === undefined) {
    return { nullValue: null };
  }
  if (typeof value === 'string') {
    return { stringValue: value };
  }
  if (typeof value === 'number') {
    if (Number.isInteger(value)) {
      return { integerValue: String(value) };
    }
    return { doubleValue: value };
  }
  if (typeof value === 'boolean') {
    return { booleanValue: value };
  }
  if (value instanceof Date) {
    return { timestampValue: value.toISOString() };
  }
  if (Array.isArray(value)) {
    return {
      arrayValue: {
        values: value.map(v => toFirestoreValue(v)),
      },
    };
  }
  if (typeof value === 'object') {
    return {
      mapValue: {
        fields: toFirestoreFields(value),
      },
    };
  }
  return { stringValue: String(value) };
}

async function seedUsers(): Promise<Map<string, string>> {
  console.log('\n👤 Creating users...');
  const uidMap = new Map<string, string>(); // email -> uid

  for (let i = 0; i < USERS.length; i++) {
    const user = USERS[i];
    const uid = await createAuthUser(user.email, user.password, user.displayName);
    if (!uid) continue;

    uidMap.set(user.email, uid);

    // Build user document
    const userDoc: any = {
      uid,
      email: user.email,
      name: user.displayName,
      roles: user.roles,
      address: CANADIAN_ADDRESSES[user.addressIndex],
      createdAt: new Date().toISOString(),
      payoutsEnabled: user.sellerProfile?.payoutsEnabled ?? false,
      chargesEnabled: user.sellerProfile?.chargesEnabled ?? false,
      onboardingCompleted: user.sellerProfile?.onboardingCompleted ?? false,
      suspended: false,
      paymentProvider: 'stripe',
      commissionRate: 0.025,
      verified: user.roles.includes('seller'),
      payoutHoldDays: 7,
    };

    if (user.sellerProfile) {
      userDoc.stripeAccountId = user.sellerProfile.stripeAccountId;
      userDoc.sellerProfile = {
        businessName: user.sellerProfile.businessName,
        businessAddress: user.sellerProfile.businessAddress,
      };
      userDoc.businessName = user.sellerProfile.businessName;
    }

    const success = await createFirestoreDoc('users', uid, userDoc);
    if (success) {
      const rolesStr = user.roles.join('+');
      console.log(`  ✅ ${user.displayName} (${rolesStr}) - ${user.email}`);
    }
  }

  return uidMap;
}

async function seedProducts(uidMap: Map<string, string>) {
  console.log('\n📦 Creating products...');

  for (let i = 0; i < PRODUCTS.length; i++) {
    const product = PRODUCTS[i];
    const sellerUser = USERS[product.sellerIndex];
    const sellerId = uidMap.get(sellerUser.email);

    if (!sellerId) {
      console.log(`  ⚠️ Skipping "${product.name}" - seller ${sellerUser.email} not created`);
      continue;
    }

    const sellerAddr = CANADIAN_ADDRESSES[sellerUser.addressIndex];
    const productId = `product_${String(i + 1).padStart(3, '0')}`;

    const productDoc: any = {
      name: product.name,
      price: product.price,
      description: product.description,
      sellerId,
      sellerAddress: sellerAddr,
      categoryId: product.categoryId,
      stockQuantity: product.stockQuantity,
      imageUrls: product.imageUrls,
      keywords: product.keywords,
      rating: Math.round((3 + Math.random() * 2) * 10) / 10, // 3.0-5.0
      ratingCount: Math.floor(Math.random() * 50),
      createdAt: new Date().toISOString(),
      isActive: true,
      isDigital: product.isDigital,
      freeShipping: product.freeShipping,
      isLocalDeliveryOnly: product.isLocalDeliveryOnly,
      isPerishable: product.isPerishable,
      estimatedShipDays: product.estimatedShipDays,
      deliveryOptions: product.deliveryOptions,
      minimumOrderQuantity: 1,
    };

    if (product.weightKg) {
      productDoc.weightKg = product.weightKg;
    }

    const success = await createFirestoreDoc('products', productId, productDoc);
    if (success) {
      console.log(`  ✅ "${product.name}" ($${product.price}) by ${sellerUser.displayName}`);
    }
  }
}

async function seedCartItems(uidMap: Map<string, string>) {
  console.log('\n🛒 Adding items to buyer carts...');

  // Give a few buyers some cart items
  const buyerEmails = ['yuniorrodriguezo460@gmail.com', 'buyer2@test.origna.ca', 'buyer3@test.origna.ca'];
  const cartProducts = [
    { productId: 'product_001', quantity: 1 },
    { productId: 'product_003', quantity: 2 },
    { productId: 'product_008', quantity: 1 },
  ];

  for (const email of buyerEmails) {
    const uid = uidMap.get(email);
    if (!uid) continue;

    const cartItem = cartProducts[buyerEmails.indexOf(email)];
    const cartDoc = {
      productId: cartItem.productId,
      quantity: cartItem.quantity,
      createdAt: new Date().toISOString(),
    };

    const success = await createFirestoreDoc(`users/${uid}/cart`, cartItem.productId, cartDoc);
    if (success) {
      console.log(`  ✅ ${email} → ${cartItem.productId} (qty: ${cartItem.quantity})`);
    }
  }
}

// ============================================================================
// MAIN
// ============================================================================

async function main() {
  console.log('🌱 OrignaGTA Emulator Seed Script');
  console.log('═══════════════════════════════════');
  console.log(`Auth Emulator: ${AUTH_EMULATOR}`);
  console.log(`Firestore Emulator: ${FIRESTORE_EMULATOR}`);
  console.log(`Project: ${PROJECT_ID}`);

  // Check emulators are running
  try {
    const authCheck = await fetch(`${AUTH_EMULATOR}/`);
    if (!authCheck.ok) throw new Error('Auth emulator not responding');
  } catch {
    console.error('\n❌ Firebase emulators are not running!');
    console.error('Start them first: firebase emulators:start');
    process.exit(1);
  }

  try {
    const fsCheck = await fetch(`${FIRESTORE_EMULATOR}/`);
    if (!fsCheck.ok) throw new Error('Firestore emulator not responding');
  } catch {
    console.error('\n❌ Firestore emulator not responding!');
    process.exit(1);
  }

  await clearEmulatorData();
  const uidMap = await seedUsers();
  await seedProducts(uidMap);
  await seedCartItems(uidMap);

  console.log('\n═══════════════════════════════════');
  console.log('✅ SEED COMPLETE!');
  console.log(`  👤 Users created: ${uidMap.size}`);
  console.log(`  📦 Products created: ${PRODUCTS.length}`);
  console.log(`  🛒 Cart items added: 3`);
  console.log(`  📧 Admin email: yr62813@gmail.com`);
  console.log('═══════════════════════════════════');
}

main().catch((e) => {
  console.error('Seed script failed:', e);
  process.exit(1);
});

// Make this file an ES module to avoid variable conflicts with mega-seed.ts
export { };
