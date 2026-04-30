import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:get/get.dart';

import 'package:sixam_mart/common/controllers/theme_controller.dart';
import 'package:sixam_mart/common/widgets/custom_app_bar.dart';
import 'package:sixam_mart/common/widgets/custom_button.dart';
import 'package:sixam_mart/common/widgets/custom_snackbar.dart';
import 'package:sixam_mart/common/widgets/custom_text_field.dart';
import 'package:sixam_mart/common/widgets/footer_view.dart';
import 'package:sixam_mart/common/widgets/menu_drawer.dart';

import 'package:sixam_mart/features/address/controllers/address_controller.dart';
import 'package:sixam_mart/features/address/domain/models/address_model.dart';
import 'package:sixam_mart/features/auth/controllers/auth_controller.dart';
import 'package:sixam_mart/features/language/controllers/language_controller.dart';
import 'package:sixam_mart/features/location/controllers/location_controller.dart';
import 'package:sixam_mart/features/location/screens/pick_map_screen.dart';
import 'package:sixam_mart/features/profile/controllers/profile_controller.dart';
import 'package:sixam_mart/features/splash/controllers/splash_controller.dart';

import 'package:sixam_mart/helper/auth_helper.dart';
import 'package:sixam_mart/helper/custom_validator.dart';
import 'package:sixam_mart/helper/responsive_helper.dart';
import 'package:sixam_mart/helper/route_helper.dart';

import 'package:sixam_mart/util/app_constants.dart';
import 'package:sixam_mart/util/dimensions.dart';
import 'package:sixam_mart/util/images.dart';
import 'package:sixam_mart/util/styles.dart';

class AddAddressScreen extends StatefulWidget {
  final bool fromCheckout;
  final bool fromRide;
  final AddressModel? address;
  final int? zoneId;
  final bool forGuest;
  final bool fromNavBar;

  const AddAddressScreen({
    super.key,
    required this.fromCheckout,
    required this.fromRide,
    this.address,
    this.zoneId,
    this.forGuest = false,
    this.fromNavBar = false,
  });

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {

  final TextEditingController _levelController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactPersonNameController = TextEditingController();
  final TextEditingController _contactPersonNumberController = TextEditingController();
  final TextEditingController _streetNumberController = TextEditingController();
  final TextEditingController _houseController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  final FocusNode _addressNode = FocusNode();
  final FocusNode _levelNode = FocusNode();
  final FocusNode _nameNode = FocusNode();
  final FocusNode _numberNode = FocusNode();
  final FocusNode _streetNode = FocusNode();
  final FocusNode _houseNode = FocusNode();
  final FocusNode _floorNode = FocusNode();
  final FocusNode _emailFocus = FocusNode();

  bool _otherSelect = false;

  String? _countryDialCode =
  Get.find<AuthController>().getUserCountryCode().isNotEmpty
      ? Get.find<AuthController>().getUserCountryCode()
      : CountryCode.fromCountryCode(
    Get.find<SplashController>().configModel!.country!,
  ).dialCode;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {

    final locationController = Get.find<LocationController>();
    locationController.setAddressTypeIndex(0, isUpdate: false);

    if (AuthHelper.isLoggedIn() &&
        Get.find<ProfileController>().userInfoModel == null) {
      Get.find<ProfileController>().getUserInfo();
    }

    if (widget.address != null) {
      splitPhoneNumber(widget.address!.contactPersonNumber!);
      _contactPersonNameController.text =
          widget.address!.contactPersonName ?? '';
      _emailController.text = widget.address!.email ?? '';
      _streetNumberController.text = widget.address!.streetNumber ?? '';
      _houseController.text = widget.address!.house ?? '';
      _floorController.text = widget.address!.floor ?? '';

      locationController.setUpdateAddress(widget.address!);

      if (widget.address!.addressType == 'home') {
        locationController.setAddressTypeIndex(0, isUpdate: false);
      } else if (widget.address!.addressType == 'office') {
        locationController.setAddressTypeIndex(1, isUpdate: false);
      } else {
        locationController.setAddressTypeIndex(2, isUpdate: false);
        _levelController.text = widget.address!.addressType ?? '';
        _otherSelect = true;
      }
    } else if (Get.find<ProfileController>().userInfoModel != null) {
      _contactPersonNameController.text =
      '${Get.find<ProfileController>().userInfoModel!.fName} '
          '${Get.find<ProfileController>().userInfoModel!.lName}';
      splitPhoneNumber(Get.find<ProfileController>().userInfoModel!.phone!);
    }
  }

  void splitPhoneNumber(String number) {
    try {
      final phoneNumber = PhoneNumber.parse(number);
      _countryDialCode = '+${phoneNumber.countryCode}';
      _contactPersonNumberController.text =
          phoneNumber.international.substring(_countryDialCode!.length);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const MenuDrawer(),
      appBar: CustomAppBar(
        title: widget.forGuest
            ? 'set_address'.tr
            : widget.address == null
            ? 'add_new_address'.tr
            : 'update_address'.tr,
      ),
      body: SafeArea(
        child: GetBuilder<LocationController>(
          builder: (locationController) {
            _addressController.text = locationController.address ?? '';

            return ResponsiveHelper.isDesktop(context)
                ? _desktopView(locationController)
                : _mobileView(locationController);
          },
        ),
      ),
    );
  }
  // ===================== UI =====================

  Widget _mapPickerBox() {
    return InkWell(
      onTap: () {
        Get.to(() => PickMapScreen(
          fromAddAddress: true,
          fromSignUp: false,
          canRoute: false,
          route: null,
        ));
      },
      child: Container(
        height: 250,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Dimensions.radiusSmall),
          border: Border.all(
            width: 2,
            color: Theme.of(context).primaryColor,
          ),
          color: Theme.of(context).cardColor,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.map,
                size: 48, color: Theme.of(context).primaryColor),
            Positioned(
              bottom: 12,
              child: Text(
                'يجب فتح الخريطه وضغط الايقونه'.tr,
                style: robotoRegular.copyWith(
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopView(LocationController locationController) {
    return SingleChildScrollView(
      child: FooterView(
        child: Center(
          child: SizedBox(
            width: Dimensions.webMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _mapPickerBox(),
                const SizedBox(height: Dimensions.paddingSizeLarge),
                _form(locationController),
                const SizedBox(height: Dimensions.paddingSizeLarge),
                _button(locationController),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileView(LocationController locationController) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _mapPickerBox(),
                const SizedBox(height: Dimensions.paddingSizeLarge),
                _form(locationController),
              ],
            ),
          ),
        ),
        _button(locationController),
      ],
    );
  }

  Widget _form(LocationController locationController) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// Address type
        Text('label_as'.tr, style: robotoRegular),
        const SizedBox(height: Dimensions.paddingSizeSmall),

        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: locationController.addressTypeList.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(
                    right: Dimensions.paddingSizeSmall),
                child: InkWell(
                  onTap: () {
                    _otherSelect = index == 2;
                    locationController.setAddressTypeIndex(index);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Dimensions.paddingSizeLarge,
                      vertical: Dimensions.paddingSizeSmall,
                    ),
                    decoration: BoxDecoration(
                      borderRadius:
                      BorderRadius.circular(Dimensions.radiusDefault),
                      color: locationController.addressTypeIndex == index
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).cardColor,
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 5,
                            spreadRadius: 1),
                      ],
                    ),
                    child: Text(
                      (locationController.addressTypeList[index] ?? '').tr,
                      style: robotoRegular.copyWith(
                        color: locationController.addressTypeIndex == index
                            ? Colors.white
                            : Theme.of(context).disabledColor,
                      ),
                    ),

                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: Dimensions.paddingSizeLarge),

        if (_otherSelect)
          CustomTextField(
            showTitle: true,
            titleText: '${'level_name'.tr} (${'optional'.tr})',
            controller: _levelController,
            focusNode: _levelNode,
          ),

        const SizedBox(height: Dimensions.paddingSizeLarge),

        CustomTextField(
          showTitle: true,
          titleText: 'delivery_address'.tr,
          controller: _addressController,
          focusNode: _addressNode,
          required: true,
          onChanged: (text) => locationController.setPlaceMark(text),
        ),

        const SizedBox(height: Dimensions.paddingSizeLarge),

        CustomTextField(
          showTitle: true,
          titleText: 'contact_person_name'.tr,
          controller: _contactPersonNameController,
          focusNode: _nameNode,
          required: true,
        ),

        const SizedBox(height: Dimensions.paddingSizeLarge),

        CustomTextField(
          showTitle: true,
          titleText: 'contact_person_number'.tr,
          controller: _contactPersonNumberController,
          focusNode: _numberNode,
          isPhone: true,
          required: true,
          onCountryChanged: (CountryCode countryCode) {
            _countryDialCode = countryCode.dialCode;
          },
          countryDialCode:
          _countryDialCode ??
              Get.find<LocalizationController>()
                  .locale
                  .countryCode,
        ),

        const SizedBox(height: Dimensions.paddingSizeLarge),

        CustomTextField(
          showTitle: true,
          titleText: '${'street_number'.tr} (${'optional'.tr})',
          controller: _streetNumberController,
          focusNode: _streetNode,
        ),

        const SizedBox(height: Dimensions.paddingSizeLarge),

        Row(
          children: [
            Expanded(
              child: CustomTextField(
                showTitle: true,
                titleText: '${'house'.tr} (${'optional'.tr})',
                controller: _houseController,
                focusNode: _houseNode,
              ),
            ),
            const SizedBox(width: Dimensions.paddingSizeSmall),
            Expanded(
              child: CustomTextField(
                showTitle: true,
                titleText: '${'floor'.tr} (${'optional'.tr})',
                controller: _floorController,
                focusNode: _floorNode,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _button(LocationController locationController) {
    return GetBuilder<AddressController>(
      builder: (addressController) {
        return Padding(
          padding: const EdgeInsets.all(Dimensions.paddingSizeSmall),
          child: CustomButton(
            isLoading: addressController.isLoading,
            buttonText: widget.forGuest
                ? 'done'.tr
                : widget.address == null
                ? 'save_location'.tr
                : 'update_address'.tr,
            onPressed: () => _onSave(locationController),
          ),
        );
      },
    );
  }

  // ===================== SAVE =====================

  void _onSave(LocationController locationController) async {

    final numberWithCountry =
        _countryDialCode! + _contactPersonNumberController.text;

    final phoneValid =
    await CustomValidator.isPhoneValid(numberWithCountry);

    if (!phoneValid.isValid) {
      showCustomSnackBar('invalid_phone_number'.tr);
      return;
    }

    final addressModel = _prepareAddressModel(
      locationController,
      phoneValid.phone,
    );

    if (addressModel == null) return;

    if (widget.address == null) {
      _addAddress(addressModel);
    } else {
      _updateAddress(addressModel);
    }
  }

  AddressModel? _prepareAddressModel(
      LocationController locationController, String phone) {

    String? addressType =
    locationController.addressTypeList[
    locationController.addressTypeIndex];

    if (locationController.addressTypeIndex == 2 &&
        _levelController.text.isNotEmpty) {
      addressType = _levelController.text.trim();
    }

    if (_addressController.text.isEmpty) {
      showCustomSnackBar('please_enter_the_delivery_address'.tr);
      return null;
    }

    if (_contactPersonNameController.text.isEmpty) {
      showCustomSnackBar('please_enter_the_contact_person_name'.tr);
      return null;
    }

    if (_contactPersonNumberController.text.isEmpty) {
      showCustomSnackBar('please_enter_the_phone_number'.tr);
      return null;
    }

    // 🔹 حل المشكلة: استخدام pickPosition إن وُجد
    // 🔹 أو الرجوع إلى position (الموقع الحالي)
    final position = locationController.pickPosition ??
        locationController.position;

    return AddressModel(
      id: widget.address?.id,
      addressType: addressType,
      address: _addressController.text,
      contactPersonName: _contactPersonNameController.text,
      contactPersonNumber: phone,
      latitude: position.latitude.toString(),
      longitude: position.longitude.toString(),
      zoneId: locationController.zoneID,
      streetNumber: _streetNumberController.text,
      house: _houseController.text,
      floor: _floorController.text,
    );
  }

  void _addAddress(AddressModel addressModel) {
    Get.find<AddressController>()
        .addAddress(addressModel, widget.fromCheckout, widget.zoneId)
        .then((response) {
      if (response.isSuccess) {
        widget.fromNavBar
            ? Get.back()
            : Get.offNamed(RouteHelper.getAddressRoute());
        showCustomSnackBar(response.message, isError: false);
      } else {
        showCustomSnackBar(response.message);
      }
    });
  }

  void _updateAddress(AddressModel addressModel) {
    Get.find<AddressController>()
        .updateAddress(addressModel, widget.address!.id)
        .then((response) {
      if (response.isSuccess) {
        Get.back();
        showCustomSnackBar(response.message, isError: false);
      } else {
        showCustomSnackBar(response.message);
      }
    });
  }
}
