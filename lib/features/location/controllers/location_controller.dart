import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as osm;
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:location/location.dart';
import 'package:sixam_mart/common/widgets/no_internet_screen.dart';
import 'package:sixam_mart/features/cart/controllers/cart_controller.dart';
import 'package:sixam_mart/features/category/controllers/category_controller.dart';
import 'package:sixam_mart/features/location/screens/pick_map_screen.dart';
import 'package:sixam_mart/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';
import 'package:sixam_mart/features/store/controllers/store_controller.dart';
import 'package:sixam_mart/features/favourite/controllers/favourite_controller.dart';
import 'package:sixam_mart/common/models/module_model.dart';
import 'package:sixam_mart/features/location/domain/models/prediction_model.dart';
import 'package:sixam_mart/features/address/controllers/address_controller.dart';
import 'package:sixam_mart/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart/features/checkout/controllers/checkout_controller.dart';
import 'package:sixam_mart/features/home/screens/home_screen.dart';
import 'package:sixam_mart/features/location/domain/models/zone_response_model.dart';
import 'package:sixam_mart/features/address/domain/models/address_model.dart';
import 'package:sixam_mart/features/location/domain/services/location_service_interface.dart';
import 'package:sixam_mart/features/location/widgets/module_dialog_widget.dart';
import 'package:sixam_mart/features/rental_module/rental_cart_screen/controllers/taxi_cart_controller.dart';
import 'package:sixam_mart/helper/address_helper.dart';
import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';
import 'package:sixam_mart/common/widgets/custom_loader.dart';
import 'package:sixam_mart/common/widgets/custom_snackbar.dart';
import 'package:sixam_mart/helper/taxi_helper.dart';
import '../services/osm_reverse_geocoding_service.dart';


class LocationController extends GetxController implements GetxService {
  osm.LatLng? _lastReverseLatLng;
  bool hasValidSavedAddress() {

    final address = AddressHelper.getUserAddressFromSharedPref();

    if (address == null) return false;

    if (address.latitude == null || address.longitude == null) return false;

    if (address.latitude == '0' || address.longitude == '0') return false;

    if (address.zoneIds == null || address.zoneIds!.isEmpty) return false;

    return true;
  }

  /// تُستدعى من PickMapScreen عند تحريك الخريطة
  void setPickPositionFromMap(double lat, double lng, {bool notify = true}) {
    _pickPosition = Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 1,
      altitude: 1,
      heading: 1,
      speed: 1,
      speedAccuracy: 1,
      altitudeAccuracy: 1,
      headingAccuracy: 1,
    );

    if (notify) {
      update();
    }
  }

  final LocationServiceInterface locationServiceInterface;

  LocationController({required this.locationServiceInterface});

  Position _position = Position(longitude: 0, latitude: 0, timestamp: DateTime.now(), accuracy: 1, altitude: 1, heading: 1, speed: 1, speedAccuracy: 1, altitudeAccuracy: 1, headingAccuracy: 1);
  Position get position => _position;

  Position _pickPosition = Position(longitude: 0, latitude: 0, timestamp: DateTime.now(), accuracy: 1, altitude: 1, heading: 1, speed: 1, speedAccuracy: 1, altitudeAccuracy: 1, headingAccuracy: 1);
  Position get pickPosition => _pickPosition;

  bool _loading = false;
  bool get loading => _loading;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _address = '';
  String? get address => _address;

  String? _pickAddress = '';
  String? get pickAddress => _pickAddress;

  bool _inZone = false;
  bool get inZone => _inZone;

  int _zoneID = 0;
  int get zoneID => _zoneID;

  bool _buttonDisabled = true;
  bool get buttonDisabled => _buttonDisabled;

  bool _showLocationSuggestion = true;
  bool get showLocationSuggestion => _showLocationSuggestion;

  bool _updateAddAddressData = true;
  bool _changeAddress = true;

  int _addressTypeIndex = 0;
  int get addressTypeIndex => _addressTypeIndex;

  final List<String?> _addressTypeList = ['home', 'office', 'others'];
  List<String?> get addressTypeList => _addressTypeList;



  final List<PredictionModel> _predictionList = [];
  List<PredictionModel> get predictionList => _predictionList;

  void showSuggestedLocation(bool status){
    _showLocationSuggestion = status;
  }

  void setAddressTypeIndex(int index, {bool isUpdate = true}) {
    _addressTypeIndex = index;
    if(isUpdate) {
      update();
    }
  }

  void disableButton() {
    _buttonDisabled = true;
    _inZone = true;
    update();
  }

  void setAddAddressData() {
    _position = _pickPosition;
    _address = _pickAddress;
    _updateAddAddressData = false;
    update();
  }

  void setUpdateAddress(AddressModel address){
    _position = Position(
      latitude: double.parse(address.latitude!), longitude: double.parse(address.longitude!), timestamp: DateTime.now(),
      altitude: 1, heading: 1, speed: 1, speedAccuracy: 1, floor: 1, accuracy: 1, altitudeAccuracy: 1, headingAccuracy: 1,
    );
    _address = address.address;
    _addressTypeIndex = _addressTypeList.indexOf(address.addressType);
  }

  void setPickData() {
    _pickPosition = _position;
    _pickAddress = _address;
  }


  Future<AddressModel> getCurrentLocation(
      bool fromAddress, {
        osm.LatLng? defaultLatLng,
        bool notify = true,
        GoogleMapController? mapController, // فقط للتوافق
      }) async {

    if (notify) {
      update();
    }

    // 1️⃣ جلب الموقع (GPS فقط)
    Position myPosition = await locationServiceInterface.getPosition(
      defaultLatLng,
      osm.LatLng(
        double.parse(
            Get.find<SplashController>().configModel!.defaultLocation!.lat ?? '0'),
        double.parse(
            Get.find<SplashController>().configModel!.defaultLocation!.lng ?? '0'),
      ),
    );

    // حفظ الموقع حسب السياق
    fromAddress ? _position = myPosition : _pickPosition = myPosition;

// ⚡ اعرض شيء فوري بدل الانتظار
    fromAddress
        ? _address = "موقعي الحالي"
        : _pickAddress = "موقعي الحالي";

    update();

// 🔄 تحميل العنوان بالخلفية (بدون await)
    OsmReverseGeocodingService.getAddressFromLatLng(
      latitude: myPosition.latitude,
      longitude: myPosition.longitude,
    ).then((addressFromOSM) {

      final String finalAddress = addressFromOSM.isNotEmpty
          ? addressFromOSM
          : "موقعك الحالي";

      fromAddress ? _address = finalAddress : _pickAddress = finalAddress;

      update();
    });

// 🔄 تحميل الزون بالخلفية (بدون انتظار)
    getZone(
      myPosition.latitude.toString(),
      myPosition.longitude.toString(),
      true,
    );

// 🚀 رجّع النتيجة فورًا بدون انتظار
    AddressModel addressModel = AddressModel(
      latitude: myPosition.latitude.toString(),
      longitude: myPosition.longitude.toString(),
      addressType: 'others',
      address: "موقعي الحالي",
      zoneId: 0,
      zoneIds: [],
    );

    _loading = false;
    update();

    return addressModel;
  }



  Future<void> getAddressFromGeocode(osm.LatLng latLng) async {

    // ✅ منع التكرار إذا لم يتغير الموقع
    if (_lastReverseLatLng != null &&
        _lastReverseLatLng!.latitude == latLng.latitude &&
        _lastReverseLatLng!.longitude == latLng.longitude) {
      return;
    }

    _lastReverseLatLng = latLng;

    try {
      _loading = true;
      _buttonDisabled = true;
      update();

      final String address =
      await locationServiceInterface.getAddressFromGeocode(latLng);

      _pickAddress = address;

      if (address.isNotEmpty) {
        _buttonDisabled = false;
      }

      _loading = false;
      update();
    } catch (e) {
      _loading = false;
      _pickAddress = '';
      _buttonDisabled = true;
      update();
    }
  }



  Future<ZoneResponseModel> getZone(
      String? lat,
      String? lng,
      bool markerLoad, {
        bool updateInAddress = false,
        bool handleError = false,
      }) async {

    if (markerLoad) {
      _loading = true;
    } else {
      _isLoading = true;
    }

    if (!updateInAddress) {
      update();
    }

    ZoneResponseModel responseModel =
    await locationServiceInterface.getZone(lat, lng, handleError: handleError);

    // ✅ لا نغير حالة الزون إلا إذا نجح الطلب فعلاً
    if (responseModel.isSuccess && responseModel.zoneIds.isNotEmpty) {
      _inZone = true;
      _zoneID = responseModel.zoneIds.first;
    }
    // ❌ إذا فشل — لا نغير _inZone ولا _zoneID
    // نحافظ على الزون السابقة لمنع ظهور "الخدمة غير متوفرة"

    if (updateInAddress && responseModel.isSuccess) {
      final address = AddressHelper.getUserAddressFromSharedPref();
      if (address != null) {
        address.zoneData = responseModel.zoneData;
        AddressHelper.saveUserAddressInSharedPref(address);
      }
    }

    if (markerLoad) {
      _loading = false;
    } else {
      _isLoading = false;
    }

    update();
    return responseModel;
  }

  Future<void> syncZoneData() async {
    bool hasInternet = await checkInternet();
    if (!hasInternet) {
      return;
    }

    final AddressModel? cachedAddress =
    AddressHelper.getUserAddressFromSharedPref();

    if (cachedAddress == null ||
        cachedAddress.latitude == null ||
        cachedAddress.longitude == null) {
      return;
    }

    ZoneResponseModel response = await getZone(
      cachedAddress.latitude,
      cachedAddress.longitude,
      false,
      updateInAddress: false,
    );

    // ✅ فقط لو السيرفر أعطى Zone صحيحة
    if (response.isSuccess && response.zoneIds.isNotEmpty) {
      cachedAddress.zoneId = response.zoneIds.first;
      cachedAddress.zoneIds = response.zoneIds;
      cachedAddress.zoneData = response.zoneData;
      cachedAddress.areaIds = response.areaIds;

      await AddressHelper.saveUserAddressInSharedPref(cachedAddress);
    } else {
      // ❗ لا تمسح البيانات القديمة
      debugPrint(
          'Zone sync failed — keeping cached zone data to avoid data loss');
    }

    update();
  }




  void saveAddressAndNavigate(AddressModel? address, bool fromSignUp, String? route, bool canRoute, bool isDesktop) {
    _prepareZoneData(address!, fromSignUp, route, canRoute, isDesktop);
  }

  void _prepareZoneData(AddressModel address, bool fromSignUp, String? route, bool canRoute, bool isDesktop) async {

    bool hasInternet = await checkInternet();
    if (!hasInternet) {
      return;
    }

    getZone(address.latitude, address.longitude, false).then((response) async {
      if (response.isSuccess) {
        Get.find<CartController>().getCartDataOnline();
        address.zoneId =
        response.zoneIds.isNotEmpty ? response.zoneIds.first : 0;

        address.zoneIds = [];
        address.zoneIds!.addAll(response.zoneIds);
        address.zoneData = [];
        address.zoneData!.addAll(response.zoneData);
        address.areaIds = [];
        address.areaIds!.addAll(response.areaIds);
        autoNavigate(address, fromSignUp, route, canRoute, isDesktop);
      } else {
        if (response.statusCode == 404) {
          Get.toNamed(RouteHelper.getPickMapRoute(route, false));
        } else {
          Get.back();
          showCustomSnackBar(response.message);
          if(route == 'splash') {
            Get.toNamed(RouteHelper.getPickMapRoute(route, false));
          }
        }
      }
    });
  }

  void autoNavigate(AddressModel? address, bool fromSignUp, String? route, bool canRoute, bool isDesktop) async {
    if (isDesktop && Get.find<SplashController>().module == null/* && Get.find<SplashController>().configModel!.module == null*/) {
      List<int>? zoneIds = address!.zoneIds;
      Map<String, String> header = locationServiceInterface.prepareHeader(zoneIds);
      await Get.find<SplashController>().getModules(headers: header);
      if (Get.isDialogOpen!) {
        Get.back();
      }
      Get.dialog(ModuleDialogWidget(callback: () {
        _saveDataAndFirebaseConfig(address, fromSignUp, route, canRoute, isDesktop);
      }), barrierDismissible: false, barrierColor: Colors.black.withValues(alpha: 0.7));
    } else {
      _saveDataAndFirebaseConfig(address!, fromSignUp, route, canRoute, isDesktop);
    }
  }

  void _saveDataAndFirebaseConfig(AddressModel address, bool fromSignUp, String? route, bool canRoute, bool isDesktop) async {
    locationServiceInterface.configureFirebaseMessaging(address);

    await _handleTaxiModuleCart(address);

    await AddressHelper.saveUserAddressInSharedPref(address);
    if(AuthHelper.isLoggedIn()) {
      if(Get.find<SplashController>().module != null) {
        await Get.find<FavouriteController>().getFavouriteList();
      } else {
        Get.find<SplashController>().getConfigData();
      }
      Get.find<AuthController>().updateZone();
    }
    HomeScreen.loadData(true);
    Get.find<CheckoutController>().clearPrevData();

    if(ResponsiveHelper.isDesktop(Get.context) && AuthHelper.isLoggedIn() && Get.find<SplashController>().module != null) {
      if(Get.find<ProfileController>().userInfoModel == null) {
        Get.dialog(const CustomLoaderWidget(), barrierDismissible: false);
        await Get.find<ProfileController>().getUserInfo();
        Get.back();
      }
      if(!Get.find<ProfileController>().userInfoModel!.selectedModuleForInterest!.contains(Get.find<SplashController>().module!.id)
          && (Get.find<SplashController>().module!.moduleType == 'food' || Get.find<SplashController>().module!.moduleType == 'grocery' || Get.find<SplashController>().module!.moduleType == 'ecommerce')
      ) {
        await Get.find<CategoryController>().getCategoryList(true, allCategory: false).then((_) async {
          if(Get.find<CategoryController>().categoryList != null && Get.find<CategoryController>().categoryList!.isNotEmpty){
            await Get.toNamed(RouteHelper.getInterestRoute());
          }else{
            Get.offAllNamed(RouteHelper.getInitialRoute());
          }
        });
      } else {
        locationServiceInterface.handleRoute(fromSignUp, route, canRoute);
      }
    } else {
      locationServiceInterface.handleRoute(fromSignUp, route, canRoute);
    }
  }

  Future<void> _handleTaxiModuleCart(AddressModel address) async{
    if(TaxiHelper.haveTaxiModule() && address.zoneIds != null && Get.find<TaxiCartController>().cartList.isNotEmpty) {
      List<int>? providerZones = Get.find<TaxiCartController>().cartList[0].provider!.pickupZoneId??[];

      if(!_hasIntersection(providerZones, address.zoneIds!)) {
        showCustomSnackBar('your_cart_has_been_cleared_as_the_selected_zone_does_not_support_the_previous_pickup_point'.tr, showDuration: 10);
        Get.find<TaxiCartController>().clearTaxiCart();
      }
    }
  }

  bool _hasIntersection(List<int> list1, List<int> list2) {
    return list1.toSet().intersection(list2.toSet()).isNotEmpty;
  }

  Future<AddressModel> setLocation(
      String? placeID,
      String? address, param2,
      ) async {

    _loading = true;
    update();

    osm.LatLng latLng = await locationServiceInterface.getLatLng(placeID);

    _pickPosition = Position(
      latitude: latLng.latitude, longitude: latLng.longitude,
      timestamp: DateTime.now(), accuracy: 1, altitude: 1, heading: 1, speed: 1, speedAccuracy: 1, altitudeAccuracy: 1, headingAccuracy: 1,
    );

    _pickAddress = address;
    _changeAddress = false;


    _loading = false;
    update();
    return AddressModel(
      latitude: _pickPosition.latitude.toString(), longitude: _pickPosition.longitude.toString(),
      addressType: 'others', address: _pickAddress,
    );
  }

  Timer? _debounce;
  Future<List<PredictionModel>> searchLocation(BuildContext context, String query) async {
    if (query.isEmpty) return [];

    _debounce?.cancel();
    final completer = Completer<List<PredictionModel>>();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final result = await locationServiceInterface.searchLocation(query);
        completer.complete(result);
      } catch (e) {
        completer.completeError(e);
      }
    });

    return completer.future;
  }

  void setPlaceMark(String address) {
    _address = address;
  }

  void checkPermission(Function onTap) async {
    locationServiceInterface.checkLocationPermission(onTap);
  }

  Future<bool> checkLocationActive() async {
    bool isActiveLocation = await Geolocator.isLocationServiceEnabled();

    if(isActiveLocation) {
      Position myPosition = await locationServiceInterface.getPosition(null,osm.LatLng(
        double.parse(Get.find<SplashController>().configModel!.defaultLocation!.lat ?? '0'),
        double.parse(Get.find<SplashController>().configModel!.defaultLocation!.lng ?? '0'),
      ));

      double distance = Geolocator.distanceBetween(
        double.parse(AddressHelper.getUserAddressFromSharedPref()!.latitude!), double.parse(AddressHelper.getUserAddressFromSharedPref()!.longitude!), myPosition.latitude, myPosition.longitude,
      ) / 1000;

      if (kDebugMode) {
        print('======== distance is : $distance');
      }
      if(distance > 1){
        return true;
      }else{
        return false;
      }
    }else{
      return false;
    }
  }

  Future<void> navigateToLocationScreen(String page, {bool offNamed = false, bool offAll = false}) async {
    bool fromSignup = page == RouteHelper.signUp;
    bool fromHome = page == 'home';
    final AddressModel? cachedAddress = AddressHelper.getUserAddressFromSharedPref();

    if (cachedAddress != null
        && cachedAddress.latitude != null
        && cachedAddress.longitude != null
        && cachedAddress.latitude != '0') {

      // ⚡ عرض الموقع فورًا
      _position = Position(
        latitude: double.parse(cachedAddress.latitude!),
        longitude: double.parse(cachedAddress.longitude!),
        timestamp: DateTime.now(),
        accuracy: 1,
        altitude: 1,
        heading: 1,
        speed: 1,
        speedAccuracy: 1,
        altitudeAccuracy: 1,
        headingAccuracy: 1,
      );

      _address = cachedAddress.address ?? "موقعك الحالي";

      update();

      // 🔄 تحديث بالخلفية بدون تعطيل
      getCurrentLocation(true);

    }

    if (!fromHome && hasValidSavedAddress()) {
      Get.dialog(const CustomLoaderWidget(), barrierDismissible: false);
      autoNavigate(
        AddressHelper.getUserAddressFromSharedPref(),
        fromSignup,
        null,
        false,
        ResponsiveHelper.isDesktop(Get.context),
      );
      return;
    }
    else if(AuthHelper.isLoggedIn()) {
      Get.dialog(const CustomLoaderWidget(), barrierDismissible: false);
      await Get.find<AddressController>().getAddressList();
      Get.back();
      locationServiceInterface.authorizeNavigation(
        page,
        Get.find<AddressController>().addressList,
        null,
        offNamed: offNamed,
        offAll: offAll,
      );

    }else {
      // locationServiceInterface.defaultNavigation(page, mapController);
      if(ResponsiveHelper.isDesktop(Get.context)) {
        showGeneralDialog(context: Get.context!, pageBuilder: (_,__,___) {
          return SizedBox(
            height: Get.context!.height * 0.75, width: 300,
            child: PickMapScreen(
              fromSignUp: (page == RouteHelper.signUp),
              canRoute: false,
              fromAddAddress: false,
              route: null,
            ),
          );
        });
      } else {
        _checkPermission(page);
      }
    }
  }

  void _checkPermission(String page) async {

    bool hasInternet = await checkInternet();
    if (!hasInternet) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if(permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if(permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      Get.toNamed(RouteHelper.getPickMapRoute(page, false));
    } else {
      if(page == 'home'){
        Get.toNamed(RouteHelper.getPickMapRoute(page, false));
      } else if (!hasValidSavedAddress() && await _locationCheck()) {
        Get.dialog(const CustomLoaderWidget(), barrierDismissible: false);
        await getCurrentLocation(false).then((value) {
          if (value.latitude != null && value.latitude != "0") {
            _onPickAddressButtonPressed(this, page);
          }
        });
      }
      else if (!hasValidSavedAddress()) {
        Get.toNamed(RouteHelper.getPickMapRoute(page, false));
      }

    }
  }

  Future<bool> _locationCheck() async {
    Location location = Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
    }
    return serviceEnabled;
  }

  void _onPickAddressButtonPressed(LocationController locationController, String page) {
    if(locationController.pickPosition.latitude != 0) {
      final safeAddress = locationController.pickAddress != null
          && locationController.pickAddress!.isNotEmpty
          ? locationController.pickAddress
          : "موقعك الحالي";
      AddressModel address = AddressModel(
        latitude: locationController.pickPosition.latitude.toString(),
        longitude: locationController.pickPosition.longitude.toString(),
        addressType: 'others', address: safeAddress,
      );
      locationController.saveAddressAndNavigate(address, false, page, false, ResponsiveHelper.isDesktop(Get.context));
    } else {
      showCustomSnackBar('pick_an_address'.tr);
    }
  }

  Future<void> setStoreAddressToUserAddress(osm.LatLng storeAddress) async {
    Position storePosition = Position(
      latitude: storeAddress.latitude, longitude: storeAddress.longitude,
      timestamp: DateTime.now(), accuracy: 1, altitude: 1, heading: 1, speed: 1, speedAccuracy: 1, altitudeAccuracy: 1, headingAccuracy: 1,
    );
     await getAddressFromGeocode(
      osm.LatLng(storeAddress.latitude, storeAddress.longitude),
    );

    final String? addressFromGeocode = _pickAddress;
    if (addressFromGeocode == null || addressFromGeocode.isEmpty) {
      return;
    }


    // لا توقف التطبيق
    _buttonDisabled = false;

// 🔄 شغل الزون بالخلفية
    getZone(
      storePosition.latitude.toString(),
      storePosition.longitude.toString(),
      true,
    ).then((responseModel) {
      // تحديث لاحق (اختياري)
      _buttonDisabled = !responseModel.isSuccess;
      update();
    });
    AddressModel addressModel = AddressModel(
      latitude: storePosition.latitude.toString(),
      longitude: storePosition.longitude.toString(),
      addressType: 'others',

      // مؤقتًا بدون زون
      zoneId: 0,
      zoneIds: [],

      address: addressFromGeocode,

      // هذه أيضًا فاضية مؤقتًا
      zoneData: [],
      areaIds: [],
    );
    await AddressHelper.saveUserAddressInSharedPref(addressModel);

    await Get.find<SplashController>().getModules();
    List<ModuleModel>? modules = Get.find<SplashController>().moduleList;
    if (Get.find<StoreController>().store == null) {
      return;
    }
    for(ModuleModel m in modules!){
      if(m.id == Get.find<StoreController>().store!.moduleId) {
        Get.find<SplashController>().setModule(m);
      }
    }

  }

  Future<bool> checkInternet() async {
    if(kIsWeb) {
      return true;
    }
    final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
    bool isConnected = connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile);
    if (!isConnected && !Platform.isIOS) {
      debugPrint('No internet — keeping current data');
      return false;
    }

    return true;
  }

}