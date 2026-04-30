import 'package:sixam_mart/features/favourite/controllers/favourite_controller.dart';
import 'package:sixam_mart/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/common/widgets/custom_snackbar.dart';
import 'package:get/get.dart';

class ApiChecker {
  static void checkApi(Response response, {bool getXSnackBar = false}) {

    // 🛑 حماية: تجاهل أخطاء الإنترنت أو الردود غير المكتملة
    if (response.statusCode == null || response.statusCode == 0 || response.statusCode == 1) {
      showCustomSnackBar(
        response.statusText ?? 'connection_to_api_server_failed'.tr,
        getXSnackBar: getXSnackBar,
      );
      return;
    }

    // 🔐 401 حقيقي (من السيرفر)
    if (response.statusCode == 401) {
      Get.find<AuthController>()
          .clearSharedData(removeToken: false)
          .then((value) {
        Get.find<FavouriteController>().removeFavourite();
        Get.offAllNamed(RouteHelper.getInitialRoute());
      });
      return;
    }

    // 🔔 باقي الأخطاء
    if (
    response.statusText != null &&
        response.statusText!.isNotEmpty &&
        response.statusText != 'The guest id field is required.'
    ) {
      showCustomSnackBar(response.statusText!, getXSnackBar: getXSnackBar);
    }
  }
}
