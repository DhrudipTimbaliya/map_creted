import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constant/ColorsConstant.dart';
import '../controller/Suggestion_controller.dart';
import '../controller/map_controller.dart';

class SerchLocation extends StatelessWidget {
  final TextEditingController controller;
  final Color? bgcolor;
  final Color? iconcolor;
  final Color? bordercolor;
  final Color? textcolor;
  final Color? hintcolor;
  final String? hinttext;
  final IconData? icon;
  final bool onSubmitted;
  final IconData? surffixIcon;
  final Color? surffixIconColor;
  final VoidCallback? surffixIcononTap;

  /// ✅ New callback parameter for onChanged
  final void Function(String)? onChanged;

  const SerchLocation({
    super.key,
    required this.controller,
    this.bgcolor,
    this.iconcolor,
    this.bordercolor,
    this.textcolor,
    this.hintcolor,
    this.icon,
    this.hinttext,
    this.onSubmitted = false,
    this.onChanged, // add the new parameter
    this.surffixIcon,
    this.surffixIconColor,
    this.surffixIcononTap,
  });

  @override
  Widget build(BuildContext context) {
    final SuggestionController suggestionController = Get.put(SuggestionController());
    final MapController mapController = Get.find<MapController>();
    return Column(
      children: [
        TextField(
          controller: controller,
          style: TextStyle(color: textcolor ?? AppColor.white),
          decoration: InputDecoration(
            hintText: hinttext ?? "Search Location",
            hintStyle: TextStyle(color: hintcolor ?? AppColor.white),
            filled: true,
            fillColor: bgcolor ?? AppColor.black,
            prefixIcon: Icon(icon ?? Icons.search, color: iconcolor ?? AppColor.white),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            suffixIcon: surffixIcon != null
                ? IconButton(
              onPressed: surffixIcononTap,
              icon: Icon(
                surffixIcon,
                color: surffixIconColor ?? AppColor.white,
              ),
            )
                : null,
          ),
          /// ✅ Use the passed callback instead of hardcoded onChanged
          onChanged: onChanged,

          onSubmitted: (value) {
            if (onSubmitted) {
              mapController.searchPlace(value);
            }
          },
        ),


      ],
    );
  }
}