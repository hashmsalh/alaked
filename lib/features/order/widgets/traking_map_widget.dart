import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:sixam_mart/features/order/domain/models/order_model.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/images.dart';

class TrackingMapWidget extends StatefulWidget {
  final OrderModel? track;
  const TrackingMapWidget({super.key, required this.track});

  @override
  State<TrackingMapWidget> createState() => _TrackingMapWidgetState();
}

class _TrackingMapWidgetState extends State<TrackingMapWidget> {

  final MapController _mapController = MapController();
  final List<Marker> _markers = [];
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (!_initialized && widget.track != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setMarkersFromOrder();
      });
      _initialized = true;
    }

    return Container(
      height: 200,
      width: ResponsiveHelper.isMobilePhone() ? width : 1070,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(Dimensions.paddingSizeExtraSmall),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
      ),
      child: widget.track?.deliveryMan != null
          ? ClipRRect(
        borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _getInitialCenter(),
            initialZoom: 12, // تم الرفع لرؤية تفاصيل الشوارع والمندوب فوراً
            minZoom: 3,
            maxZoom: 12,
          ),
          children: [
            /// 🌍 خريطة العالم الأساسية
            TileLayer(
              urlTemplate: 'https://tiles.gpsstorebx.com/data/world/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.gpsstore.bx',
              minZoom: 3,
              maxZoom: 10,
              maxNativeZoom: 10,
              keepBuffer: 1,
            ),

            /// 🌍 خريطة الشرق الأوسط (تفاصيل دقيقة)
            TileLayer(
              urlTemplate: 'https://tiles.gpsstorebx.com/data/middleeast/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.gpsstore.bx',
              minZoom: 8,
              maxZoom: 12,
              maxNativeZoom: 12, // استخدام أقصى دقة متوفرة للمندوب
              keepBuffer: 1,
            ),

            /// 📍 طبقة العلامات (Markers) لتمثيل العميل والمندوب
            MarkerLayer(markers: _markers),
          ],
        )
      )
          : Center(
        child: Text(
          'no_delivery_man_data_found'.tr,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  LatLng _getInitialCenter() {
    final address = widget.track!.deliveryAddress!;
    return LatLng(
      double.parse(address.latitude!),
      double.parse(address.longitude!),
    );
  }

  void _setMarkersFromOrder() {
    _markers.clear();

    final order = widget.track!;
    final store = order.store;
    final deliveryMan = order.deliveryMan;
    final deliveryAddress = order.deliveryAddress;

    if (deliveryAddress != null) {
      _markers.add(
        Marker(
          point: LatLng(
            double.parse(deliveryAddress.latitude!),
            double.parse(deliveryAddress.longitude!),
          ),
          width: 40,
          height: 40,
          child: Image.asset(
            order.orderType == 'take_away'
                ? Images.myLocationMarker
                : Images.userMarker,
          ),
        ),
      );
    }

    if (store != null) {
      _markers.add(
        Marker(
          point: LatLng(
            double.parse(store.latitude!),
            double.parse(store.longitude!),
          ),
          width: 50,
          height: 50,
          child: Image.asset(
            order.moduleType == 'food'
                ? Images.restaurantMarker
                : Images.markerStore,
          ),
        ),
      );
    }

    if (deliveryMan != null) {
      _markers.add(
        Marker(
          point: LatLng(
            double.parse(deliveryMan.lat ?? '0'),
            double.parse(deliveryMan.lng ?? '0'),
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
    final center = LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );

    final diff = (maxLat - minLat).abs() > (maxLng - minLng).abs()
        ? (maxLat - minLat).abs()
        : (maxLng - minLng).abs();
    double zoom = 10;

    if (diff > 1) {
      zoom = 8;
    } else if (diff > 0.5) {
      zoom = 10;
    } else if (diff > 0.1) {
      zoom = 11;
    }

// لا تسمح بتجاوز 12
    if (zoom > 12) zoom = 12;

    _mapController.move(center, zoom);
  }
}
