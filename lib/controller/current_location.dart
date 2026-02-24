import 'package:geolocator/geolocator.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';

import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'map_controller.dart';


class CurrentLocationController extends GetxController {
  GoogleMapController? mapController;
  final MapController findPLaceController = Get.put(MapController());
  /// Existing markers (already defined in your controller)


  /// Attach the GoogleMapController
  void setMapController(GoogleMapController controller) {
    mapController = controller;
  }

  /// Move camera to current location and update marker
  Future<void> goToCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Get.snackbar("Error", "Location services are disabled.");
        return;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) {
        Get.snackbar("Error", "Location permission permanently denied.");
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      LatLng currentLatLng = LatLng(position.latitude, position.longitude);

      // Move camera
      mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: currentLatLng,
            zoom: 16,
          ),
        ),
      );

      // Update marker
      findPLaceController.markers.removeWhere((m) => m.markerId.value == "current_location");
      findPLaceController.markers.add(
        Marker(
          markerId: const MarkerId("current_location"),
          position: currentLatLng,
          infoWindow: const InfoWindow(title: "My Current Location"),
        ),
      );
    } catch (e) {
      Get.snackbar("Error", "Failed to get current location");
      print("Current location error: $e");
    }
  }
}