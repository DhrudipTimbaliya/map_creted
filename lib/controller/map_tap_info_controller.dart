import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class MapTapInfoController extends GetxController {
  GoogleMapController? mapController;

  // Reactive state for bottom sheet
  final RxBool showBottomSheet = false.obs;
  final Rx<LatLng?> tappedPosition = Rx<LatLng?>(null);
  final RxString address = "Fetching address...".obs;
  final RxString placeName = "".obs;

  // Call this when map is tapped
  Future<void> onMapTapped(LatLng position) async {
    tappedPosition.value = position;
    showBottomSheet.value = true;

    // Reset previous data
    address.value = "Fetching address...";
    placeName.value = "";

    try {
      // Reverse geocoding
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks[0];

        // Build nice address
        final parts = <String>[];
        if (placemark.name?.isNotEmpty ?? false) parts.add(placemark.name!);
        if (placemark.subLocality?.isNotEmpty ?? false) parts.add(placemark.subLocality!);
        if (placemark.locality?.isNotEmpty ?? false) parts.add(placemark.locality!);
        if (placemark.administrativeArea?.isNotEmpty ?? false) parts.add(placemark.administrativeArea!);
        if (placemark.country?.isNotEmpty ?? false) parts.add(placemark.country!);

        address.value = parts.join(", ");
        placeName.value = placemark.name ?? placemark.subLocality ?? "Unknown place";
      } else {
        address.value = "No address found";
        placeName.value = "Unknown location";
      }
    } catch (e) {
      address.value = "Error fetching address";
      placeName.value = "Error";
      print("Reverse geocoding error: $e");
    }
  }

  void closeBottomSheet() {
    showBottomSheet.value = false;
    tappedPosition.value = null;
  }
}