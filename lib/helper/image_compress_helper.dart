import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

class ImageCompressHelper {
  static Future<File?> compressImage(File file) async {
    try {
      final dir = await getTemporaryDirectory();

      final targetPath =
          "${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${basename(file.path)}";

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70, // جودة 70% ممتازة ومتوازنة
        minWidth: 1080,
        minHeight: 1080,
      );

      if (result == null) return null;

      return File(result.path);
    } catch (e) {
      return null;
    }
  }
}