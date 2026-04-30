import 'package:get/get_connect/http/src/response/response.dart';
import 'package:latlong2/latlong.dart' as osm;

import 'package:sixam_mart/common/enums/data_source_enum.dart';
import 'package:sixam_mart/features/checkout/domain/models/place_order_body_model.dart';
import 'package:sixam_mart/features/parcel/domain/models/parcel_cancellation_reasons_model.dart';
import 'package:sixam_mart/features/parcel/domain/models/parcel_category_model.dart';
import 'package:sixam_mart/features/parcel/domain/models/video_content_model.dart';
import 'package:sixam_mart/features/parcel/domain/models/why_choose_model.dart';
import 'package:sixam_mart/features/payment/domain/models/offline_method_model.dart';

import '../models/parcel_instruction_model.dart';

abstract class ParcelServiceInterface {

  /// فئات الشحن
  Future<List<ParcelCategoryModel>?> getParcelCategory();

  /// تعليمات الشحن
  Future<List<Data>?> getParcelInstruction(int offset);

  /// لماذا تختارنا
  Future<WhyChooseModel?> getWhyChooseDetails({
    required DataSourceEnum source,
  });

  /// محتوى الفيديو
  Future<VideoContentModel?> getVideoContentDetails({
    required DataSourceEnum source,
  });

  /// 🔥 بديل Google Places
  /// يجلب الإحداثيات فقط باستخدام OSM / API داخلي
  Future<osm.LatLng> getPlaceDetails(String? placeID);

  /// طرق الدفع اليدوية
  Future<List<OfflineMethodModel>?> getOfflineMethodList();

  /// أكثر قيمة بقشيش
  Future<int> getDmTipMostTapped();

  /// تنفيذ الطلب
  Future<Response> placeOrder(PlaceOrderBodyModel orderBody);

  /// أسباب إلغاء الشحنة
  Future<ParcelCancellationReasonsModel?> getParcelCancellationReasons({
    required bool isBeforePickup,
  });
}
