import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import '../model/route_step_model.dart';
import '../project_specific/direction_step_seet.dart';

class BicycleRouteController extends GetxController {
  // ---------------------------------------------------------------------------
  // 1. STATE VARIABLES
  // ---------------------------------------------------------------------------
  GoogleMapController? mapController;
  final String apiKey = "AIzaSyB4OsZKR2hF7xBBCJR8sM2b6xf17v5DWZs";

  final markers = <Marker>{}.obs;
  final polylines = <Polyline>{}.obs;

  final distance = "0 km".obs;
  final duration = "0 min".obs;
  final isLoadingRoute = false.obs;
  final isMapLoading = true.obs;

  final steps = <RouteStep>[].obs;
  final currentStepIndex = 0.obs;
  final routeInfoData = Rxn<RouteInfo>();

  // Specific to Bicycling
  final travelMode = "bicycling".obs;

  LatLng? start;
  LatLng? end;
  final currentLocation = const LatLng(0, 0).obs;

  @override
  void onInit() {
    super.onInit();
    _initializeBicycleController();
  }

  // ---------------------------------------------------------------------------
  // 2. INITIALIZATION
  // ---------------------------------------------------------------------------

  Future<void> _initializeBicycleController() async {
    isMapLoading.value = true;
    bool hasPermission = await _checkPermissions();
    if (hasPermission) {
      await _fetchInitialPosition();
    }
    isMapLoading.value = false;
  }

  Future<bool> _checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission != LocationPermission.deniedForever &&
        permission != LocationPermission.denied;
  }

  Future<void> _fetchInitialPosition() async {
    try {
      Position pos = await Geolocator.getCurrentPosition();
      currentLocation.value = LatLng(pos.latitude, pos.longitude);
      start = currentLocation.value;
      _updateMarkers();
    } catch (e) {
      debugPrint("Bicycle Mode Location Error: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // 3. ROUTE CALCULATION (BICYCLE OPTIMIZED)
  // ---------------------------------------------------------------------------

  Future<void> findBicycleRoute(String destinationAddress) async {
    if (start == null) return;

    LatLng? destination = await _geoCode(destinationAddress);
    if (destination != null) {
      end = destination;
      await calculateBicyclePath();
    }
  }

  Future<void> calculateBicyclePath() async {
    if (start == null || end == null) return;

    isLoadingRoute.value = true;
    steps.clear();

    // Google Directions API for 'bicycling'
    final String url = "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=${start!.latitude},${start!.longitude}"
        "&destination=${end!.latitude},${end!.longitude}"
        "&mode=bicycling"
        "&key=$apiKey";

    try {
      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body);

      if (data["status"] == "OK") {
        final leg = data["routes"][0]["legs"][0];

        distance.value = leg["distance"]["text"];
        duration.value = leg["duration"]["text"];

        // Parse Bicycle Steps
        final List rawSteps = leg["steps"];
        steps.assignAll(rawSteps.map((s) => RouteStep(
          instruction: _stripHtml(s['html_instructions']),
          distance: s['distance']['text'],
          duration: s['duration']['text'],
          maneuver: s['maneuver'] ?? 'bicycle',
        )).toList());

        routeInfoData.value = RouteInfo(
          totalDistance: distance.value,
          totalDuration: duration.value,
          steps: steps,
        );

        _drawPath(data["routes"][0]["overview_polyline"]["points"]);
        _zoomToRoute();
        _showBicycleSheet();
      }
    } catch (e) {
      _showError("Bicycle Routing Failed", "Could not calculate cycling path.");
    } finally {
      isLoadingRoute.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  // 4. UTILITIES & UI
  // ---------------------------------------------------------------------------

  void _drawPath(String encodedPoints) {
    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> decoded = polylinePoints.decodePolyline(encodedPoints);
    List<LatLng> points = decoded.map((p) => LatLng(p.latitude, p.longitude)).toList();

    polylines.value = {
      Polyline(
        polylineId: const PolylineId("bicycle_path"),
        color: Colors.green, // Using Green to signify eco-friendly/bicycle mode
        width: 5,
        points: points,
        jointType: JointType.round,
      )
    };
    _updateMarkers();
  }

  void _updateMarkers() {
    markers.clear();
    if (start != null) {
      markers.add(Marker(
        markerId: const MarkerId("bike_start"),
        position: start!,
        infoWindow: const InfoWindow(title: "Start Point"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }
    if (end != null) {
      markers.add(Marker(
        markerId: const MarkerId("bike_end"),
        position: end!,
        infoWindow: const InfoWindow(title: "Bicycle Destination"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }
  }

  void _zoomToRoute() {
    if (mapController == null || start == null || end == null) return;

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        math.min(start!.latitude, end!.latitude),
        math.min(start!.longitude, end!.longitude),
      ),
      northeast: LatLng(
        math.max(start!.latitude, end!.latitude),
        math.max(start!.longitude, end!.longitude),
      ),
    );
    mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _showBicycleSheet() {
    if (steps.isNotEmpty) {
      Get.bottomSheet(
        DirectionStepsBottomSheet(
          data: routeInfoData.value!,
          travelModedata: TravelModeData.bicycle, // Ensure your model supports this
        ),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );
    }
  }

  // --- Helpers ---
  Future<LatLng?> _geoCode(String address) async {
    try {
      List<Location> locs = await locationFromAddress(address);
      return LatLng(locs.first.latitude, locs.first.longitude);
    } catch (_) { return null; }
  }

  String _stripHtml(String html) => html.replaceAll(RegExp(r'<[^>]*>'), '');

  void _showError(String t, String m) => Get.snackbar(t, m, snackPosition: SnackPosition.BOTTOM);

  @override
  void onClose() {
    mapController?.dispose();
    super.onClose();
  }
}