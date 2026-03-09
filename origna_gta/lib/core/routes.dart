/// Named route constants and typed argument classes for the app.
/// Used with Navigator.pushNamed() and onGenerateRoute.
///
/// NEVER pass raw `Map<String, dynamic>` as route arguments.
/// Use the typed classes below — they are compile-time safe.
library;

import 'package:origna_gta/models/generated/models.dart' show Product;
import 'package:origna_gta/models/models.dart' show CartItemDetailModel;

/// Documentation for AppRoutes
class AppRoutes {
  static const String home = '/';

  static const String login = '/login';
  static const String cart = '/cart';
  static const String profile = '/profile';
  static const String orders = '/orders';
  static const String orderDetail = '/orders/detail';
  static const String addProduct = '/add-product';
  static const String editProduct = '/edit-product';
  static const String productDetails = '/product-details';
  static const String addressManagement = '/addresses';
  static const String addEditAddress = '/address/edit';
  static const String checkout = '/checkout';
  static const String orderSuccess = '/order-success';
  static const String shippingApproval = '/shipping-approval';
  static const String sellerRegistration = '/seller/register';
  // BOOT-L2: sellerSetup route removed — screen not implemented
  static const String sellerOrders = '/seller/orders';
  static const String sellerProducts = '/seller/products';
  static const String sellerWarehouses = '/seller/warehouses';
  static const String sellerIntegration = '/seller/integration';
  static const String favorites = '/favorites';
  static const String adminPanel = '/admin';
  static const String privacyPolicy = '/privacy-policy';
  static const String termsOfService = '/terms-of-service';
  static const String paymentSuccess = '/payment-success';
  static const String paymentCancel = '/payment-cancel';
  static const String sellerReturn = '/seller/return';
  static const String sellerRefresh = '/seller/refresh';
  static const String productBySlug = '/p';
  static const String productById = '/product';
  static const String subscription = '/subscription';
  static const String subscriptionSuccess = '/subscription/success';
  static const String subscriptionCancel = '/subscription/cancel';
  static const String chat = '/chat';
  static const String chatInbox = '/chat/inbox';
  static const String notifications = '/notifications';
  AppRoutes._(); // Prevent instantiation
}

// ─── Typed route arguments ─────────────────────────────────────────

/// Arguments for [AppRoutes.chat].
class ChatArgs {
  final String productId;
  final String productTitle;
  const ChatArgs({required this.productId, required this.productTitle});
}

/// Arguments for [AppRoutes.checkout].
class CheckoutArgs {
  final List<CartItemDetailModel> items;
  final double total;

  const CheckoutArgs({required this.items, required this.total});
}

/// Arguments for [AppRoutes.editProduct].
/// Wraps [Product] for consistency and future extensibility.
class EditProductArgs {
  final Product product;

  const EditProductArgs({required this.product});
}

/// Arguments for [AppRoutes.orderDetail].
class OrderDetailArgs {
  final String orderId;
  const OrderDetailArgs({required this.orderId});
}

/// Arguments for [AppRoutes.productDetails].
class ProductDetailsArgs {
  final String productId;
  final Map<String, dynamic>? product;

  const ProductDetailsArgs({required this.productId, this.product});
}

/// Arguments for [AppRoutes.productBySlug].
class ProductSlugArgs {
  final String slug;
  const ProductSlugArgs({required this.slug});
}
