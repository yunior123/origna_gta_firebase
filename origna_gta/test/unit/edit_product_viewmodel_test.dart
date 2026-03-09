import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/product_repository.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/features/products/edit_product_viewmodel.dart';
import 'package:origna_gta/models/generated/models.dart' as models;
import 'package:origna_gta/utils/utils.dart';

@GenerateNiceMocks([MockSpec<ProductRepository>()])
import 'edit_product_viewmodel_test.mocks.dart';

void main() {
  late MockProductRepository mockRepo;
  late ProviderContainer container;

  final initialProduct = models.Product(
    productId: 'prod_123',
    name: 'Initial Name',
    description: 'Initial long enough description for validation purposes',
    price: 50.0,
    stockQuantity: 10,
    categoryId: 1,
    sellerId: 'user_123',
    imageUrls: ['image1.jpg'],
    createdAt: DateTime.now(),
    sellerAddress: models.Address(
      street: '123 Initial St',
      city: 'Toronto',
      state: 'ON',
      postalCode: 'M1M 1M1',
      latitude: 43.0,
      longitude: -79.0,
      country: 'Canada',
    ),
    deliveryOptions: [models.SellerDeliveryOption(type: DeliveryTypeValues.standard, costCents: 1000, estimatedDays: 3)],
  );

  setUp(() {
    mockRepo = MockProductRepository();
    container = ProviderContainer(overrides: [productRepositoryProvider.overrideWithValue(mockRepo), userIdProvider.overrideWith((ref) => 'user_123')]);
  });

  group('EditProductViewModel', () {
    test('initializes state correctly from product', () {
      final state = container.read(editProductViewModelProvider(initialProduct));
      expect(state.isSoldOut, isFalse);
      expect(state.existingImageUrls, contains('image1.jpg'));
      expect(state.selectedProvince, 'ON');
      expect(state.latitude, 43.0);
      expect(state.standardEnabled, isTrue);
    });

    test('onStreetChanged fetches suggestions', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      final suggestions = [
        {'label': '123 New St'},
      ];
      when(mockRepo.getAutocompleteSuggestions(any)).thenAnswer((_) async => suggestions);

      await viewModel.onStreetChanged('123 New');
      final state = container.read(editProductViewModelProvider(initialProduct));

      expect(state.addressSuggestions, suggestions);
      expect(state.showSuggestions, isTrue);
      verify(mockRepo.getAutocompleteSuggestions('123 New')).called(1);
    });

    test('selectAddress updates coordinates', () {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      viewModel.selectAddress({
        'geometry': {
          'coordinates': [-80.0, 44.0],
        },
        'properties': {'state_code': 'QC'},
      });

      final state = container.read(editProductViewModelProvider(initialProduct));
      expect(state.latitude, 44.0);
      expect(state.longitude, -80.0);
      expect(state.selectedProvince, 'QC');
    });

    test('removeExistingImage updates list', () {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      viewModel.removeExistingImage(0);
      final state = container.read(editProductViewModelProvider(initialProduct));
      expect(state.existingImageUrls, isEmpty);
    });

    test('setExistingImageAsCover moves image to front', () {
      final product = initialProduct.copyWith(imageUrls: ['img1', 'img2', 'img3']);
      final viewModel = container.read(editProductViewModelProvider(product).notifier);

      viewModel.setExistingImageAsCover(2); // Move 'img3' to front
      final state = container.read(editProductViewModelProvider(product));
      expect(state.existingImageUrls.first, 'img3');
      expect(state.existingImageUrls[1], 'img1');
    });

    test('toggleDigital updates shipping options', () {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      viewModel.toggleDigital(true);

      final state = container.read(editProductViewModelProvider(initialProduct));
      expect(state.isDigital, isTrue);
      expect(state.freeShipping, isTrue);
      expect(state.standardEnabled, isFalse);
    });

    test('unauthorized user cannot update product', () async {
      // Override userId to different user
      container = ProviderContainer(overrides: [productRepositoryProvider.overrideWithValue(mockRepo), userIdProvider.overrideWith((ref) => 'user_999')]);

      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      await viewModel.updateProduct(
        name: 'New Name',
        description: 'New Description',
        price: 20.0,
        stock: 5,
        categoryId: 1,
        street: 'Street',
        apartment: '',
        city: 'City',
        postalCode: 'M1M 1M1',
        shipDays: 3,
        deliveryOptions: [],
      );

      final state = container.read(editProductViewModelProvider(initialProduct));
      expect(state.errorMessage, contains('Unauthorized'));
    });

    test('validation fails on empty name', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      await viewModel.updateProduct(
        name: '',
        description: 'Valid Description',
        price: 20.0,
        stock: 5,
        categoryId: 1,
        street: 'Street',
        apartment: '',
        city: 'City',
        postalCode: 'M1M 1M1',
        shipDays: 3,
        deliveryOptions: [],
      );

      final state = container.read(editProductViewModelProvider(initialProduct));
      expect(state.errorMessage, contains('name is required'));
    });

    test('successful update calls repository with custom delivery options', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);

      when(mockRepo.updateProduct(any, any)).thenAnswer((_) async {});

      final deliveryOptions = [models.SellerDeliveryOption(type: DeliveryTypeValues.express, costCents: 2000, estimatedDays: 1)];

      await viewModel.updateProduct(
        name: 'Updated Name',
        description: 'Updated Description',
        price: 45.0,
        stock: 8,
        categoryId: 2,
        street: '123 Initial St',
        apartment: '',
        city: 'Toronto',
        postalCode: 'M1M 1M1',
        shipDays: 5,
        deliveryOptions: deliveryOptions,
      );

      final state = container.read(editProductViewModelProvider(initialProduct));
      expect(state.isSuccess, isTrue);

      final verification = verify(mockRepo.updateProduct(initialProduct.productId, captureAny));
      verification.called(1);
      final updateMap = verification.captured.first as Map<String, dynamic>;
      expect(updateMap['name'], 'Updated Name');
      expect(updateMap['deliveryOptions'], isNotEmpty);
    });

    test('validation: name empty', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      await viewModel.updateProduct(
        name: '  ',
        description: 'Valid desc',
        price: 10,
        stock: 5,
        categoryId: 1,
        street: 'Valid St',
        apartment: '',
        city: 'City',
        postalCode: 'M1M 1M1',
        shipDays: 3,
        deliveryOptions: [],
      );
      expect(container.read(editProductViewModelProvider(initialProduct)).errorMessage, contains('name'));
    });

    test('validation: description empty', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      await viewModel.updateProduct(
        name: 'Valid Name',
        description: ' ',
        price: 10,
        stock: 5,
        categoryId: 1,
        street: 'Valid St',
        apartment: '',
        city: 'City',
        postalCode: 'M1M 1M1',
        shipDays: 3,
        deliveryOptions: [],
      );
      expect(container.read(editProductViewModelProvider(initialProduct)).errorMessage, contains('Description'));
    });

    test('validation: price limits', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);

      await viewModel.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 100001,
        stock: 5,
        categoryId: 1,
        street: 'St',
        apartment: '',
        city: 'City',
        postalCode: 'M1M 1M1',
        shipDays: 3,
        deliveryOptions: [],
      );
      expect(container.read(editProductViewModelProvider(initialProduct)).errorMessage, contains('100,000'));

      await viewModel.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 0,
        stock: 5,
        categoryId: 1,
        street: 'St',
        apartment: '',
        city: 'City',
        postalCode: 'M1M 1M1',
        shipDays: 3,
        deliveryOptions: [],
      );
      expect(container.read(editProductViewModelProvider(initialProduct)).errorMessage, contains('product.please_enter_price'));
    });

    test('validation: compareAtPrice logic', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      await viewModel.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 10,
        compareAtPrice: 10.4,
        stock: 5,
        categoryId: 1,
        street: 'St',
        apartment: '',
        city: 'City',
        postalCode: 'M1M 1M1',
        shipDays: 3,
        deliveryOptions: [],
      );
      expect(container.read(editProductViewModelProvider(initialProduct)).errorMessage, contains('product.compare_at_price_must_be_higher'));
    });

    test('validation: negative stock', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      await viewModel.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 10,
        stock: -1,
        categoryId: 1,
        street: 'St',
        apartment: '',
        city: 'City',
        postalCode: 'M1M 1M1',
        shipDays: 3,
        deliveryOptions: [],
      );
      expect(container.read(editProductViewModelProvider(initialProduct)).errorMessage, contains('Stock'));
    });

    test('validation: physical address missing', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      await viewModel.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 10,
        stock: 5,
        categoryId: 1,
        street: '',
        apartment: '',
        city: '',
        postalCode: '',
        shipDays: 3,
        deliveryOptions: [],
      );
      expect(container.read(editProductViewModelProvider(initialProduct)).errorMessage, contains('address'));
    });

    test('validation: unverified address (null coords)', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      // Street is not empty, but state has no coords
      viewModel.onStreetChanged('Something');
      await viewModel.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 10,
        stock: 5,
        categoryId: 1,
        street: '123 St',
        apartment: '',
        city: 'City',
        postalCode: 'M1M 1M1',
        shipDays: 3,
        deliveryOptions: [],
      );
      // Note: initialProduct has coords, so we need to clear them if possible or use a product without them
      final productNoCoords = initialProduct.copyWith(sellerAddress: initialProduct.sellerAddress?.copyWith(latitude: null, longitude: null));
      final vmNoCoords = container.read(editProductViewModelProvider(productNoCoords).notifier);
      await vmNoCoords.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 10,
        stock: 5,
        categoryId: 1,
        street: '123 St',
        apartment: '',
        city: 'City',
        postalCode: 'M1M 1M1',
        shipDays: 3,
        deliveryOptions: [],
      );
      expect(container.read(editProductViewModelProvider(productNoCoords)).errorMessage, contains('suggestions'));
    });

    test('validation: negative dimensions', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      await viewModel.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 10,
        stock: 5,
        categoryId: 1,
        street: 'St',
        apartment: '',
        city: 'City',
        postalCode: 'M1M 1M1',
        shipDays: 3,
        deliveryOptions: [],
        weight: -1,
      );
      expect(container.read(editProductViewModelProvider(initialProduct)).errorMessage, contains('positive'));
    });

    test('validation: delivery options required for physical', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      // Disable all options
      viewModel.setStandardEnabled(false);
      viewModel.setExpressEnabled(false);
      viewModel.setSameDayEnabled(false);

      await viewModel.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 10,
        stock: 5,
        categoryId: 1,
        street: 'St',
        apartment: '',
        city: 'City',
        postalCode: 'M1M 1M1',
        shipDays: 3,
        deliveryOptions: [],
      );
      expect(container.read(editProductViewModelProvider(initialProduct)).errorMessage, contains('one delivery option'));
    });

    test('validation: digital type required', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      viewModel.toggleDigital(true);
      viewModel.setDigitalType(null);

      await viewModel.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 10,
        stock: 5,
        categoryId: 1,
        street: '',
        apartment: '',
        city: '',
        postalCode: '',
        shipDays: 0,
        deliveryOptions: [],
      );
      expect(container.read(editProductViewModelProvider(initialProduct)).errorMessage, contains('digital product type'));
    });

    test('validation: software URLs missing', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      viewModel.toggleDigital(true);
      viewModel.setDigitalType(DigitalTypeValues.software);

      await viewModel.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 10,
        stock: 5,
        categoryId: 1,
        street: '',
        apartment: '',
        city: '',
        postalCode: '',
        shipDays: 0,
        deliveryOptions: [],
      );
      expect(container.read(editProductViewModelProvider(initialProduct)).errorMessage, contains('download URL'));
    });

    test('validation: software URLs invalid protocol', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      viewModel.toggleDigital(true);
      viewModel.setDigitalType(DigitalTypeValues.software);
      viewModel.setWindowsDownloadUrl('http://insecure.com');

      await viewModel.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 10,
        stock: 5,
        categoryId: 1,
        street: '',
        apartment: '',
        city: '',
        postalCode: '',
        shipDays: 0,
        deliveryOptions: [],
      );
      expect(container.read(editProductViewModelProvider(initialProduct)).errorMessage, contains('https://'));
    });

    test('validation: book URL invalid', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      viewModel.toggleDigital(true);
      viewModel.setDigitalType(DigitalTypeValues.book);

      viewModel.setBookSourceUrl('http://insecure.com');
      await viewModel.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 10,
        stock: 5,
        categoryId: 1,
        street: '',
        apartment: '',
        city: '',
        postalCode: '',
        shipDays: 0,
        deliveryOptions: [],
      );
      expect(container.read(editProductViewModelProvider(initialProduct)).errorMessage, contains('product.book_url_https_required'));

      viewModel.setBookSourceUrl('https://${'a' * 501}');
      await viewModel.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 10,
        stock: 5,
        categoryId: 1,
        street: '',
        apartment: '',
        city: 'City',
        postalCode: 'M1M 1M1',
        shipDays: 0,
        deliveryOptions: [],
      );
      expect(container.read(editProductViewModelProvider(initialProduct)).errorMessage, contains('product.url_too_long'));
    });

    test('validation: no images left', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      viewModel.removeExistingImage(0);

      await viewModel.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 10,
        stock: 5,
        categoryId: 1,
        street: 'St',
        apartment: '',
        city: 'City',
        postalCode: 'M1M 1M1',
        shipDays: 3,
        deliveryOptions: [],
      );
      expect(container.read(editProductViewModelProvider(initialProduct)).errorMessage, contains('least one product image'));
    });

    test('onStreetChanged logs error on failure', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      when(mockRepo.getAutocompleteSuggestions(any)).thenThrow(Exception('Network error'));

      await viewModel.onStreetChanged('123 Test');
      // Should not crash, and state should remain same or show no suggestions
      expect(container.read(editProductViewModelProvider(initialProduct)).addressSuggestions, isEmpty);
    });

    test('removeVideo clears video state', () {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      viewModel.removeVideo();
      final state = container.read(editProductViewModelProvider(initialProduct));
      expect(state.existingVideoUrl, isNull);
      expect(state.videoFile, isNull);
    });

    test('setExistingImageAsCover handles invalid index', () {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      final originalList = List.from(container.read(editProductViewModelProvider(initialProduct)).existingImageUrls);

      viewModel.setExistingImageAsCover(-1);
      expect(container.read(editProductViewModelProvider(initialProduct)).existingImageUrls, originalList);

      viewModel.setExistingImageAsCover(10);
      expect(container.read(editProductViewModelProvider(initialProduct)).existingImageUrls, originalList);

      viewModel.setExistingImageAsCover(0); // already cover
      expect(container.read(editProductViewModelProvider(initialProduct)).existingImageUrls, originalList);
    });

    test('successful update calls repository', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);

      when(mockRepo.updateProduct(any, any)).thenAnswer((_) async {});

      await viewModel.updateProduct(
        name: 'Updated Name',
        description: 'Updated Description',
        price: 45.0,
        stock: 8,
        categoryId: 2,
        street: '123 Initial St',
        apartment: '',
        city: 'Toronto',
        postalCode: 'M1M 1M1',
        shipDays: 5,
        deliveryOptions: [],
      );

      final state = container.read(editProductViewModelProvider(initialProduct));
      expect(state.isSuccess, isTrue);
      expect(state.errorMessage, isNull);
      verify(mockRepo.updateProduct(initialProduct.productId, any)).called(1);
    });

    test('successful update with new images and video', () async {
      final sub = container.listen(editProductViewModelProvider(initialProduct), (_, _) {});
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);

      when(mockRepo.uploadImages(any, any)).thenAnswer((_) async => ['new_image_url.jpg']);
      when(mockRepo.uploadProductVideo(any, any)).thenAnswer((_) async => 'new_video_url.mp4');
      when(mockRepo.updateProduct(any, any)).thenAnswer((_) async {});

      // Add a new image
      final newImage = ImageModel(url: 'local_path', bytes: Uint8List(100));
      viewModel.state = viewModel.state.copyWith(newImages: [newImage]);

      // Set a video
      final videoFile = XFile.fromData(Uint8List(100), name: 'test.mp4');
      viewModel.setVideo(videoFile, 30);

      await viewModel.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 10,
        stock: 5,
        categoryId: 1,
        street: '123 Initial St',
        apartment: '',
        city: 'Toronto',
        postalCode: 'M1M 1M1',
        shipDays: 3,
        deliveryOptions: [],
      );

      final state = container.read(editProductViewModelProvider(initialProduct));
      expect(state.isSuccess, isTrue);
      verify(mockRepo.uploadImages(any, any)).called(1);
      verify(mockRepo.uploadProductVideo(any, any)).called(1);
      sub.close();
    });

    test('updateProduct failure on video too long', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      final videoFile = XFile.fromData(Uint8List(100), name: 'test.mp4');
      viewModel.setVideo(videoFile, 301); // Too long (max 300)

      await viewModel.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 10,
        stock: 5,
        categoryId: 1,
        street: '123 Initial St',
        apartment: '',
        city: 'Toronto',
        postalCode: 'M1M 1M1',
        shipDays: 3,
        deliveryOptions: [],
      );

      expect(container.read(editProductViewModelProvider(initialProduct)).errorMessage, contains('product.video_too_long'));
    });

    test('updateProduct failure on delivery option missing when required', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      viewModel.toggleLocalDelivery(false);
      viewModel.toggleDigital(false);
      viewModel.setStandardEnabled(false);
      viewModel.setExpressEnabled(false);
      viewModel.setSameDayEnabled(false);

      await viewModel.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 10,
        stock: 5,
        categoryId: 1,
        street: 'St',
        apartment: '',
        city: 'City',
        postalCode: 'M1M 1M1',
        shipDays: 3,
        deliveryOptions: [],
      );

      expect(container.read(editProductViewModelProvider(initialProduct)).errorMessage, contains('at least one delivery option'));
    });

    test('toggleDigital logic updates state properties', () {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);

      viewModel.toggleDigital(true);
      var state = container.read(editProductViewModelProvider(initialProduct));
      expect(state.isDigital, isTrue);
      expect(state.freeShipping, isTrue);
      expect(state.isPerishable, isFalse);
      expect(state.isLocalDeliveryOnly, isFalse);
      expect(state.standardEnabled, isFalse);
      expect(state.expressEnabled, isFalse);
      expect(state.sameDayEnabled, isFalse);

      viewModel.toggleDigital(false);
      state = container.read(editProductViewModelProvider(initialProduct));
      expect(state.isDigital, isFalse);
      // Implementation preserves freeShipping when toggling OFF
      expect(state.freeShipping, isTrue);
    });

    test('toggleAgeRestricted', () {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      viewModel.toggleAgeRestricted(true);
      expect(container.read(editProductViewModelProvider(initialProduct)).isAgeRestricted, isTrue);
    });

    test('updateProduct failure on compareAtPrice < price', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      await viewModel.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 100,
        stock: 5,
        categoryId: 1,
        street: '123 Initial St',
        apartment: '',
        city: 'Toronto',
        postalCode: 'M1M 1M1',
        shipDays: 3,
        deliveryOptions: [],
        compareAtPrice: 50, // Must be higher
      );
      expect(container.read(editProductViewModelProvider(initialProduct)).errorMessage, contains('higher'));
    });
    test('onStreetChanged success', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      when(mockRepo.getAutocompleteSuggestions('New St')).thenAnswer(
        (_) async => [
          {'description': 'New St, Result'},
        ],
      );

      await viewModel.onStreetChanged('New St');

      expect(container.read(editProductViewModelProvider(initialProduct)).addressSuggestions.isNotEmpty, isTrue);
    });

    test('updateProduct handles image compression failure (skips image)', () async {
      final sub = container.listen(editProductViewModelProvider(initialProduct), (_, _) {});
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);

      when(mockRepo.updateProduct(any, any)).thenAnswer((_) async {});
      when(mockRepo.uploadImages(any, any)).thenAnswer((_) async => []);

      // Providing bytes that result in a null compression (simulated)
      final invalidFile = XFile.fromData(Uint8List(100), name: 'fail.jpg');
      // Since it's a StateNotifier and we want to wait for the bytes to be read:
      await viewModel.addImage(invalidFile);

      await viewModel.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 10,
        stock: 5,
        categoryId: 1,
        street: 'St',
        apartment: '',
        city: 'City',
        postalCode: 'M1M 1M1',
        shipDays: 3,
        deliveryOptions: [models.SellerDeliveryOption(type: DeliveryTypeValues.standard, costCents: 1000, estimatedDays: 3)],
      );

      final state = container.read(editProductViewModelProvider(initialProduct));
      expect(state.isSuccess, isTrue);
      // uploadImages IS called with an empty list because processedImages is empty due to compression failure
      verify(mockRepo.uploadImages(argThat(isEmpty), any)).called(1);
      sub.close();
    });

    test('toggleDigital for different digital types', () {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);

      viewModel.toggleDigital(true);
      viewModel.setDigitalType(DigitalTypeValues.book);
      expect(container.read(editProductViewModelProvider(initialProduct)).digitalType, DigitalTypeValues.book);

      viewModel.setDigitalType(DigitalTypeValues.software);
      expect(container.read(editProductViewModelProvider(initialProduct)).digitalType, DigitalTypeValues.software);
    });

    test('setProvince updates state', () {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      viewModel.setProvince(ProvinceCodeValues.quebec);
      expect(container.read(editProductViewModelProvider(initialProduct)).selectedProvince, ProvinceCodeValues.quebec);
    });

    test('digital software validation failure cases', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      viewModel.toggleDigital(true);
      viewModel.setDigitalType(DigitalTypeValues.software);

      // Missing URLs
      await viewModel.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 10,
        stock: 5,
        categoryId: 1,
        street: 'St',
        apartment: '',
        city: 'City',
        postalCode: 'M1M 1M1',
        shipDays: 1,
        deliveryOptions: [],
      );
      expect(container.read(editProductViewModelProvider(initialProduct)).errorMessage, contains('Add at least one platform download URL'));

      // Non-https URL
      viewModel.setMacosDownloadUrl('http://insecure.com');
      await viewModel.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 10,
        stock: 5,
        categoryId: 1,
        street: 'St',
        apartment: '',
        city: 'City',
        postalCode: 'M1M 1M1',
        shipDays: 1,
        deliveryOptions: [],
      );
      expect(container.read(editProductViewModelProvider(initialProduct)).errorMessage, contains('must start with https://'));
    });

    test('digital book validation failure cases', () async {
      final viewModel = container.read(editProductViewModelProvider(initialProduct).notifier);
      viewModel.toggleDigital(true);
      viewModel.setDigitalType(DigitalTypeValues.book);

      // Non-https URL
      viewModel.setBookSourceUrl('http://insecure.com');
      await viewModel.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 10,
        stock: 5,
        categoryId: 1,
        street: 'St',
        apartment: '',
        city: 'City',
        postalCode: 'M1M 1M1',
        shipDays: 1,
        deliveryOptions: [],
      );
      expect(container.read(editProductViewModelProvider(initialProduct)).errorMessage, contains('product.book_url_https_required'));

      // URL too long
      viewModel.setBookSourceUrl('https://${'a' * 501}');
      await viewModel.updateProduct(
        name: 'Name',
        description: 'Desc',
        price: 10,
        stock: 5,
        categoryId: 1,
        street: 'St',
        apartment: '',
        city: 'City',
        postalCode: 'M1M 1M1',
        shipDays: 1,
        deliveryOptions: [],
      );
      expect(container.read(editProductViewModelProvider(initialProduct)).errorMessage, contains('product.url_too_long'));
    });
  });
}
