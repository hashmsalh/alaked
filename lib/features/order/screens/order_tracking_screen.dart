import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as osm;
import 'package:geolocator/geolocator.dart';

import 'package:sixam_mart/common/controllers/theme_controller.dart';
import 'package:sixam_mart/common/widgets/custom_snackbar.dart';
import 'package:sixam_mart/common/widgets/footer_view.dart';
import 'package:sixam_mart/common/widgets/custom_app_bar.dart';
import 'package:sixam_mart/common/widgets/menu_drawer.dart';

import 'package:sixam_mart/features/location/controllers/location_controller.dart';
import 'package:sixam_mart/features/location/widgets/permission_dialog_widget.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';

import 'package:sixam_mart/features/notification/domain/models/notification_body_model.dart';
import 'package:sixam_mart/features/address/domain/models/address_model.dart';
import 'package:sixam_mart/features/chat/domain/models/conversation_model.dart';

import 'package:sixam_mart/features/order/controllers/order_controller.dart';
import 'package:sixam_mart/features/order/domain/models/order_model.dart';
import 'package:sixam_mart/features/order/widgets/track_details_view_widget.dart';
import 'package:sixam_mart/features/order/widgets/tracking_stepper_widget.dart';

import 'package:sixam_mart/features/store/domain/models/store_model.dart';

import 'package:sixam_mart/helper/address_helper.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/pusher_helper.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';

import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/images.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String? orderID;
  final String? contactNumber;

  const OrderTrackingScreen({
    super.key,
    required this.orderID,
    this.contactNumber,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with WidgetsBindingObserver {

  /// 🗺️ flutter_map controller
  final MapController _mapController = MapController();

  /// 📍 Markers (Store / User / Delivery)
  final List<Marker> _markers = [];

  bool _isLoading = true;
  bool _mapInitialized = false;

  Timer? _timer;
  bool showChatPermission = true;
  bool isHovered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    PusherHelper.initializePusher();
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    PusherHelper().pusherDisconnectPusher();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTracking();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  /// ===============================
  /// 🔄 تحميل البيانات الأولية
  /// ===============================
  Future<void> _loadData() async {
    await Get.find<LocationController>().getCurrentLocation(
      true,
      notify: false,
      defaultLatLng: osm.LatLng(
        double.parse(AddressHelper.getUserAddressFromSharedPref()!.latitude!),
        double.parse(AddressHelper.getUserAddressFromSharedPref()!.longitude!),
      ),
    );

    await Get.find<OrderController>().trackOrder(
      widget.orderID,
      null,
      true,
      contactNumber: widget.contactNumber,
    );

    _startTracking();
  }

  /// ===============================
  /// 📡 بدء التتبع (Pusher أو Timer)
  /// ===============================
  void _startTracking() {
    final orderController = Get.find<OrderController>();
    final track = orderController.trackModel;

    if (track == null) return;

    final canTrack =
        track.orderStatus != 'delivered' &&
            track.orderStatus != 'failed' &&
            track.orderStatus != 'canceled';

    if (Get.find<SplashController>().configModel!.websocketEnabled! &&
        track.deliveryMan != null &&
        canTrack) {
      _trackWithPusher();
    } else {
      _trackWithTimer();
    }
  }

  void _trackWithPusher() {
    final orderController = Get.find<OrderController>();
    final track = orderController.trackModel;

    if (track?.deliveryMan == null) return;

    orderController.timerTrackOrder(
      widget.orderID.toString(),
      contactNumber: widget.contactNumber,
    );

    PusherHelper().pusherDriverStatus(
      deliverymanId: track!.deliveryMan!.id.toString(),
      onLocationReceived: (RecordLocationBodyModel dmLocation) {
        updateDeliverymanMarker(dmLocation);
      },
    );
  }

  void _trackWithTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;

      if (Get.currentRoute.contains(RouteHelper.orderTracking)) {
        Get.find<OrderController>().timerTrackOrder(
          widget.orderID.toString(),
          contactNumber: widget.contactNumber,
        );


      } else {
        _timer?.cancel();
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'order_tracking'.tr),
      endDrawer: const MenuDrawer(),
      endDrawerEnableOpenDragGesture: false,
      body: GetBuilder<OrderController>(
        builder: (orderController) {
          OrderModel? track = orderController.trackModel;

          if (track != null) {
            if (track.orderType != 'parcel') {
              if (track.store!.storeBusinessModel == 'commission') {
                showChatPermission = true;
              } else if (track.store!.storeSubscription != null &&
                  track.store!.storeBusinessModel == 'subscription') {
                showChatPermission =
                    track.store!.storeSubscription!.chat == 1;
              } else {
                showChatPermission = false;
              }
            } else {
              showChatPermission = AuthHelper.isLoggedIn();
            }
          }

          return track == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            physics: isHovered || !ResponsiveHelper.isDesktop(context)
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
            child: FooterView(
              child: Center(
                child: SizedBox(
                  width: Dimensions.webMaxWidth,
                  height: ResponsiveHelper.isDesktop(context)
                      ? 700
                      : MediaQuery.of(context).size.height * 0.85,
                  child: Stack(
                    children: [

                      /// 🗺️ MAP
                      MouseRegion(
                        onEnter: (_) => setState(() => isHovered = true),
                        onExit: (_) => setState(() => isHovered = false),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            Dimensions.radiusLarge,
                          ),
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _getInitialCenter(track),
                              initialZoom: 12, // 💡 التعديل: رفعه لـ 12 لفتح الخريطة على أدق تفاصيل الشوارع فوراً
                              minZoom: 3,
                              maxZoom: 12,
                              onMapReady: () {
                                if (!_mapInitialized) {
                                  _setMarkersFromOrder(track);
                                  _mapInitialized = true;
                                  _isLoading = false;
                                  setState(() {});
                                }
                              },
                            ),
                            children: [
                              /// 🌍 خريطة العالم (World)
                              TileLayer(
                                urlTemplate: 'https://tiles.gpsstorebx.com/data/world/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.gpsstore.bx',
                                minZoom: 3,
                                maxZoom: 10,
                                maxNativeZoom: 10,
                                keepBuffer: 1,
                              ),

                              /// 🌍 خريطة الشرق الأوسط (Middle East)
                              TileLayer(
                                urlTemplate: 'https://tiles.gpsstorebx.com/data/middleeast/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.gpsstore.bx',
                                minZoom: 8,
                                maxZoom: 12,
                                maxNativeZoom: 12,
                                keepBuffer: 1,
                              ),

                              MarkerLayer(markers: _markers),
                            ],
                          ),
                        ),
                      ),

                      /// ⏳ LOADER
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(),
                        ),

                      /// 🔄 TRACKING STEPPER
                      Positioned(
                        top: Dimensions.paddingSizeSmall,
                        left: Dimensions.paddingSizeSmall,
                        right: Dimensions.paddingSizeSmall,
                        child: TrackingStepperWidget(
                          status: track.orderStatus,
                          takeAway: track.orderType == 'take_away',
                        ),
                      ),

                      /// 📍 CURRENT LOCATION BUTTON
                      Positioned(
                        right: 15,
                        bottom: track.orderType != 'take_away' &&
                            track.deliveryMan == null
                            ? 150
                            : 220,
                        child: InkWell(
                          onTap: () => _checkPermission(() async {
                            AddressModel address =
                            await Get.find<LocationController>()
                                .getCurrentLocation(false);

                            _moveToCurrentLocation(address);
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(
                                Dimensions.paddingSizeSmall),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(50),
                              color: Colors.white,
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

                      /// 📦 ORDER DETAILS + CHAT
                      Positioned(
                        bottom: Dimensions.paddingSizeSmall,
                        left: Dimensions.paddingSizeSmall,
                        right: Dimensions.paddingSizeSmall,
                        child: TrackDetailsViewWidget(
                          status: track.orderStatus,
                          track: track,
                          showChatPermission: showChatPermission,
                          callback: () async {
                            bool takeAway =
                                track.orderType == 'take_away';
                            _timer?.cancel();

                            await Get.toNamed(
                              RouteHelper.getChatRoute(
                                notificationBody: takeAway
                                    ? NotificationBodyModel(
                                  restaurantId:
                                  track.store!.id,
                                  orderId: int.parse(
                                      widget.orderID!),
                                )
                                    : NotificationBodyModel(
                                  deliverymanId:
                                  track.deliveryMan!.id,
                                  orderId: int.parse(
                                      widget.orderID!),
                                ),
                                user: User(
                                  id: takeAway
                                      ? track.store!.id
                                      : track.deliveryMan!.id,
                                  fName: takeAway
                                      ? track.store!.name
                                      : track.deliveryMan!.fName,
                                  lName:
                                  takeAway ? '' : track.deliveryMan!.lName,
                                  imageFullUrl: takeAway
                                      ? track.store!.logoFullUrl
                                      : track.deliveryMan!.imageFullUrl,
                                ),
                              ),
                            );

                            _startTracking();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// ===============================
  /// 📍 المركز الابتدائي للخريطة
  /// ===============================
  osm.LatLng _getInitialCenter(OrderModel track) {
    final address = track.deliveryAddress!;
    return osm.LatLng(
      double.parse(address.latitude!),
      double.parse(address.longitude!),
    );
  }
  /// ===============================
  /// 📌 تجهيز الماركرات من بيانات الطلب
  /// ===============================
  void _setMarkersFromOrder(OrderModel track) {
    _markers.clear();

    final store = track.store;
    final deliveryMan = track.deliveryMan;
    final deliveryAddress = track.deliveryAddress;

    /// 📍 عنوان العميل
    if (deliveryAddress != null) {
      _markers.add(
        Marker(
          point: osm.LatLng(
            double.parse(deliveryAddress.latitude!),
            double.parse(deliveryAddress.longitude!),
          ),
          width: 40,
          height: 40,
          child: Image.asset(
            track.orderType == 'take_away'
                ? Images.myLocationMarker
                : Images.userMarker,
          ),
        ),
      );
    }

    /// 🏪 المتجر
    if (store != null) {
      _markers.add(
        Marker(
          point: osm.LatLng(
            double.parse(store.latitude!),
            double.parse(store.longitude!),
          ),
          width: 50,
          height: 50,
          child: Image.asset(
            track.moduleType == 'food'
                ? Images.restaurantMarker
                : Images.markerStore,
          ),
        ),
      );
    }

    /// 🛵 مندوب التوصيل
    if (deliveryMan != null &&
        deliveryMan.lat != null &&
        deliveryMan.lng != null) {
      _markers.add(
        Marker(
          point: osm.LatLng(
            double.parse(deliveryMan.lat!),
            double.parse(deliveryMan.lng!),
          ),
          width: 30,
          height: 30,
          child: Image.asset(Images.deliveryManMarker),
        ),
      );
    }

    _fitMarkersOnMap();
    setState(() {});
  }

  /// ===============================
  /// 🧭 تحريك الخريطة لتشمل كل النقاط
  /// ===============================
  void _fitMarkersOnMap() {
    if (_markers.isEmpty) return;

    double minLat = _markers.first.point.latitude;
    double maxLat = _markers.first.point.latitude;
    double minLng = _markers.first.point.longitude;
    double maxLng = _markers.first.point.longitude;

    for (final marker in _markers) {
      minLat = marker.point.latitude < minLat ? marker.point.latitude : minLat;
      maxLat = marker.point.latitude > maxLat ? marker.point.latitude : maxLat;
      minLng = marker.point.longitude < minLng ? marker.point.longitude : minLng;
      maxLng = marker.point.longitude > maxLng ? marker.point.longitude : maxLng;
    }

    final center = osm.LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );

    final diffLat = (maxLat - minLat).abs();
    final diffLng = (maxLng - minLng).abs();
    final maxDiff = diffLat > diffLng ? diffLat : diffLng;

    double zoom = 10;

    if (maxDiff > 1) {
      zoom = 8;
    } else if (maxDiff > 0.5) {
      zoom = 10;
    } else if (maxDiff > 0.1) {
      zoom = 11;
    }

    if (zoom > 12) zoom = 12;


    _mapController.move(center, zoom);
  }

  /// ===============================
  /// 🔄 تحديث موقع مندوب التوصيل (Pusher)
  /// ===============================
  Future<void> updateDeliverymanMarker(
      RecordLocationBodyModel dmLocation) async {
    if (dmLocation.latitude == null ||
        dmLocation.longitude == null ||
        dmLocation.latitude!.isEmpty ||
        dmLocation.longitude!.isEmpty) {
      return;
    }

    _markers.removeWhere((m) =>
    m.child is Image &&
        (m.child as Image).image ==
            const AssetImage(Images.deliveryManMarker));

    _markers.add(
      Marker(
        point: osm.LatLng(
          double.parse(dmLocation.latitude!),
          double.parse(dmLocation.longitude!),
        ),
        width: 30,
        height: 30,
        child: Image.asset(Images.deliveryManMarker),
      ),
    );

    _fitMarkersOnMap();
    setState(() {});
  }

  /// ===============================
  /// 📍 التحريك للموقع الحالي
  /// ===============================
  void _moveToCurrentLocation(AddressModel address) {
    final point = osm.LatLng(
      double.parse(address.latitude!),
      double.parse(address.longitude!),
    );

    _mapController.move(point, 10);
  }

  /// ===============================
  /// ▶️ بدء التتبع الدوري
  /// ===============================


  /// ===============================
  /// 🔐 التحقق من صلاحيات الموقع
  /// ===============================
  void _checkPermission(Function onTap) async {
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
}
