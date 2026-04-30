import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as osm;

import 'package:sixam_mart/features/location/domain/models/prediction_model.dart';
import 'package:sixam_mart/features/address/domain/models/address_model.dart';
import 'package:sixam_mart/features/location/domain/models/zone_response_model.dart';

abstract class LocationServiceInterface {

  /// الحصول على الموقع الحالي
  /// defaultLatLng: موقع مختار يدويًا (إن وجد)
  /// configLatLng: الموقع الافتراضي من الإعدادات
  Future<Position> getPosition(
      osm.LatLng? defaultLatLng,
      osm.LatLng configLatLng,
      );

  /// تحريك الخريطة (غير مستخدم مع OSM – يُترك فارغًا)
  void handleMapAnimation(dynamic mapController, Position myPosition);

  /// تحويل إحداثيات إلى عنوان نصي
  Future<String> getAddressFromGeocode(osm.LatLng latLng);

  /// جلب بيانات المنطقة (Zone)
  Future<ZoneResponseModel> getZone(
      String? lat,
      String? lng, {
        bool handleError = false,
      });

  /// تجهيز الهيدر مع zoneIds
  Map<String, String> prepareHeader(List<int>? zoneIds);

  /// إعداد Firebase Messaging حسب المنطقة
  void configureFirebaseMessaging(AddressModel address);

  /// التنقل بعد تحديد الموقع
  void handleRoute(bool fromSignUp, String? route, bool canRoute);

  /// جلب LatLng من place id (بحث)
  Future<osm.LatLng> getLatLng(String? id);

  /// البحث عن موقع
  Future<List<PredictionModel>> searchLocation(String text);

  /// التحقق من صلاحيات الموقع
  void checkLocationPermission(Function onTap);

  /// منطق التنقل عند وجود / عدم وجود عناوين
  Future<void> authorizeNavigation(
      String page,
      List<AddressModel>? addressList,
      dynamic mapController, {
        bool offNamed = false,
        bool offAll = false,
      });

  /// التنقل الافتراضي
  void defaultNavigation(String page, dynamic mapController);
}
