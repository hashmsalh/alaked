import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import 'package:latlong2/latlong.dart';

import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import 'package:sixam_mart/common/widgets/custom_asset_image_widget.dart';
import 'package:sixam_mart/common/widgets/custom_snackbar.dart';
import 'package:sixam_mart/common/widgets/custom_text_field.dart';
import 'package:sixam_mart/common/widgets/custom_button.dart';
import 'package:sixam_mart/common/widgets/custom_dropdown.dart';

import 'package:sixam_mart/features/auth/widgets/pickup_zone_widget.dart';
import 'package:sixam_mart/features/auth/widgets/zone_selection_widget.dart';
import 'package:sixam_mart/features/auth/widgets/module_view_widget.dart';

import 'package:sixam_mart/features/location/controllers/location_controller.dart';
import 'package:sixam_mart/features/location/domain/models/zone_data_model.dart';
import 'package:sixam_mart/features/location/widgets/location_search_dialog_widget.dart';
import 'package:sixam_mart/features/location/widgets/permission_dialog_widget.dart';

import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/auth/controllers/store_registration_controller.dart';

import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/validate_check.dart';

import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/images.dart';
import 'package:sixam_mart/util/styles.dart';

class SelectLocationViewWidget extends StatefulWidget {
  final bool fromView;
  final bool mapView;
  final bool zoneModuleView;
  final TextEditingController? addressController;
  final FocusNode? addressFocus;
  final bool inDialog;

  const SelectLocationViewWidget({
    super.key,
    required this.fromView,
    this.mapView = false,
    this.zoneModuleView = false,
    this.addressController,
    this.addressFocus,
    this.inDialog = false,
  });

  @override
  State<SelectLocationViewWidget> createState() =>
      _SelectLocationViewWidgetState();
}

class _SelectLocationViewWidgetState
    extends State<SelectLocationViewWidget> {

  final MapController _mapController = MapController();

  late LatLng _cameraTarget;
  LatLng? _markerPosition;

  List<Polygon> _polygons = [];

  @override
  void initState() {
    super.initState();

    _cameraTarget = LatLng(
      double.parse(
        Get.find<SplashController>()
            .configModel
            ?.defaultLocation
            ?.lat ??
            '15.3694',
      ),
      double.parse(
        Get.find<SplashController>()
            .configModel
            ?.defaultLocation
            ?.lng ??
            '44.1910',
      ),
    );

    _markerPosition = _cameraTarget;
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<StoreRegistrationController>(
      builder: (storeRegController) {

        final bool isDesktop = ResponsiveHelper.isDesktop(context);

        final bool isRentalModule =
            widget.fromView &&
                storeRegController.moduleList != null &&
                storeRegController.selectedModuleIndex != -1 &&
                storeRegController
                    .moduleList![storeRegController.selectedModuleIndex!]
                    .moduleType ==
                    AppConstants.taxi;

        List<DropdownItem<int>> zoneList = [];
        if (storeRegController.zoneList != null) {
          for (int i = 0;
          i < storeRegController.zoneList!.length;
          i++) {
            zoneList.add(
              DropdownItem<int>(
                value: i,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    storeRegController.zoneList![i].name ?? '',
                  ),
                ),
              ),
            );
          }
        }

        return Container(
          alignment: Alignment.center,
          padding: widget.fromView && !isDesktop
              ? const EdgeInsets.symmetric(
            horizontal: Dimensions.paddingSizeSmall,
            vertical: Dimensions.paddingSizeDefault,
          )
              : EdgeInsets.zero,
          child: SizedBox(
            width: Dimensions.webMaxWidth,
            child: SingleChildScrollView(
              child: isDesktop && widget.fromView
                  ? _webView(storeRegController, zoneList)
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const SizedBox(height: Dimensions.paddingSizeSmall),

                  widget.fromView
                      ? ZoneSelectionWidget(
                    storeRegController:
                    storeRegController,
                    zoneList: zoneList,
                    callBack: () {
                      _setPolygon(
                        storeRegController.zoneList![
                        storeRegController
                            .selectedZoneIndex!],
                      );
                    },
                  )
                      : const SizedBox(),

                  widget.fromView
                      ? const SizedBox(
                      height:
                      Dimensions.paddingSizeExtremeLarge)
                      : const SizedBox(),

                  widget.fromView
                      ? const ModuleViewWidget()
                      : const SizedBox(),

                  widget.fromView
                      ? const SizedBox(
                      height:
                      Dimensions.paddingSizeExtremeLarge)
                      : const SizedBox(),

                  isRentalModule
                      ? const PickupZoneWidget()
                      : const SizedBox(),

                  isRentalModule
                      ? const SizedBox(
                      height:
                      Dimensions.paddingSizeExtremeLarge)
                      : const SizedBox(),

                  /// ⬇️ الخريطة (الجزء الثاني سيكملها)
                  _mapView(storeRegController),

                  if (widget.fromView && !isDesktop)
                    CustomTextField(
                      titleText:
                      'write_store_address'.tr,
                      controller:
                      widget.addressController,
                      focusNode:
                      widget.addressFocus,
                      inputType:
                      TextInputType.text,
                      maxLines: 3,
                      required: true,
                      validator: (value) =>
                          ValidateCheck
                              .validateEmptyText(
                            value,
                            'store_address_field_is_required'
                                .tr,
                          ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// ========================= WEB VIEW =========================
  Widget _webView(
      StoreRegistrationController storeRegController,
      List<DropdownItem<int>> zoneList,
      ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              ZoneSelectionWidget(
                storeRegController: storeRegController,
                zoneList: zoneList,
                callBack: () {
                  _setPolygon(
                    storeRegController.zoneList![
                    storeRegController.selectedZoneIndex!],
                  );
                },
              ),
              const SizedBox(height: Dimensions.paddingSizeLarge),
              _mapView(storeRegController),
            ],
          ),
        ),
      ],
    );
  }

  /// ========================= MAP VIEW =========================
  Widget _mapView(StoreRegistrationController storeRegController) {
    if (storeRegController.zoneList == null ||
        storeRegController.zoneList!.isEmpty) {
      return const SizedBox();
    }

    return Center(
      child: Container(
        height: ResponsiveHelper.isDesktop(context)
            ? widget.fromView
            ? 220
            : MediaQuery.of(context).size.height * 0.8
            : widget.fromView
            ? 170
            : MediaQuery.of(context).size.height * 0.87,
        width: widget.inDialog
            ? MediaQuery.of(context).size.width * 0.7
            : MediaQuery.of(context).size.width,
        decoration: widget.fromView
            ? BoxDecoration(
          borderRadius:
          BorderRadius.circular(Dimensions.radiusDefault),
          border: Border.all(
            width: 1,
            color: Theme.of(context).primaryColor,
          ),
        )
            : null,
        child: ClipRRect(
          borderRadius:
          BorderRadius.circular(Dimensions.radiusDefault),
          child: Stack(
            clipBehavior: Clip.none,
            children: [

              /// ================= MAP =================
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _cameraTarget,
                  initialZoom: 10,
                  maxZoom: 12,
                  minZoom: 3,
                  onMapReady: () {
                    _setPolygon(
                      storeRegController.zoneList![
                      storeRegController.selectedZoneIndex!],
                    );
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tiles.gpsstorebx.com/data/world/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.gpsstore.bx',
                    minZoom: 3,
                    maxZoom: 10,
                    maxNativeZoom: 10,
                    // تحسين الأداء لتقليل استهلاك الرام في الجوال
                    keepBuffer: 1,
                  ),

                  /// 🌍 خريطة الشرق الأوسط (تفاصيل أعلى)
                  TileLayer(
                    urlTemplate: 'https://tiles.gpsstorebx.com/data/middleeast/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.gpsstore.bx',
                    minZoom: 8,
                    maxZoom: 12,
                    maxNativeZoom: 12,
                    // تحسين الأداء ومنع تعليق الشبكة
                    keepBuffer: 1,
                  ),


                  /// ================= ZONE =================
                  PolygonLayer(
                    polygons: _polygons,
                  ),

                  /// ================= DRAG MARKER =================
                  DragMarkers(
                    markers: [
                      DragMarker(
                        point: _markerPosition!,
                        size: const Size(40, 40),
                        builder: (context, point, isDragging) {
                          return CustomAssetImageWidget(
                            Images.markerStore,
                            height: isDragging ? 45 : 40,
                            width: isDragging ? 45 : 40,
                          );
                        },
                        onDragEnd: (details, LatLng newPosition) {
                          setState(() {
                            _markerPosition = newPosition;
                            _cameraTarget = newPosition;
                          });

                          storeRegController.setLocation(
                            newPosition,
                            forStoreRegistration: true,
                            zoneId: storeRegController
                                .zoneList![storeRegController.selectedZoneIndex!]
                                .id,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),

              /// ================= SEARCH =================
              Positioned(
                top: widget.fromView ? 10 : 20,
                left: widget.fromView ? 10 : 20,
                child: InkWell(
                  onTap: () async {
                    final Position? position =
                    await Get.dialog(
                        LocationSearchDialogWidget());

                    if (position != null) {
                      final LatLng newPos = LatLng(
                        position.latitude,
                        position.longitude,
                      );

                      setState(() {
                        _markerPosition = newPos;
                        _cameraTarget = newPos;
                      });

                      _mapController.move(newPos, 12);

                      storeRegController.setLocation(
                        newPos,
                        forStoreRegistration: true,
                        zoneId: storeRegController
                            .zoneList![storeRegController
                            .selectedZoneIndex!]
                            .id,
                      );
                    }
                  },
                  child: Container(
                    height: widget.fromView ? 30 : 40,
                    width: 200,
                    padding:
                    const EdgeInsets.only(left: 10),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color:
                      Theme.of(context).cardColor,
                      borderRadius:
                      BorderRadius.circular(
                          Dimensions.radiusSmall),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 5),
                      ],
                    ),
                    child: Text(
                      'search'.tr,
                      style: robotoRegular.copyWith(
                        color:
                        Theme.of(context).hintColor,
                      ),
                    ),
                  ),
                ),
              ),

              /// ================= CURRENT LOCATION =================
              Positioned(
                bottom: widget.fromView ? 10 : 100,
                right: 10,
                child: InkWell(
                  onTap: () => _checkPermission(
                        () async {
                      Position pos =
                      await Geolocator
                          .getCurrentPosition();

                      final LatLng newPos = LatLng(
                        pos.latitude,
                        pos.longitude,
                      );

                      setState(() {
                        _markerPosition = newPos;
                        _cameraTarget = newPos;
                      });

                      _mapController.move(newPos, 10);

                      storeRegController.setLocation(
                        newPos,
                        forStoreRegistration: true,
                        zoneId: storeRegController
                            .zoneList![storeRegController
                            .selectedZoneIndex!]
                            .id,
                      );
                    },
                  ),
                  child: Container(
                    padding:
                    const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: Icon(
                      Icons.my_location_outlined,
                      color: Theme.of(context)
                          .primaryColor,
                    ),
                  ),
                ),
              ),

              /// ================= SET LOCATION BUTTON =================
              if (!widget.fromView)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: CustomButton(
                    buttonText: storeRegController
                        .inZone
                        ? 'set_location'.tr
                        : 'not_in_zone'.tr,
                    onPressed:
                    storeRegController.inZone
                        ? () {
                      storeRegController
                          .setLocation(
                        _markerPosition!,
                        forStoreRegistration:
                        true,
                        zoneId:
                        storeRegController
                            .zoneList![
                        storeRegController
                            .selectedZoneIndex!]
                            .id,
                      );
                      Get.back();
                    }
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// ========================= POLYGON =========================
  void _setPolygon(ZoneDataModel zoneModel) {
    final List<LatLng> points = [];

    zoneModel.formatedCoordinates?.forEach((c) {
      points.add(LatLng(c.lat!, c.lng!));
    });

    _polygons = [
      Polygon(
        points: points,
        color: Get.theme.colorScheme.primary
            .withOpacity(0.2),
        borderColor:
        Get.theme.colorScheme.primary,
        borderStrokeWidth: 2,
      ),
    ];

    setState(() {});
  }

  /// ========================= PERMISSION =========================
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