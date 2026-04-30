import 'package:get/get_connect/http/src/response/response.dart';
import 'package:latlong2/latlong.dart' as osm;

import 'package:sixam_mart/features/location/domain/models/zone_response_model.dart';
import 'package:sixam_mart/interfaces/repository_interface.dart';

abstract class LocationRepositoryInterface<T>
    implements RepositoryInterface {

  /// 🔹 OSM Geocoding (بدل Google Maps)
  Future<String> getAddressFromGeocode(osm.LatLng latLng);

  /// 🔹 Zone check
  Future<ZoneResponseModel> getZone(
      String? lat,
      String? lng, {
        bool handleError = false,
      });

  /// 🔹 Search location (API backend)
  Future<Response> searchLocation(String text);

  /// 🔹 Get lat/lng by place id (backend)
  Future<Response?> get(String? id);
}
