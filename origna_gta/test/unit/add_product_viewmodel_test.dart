import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/location_repository.dart';
import 'package:origna_gta/core/repositories/product_repository.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/features/products/add_product_state.dart';
import 'package:origna_gta/features/products/add_product_viewmodel.dart';
import 'package:origna_gta/utils/env_config.dart';
import 'package:origna_gta/utils/utils.dart';

@GenerateNiceMocks([MockSpec<ProductRepository>(), MockSpec<LocationRepository>(), MockSpec<XFile>(), MockSpec<EnvConfig>()])
import 'add_product_viewmodel_test.mocks.dart';

void main() {
  late MockProductRepository mockRepo;
  late MockLocationRepository mockLocationRepo;
  late MockEnvConfig mockConfig;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockProductRepository();
    mockLocationRepo = MockLocationRepository();
    mockConfig = MockEnvConfig();

    when(mockConfig.isDev).thenReturn(true);
    when(mockConfig.isEmulator).thenReturn(false);

    container = ProviderContainer(
      overrides: [
        productRepositoryProvider.overrideWithValue(mockRepo),
        locationRepositoryProvider.overrideWithValue(mockLocationRepo),
        envConfigProvider.overrideWithValue(mockConfig),
        userIdProvider.overrideWithValue('test_seller'),
      ],
    );
    container.listen(addProductViewModelProvider, (prev, next) {});
  });

  AddProductViewModel getViewModel() => container.read(addProductViewModelProvider.notifier);
  AddProductState getState() => container.read(addProductViewModelProvider);

  void setupBasicValidState(AddProductViewModel vm) {
    vm.addImage(ImageModel(url: 'test', bytes: transparentPng));
    vm.setCategoryId('1');
    vm.selectAddress({
      'geometry': {
        'coordinates': [0, 0],
      },
      'properties': {'state_code': 'ON'},
    });
    vm.setStandardEnabled(true);
  }

  group('AddProductViewModel Final Combined Tests', () {
    test('Exhaustive Validation Errors', () async {
      final vm = getViewModel();

      // Basic fields
      await vm.addProduct(
        name: '',
        description: '',
        price: 0,
        stock: 0,
        categoryId: 0,
        street: '',
        apartment: '',
        city: '',
        postalCode: '',
        deliveryOptions: [],
      );
      expect(getState().errorMessage, isNotNull);

      // Address (Production Mode)
      setupBasicValidState(vm);
      vm.clearCoordinates();
      when(mockConfig.isDev).thenReturn(false);
      when(mockConfig.isEmulator).thenReturn(false);
      await vm.addProduct(
        name: 'P',
        description: 'Desc long enough',
        price: 10,
        stock: 1,
        categoryId: 1,
        street: 'Valid St',
        apartment: '',
        city: 'Toronto',
        postalCode: 'M5V 2L7',
        deliveryOptions: [],
      );
      expect(getState().errorMessage, contains('verified'));

      // Image Required
      setupBasicValidState(vm);
      vm.updateImages([]);
      await vm.addProduct(
        name: 'P',
        description: 'Desc long enough',
        price: 10,
        stock: 1,
        categoryId: 1,
        street: 'Valid St',
        apartment: '',
        city: 'Toronto',
        postalCode: 'M5V 2L7',
        deliveryOptions: [],
      );
      expect(getState().errorMessage, contains('image'));
      when(mockConfig.isDev).thenReturn(true);

      // Warehouse error
      setupBasicValidState(vm);
      await vm.addProduct(
        name: 'P',
        description: 'Desc long enough',
        price: 10,
        stock: 1,
        categoryId: 1,
        street: 'Valid St',
        apartment: '',
        city: 'Toronto',
        postalCode: 'M5V 2L7',
        deliveryOptions: [],
        sellerHasWarehouses: true,
      );
      expect(getState().errorMessage, contains('warehouse'));
    });

    test('Success Paths - Full coverage including video', () async {
      final vm = getViewModel();
      setupBasicValidState(vm);
      vm.updateImages([]);

      final mockVideo = MockXFile();
      when(mockVideo.length()).thenAnswer((_) async => 100);
      vm.setVideo(mockVideo, 5);

      when(mockRepo.uploadProductVideo(any, any)).thenAnswer((_) async => 'v_url');
      when(
        mockRepo.createProductAtomic(any, any, testImageUrls: anyNamed('testImageUrls'), bookSourceUrl: anyNamed('bookSourceUrl')),
      ).thenAnswer((_) async => 'p1');

      await vm.addProduct(
        name: 'Full',
        description: 'Description long enough',
        price: 10,
        stock: 5,
        categoryId: 1,
        street: 'Valid St',
        apartment: '1',
        city: 'Toronto',
        postalCode: 'M5V 2L7',
        deliveryOptions: [],
      );
      expect(getState().isSuccess, isTrue);
    });

    test('Success path with image compression', () async {
      final vm = getViewModel();
      setupBasicValidState(vm); // Adds image with bytes

      when(
        mockRepo.createProductAtomic(any, any, testImageUrls: anyNamed('testImageUrls'), bookSourceUrl: anyNamed('bookSourceUrl')),
      ).thenAnswer((_) async => 'p1');

      await vm.addProduct(
        name: 'P',
        description: 'Description long enough',
        price: 10,
        stock: 5,
        categoryId: 1,
        street: 'Valid St',
        apartment: '',
        city: 'Toronto',
        postalCode: 'M5V 2L7',
        deliveryOptions: [],
      );
      expect(getState().isSuccess, isTrue);
    });

    test('Validation: Image too large', () async {
      final vm = getViewModel();
      setupBasicValidState(vm);
      final largeBytes = Uint8List(11 * 1024 * 1024); // 11MB
      vm.updateImages([ImageModel(url: 'large', bytes: largeBytes)]);

      await vm.addProduct(
        name: 'P',
        description: 'Desc long enough',
        price: 10,
        stock: 1,
        categoryId: 1,
        street: 'Valid St',
        apartment: '',
        city: 'Toronto',
        postalCode: 'M5V 2L7',
        deliveryOptions: [],
      );
      expect(getState().errorMessage, isNotNull);
    });

    test('Success Paths - Digital and Variants', () async {
      final vm = getViewModel();
      when(
        mockRepo.createProductAtomic(any, any, testImageUrls: anyNamed('testImageUrls'), bookSourceUrl: anyNamed('bookSourceUrl')),
      ).thenAnswer((_) async => 'p1');

      // Digital software
      vm.resetIfSuccess();
      setupBasicValidState(vm);
      vm.updateImages([]);
      vm.toggleDigital(true);
      vm.setDigitalType(DigitalTypeValues.software);
      vm.setMacosDownloadUrl('https://mac.com');
      await vm.addProduct(
        name: 'Software',
        description: 'Description long enough',
        price: 10,
        stock: 1,
        categoryId: 1,
        street: '',
        apartment: '',
        city: '',
        postalCode: '',
        deliveryOptions: [],
      );
      expect(getState().isSuccess, isTrue);

      // Variants
      vm.resetIfSuccess();
      setupBasicValidState(vm);
      vm.updateImages([]);
      vm.toggleHasVariants(true);
      vm.addVariantOption('Size', ['S', 'M']);
      vm.updateVariantPrice(0, 10.0);
      vm.updateVariantStock(0, 5);
      vm.updateVariantPrice(1, 12.0);
      vm.updateVariantStock(1, 10);
      await vm.addProduct(
        name: 'Variant',
        description: 'Description long enough',
        price: 10,
        stock: 0,
        categoryId: 1,
        street: 'Valid St',
        apartment: '',
        city: 'Toronto',
        postalCode: 'M5V 2L7',
        deliveryOptions: [],
      );
      expect(getState().isSuccess, isTrue);
    });

    test('All Setters and Misc', () async {
      final vm = getViewModel();
      vm.setCategoryId('c');
      vm.setSubcategory('s');
      vm.setCondition('n');
      vm.setDigitalType('t');
      vm.setDeviceLimit(1);
      vm.setMacosDownloadUrl('u');
      vm.setWindowsDownloadUrl('u');
      vm.setLinuxDownloadUrl('u');
      vm.setBookSourceUrl('u');
      vm.setSellerSku('s');
      vm.setAllowBackorder(true);
      vm.setTrackQuantity(true);
      vm.setInventoryManaged(true);
      vm.setLowStockAlertEnabled(true);
      vm.setActiveStep(1);
      vm.setHasAttemptedSubmit(true);
      vm.setHasTracking(true);
      vm.setDiscountTierError(true);
      vm.setExpressEnabled(true);
      vm.setSameDayEnabled(true);
      vm.setStandardEnabled(true);
      vm.setLocalDeliveryOnly(true);
      vm.setProvince('QC');
      vm.setSupplierCurrency('USD');
      vm.setSupplierType('t');
      vm.setMinimumOrderQuantity(5);

      vm.togglePerishable(true);
      vm.toggleAgeRestricted(true);
      vm.toggleWarehouseSelection('w1');
      vm.setWarehouseStock('w1', 10);

      when(mockLocationRepo.getAddressSuggestions('123')).thenAnswer((_) async => []);
      await vm.onStreetChanged('123');

      vm.toggleHasVariants(true);
      vm.addVariantOption('S', ['V']);
      vm.updateVariantOption(0, 'N', ['V2']);
      vm.removeVariantOption(0);

      vm.clearError();
      vm.clearSkuError();
      vm.removeVideo();
    });
    group('Variant Logic', () {
      test('Variant combination generation and preservation', () async {
        final vm = getViewModel();
        vm.toggleHasVariants(true);
        vm.addVariantOption('Size', ['S', 'M']);
        expect(getState().variants.length, 2);

        vm.updateVariantPrice(0, 10.0);
        vm.updateVariantOption(0, 'Size', ['S', 'M', 'L']);
        expect(getState().variants.length, 3);
        expect(getState().variants[0].priceCents, 1000);
      });
    });
  });
}

// Valid 1x1 transparent PNG
final transparentPng = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);
