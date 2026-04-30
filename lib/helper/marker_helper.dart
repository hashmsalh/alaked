import 'package:flutter/material.dart';

/// 🧭 MarkerHelper
/// بديل كامل لـ Google Maps MarkerHelper
/// يعمل مع flutter_map باستخدام Widgets
class MarkerHelper {

  /// 📍 ماركر صورة عادي
  static Widget asset({
    required String imagePath,
    double width = 40,
    double height = 40,
    BoxFit fit = BoxFit.contain,
  }) {
    return Image.asset(
      imagePath,
      width: width,
      height: height,
      fit: fit,
    );
  }

  /// 📍 ماركر دائري (مفيد لمندوب التوصيل)
  static Widget circular({
    required String imagePath,
    double size = 40,
    Color backgroundColor = Colors.white,
    EdgeInsets padding = const EdgeInsets.all(4),
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: Image.asset(
          imagePath,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  /// 📍 ماركر مع Label (اختياري)
  static Widget labeled({
    required String imagePath,
    required String label,
    double size = 40,
    TextStyle? textStyle,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          imagePath,
          width: size,
          height: size,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: textStyle ??
              const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}
