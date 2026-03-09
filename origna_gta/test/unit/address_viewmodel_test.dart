import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:origna_gta/core/providers.dart';
import 'package:origna_gta/core/repositories/location_repository.dart';
import 'package:origna_gta/core/repositories/user_repository.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';
import 'package:origna_gta/features/profile/address_state.dart';
import 'package:origna_gta/features/profile/address_viewmodel.dart';
import 'package:origna_gta/utils/utils.dart';

@GenerateNiceMocks([
  MockSpec<UserRepository>(),
  MockSpec<LocationRepository>(),
])
import 'address_viewmodel_test.mocks.dart';

void main() {
  // =========================================================================
  // AddressState
  // =========================================================================
  group('AddressState', () {
    test('default values', () {
      final state = AddressState();
      expect(state.isLoading, isFalse);
      expect(state.selectedProvince, ProvinceCodeValues.ontario);
      expect(state.selectedLabel, AddressLabelValues.home);
      expect(state.addressSuggestions, isEmpty);
      expect(state.showSuggestions, isFalse);
      expect(state.latitude, isNull);
      expect(state.longitude, isNull);
      expect(state.addressId, isNull);
      expect(state.errorMessage, isNull);
      expect(state.isSuccess, isFalse);
      expect(state.isDefault, isFalse);
    });

    test('copyWith preserves existing values when no args', () {
      final state = AddressState(
        isLoading: true,
        selectedProvince: 'QC',
        latitude: 45.5,
        longitude: -73.5,
        addressId: 'addr1',
        isDefault: true,
      );
      final copy = state.copyWith();
      expect(copy.isLoading, isTrue);
      expect(copy.selectedProvince, 'QC');
      expect(copy.latitude, 45.5);
      expect(copy.longitude, -73.5);
      expect(copy.addressId, 'addr1');
      expect(copy.isDefault, isTrue);
    });

    test('copyWith clearCoordinates resets lat/lng', () {
      final state = AddressState(latitude: 45.5, longitude: -73.5);
      final copy = state.copyWith(clearCoordinates: true);
      expect(copy.latitude, isNull);
      expect(copy.longitude, isNull);
    });

    test('copyWith overrides specific fields', () {
      final state = AddressState();
      final copy = state.copyWith(
        isLoading: true,
        selectedProvince: 'BC',
        selectedLabel: AddressLabelValues.work,
        showSuggestions: true,
        latitude: 49.2,
        longitude: -123.1,
        addressId: 'a1',
        errorMessage: 'err',
        isSuccess: true,
        isDefault: true,
      );
      expect(copy.isLoading, isTrue);
      expect(copy.selectedProvince, 'BC');
      expect(copy.selectedLabel, AddressLabelValues.work);
      expect(copy.showSuggestions, isTrue);
      expect(copy.latitude, 49.2);
      expect(copy.longitude, -123.1);
      expect(copy.addressId, 'a1');
      expect(copy.errorMessage, 'err');
      expect(copy.isSuccess, isTrue);
      expect(copy.isDefault, isTrue);
    });

    test('copyWith sets errorMessage to null', () {
      final state = AddressState(errorMessage: 'old error');
      // errorMessage: null in copyWith clears it
      final copy = state.copyWith(errorMessage: null);
      expect(copy.errorMessage, isNull);
    });
  });

  // =========================================================================
  // AddressViewModel
  // =========================================================================
  group('AddressViewModel', () {
    late MockUserRepository mockUserRepo;
    late MockLocationRepository mockLocationRepo;
    late ProviderContainer container;

    setUp(() {
      mockUserRepo = MockUserRepository();
      mockLocationRepo = MockLocationRepository();

      container = ProviderContainer(
        overrides: [
          userRepositoryProvider.overrideWithValue(mockUserRepo),
          locationRepositoryProvider.overrideWithValue(mockLocationRepo),
          userIdProvider.overrideWith((ref) => 'testUser123'),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('initial state has default province and label', () {
      final vm = container.read(addressViewModelProvider.notifier);
      final state = container.read(addressViewModelProvider);
      expect(state.selectedProvince, ProvinceCodeValues.ontario);
      expect(state.selectedLabel, AddressLabelValues.home);
      expect(state.isLoading, isFalse);
      expect(vm, isNotNull);
    });

    test('setProvince updates state', () {
      final vm = container.read(addressViewModelProvider.notifier);
      vm.setProvince('BC');
      expect(container.read(addressViewModelProvider).selectedProvince, 'BC');
    });

    test('setLabel updates state', () {
      final vm = container.read(addressViewModelProvider.notifier);
      vm.setLabel(AddressLabelValues.work);
      expect(container.read(addressViewModelProvider).selectedLabel, AddressLabelValues.work);
    });

    test('setDefault updates state', () {
      final vm = container.read(addressViewModelProvider.notifier);
      vm.setDefault(true);
      expect(container.read(addressViewModelProvider).isDefault, isTrue);
    });

    test('setInitialData sets state from address', () {
      final vm = container.read(addressViewModelProvider.notifier);
      final addr = Address(
        street: '123 Main',
        city: 'Toronto',
        state: 'QC',
        postalCode: 'H1A',
        country: 'CA',
        latitude: 45.5,
        longitude: -73.5,
        label: AddressLabelValues.work,
        addressId: 'addr1',
        isDefault: true,
      );
      vm.setInitialData(addr);
      final state = container.read(addressViewModelProvider);
      expect(state.selectedProvince, 'QC');
      expect(state.selectedLabel, AddressLabelValues.work);
      expect(state.latitude, 45.5);
      expect(state.longitude, -73.5);
      expect(state.addressId, 'addr1');
      expect(state.isDefault, isTrue);
    });

    test('setInitialData with null address does nothing', () {
      final vm = container.read(addressViewModelProvider.notifier);
      vm.setInitialData(null);
      final state = container.read(addressViewModelProvider);
      expect(state.selectedProvince, ProvinceCodeValues.ontario);
    });

    test('selectAddress updates state from suggestion', () {
      final vm = container.read(addressViewModelProvider.notifier);
      final suggestion = {
        'properties': {
          'housenumber': '456',
          'street': 'Oak Ave',
          'formatted': '456 Oak Ave',
          'city': 'Vancouver',
          'state_code': 'BC',
          'postcode': 'V5K',
        },
        'geometry': {
          'coordinates': [-123.1, 49.2],
        },
      };
      vm.selectAddress(suggestion);
      final state = container.read(addressViewModelProvider);
      expect(state.selectedProvince, 'BC');
      expect(state.latitude, closeTo(49.2, 0.01));
      expect(state.longitude, closeTo(-123.1, 0.01));
      expect(state.showSuggestions, isFalse);
    });

    test('onStreetChanged with short input hides suggestions', () {
      final vm = container.read(addressViewModelProvider.notifier);
      vm.onStreetChanged('ab');
      final state = container.read(addressViewModelProvider);
      expect(state.showSuggestions, isFalse);
      expect(state.addressSuggestions, isEmpty);
    });

    test('onStreetChanged clears coordinates', () {
      final vm = container.read(addressViewModelProvider.notifier);
      // Set coordinates first
      vm.selectAddress({
        'properties': {'state_code': 'ON'},
        'geometry': {'coordinates': [-79.0, 43.0]},
      });
      expect(container.read(addressViewModelProvider).latitude, isNotNull);

      // Type manually — should clear coordinates
      vm.onStreetChanged('new address');
      expect(container.read(addressViewModelProvider).latitude, isNull);
      expect(container.read(addressViewModelProvider).longitude, isNull);
    });

    test('saveAddress fails without coordinates', () async {
      final vm = container.read(addressViewModelProvider.notifier);
      // No coordinates set
      await vm.saveAddress(
        street: '123 Main',
        apartment: '',
        city: 'Toronto',
        postalCode: 'M5V 1A1',
        phoneNumber: '4165551234',
      );
      final state = container.read(addressViewModelProvider);
      expect(state.errorMessage, isNotNull);
      expect(state.isSuccess, isFalse);
    });

    test('saveAddress creates new address', () async {
      final vm = container.read(addressViewModelProvider.notifier);
      // Set coordinates
      vm.selectAddress({
        'properties': {'state_code': 'ON'},
        'geometry': {'coordinates': [-79.3, 43.6]},
      });

      when(mockUserRepo.addBuyerAddress(any)).thenAnswer((_) async => 'newId');

      await vm.saveAddress(
        street: '123 Main St',
        apartment: 'Unit 5',
        city: 'Toronto',
        postalCode: 'm5v 1a1',
        phoneNumber: '4165551234',
      );
      final state = container.read(addressViewModelProvider);
      expect(state.isSuccess, isTrue);
      expect(state.isLoading, isFalse);
      verify(mockUserRepo.addBuyerAddress(any)).called(1);
    });

    test('saveAddress updates existing address', () async {
      final vm = container.read(addressViewModelProvider.notifier);
      // Set coordinates + addressId (editing mode)
      vm.setInitialData(Address(
        street: '123', city: 'T', state: 'ON', postalCode: 'M5V', country: 'CA',
        latitude: 43.6, longitude: -79.3, addressId: 'existing123',
      ));

      when(mockUserRepo.updateBuyerAddress(any, any)).thenAnswer((_) async {});

      await vm.saveAddress(
        street: '456 New St',
        apartment: '',
        city: 'Ottawa',
        postalCode: 'K1A',
        phoneNumber: '',
      );
      final state = container.read(addressViewModelProvider);
      expect(state.isSuccess, isTrue);
      verify(mockUserRepo.updateBuyerAddress('existing123', any)).called(1);
    });

    test('saveAddress handles error gracefully', () async {
      final vm = container.read(addressViewModelProvider.notifier);
      vm.selectAddress({
        'properties': {'state_code': 'ON'},
        'geometry': {'coordinates': [-79.3, 43.6]},
      });

      when(mockUserRepo.addBuyerAddress(any)).thenThrow(Exception('network error'));

      await vm.saveAddress(
        street: '123 Main',
        apartment: '',
        city: 'Toronto',
        postalCode: 'M5V',
        phoneNumber: '',
      );
      final state = container.read(addressViewModelProvider);
      expect(state.isSuccess, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNotNull);
    });

    test('saveAddress returns early if userId is null', () async {
      // Override userId to null
      final nullContainer = ProviderContainer(
        overrides: [
          userRepositoryProvider.overrideWithValue(mockUserRepo),
          locationRepositoryProvider.overrideWithValue(mockLocationRepo),
          userIdProvider.overrideWith((ref) => null),
        ],
      );

      final vm = nullContainer.read(addressViewModelProvider.notifier);
      await vm.saveAddress(
        street: '123', apartment: '', city: 'T', postalCode: 'M5V', phoneNumber: '',
      );
      // Should not call any repo methods
      verifyNever(mockUserRepo.addBuyerAddress(any));
      verifyNever(mockUserRepo.updateBuyerAddress(any, any));
      nullContainer.dispose();
    });
  });
}
