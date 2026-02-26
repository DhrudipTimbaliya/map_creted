import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CenterMarkerController extends GetxController {
  // ───────────────────────────────────────────────
  //  Core map & location state
  // ───────────────────────────────────────────────
  GoogleMapController? mapController;
  final Rx<LatLng> centerPosition = const LatLng(23.0225, 72.5714).obs; // Default: Ahmedabad, Gujarat

  // Displayed info
  final RxString currentAddress = "Fetching address...".obs;
  final RxString currentPincode = "—".obs;
  final RxBool isLoadingAddress = false.obs;

  // UI / loading states
  final RxBool isMapReady = false.obs;
  final RxBool hasLocationPermission = false.obs;

  @override
  void onInit() {
    super.onInit();
    _checkAndRequestLocationPermission();
  }

  Future<void> _checkAndRequestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Get.snackbar("Location Services", "Please enable location services");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        Get.snackbar("Permission Denied", "Location permission is required");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      Get.snackbar("Permission Denied Forever", "Please enable from settings");
      return;
    }

    hasLocationPermission.value = true;

    // Try to move to user's real location on first load
    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      centerPosition.value = LatLng(pos.latitude, pos.longitude);
      _moveCameraToCenterPosition(animate: false);
      _fetchAddressFromLatLng(centerPosition.value);
    } catch (e) {
      debugPrint("Couldn't get current position: $e");
      // Fallback → already set to default (Ahmedabad)
      _fetchAddressFromLatLng(centerPosition.value);
    }
  }

  // ───────────────────────────────────────────────
  //  Called when map is created
  // ───────────────────────────────────────────────
  void onMapCreated(GoogleMapController controller) {
    mapController = controller;
    isMapReady.value = true;

    // Important: initial fetch after map is ready
    _fetchAddressFromLatLng(centerPosition.value);

    // Optional: slight delay to make sure map is fully rendered
    Future.delayed(const Duration(milliseconds: 400), () {
      _moveCameraToCenterPosition(animate: false);
    });
  }

  // ───────────────────────────────────────────────
  //  Main listener — called whenever camera moves
  // ───────────────────────────────────────────────
  void onCameraMove(CameraPosition position) {
    centerPosition.value = position.target;
    // We debounce / throttle real reverse geocoding in production
    // Here we do it live for simplicity (you can optimize later)
    _fetchAddressFromLatLng(position.target);
  }

  // ───────────────────────────────────────────────
  //  Reverse geocoding (LatLng → Address + Pincode)
  // ───────────────────────────────────────────────
  Future<void> _fetchAddressFromLatLng(LatLng latLng) async {
    isLoadingAddress.value = true;
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // Build nice address
        String address = [
          place.name,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((part) => part != null && part.isNotEmpty).join(", ");

        if (address.trim().isEmpty) {
          address = "Unknown location";
        }

        currentAddress.value = address;
        currentPincode.value = place.postalCode ?? "—";
      } else {
        currentAddress.value = "No address found";
        currentPincode.value = "—";
      }
    } catch (e) {
      debugPrint("Reverse geocoding error: $e");
      currentAddress.value = "Error fetching address";
      currentPincode.value = "—";
    } finally {
      isLoadingAddress.value = false;
    }
  }

  // ───────────────────────────────────────────────
  //  Keep visual marker in center by moving camera
  // ───────────────────────────────────────────────
  void _moveCameraToCenterPosition({bool animate = true}) {
    if (mapController == null) return;

    final update = CameraUpdate.newLatLng(centerPosition.value);

    if (animate) {
      mapController!.animateCamera(update);
    } else {
      mapController!.moveCamera(update);
    }
  }

  // Optional: user can tap "My Location" button
  Future<void> goToMyLocation() async {
    if (!hasLocationPermission.value) {
      await _checkAndRequestLocationPermission();
      return;
    }

    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      centerPosition.value = LatLng(pos.latitude, pos.longitude);
      _moveCameraToCenterPosition(animate: true);
      _fetchAddressFromLatLng(centerPosition.value);
    } catch (e) {
      Get.snackbar("Error", "Could not get current location");
    }
  }

  @override
  void onClose() {
    mapController?.dispose();
    super.onClose();
  }
}