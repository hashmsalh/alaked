import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:get/get.dart';

import 'package:sixam_mart/features/location/controllers/location_controller.dart';
import 'package:sixam_mart/features/location/domain/models/prediction_model.dart';
import 'package:sixam_mart/features/parcel/controllers/parcel_controller.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/util/dimensions.dart';

class LocationSearchDialogWidget extends StatelessWidget {
  final bool? isPickedUp;
  final bool isFrom;

  const LocationSearchDialogWidget({
    super.key,
    this.isPickedUp,
    this.isFrom = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 500,
      margin: EdgeInsets.only(
        top: ResponsiveHelper.isDesktop(context) ? 180 : 0,
      ),
      padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
      alignment: Alignment.topCenter,
      child: Material(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
        ),
        child: SizedBox(
          width: ResponsiveHelper.isDesktop(context)
              ? 600
              : Dimensions.webMaxWidth,
          child: TypeAheadField<PredictionModel>(
            hideOnEmpty: true,

            /// 🔍 INPUT
            builder: (context, controller, focusNode) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                textInputAction: TextInputAction.search,
                textCapitalization: TextCapitalization.words,
                keyboardType: TextInputType.streetAddress,
                decoration: InputDecoration(
                  hintText: 'search_location'.tr,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                    const BorderSide(style: BorderStyle.none, width: 0),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                ),
              );
            },

            /// 🔍 SEARCH (OSM)
            suggestionsCallback: (pattern) async {
              return await Get.find<LocationController>()
                  .searchLocation(context, pattern);
            },

            /// 📍 ITEM
            itemBuilder: (context, PredictionModel suggestion) {
              return Padding(
                padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
                child: Row(
                  children: [
                    const Icon(Icons.location_on),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        suggestion.description ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },

            /// ✅ ON SELECT (FINAL – بدون أخطاء)
            onSelected: (PredictionModel suggestion) {
              if (isPickedUp == null) {
                /// 📍 LocationController
                Get.find<LocationController>().setLocation(
                  null, // ❗ لا placeId
                  suggestion.description,
                  true,
                );
              } else {
                /// 📦 ParcelController
                Get.find<ParcelController>().setLocationFromPlace(
                  null, // ❗ لا placeId
                  suggestion.description,
                  isPickedUp,
                );
              }

              Get.back();
            },

            errorBuilder: (_, __) => const SizedBox(),
          ),
        ),
      ),
    );
  }
}
