import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _defaultTermsContent = '''
Welcome to OrignaGTA. By accessing or using our platform, you agree to be bound by these Terms and Conditions.

1. ACCEPTANCE OF TERMS

By creating an account, browsing, or making purchases on OrignaGTA, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions, as well as our Privacy Policy.

2. ACCOUNT REGISTRATION

To use certain features of our platform, you must register for an account. You agree to:
- Provide accurate and complete information
- Maintain the security of your account credentials
- Accept responsibility for all activities under your account
- Notify us immediately of any unauthorized use

3. PURCHASES AND PAYMENTS

When you make a purchase on OrignaGTA:
- All prices are in Canadian Dollars (CAD) unless otherwise stated
- Prices include applicable taxes as required by law
- Payment is processed securely through Stripe
- You agree to pay all charges at the prices in effect when incurred
- We reserve the right to refuse or cancel orders at our discretion

4. SHIPPING AND DELIVERY

- Shipping costs are calculated dynamically using an industry-leading tiered model benchmarked against major platforms (Instacart, DoorDash, and Canada Post).
- Hyper-Local Rates (≤ 15km):
  * Standard: \$1.99 (Matches Instacart Scheduled)
  * Rapid: \$7.99 (Matches DoorDash Retail)
  * Same-Day: \$8.99 (Matches Premium Grocery Delivery)
- National Rates: Capped at a standard \$26.99 ceiling to remain competitive with Canada Post Regular Parcel rates.
- Delivery times are estimates provided by the system based on selected speed (Standard, Express, or Same-Day).
- Sellers are responsible for ensuring timely dispatch, particularly for Rapid and Same-Day services.

5. RETURNS AND REFUNDS

- Return policies are set by individual sellers
- Contact the seller directly for return requests
- Refunds will be processed to the original payment method
- Some items may not be eligible for return

6. SELLER RESPONSIBILITIES

If you sell products on OrignaGTA, you agree to:
- Provide accurate product descriptions, images, weights, and dimensions
- Ship products within the specified timeframe (Priority given to Rapid/Same-Day orders)
- Respond to buyer inquiries promptly
- Comply with all applicable laws and regulations
- Accept responsibility for the quality of your products and the accuracy of shipping data provided

7. PROHIBITED ACTIVITIES

You may not:
- Violate any laws or regulations
- Infringe on intellectual property rights
- Post false or misleading information
- Engage in fraudulent activities
- Attempt to manipulate the platform

8. INTELLECTUAL PROPERTY

All content on OrignaGTA, including logos, designs, and text, is our property or licensed to us. You may not use, reproduce, or distribute this content without permission.

9. LIMITATION OF LIABILITY

OrignaGTA is provided "as is" without warranties. We are not liable for:
- Indirect, incidental, or consequential damages
- Loss of data or profits
- Actions of third-party sellers
- Service interruptions

10. PRIVACY

Your use of OrignaGTA is also governed by our Privacy Policy. By using our platform, you consent to the collection and use of your information as described therein.

11. CHANGES TO TERMS

We may modify these Terms at any time. Continued use of the platform after changes constitutes acceptance of the new Terms.

12. TERMINATION

We reserve the right to terminate or suspend your account for violations of these Terms or for any other reason at our sole discretion.

13. GOVERNING LAW

These Terms are governed by the laws of Ontario, Canada. Any disputes shall be resolved in the courts of Ontario.

14. CONTACT US

For questions about these Terms, please contact us at:
Email: support@orignaventures.ca

By using OrignaGTA, you acknowledge that you have read and understood these Terms and Conditions and agree to be bound by them.
''';

final termsProvider = FutureProvider<String>((ref) async {
  try {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.fetchAndActivate();
    final content = remoteConfig.getString('terms_and_conditions');
    if (content.isNotEmpty) {
      return content;
    }
  } catch (e) {
    // Remote config unavailable — use default terms content
    // This is expected on first launch or when offline
  }
  return _defaultTermsContent;
});
