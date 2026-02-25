import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

// Internal Project Imports
import '../constant/ColorsConstant.dart';
import '../model/route_step_model.dart';
import '../project_specific/direction_step_seet.dart';

class TwoMapRouteController extends GetxController {
  // ---------------------------------------------------------------------------
  // 1. STATE VARIABLES & CONFIGURATION
  // ---------------------------------------------------------------------------
  GoogleMapController? mapController;
  final String apiKey = "AIzaSyB4OsZKR2hF7xBBCJR8sM2b6xf17v5DWZs";

  // Map Drawing Observables
  final markers = <Marker>{}.obs;
  final polylines = <Polyline>{}.obs;

  // Route Info Observables
  final distance = "0 km".obs;
  final duration = "0 min".obs;
  final isLoadingRoute = false.obs;
  final isMapLoading = true.obs;
  final isTrafficEnabled = false.obs;

  // Step Logic & Navigation Observables
  final steps = <RouteStep>[].obs;
  final travelMode = "driving".obs;
  final currentStepIndex = 0.obs; // Tracks which step the user is looking at
  final routeInfoData = Rxn<RouteInfo>();

  // Coordinate State
  LatLng? start;
  LatLng? end;
  final List<LatLng> waypoints = <LatLng>[].obs; // Support for mid-stops
  final currentLocation = const LatLng(0, 0).obs;

  @override
  void onInit() {
    super.onInit();
    _initializeController();
  }

  // ---------------------------------------------------------------------------
  // 2. INITIALIZATION & PERMISSIONS
  // ---------------------------------------------------------------------------

  Future<void> _initializeController() async {
    isMapLoading.value = true;
    bool hasPermission = await _handleLocationPermission();
    if (hasPermission) {
      await getCurrentLocation();
    }
    isMapLoading.value = false;
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError("GPS Disabled", "Please enable location services.");
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError("Permission Denied", "Location permissions are required.");
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showError(
          "Permission Blocked", "Please enable permissions from settings.");
      return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // 3. CORE LOCATION FUNCTIONS
  // ---------------------------------------------------------------------------

  Future<void> getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      currentLocation.value = LatLng(position.latitude, position.longitude);
      start = currentLocation.value;
      _updateMarkers();

      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(currentLocation.value, 15),
      );
    } catch (e) {
      debugPrint("Error fetching location: $e");
    }
  }

  Future<LatLng?> getLatLngFromAddress(String address) async {
    if (address
        .trim()
        .isEmpty) return null;
    try {
      if (address.trim().toLowerCase() == "your location") {
        return currentLocation.value;
      }
      List<Location> locations = await locationFromAddress(address.trim());
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (e) {
      _showError("Search Error", "Could not find the address: $address");
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 4. ROUTE CALCULATION & ADVANCED STEP PARSING
  // ---------------------------------------------------------------------------

  Future<void> setPoint(String address, bool isStart) async {
    LatLng? point = await getLatLngFromAddress(address);
    if (point == null) return;

    if (isStart)
      start = point;
    else
      end = point;

    _updateMarkers();
    if (start != null && end != null) {
      await calculateAndDrawRoute();
    }
  }

  Future<void> calculateAndDrawRoute() async {
    if (start == null || end == null) return;

    isLoadingRoute.value = true;
    steps.clear();
    currentStepIndex.value = 0;

    // Advanced URL with Travel Mode and Waypoints logic
    String url = "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=${start!.latitude},${start!.longitude}"
        "&destination=${end!.latitude},${end!.longitude}"
        "&mode=${travelMode.value}"
        "&key=$apiKey";

    try {
      final response = await http.get(Uri.parse(url));
      final Map<String, dynamic> data = jsonDecode(response.body);

      if (data["status"] == "OK") {
        final route = data["routes"][0];
        final leg = route["legs"][0];

        distance.value = leg["distance"]["text"];
        duration.value = leg["duration"]["text"];

        // PARSE STEPS Logic
        final List rawSteps = leg["steps"];
        final List<RouteStep> parsedSteps = rawSteps.map((s) {
          return RouteStep(
            instruction: _stripHtml(s['html_instructions']),
            distance: s['distance']['text'],
            duration: s['duration']['text'],
            maneuver: s['maneuver'] ?? 'straight',
          );
        }).toList();

        steps.assignAll(parsedSteps);

        // Update the RouteInfo model for the BottomSheet
        routeInfoData.value = RouteInfo(
          totalDistance: distance.value,
          totalDuration: duration.value,
          steps: steps,
        );

        // POLYLINE DECODING
        List<LatLng> polylinePoints = _decodePolyline(
            route["overview_polyline"]["points"]);
        _drawPolylineOnMap(polylinePoints);

        _zoomToFit();
        _showStepsBottomSheet();
      } else {
        _showError("Route Error", "Status: ${data["status"]}");
      }
    } catch (e) {
      _showError("Connection Error", "Check your internet connectivity.");
    } finally {
      isLoadingRoute.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  // 5. STEP INTERACTION & NAVIGATION LOGIC (New Functions)
  // ---------------------------------------------------------------------------

  void nextStep() {
    if (currentStepIndex.value < steps.length - 1) {
      currentStepIndex.value++;
      focusOnStep(currentStepIndex.value);
    }
  }

  void previousStep() {
    if (currentStepIndex.value > 0) {
      currentStepIndex.value--;
      focusOnStep(currentStepIndex.value);
    }
  }

  /// Focuses the camera on a specific step's coordinate
  void focusOnStep(int index) {
    if (index >= 0 && index < steps.length) {
      // Note: In a real scenario, you'd extract the LatLng from the step data
      // For now, we use a mid-point calculation or step-start-location
      _showStepHighlight(index);
    }
  }

  void _showStepHighlight(int index) {
    // Logic to visually highlight the current segment of the polyline
    debugPrint("Navigating to step: ${steps[index].instruction}");
  }

  // ---------------------------------------------------------------------------
  // 6. HELPER & UTILITY METHODS
  // ---------------------------------------------------------------------------

  String _stripHtml(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ').trim();
  }

  List<LatLng> _decodePolyline(String encoded) {
    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> result = polylinePoints.decodePolyline(encoded);
    return result.map((p) => LatLng(p.latitude, p.longitude)).toList();
  }

  void _drawPolylineOnMap(List<LatLng> points) {
    polylines.value = {
      Polyline(
        polylineId: const PolylineId("main_route"),
        color: AppColor.blue,
        width: 6,
        points: points,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      )
    };
  }

  /// Logic to find the angle/bearing between two LatLng points
  double calculateBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * math.pi / 180.0;
    double lon1 = start.longitude * math.pi / 180.0;
    double lat2 = end.latitude * math.pi / 180.0;
    double lon2 = end.longitude * math.pi / 180.0;

    double dLon = lon2 - lon1;
    double y = math.sin(dLon) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    double radians = math.atan2(y, x);
    return (radians * 180.0 / math.pi + 360.0) % 360.0;
  }

  void _zoomToFit() {
    if (mapController == null || start == null || end == null) return;
    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(math.min(start!.latitude, end!.latitude),
          math.min(start!.longitude, end!.longitude)),
      northeast: LatLng(math.max(start!.latitude, end!.latitude),
          math.max(start!.longitude, end!.longitude)),
    );
    mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  void _updateMarkers() {
    markers.clear();
    if (start != null) {
      markers.add(Marker(markerId: const MarkerId("origin"), position: start!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed)));
    }
    if (end != null) {
      markers.add(
          Marker(markerId: const MarkerId("destination"), position: end!,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen)));
    }
  }

  // ---------------------------------------------------------------------------
  // 7. UI TRIGGERS
  // ---------------------------------------------------------------------------

  void _showStepsBottomSheet() {
    if (Get.isBottomSheetOpen ?? false) {
      Get.back();
    }
    if (steps.isNotEmpty && routeInfoData.value != null) {
      Get.bottomSheet(
        DirectionStepsBottomSheet(data: routeInfoData.value!,travelModedata: TravelModeData.car,),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        enableDrag: true,
        isDismissible: false,
        // Ensure we track state when it's closed manually by user
      ).then((_) {
        debugPrint("Direction Sheet Dismissed");
      });
    }

  }

  void _showError(String title, String msg) {
    Get.snackbar(title, msg, snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent, colorText: Colors.white, margin: const EdgeInsets.all(10));
  }

  void clearRoute() {
    start = null;
    end = null;
    markers.clear();
    polylines.clear();
    steps.clear();
    distance.value = "0 km";
    duration.value = "0 min";
    routeInfoData.value = null;
  }

  @override
  void onClose() {
    mapController?.dispose();
    super.onClose();
  }
}