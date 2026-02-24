import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import '../constant/ColorsConstant.dart';

class TwoMapRouteController extends GetxController {
  GoogleMapController? mapController;

  var markers = <Marker>{}.obs;
  var polylines = <Polyline>{}.obs;

  var distance = "".obs;
  var duration = "".obs;
  var isLoadingRoute = false.obs;

  LatLng? start;
  LatLng? end;

  Rx<LatLng> currentLocation = const LatLng(0, 0).obs;

  final String apiKey = "AIzaSyB4OsZKR2hF7xBBCJR8sM2b6xf17v5DWZs";

  @override
  void onInit() {
    super.onInit();
    getCurrentLocation();
  }

  Future<void> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Get.snackbar("Error", "Location services are disabled. Please enable them.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        Get.snackbar("Error", "Location permission denied");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      Get.snackbar("Error", "Location permission permanently denied. Please enable in settings.");
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    currentLocation.value = LatLng(position.latitude, position.longitude);
    start = currentLocation.value;
    _updateMarkers();

    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(currentLocation.value, 15),
    );
  }

  // Future<LatLng?> getLatLngFromAddress(String address) async {
  //   if (address.trim().isEmpty) return null;
  //
  //   try {
  //     List<Location> locations = await locationFromAddress(address.trim());
  //     if (locations.isNotEmpty) {
  //       return LatLng(locations.first.latitude, locations.first.longitude);
  //     }
  //   } catch (e) {
  //     print("Geocoding error: $e");
  //     Get.snackbar("Error", "Could not find location: $address");
  //   }
  //   return null;
  // }
  Future<LatLng?> getLatLngFromAddress(String address) async {
    if (address.trim().isEmpty) return null;

    try {
      /// ✅ If user selected "Your Location"
      if (address.trim().toLowerCase() == "your location") {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          Get.snackbar("Error", "Location services are disabled.");
          return null;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            Get.snackbar("Error", "Location permission denied.");
            return null;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          Get.snackbar("Error", "Location permission permanently denied.");
          return null;
        }

        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        return LatLng(position.latitude, position.longitude);
      }

      /// ✅ Otherwise convert address to LatLng
      List<Location> locations =
      await locationFromAddress(address.trim());

      if (locations.isNotEmpty) {
        return LatLng(
          locations.first.latitude,
          locations.first.longitude,
        );
      }
    } catch (e) {
      print("Geocoding error: $e");
      Get.snackbar("Error", "Could not find location: $address");
    }

    return null;
  }

  Future<void> setPoint(String address, bool isStart) async {
    LatLng? point = await getLatLngFromAddress(address);
    if (point == null) return;

    if (isStart) {

      start = point;
    } else {
      end = point;
    }

    _updateMarkers();

    if (start != null && end != null) {
      await _drawRoute();
      _zoomToFit();
    }
  }

  void _updateMarkers() {
    markers.clear();

    if (start != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("start"),
          position: start!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: "Start"),
        ),
      );
    }

    if (end != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("end"),
          position: end!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: "Destination"),
        ),
      );
    }
  }

  Future<void> _drawRoute() async {
    if (start == null || end == null || mapController == null) return;

    isLoadingRoute.value = true;

    final url =
        "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=${start!.latitude},${start!.longitude}"
        "&destination=${end!.latitude},${end!.longitude}"
        "&mode=driving"
        "&key=$apiKey";

    try {
      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body);

      if (data["routes"].isEmpty || data["status"] != "OK") {
        Get.snackbar("No Route", "No route found between these points");
        isLoadingRoute.value = false;
        return;
      }

      distance.value = data["routes"][0]["legs"][0]["distance"]["text"];
      duration.value = data["routes"][0]["legs"][0]["duration"]["text"];

      List<LatLng> routePoints = [];

      List steps = data["routes"][0]["legs"][0]["steps"];

      for (var step in steps) {
        String encoded = step["polyline"]["points"];

        List<PointLatLng> decoded = PolylinePoints().decodePolyline(encoded);

        for (var point in decoded) {
          routePoints.add(
            LatLng(point.latitude, point.longitude),
          );
        }
      }

      polylines.clear();

      polylines.add(
        Polyline(
          polylineId: const PolylineId("route"),
          color:AppColor.blue,
          width: 6,
          points: routePoints,
          geodesic: true,
        ),
      );

      // Optional: zoom after route is drawn (your original behavior)
      _zoomToFit();
    } catch (e) {
      print("Route error: $e");
      Get.snackbar("Error", "Failed to load route: $e");
    } finally {
      isLoadingRoute.value = false;
    }
  }

  String _formatDistance(int meters) {
    if (meters >= 1000) {
      return "${(meters / 1000).toStringAsFixed(1)} km";
    }
    return "$meters m";
  }

  String _formatDurationFromSeconds(int seconds) {
    if (seconds <= 0) return "—";

    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;

    final parts = <String>[];
    if (h > 0) parts.add("${h}h");
    if (m > 0) parts.add("${m}min");
    if (s > 0 && h == 0) parts.add("${s}s");

    return parts.join(" ");
  }

  void _zoomToFit() {
    if (mapController == null || start == null || end == null) return;

    final double south = math.min(start!.latitude, end!.latitude);
    final double west  = math.min(start!.longitude, end!.longitude);
    final double north = math.max(start!.latitude, end!.latitude);
    final double east  = math.max(start!.longitude, end!.longitude);

    final bounds = LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );

    mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  void clearRouteInfo() {
    start = null;
    end = null;
    markers.clear();
    polylines.clear();
    distance.value = "";
    duration.value = "";
  }

  @override
  void onClose() {
    mapController?.dispose();
    super.onClose();
  }
}