import 'dart:convert';
import 'package:http/http.dart' as http;

class OsmReverseGeocodingService {

  /// 🔁 Reverse Geocoding via OpenStreetMap (Nominatim)
  static Future<String> getAddressFromLatLng({
    required double latitude,
    required double longitude,
  }) async {

    final Uri url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
          '?format=json'
          '&lat=$latitude'
          '&lon=$longitude'
          '&zoom=18'
          '&addressdetails=1',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'gpsstorebx-app', // مهم
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'] ?? '';
      } else {
        return '';
      }
    } catch (e) {
      return '';
    }
  }
}
