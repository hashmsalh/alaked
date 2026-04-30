import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:sixam_mart/common/controllers/theme_controller.dart';
import 'package:sixam_mart/common/widgets/custom_app_bar.dart';
import 'package:sixam_mart/common/widgets/custom_snackbar.dart';
import 'package:sixam_mart/common/widgets/footer_view.dart';
import 'package:sixam_mart/common/widgets/menu_drawer.dart';
import 'package:sixam_mart/features/address/domain/models/address_model.dart';
import 'package:sixam_mart/features/location/controllers/location_controller.dart';
import 'package:sixam_mart/features/location/widgets/permission_dialog_widget.dart';
import 'package:sixam_mart/features/order/widgets/address_details_widget.dart';
import 'package:sixam_mart/helper/address_helper.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/images.dart';
import 'package:sixam_mart/util/styles.dart';

class MapScreen extends StatefulWidget {
  final AddressModel address;
  final bool fromStore;
  final bool isFood;
  final String storeName;

  const MapScreen({
    super.key,
    required this.address,
    this.fromStore = false,
    this.isFood = false,
    required this.storeName,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  bool get _isDarkMap {
    return Get.isDarkMode &&
        Get.find<ThemeController>().darkTheme;
  }
  late LatLng _targetLatLng;
  LatLng? _myLatLng;

  bool isHovered = false;

  @override
  void initState() {
    super.initState();

    _targetLatLng = LatLng(

      double.parse(widget.address.latitude!),
      double.parse(widget.address.longitude!),

    );
    final savedLatLng = _getSavedUserLatLng();
    if (savedLatLng != null) {
      _myLatLng = savedLatLng;
    }
  }

  Future<LatLng> _getCurrentLocationLatLng() async {
    final Position pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    return LatLng(pos.latitude, pos.longitude);
  }
  LatLng? _getSavedUserLatLng() {
    final savedAddress = AddressHelper.getUserAddressFromSharedPref();
    if (savedAddress == null ||
        savedAddress.latitude == null ||
        savedAddress.longitude == null) {
      return null;
    }

    return LatLng(
      double.parse(savedAddress.latitude!),
      double.parse(savedAddress.longitude!),
    );
  }

  void _onEntered(bool value) {
    setState(() => isHovered = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: widget.storeName.isNotEmpty && widget.storeName != 'null'
            ? widget.storeName
            : 'location'.tr,
      ),
      endDrawer: const MenuDrawer(),
      endDrawerEnableOpenDragGesture: false,
      body: SingleChildScrollView(
        physics: isHovered || !ResponsiveHelper.isDesktop(context)
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(),
        child: FooterView(
          child: Center(
            child: SizedBox(
              width: Dimensions.webMaxWidth,
              height: ResponsiveHelper.isDesktop(context)
                  ? 600
                  : MediaQuery.of(context).size.height * 0.85,
              child: Stack(
                children: [
                  MouseRegion(
                    onEnter: (_) => _onEntered(true),
                    onExit: (_) => _onEntered(false),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _targetLatLng,
                        initialZoom: 10,
                        minZoom: 3,
                        maxZoom: 12,
                      ),
                      children: [

                        TileLayer(
                          // توحيد الرابط للخريطة العادية لمنع ظهور لون رمادي عند تفعيل الوضع المظلم
                          urlTemplate: 'https://tiles.gpsstorebx.com/data/world/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.gpsstore.bx',
                          minZoom: 3,
                          maxZoom: 10,
                          maxNativeZoom: 10,
                          keepBuffer: 1, // تحسين استهلاك الرام ومنع تعليق الجوال
                        ),

                        /// 🌍 خريطة الشرق الأوسط (تفاصيل أعلى)
                        TileLayer(
                          urlTemplate: 'https://tiles.gpsstorebx.com/data/middleeast/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.gpsstore.bx',
                          minZoom: 8,
                          maxZoom: 12,
                          maxNativeZoom: 12,
                          keepBuffer: 1, // ضمان سلاسة الحركة عند السحب السريع
                        ),


                        MarkerLayer(
                          markers: [
                            /// 📍 Target address
                            Marker(
                              point: _targetLatLng,
                              width: 50,
                              height: 50,
                              child: Image.asset(
                                widget.fromStore
                                    ? widget.isFood
                                    ? Images.restaurantMarker
                                    : Images.markerStore
                                    : Images.locationMarker,
                              ),
                            ),

                            /// 🧍 My location
                            if (_myLatLng != null)
                              Marker(
                                point: _myLatLng!,
                                width: 30,
                                height: 30,
                                child: Image.asset(
                                  Images.userMarker,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  /// 🔘 Buttons + info
                  Positioned(
                    left: Dimensions.paddingSizeLarge,
                    right: Dimensions.paddingSizeLarge,
                    bottom: Dimensions.paddingSizeLarge,
                    child: Column(
                      children: [
                        /// 📍 My location button
                        Align(
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            onTap: () => _checkPermission(() async {
                              final LatLng myLocation = await _getCurrentLocationLatLng();

                              setState(() {
                                _myLatLng = myLocation;
                              });

                              _mapController.move(myLocation, 10);
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(
                                  Dimensions.paddingSizeSmall),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(50),
                                color: Theme.of(context).cardColor,
                              ),
                              child: Icon(
                                Icons.my_location_outlined,
                                color:
                                Theme.of(context).primaryColor,
                                size: 25,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(
                            height: Dimensions.paddingSizeLarge),

                        /// 📦 Address info
                        Container(
                          padding: const EdgeInsets.all(
                              Dimensions.paddingSizeSmall),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                                Dimensions.radiusSmall),
                            color: Theme.of(context).cardColor,
                          ),
                          child: widget.fromStore
                              ? Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.address.address ?? '',
                                  style: robotoMedium,
                                  maxLines: 2,
                                  overflow:
                                  TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(
                                  width:
                                  Dimensions.paddingSizeDefault),
                              InkWell(
                                onTap: () async {
                                  final url =
                                      'https://www.google.com/maps/dir/?api=1&destination=${widget.address.latitude},${widget.address.longitude}';
                                  if (await canLaunchUrlString(
                                      url)) {
                                    await launchUrlString(
                                      url,
                                      mode: LaunchMode
                                          .externalApplication,
                                    );
                                  } else {
                                    showCustomSnackBar(
                                        'unable_to_launch_google_map'
                                            .tr);
                                  }
                                },
                                child: const Icon(
                                    Icons.directions),
                              ),
                            ],
                          )
                              : Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              AddressDetailsWidget(
                                addressDetails:
                                widget.address,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _checkPermission(Function onTap) async {
    LocationPermission permission =
    await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      showCustomSnackBar('you_have_to_allow'.tr);
    } else if (permission ==
        LocationPermission.deniedForever) {
      Get.dialog(const PermissionDialogWidget());
    } else {
      onTap();
    }
  }
}
