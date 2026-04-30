import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:get/get.dart';
import 'package:sixam_mart/util/styles.dart';

class PriceConverter {

  /// 🔥 أهم دالة (تم تعديلها لدعم productCurrency)
  static String convertPrice(
      double? price, {
        double? discount,
        String? discountType,
        String? productCurrency, // 👈 الجديد
        bool forDM = false,
        bool isFoodVariation = false,
        String? formatedStringPrice,
        bool forTaxi = false,
        bool forMenuWallet = false,
      }) {

    if (price == null) return '';

    /// تطبيق الخصم
    if (discount != null && discountType != null) {
      if (discountType == 'amount' && !isFoodVariation) {
        price = price - discount;
      } else if (discountType == 'percent') {
        price = price - ((discount / 100) * price);
      }
    }

    /// اتجاه العملة
    bool isRightSide = Get.find<SplashController>()
        .configModel!
        .currencySymbolDirection == 'right';

    /// 🔥 تحديد العملة (الأهم)
    String currency = productCurrency ??
        Get.find<SplashController>().configModel!.currencySymbol!;

    /// حالات خاصة
    if (forMenuWallet) {
      return '${isRightSide ? '' : '$currency '}'
          '${intl.NumberFormat.compact().format(price)}'
          '${isRightSide ? ' $currency' : ''}';
    }

    if (forTaxi && price > 100000) {
      return '${isRightSide ? '' : '$currency '}'
          '${intl.NumberFormat.compact().format(price)}'
          '${isRightSide ? ' $currency' : ''}';
    }

    /// الشكل الأساسي
    return '${isRightSide ? '' : '$currency '}'
        '${formatedStringPrice ?? toFixed(price).toStringAsFixed(
      forDM
          ? 0
          : Get.find<SplashController>()
          .configModel!
          .digitAfterDecimalPoint!,
    ).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    )}'
        '${isRightSide ? ' $currency' : ''}';
  }

  /// 🔥 نفس التعديل للأنيميشن
  static Widget convertAnimationPrice(
      double? price, {
        double? discount,
        String? discountType,
        String? productCurrency, // 👈 الجديد
        bool forDM = false,
        TextStyle? textStyle,
      }) {

    if (price == null) return const SizedBox();

    if (discount != null && discountType != null) {
      if (discountType == 'amount') {
        price = price - discount;
      } else if (discountType == 'percent') {
        price = price - ((discount / 100) * price);
      }
    }

    bool isRightSide = Get.find<SplashController>()
        .configModel!
        .currencySymbolDirection == 'right';

    String currency = productCurrency ??
        Get.find<SplashController>().configModel!.currencySymbol!;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: AnimatedFlipCounter(
        duration: const Duration(milliseconds: 500),
        value: toFixed(price),
        textStyle: textStyle ?? robotoMedium,
        fractionDigits: forDM
            ? 0
            : Get.find<SplashController>()
            .configModel!
            .digitAfterDecimalPoint!,
        prefix: isRightSide ? '' : '$currency ',
        suffix: isRightSide ? ' $currency' : '',
      ),
    );
  }

  static double? convertWithDiscount(
      double? price, double? discount, String? discountType,
      {bool isFoodVariation = false}) {
    if (price == null) return null;

    if (discountType == 'amount' && !isFoodVariation) {
      price = price - discount!;
    } else if (discountType == 'percent') {
      price = price - ((discount! / 100) * price);
    }
    return price;
  }

  static double calculation(
      double amount, double? discount, String type, int quantity) {
    double calculatedAmount = 0;

    if (type == 'amount' || type == 'fixed') {
      calculatedAmount = discount! * quantity;
    } else if (type == 'percent') {
      calculatedAmount = (discount! / 100) * (amount * quantity);
    }

    return calculatedAmount;
  }

  static String percentageCalculation(
      String price, String discount, String discountType) {
    return '$discount${discountType == 'percent'
        ? '%'
        : Get.find<SplashController>().configModel!.currencySymbol} OFF';
  }

  static double toFixed(double val) {
    num mod = power(
        10,
        Get.find<SplashController>()
            .configModel!
            .digitAfterDecimalPoint!);
    return (((val * mod)
        .toPrecision(Get.find<SplashController>()
        .configModel!
        .digitAfterDecimalPoint!))
        .floor()
        .toDouble() /
        mod);
  }

  static int power(int x, int n) {
    int retval = 1;
    for (int i = 0; i < n; i++) {
      retval *= x;
    }
    return retval;
  }
}