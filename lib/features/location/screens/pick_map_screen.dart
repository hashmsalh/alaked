import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'package:sixam_mart/common/widgets/custom_button.dart';
import 'package:sixam_mart/common/widgets/custom_snackbar.dart';
import 'package:sixam_mart/common/widgets/menu_drawer.dart';
import 'package:sixam_mart/features/address/domain/models/address_model.dart';
import 'package:sixam_mart/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart/features/location/controllers/location_controller.dart';
import 'package:sixam_mart/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/helper/address_helper.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/images.dart';
import 'dart:async';

class PickMapScreen extends StatefulWidget {
  final bool fromSignUp;
  final bool fromAddAddress;
  final bool canRoute;
  final String? route;
  final Function(AddressModel address)? onPicked;
  final bool fromLandingPage;

  const PickMapScreen({
    super.key,
    required this.fromSignUp,
    required this.fromAddAddress,
    required this.canRoute,
    required this.route,
    this.onPicked,
    this.fromLandingPage = false,
  });

  @override
  State<PickMapScreen> createState() => _PickMapScreenState();
}

class _PickMapScreenState extends State<PickMapScreen> {
  Timer? _mapDebounce;
  @override
  void dispose() {
    _mapDebounce?.cancel();
    super.dispose();
  }


  final MapController _mapController = MapController();
  late LatLng _initialCenter;

  @override
  void initState() {
    super.initState();

    if (widget.fromAddAddress) {
      Get.find<LocationController>().setPickData();
    }

    _initialCenter = LatLng(
      double.parse(Get.find<SplashController>().configModel!.defaultLocation!.lat ?? '0'),
      double.parse(Get.find<SplashController>().configModel!.defaultLocation!.lng ?? '0'),
    );
  }
  Future<void> _moveToMyLocation(LocationController controller) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      showCustomSnackBar('you_have_to_allow'.tr);
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    final latLng = LatLng(position.latitude, position.longitude);

    // 1️⃣ حرّك الخريطة
    _mapController.move(latLng, 10);

    // 2️⃣ حدّث الإحداثيات
    controller.setPickPositionFromMap(
      latLng.latitude,
      latLng.longitude,
    );

    // 3️⃣ اجلب العنوان (🔥 هذا هو المفتاح)
    await controller.getAddressFromGeocode(latLng);

    // 4️⃣ حدّث الزون
    await controller.getZone(
      latLng.latitude.toString(),
      latLng.longitude.toString(),
      true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ResponsiveHelper.isDesktop(context)
          ? Colors.transparent
          : Theme.of(context).cardColor,
      endDrawer: const MenuDrawer(),
      endDrawerEnableOpenDragGesture: false,
      body: SafeArea(
        child: GetBuilder<LocationController>(
          builder: (locationController) {
            return Center(
              child: Container(
                height: ResponsiveHelper.isDesktop(context) ? 600 : null,
                width: ResponsiveHelper.isDesktop(context)
                    ? 700
                    : Dimensions.webMaxWidth,
                decoration: ResponsiveHelper.isDesktop(context)
                    ? BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius:
                  BorderRadius.circular(Dimensions.radiusSmall),
                )
                    : null,
                child: Stack(
                  children: [

                    /// 🔍 SEARCH BAR
                    Positioned(
                      top: Dimensions.paddingSizeLarge,
                      left: Dimensions.paddingSizeLarge,
                      right: Dimensions.paddingSizeLarge,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText:
                          'type_your_address_here_to_pick_form_map'.tr,
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                                Dimensions.radiusSmall),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            locationController.searchLocation(context, value);

                          }
                        },
                      ),
                    ),

                    /// 🗺️ MAP SECTION
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: widget.fromAddAddress
                            ? LatLng(
                          locationController.position.latitude,
                          locationController.position.longitude,
                        )
                            : _initialCenter,
                        initialZoom: 10,

                        // 🛑 قيود الزوم
                        minZoom: 3,
                        maxZoom: 12,

                        onPositionChanged: (position, hasGesture) {

                          if (!hasGesture || position.center == null) return;

                          final lat = position.center!.latitude;
                          final lng = position.center!.longitude;

                          // تحديث الإحداثيات مباشرة
                          locationController.setPickPositionFromMap(lat, lng);

                          // إلغاء أي طلب سابق
                          _mapDebounce?.cancel();

                          // انتظر 600ms بعد توقف السحب
                          _mapDebounce = Timer(const Duration(milliseconds: 600), () async {

                            // 🔎 جلب العنوان
                            await locationController.getAddressFromGeocode(
                              LatLng(lat, lng),
                            );

                            // 🌍 تحديث الزون
                            await locationController.getZone(
                              lat.toString(),
                              lng.toString(),
                              true,
                            );

                          });
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tiles.gpsstorebx.com/data/world/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.gpsstore.bx',
                          minZoom: 3,
                          maxZoom: 10,
                          maxNativeZoom: 10,
                          keepBuffer: 1,
                        ),

                        TileLayer(
                          urlTemplate: 'https://tiles.gpsstorebx.com/data/middleeast/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.gpsstore.bx',
                          minZoom: 8,
                          maxZoom: 12,
                          maxNativeZoom: 12,
                          keepBuffer: 1,
                        ),
                      ],
                    ),


                    /// 📍 CENTER MARKER (علامة التثبيت في المنتصف)
                Center(
                  child: locationController.loading
                      ? const CircularProgressIndicator()
                      : Padding(
                    padding: const EdgeInsets.only(bottom: 35), // لضبط رأس الدبوس على الموقع بدقة
                    child: Image.asset(
                      Images.pickMarker,
                      height: 50,
                      width: 50,
                    ),
                  ),
                ),

                /// 📍 MY LOCATION BUTTON
                Positioned(
                  bottom: 90,
                  right: Dimensions.paddingSizeLarge,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: Theme.of(context).cardColor,
                    onPressed: () => _moveToMyLocation(locationController),
                    child: Icon(
                      Icons.my_location,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),

                /// ✅ PICK BUTTON
                Positioned(
                  bottom: Dimensions.paddingSizeLarge,
                  left: Dimensions.paddingSizeLarge,
                  right: Dimensions.paddingSizeLarge,
                  child: CustomButton(
                    buttonText: locationController.inZone
                        ? (widget.fromAddAddress ? 'pick_address'.tr : 'pick_location'.tr)
                        : 'service_not_available_in_this_area'.tr,
                    isLoading: locationController.isLoading,
                    onPressed: locationController.isLoading ||
                        locationController.buttonDisabled ||
                        locationController.loading
                        ? null
                        : () => _onPickAddress(locationController),
                  ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }


  void _onPickAddress(LocationController locationController) {
    final position = locationController.pickPosition ??
        locationController.position;

    if (position.latitude != 0 &&
        (locationController.pickAddress?.isNotEmpty ?? false)) {


      AddressModel address = AddressModel(
        latitude: position.latitude.toString(),
        longitude: position.longitude.toString(),
        addressType: 'others',
        address: locationController.pickAddress,
        contactPersonName:
        AddressHelper.getUserAddressFromSharedPref()?.contactPersonName,
        contactPersonNumber:
        AddressHelper.getUserAddressFromSharedPref()?.contactPersonNumber,
      );

// 🔹 في حال كان هناك callback (استخدام مخصص)
      if (widget.onPicked != null) {
        widget.onPicked!(address);
        Get.back();
        return;
      }

// 🔹 في حال إضافة عنوان فقط (بدون تغيير موقع التطبيق)
      if (widget.fromAddAddress) {
        Get.back();
        return;
      }

// 🔹 السيناريوهات الأخرى (Landing / Signup / Home)
      if (widget.fromLandingPage) {
        if (!AuthHelper.isGuestLoggedIn() && !AuthHelper.isLoggedIn()) {
          Get.find<AuthController>().guestLogin().then((response) {
            if (response.isSuccess) {
              Get.find<ProfileController>().setForceFullyUserEmpty();
              Get.back();
              locationController.saveAddressAndNavigate(
                address,
                widget.fromSignUp,
                widget.route,
                widget.canRoute,
                ResponsiveHelper.isDesktop(context),
              );
            }
          });
        } else {
          Get.back();
          locationController.saveAddressAndNavigate(
            address,
            widget.fromSignUp,
            widget.route,
            widget.canRoute,
            ResponsiveHelper.isDesktop(context),
          );
        }
      } else {
        locationController.saveAddressAndNavigate(
          address,
          widget.fromSignUp,
          widget.route,
          widget.canRoute,
          ResponsiveHelper.isDesktop(context),
        );
      }
    }
  }
}
