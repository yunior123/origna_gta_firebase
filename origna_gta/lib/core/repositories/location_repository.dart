import 'package:cloud_functions/cloud_functions.dart';
import 'package:origna_gta/core/schema/schema_constants.dart';

abstract class LocationRepository {
  Future<List<Map<String, dynamic>>> getAddressSuggestions(String query);
}

/// Calls the `get_address_suggestions` Cloud Function which proxies Geoapify
/// server-side, keeping the API key out of the client bundle.
class GeoapifyLocationRepository implements LocationRepository {
  final FirebaseFunctions _functions;

  GeoapifyLocationRepository({FirebaseFunctions? functions}) : _functions = functions ?? FirebaseFunctions.instance;

  @override
  Future<List<Map<String, dynamic>>> getAddressSuggestions(String query) async {
    try {
      final result = await _functions
          .httpsCallable(CloudFunctionEndpoints.getAddressSuggestions)
          .call<Map>({'query': query, 'limit': 5});
      final features = (result.data['features'] as List?) ?? [];
      return features.cast<Map<String, dynamic>>();
    } catch (e) {
      // Fail soft — address suggestions are non-critical.
      // ignore: avoid_print
      print('⚠️ get_address_suggestions CF failed: $e');
      return [];
    }
  }
}
