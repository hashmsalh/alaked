import 'dart:convert';
import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart' as osm;

import 'package:sixam_mart/common/widgets/custom_snackbar.dart';
import 'package:sixam_mart/features/address/domain/models/address_model.dart';
import 'package:sixam_mart/features/location/domain/models/prediction_model.dart';
import 'package:sixam_mart/features/location/domain/models/zone_response_model.dart';
import 'package:sixam_mart/features/location/domain/repositories/location_repository_interface.dart';
import 'package:sixam_mart/features/location/domain/services/location_service_interface.dart';
import 'package:sixam_mart/features/location/screens/pick_map_screen.dart';
import 'package:sixam_mart/features/location/widgets/permission_dialog_widget.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/helper/address_helper.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/util/app_constants.dart';

class LocationService implements LocationServiceInterface {
  final LocationRepositoryInterface locationRepoInterface;

  LocationService({required this.locationRepoInterface});

  // ==================== GEO ====================

  @override
  Future<String> getAddressFromGeocode(osm.LatLng latLng) async {
    return await locationRepoInterface.getAddressFromGeocode(latLng);
  }

  @override
  Future<ZoneResponseModel> getZone(
      String? lat,
      String? lng, {
        bool handleError = false,
      }) async {
    return await locationRepoInterface.getZone(
      lat,
      lng,
      handleError: handleError,
    );
  }
  @override
  Future<Position> getPosition(
      osm.LatLng? defaultLatLng,
      osm.LatLng configLatLng,
      ) async {
    try {
      // 1️⃣ محاولة جلب آخر موقع معروف (سريع جدًا)
      Position? lastKnown = await Geolocator.getLastKnownPosition();

      if (lastKnown != null &&
          lastKnown.latitude != 0 &&
          lastKnown.longitude != 0) {
        return lastKnown;
      }

      // 2️⃣ fallback إلى GPS الحقيقي
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      if (position.latitude == 0 || position.longitude == 0) {
        throw Exception('Invalid GPS position');
      }

      return position;
    } catch (_) {
      // 3️⃣ fallback النهائي (default → config)
      return Position(
        latitude: defaultLatLng?.latitude ?? configLatLng.latitude,
        longitude: defaultLatLng?.longitude ?? configLatLng.longitude,
        timestamp: DateTime.now(),
        accuracy: 1,
        altitude: 1,
        heading: 1,
        speed: 1,
        speedAccuracy: 1,
        altitudeAccuracy: 1,
        headingAccuracy: 1,
      );
    }
  }



  /// غير مستخدم مع OSM (موجود فقط للتوافق مع الواجهة)
  @override
  void handleMapAnimation(dynamic controller, Position myPosition) {
    // NO-OP
  }

  // ==================== HEADER ====================

  @override
  Map<String, String> prepareHeader(List<int>? zoneIds) {
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      AppConstants.zoneId: zoneIds != null ? jsonEncode(zoneIds) : '',
    };
  }

  // ==================== FIREBASE ====================

  @override
  void configureFirebaseMessaging(AddressModel address) {
    if (GetPlatform.isWeb) return;

    final splash = Get.find<SplashController>();

    if (splash.configModel!.demo!) {
      FirebaseMessaging.instance.subscribeToTopic('demo_reset');
    } else {
      FirebaseMessaging.instance.unsubscribeFromTopic('demo_reset');
    }

    final savedAddress = AddressHelper.getUserAddressFromSharedPref();

    if (savedAddress != null) {
      if (savedAddress.zoneIds != null) {
        for (int zoneID in savedAddress.zoneIds!) {
          FirebaseMessaging.instance
              .unsubscribeFromTopic('zone_${zoneID}_customer');
        }
      } else {
        FirebaseMessaging.instance.unsubscribeFromTopic(
          'zone_${savedAddress.zoneId}_customer',
        );
      }
    }

    if (address.zoneIds != null) {
      for (int zoneID in address.zoneIds!) {
        FirebaseMessaging.instance
            .subscribeToTopic('zone_${zoneID}_customer');
      }
    } else {
      FirebaseMessaging.instance.subscribeToTopic(
        'zone_${address.zoneId}_customer',
      );
    }
  }

  // ==================== ROUTING ====================

  @override
  void handleRoute(bool fromSignUp, String? route, bool canRoute) {
    if (route != null && canRoute) {
      Get.offAllNamed(route);
    } else {
      Get.offAllNamed(RouteHelper.getInitialRoute());
    }
  }

  // ==================== LAT LNG ====================

  @override
  Future<osm.LatLng> getLatLng(String? id) async {
    osm.LatLng latLng = const osm.LatLng(0, 0);

    final response = await locationRepoInterface.get(id);
    if (response?.statusCode == 200) {
      final location = response?.body['location'];
      latLng = osm.LatLng(
        location['latitude'],
        location['longitude'],
      );
    }

    return latLng;
  }

  // ==================== SEARCH ====================

  @override
  Future<List<PredictionModel>> searchLocation(String text) async {
    List<PredictionModel> list = [];
    final response = await locationRepoInterface.searchLocation(text);

    if (response.statusCode == 200) {
      try {
        response.body['suggestions']
            .forEach((p) => list.add(PredictionModel.fromJson(p)));
      } catch (e) {
        log(e.toString());
      }
    } else {
      showCustomSnackBar(
        response.body['error_message'] ?? response.bodyString,
      );
    }
    return list;
  }

  // ==================== PERMISSION ====================

  @override
  void checkLocationPermission(Function onTap) async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      showCustomSnackBar('you_have_to_allow'.tr);
    } else if (permission == LocationPermission.deniedForever) {
      Get.dialog(const PermissionDialogWidget());
    } else {
      onTap();
    }
  }

  // ==================== NAVIGATION ====================

  @override
  Future<void> authorizeNavigation(
      String page,
      List<AddressModel>? addressList,
      dynamic _,
      {
        bool offNamed = false,
        bool offAll = false,
      }) async {
    if (addressList != null && addressList.isEmpty) {
      if (ResponsiveHelper.isDesktop(Get.context)) {
        showGeneralDialog(
          context: Get.context!,
          pageBuilder: (_, __, ___) {
            return const SizedBox(
              height: 300,
              width: 300,
              child: PickMapScreen(
                fromSignUp: false,
                canRoute: false,
                fromAddAddress: false,
                route: null,
              ),
            );
          },
        );
      } else {
        Get.toNamed(RouteHelper.getPickMapRoute(page, false));
      }
    } else {
      if (offNamed) {
        Get.offNamed(RouteHelper.getAccessLocationRoute(page));
      } else if (offAll) {
        Get.offAllNamed(RouteHelper.getAccessLocationRoute(page));
      } else {
        Get.toNamed(RouteHelper.getAccessLocationRoute(page));
      }
    }
  }

  @override
  void defaultNavigation(String page, dynamic _) {
    if (ResponsiveHelper.isDesktop(Get.context)) {
      showGeneralDialog(
        context: Get.context!,
        pageBuilder: (_, __, ___) {
          return SizedBox(
            height: Get.context!.height * 0.75,
            width: 300,
            child: PickMapScreen(
              fromSignUp: page == RouteHelper.signUp,
              canRoute: false,
              fromAddAddress: false,
              route: null,
            ),
          );
        },
      );
    } else {
      Get.toNamed(RouteHelper.getPickMapRoute(page, false));
    }
  }
}
