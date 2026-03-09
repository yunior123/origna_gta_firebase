// coverage:ignore-file
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:origna_gta/core/schema/schema_constants.dart' show CloudFunctionEndpoints, Fields, PolicyVersionValues;
import 'package:origna_gta/utils/constants.dart';
import 'package:origna_gta/utils/utils.dart';
import 'package:rxdart/rxdart.dart';

/// Documentation for FirebaseUserRepository
class FirebaseUserRepository implements UserRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  FirebaseUserRepository(this._firestore, this._functions);

  @override
  Future<String> addBuyerAddress(Address address) async {
    final callable = _functions.httpsCallable(CloudFunctionEndpoints.addBuyerAddress);
    final response = await callable.call(address.toMap());
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Failed to add address');
    }
    return data[Fields.addressId] as String;
  }

  @override
  Future<void> deleteBuyerAddress(String addressId) async {
    final callable = _functions.httpsCallable(CloudFunctionEndpoints.deleteBuyerAddress);
    final response = await callable.call({'addressId': addressId});
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Failed to delete address');
    }
  }

  @override
  Future<SellerAccountStatus> getSellerAccountStatus(String userId) async {
    final doc = await _firestore.collection(Collections.users).doc(userId).get();
    final spDoc = await _firestore.collection(Collections.sellerProfiles).doc(userId).get();
    return _parseSellerStatus(doc.data(), spDoc.data());
  }

  @override
  Future<UserModel?> getUserProfile(String userId) async {
    final doc = await _firestore.collection(Collections.users).doc(userId).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  /// Records that the user accepted the terms of service.
  /// Backend sets the server-side timestamp — client only sends a flag.
  /// Fire-and-forget: do not await unless you need confirmation.
  @override
  Future<void> recordTermsAcceptance() async {
    final callable = _functions.httpsCallable(CloudFunctionEndpoints.updateUserProfile);
    final response = await callable.call({Fields.termsAcceptedAt: true, Fields.termsVersion: PolicyVersionValues.defaultVersion});
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Failed to record terms acceptance');
    }
  }

  @override
  Future<void> setDefaultBuyerAddress(String addressId) async {
    final callable = _functions.httpsCallable(CloudFunctionEndpoints.setDefaultBuyerAddress);
    final response = await callable.call({'addressId': addressId});
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Failed to set default address');
    }
  }

  @override
  Future<void> updateBuyerAddress(String addressId, Address address) async {
    final callable = _functions.httpsCallable(CloudFunctionEndpoints.updateBuyerAddress);
    final Map<String, dynamic> payload = address.toMap();
    payload['addressId'] = addressId;
    final response = await callable.call(payload);
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Failed to update address');
    }
  }

  @override
  Future<void> updateNotificationPreferences(String userId, {bool? notifyNewProducts, bool? notifyTrending}) async {
    final updates = <String, dynamic>{};
    if (notifyNewProducts != null) updates[Fields.notifyNewProducts] = notifyNewProducts;
    if (notifyTrending != null) updates[Fields.notifyTrending] = notifyTrending;
    if (updates.isEmpty) return;
    // Use CF to prevent field injection and validate isPremium server-side
    final callable = _functions.httpsCallable(CloudFunctionEndpoints.updateNotificationPreferences);
    final response = await callable.call(updates);
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Failed to update notification preferences');
    }
  }

  @override
  Future<void> updatePreferredLanguage(String userId, String lang) async {
    final callable = _functions.httpsCallable(CloudFunctionEndpoints.updateUserProfile);
    final response = await callable.call({Fields.preferredLanguage: lang});
    final data = response.data as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Failed to update language preference');
    }
  }

  // --- Address Book Methods ---

  @override
  Stream<List<Address>> watchAddresses(String userId) {
    return _firestore.collection(Collections.users).doc(userId).collection(Collections.addresses).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Address.fromMap(data, docId: doc.id);
      }).toList();
    });
  }

  @override
  Stream<SellerAccountStatus> watchSellerAccountStatus(String userId) {
    // Combine users doc (for roles) and seller_profiles doc (for Stripe status) in parallel.
    // Using combineLatest2 avoids N+1: both streams fire independently on their own writes.
    return Rx.combineLatest2(
      _firestore.collection(Collections.users).doc(userId).snapshots(),
      _firestore.collection(Collections.sellerProfiles).doc(userId).snapshots(),
      (DocumentSnapshot userDoc, DocumentSnapshot spDoc) => _parseSellerStatus(userDoc.data() as Map<String, dynamic>?, spDoc.data() as Map<String, dynamic>?),
    );
  }

  // userData: from users/{uid} (roles). spData: from seller_profiles/{uid} (Stripe status fields).
  SellerAccountStatus _parseSellerStatus(Map<String, dynamic>? userData, Map<String, dynamic>? spData) {
    final roles = List<String>.from(userData?[Fields.roles] ?? const []);
    final isSeller = roles.contains(UserRoles.seller) || roles.contains(UserRoles.admin);
    final chargesEnabled = spData?[Fields.chargesEnabled] == true;
    final payoutsEnabled = spData?[Fields.payoutsEnabled] == true;
    final onboardingCompleted = spData?[Fields.onboardingCompleted] == true;
    final pendingRequirements = List<String>.from(spData?[Fields.pendingRequirements] ?? const []);
    return SellerAccountStatus(
      isSeller: isSeller,
      chargesEnabled: chargesEnabled && payoutsEnabled,
      detailsSubmitted: onboardingCompleted,
      hasPendingRequirements: pendingRequirements.isNotEmpty,
      pendingRequirements: pendingRequirements,
    );
  }
}

/// Documentation for SellerAccountStatus
class SellerAccountStatus {
  final bool isSeller;
  final bool chargesEnabled;
  final bool detailsSubmitted;
  final bool hasPendingRequirements;
  final List<String> pendingRequirements;

  const SellerAccountStatus({
    required this.isSeller,
    required this.chargesEnabled,
    this.detailsSubmitted = false,
    this.hasPendingRequirements = false,
    this.pendingRequirements = const [],
  });

  /// Account is fully verified and can sell products
  bool get isComplete => isSeller && chargesEnabled;

  /// User has started but there are still requirements to complete
  bool get isIncomplete => isSeller && (!detailsSubmitted || hasPendingRequirements);

  /// User has submitted all info and documents, waiting for Stripe review
  bool get isPendingVerification => isSeller && detailsSubmitted && !chargesEnabled && !hasPendingRequirements;

  /// Check if identity documents are required
  bool get needsIdentityDocuments => pendingRequirements.any(
    (r) => r.contains('verification') || r.contains('document') || r.contains('individual.id_number') || r.contains('individual.verification'),
  );

  /// Get a human-readable description of what's missing
  String get pendingRequirementsDescription {
    if (pendingRequirements.isEmpty) return '';

    final descriptions = <String>[];
    for (final req in pendingRequirements) {
      if (req.contains('verification.document')) {
        descriptions.add('Identity document (ID, passport, or driver\'s license)');
      } else if (req.contains('individual.id_number')) {
        descriptions.add('Social Insurance Number (SIN)');
      } else if (req.contains('external_account')) {
        descriptions.add('Bank account for payouts');
      } else if (req.contains('business_profile')) {
        descriptions.add('Business information');
      } else if (req.contains('tos_acceptance')) {
        descriptions.add('Terms of Service acceptance');
      } else if (!descriptions.contains(req)) {
        // Add other requirements as-is but formatted
        descriptions.add(req.replaceAll('.', ' ').replaceAll('_', ' '));
      }
    }
    return descriptions.toSet().join('\n• ');
  }
}

abstract class UserRepository {
  Future<String> addBuyerAddress(Address address);
  Future<void> deleteBuyerAddress(String addressId);
  Future<SellerAccountStatus> getSellerAccountStatus(String userId);
  Future<UserModel?> getUserProfile(String userId);
  Future<void> recordTermsAcceptance();
  Future<void> setDefaultBuyerAddress(String addressId);
  Future<void> updateBuyerAddress(String addressId, Address address);
  Future<void> updateNotificationPreferences(String userId, {bool? notifyNewProducts, bool? notifyTrending});
  Future<void> updatePreferredLanguage(String userId, String lang);
  // Address Book
  Stream<List<Address>> watchAddresses(String userId);
  Stream<SellerAccountStatus> watchSellerAccountStatus(String userId);
}
