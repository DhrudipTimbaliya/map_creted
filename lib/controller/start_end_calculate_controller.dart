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
import 'route_controller.dart/walk_controller.dart';
import 'route_controller.dart/bicycle_controller.dart';
import 'route_controller.dart/bus_controller.dart';
import 'route_controller.dart/train_controller.dart';
import '../api/vehicle_service.dart';

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
  final selectedMode = TravelModeData.car.obs;
  final currentStepIndex = 0.obs;
  final routeInfoData = Rxn<RouteInfo>();
  final isBottomSheetOpen = false.obs;

  // Coordinate State
  LatLng? start;
  LatLng? end;
  final List<LatLng> waypoints = <LatLng>[].obs;
  final currentLocation = const LatLng(0, 0).obs;

  // Address strings for non-car modes
  final startAddress = ''.obs;
  final endAddress = ''.obs;

  // Child controllers for non-car modes
  late final WalkRouteController _walkRouteController;
  late final BikeRouteController _bikeRouteController;
  late final BusRouteController _busRouteController;
  late final TrainRouteController _trainRouteController;

  // Caching
  final Map<TravelModeData, RouteInfo> _routeCache = {};
  final Map<TravelModeData, List<LatLng>> _polylineCache = {};

  // Navigation & vehicle state
  final isNavigationStarted = false.obs;
  final isLoadingVehicles = false.obs;
  final vehicles = <VehicleOption>[].obs;

  // Polyline quality tuning
  static const double _maxSegmentDistanceMeters = 120000.0;
  static const int _maxWaypointCount = 5;

  @override
  void onInit() {
    super.onInit();
    _initializeController();

    final converter = getLatLngFromAddress;
    _walkRouteController = Get.put(
      WalkRouteController(latLngFromAddress: converter, apiKey: apiKey),
    );
    _bikeRouteController = Get.put(
      BikeRouteController(latLngFromAddress: converter, apiKey: apiKey),
    );
    _busRouteController = Get.put(
      BusRouteController(latLngFromAddress: converter, apiKey: apiKey),
    );
    _trainRouteController = Get.put(
      TrainRouteController(latLngFromAddress: converter, apiKey: apiKey),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. INITIALIZATION & PERMISSIONS
  // ---------------------------------------------------------------------------

  Future<void> _initializeController() async {
    isMapLoading.value = true;
    final hasPermission = await _handleLocationPermission();
    if (hasPermission) {
      await getCurrentLocation();
    }
    isMapLoading.value = false;
  }

  Future<bool> _handleLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError("GPS Disabled", "Please enable location services.");
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError("Permission Denied", "Location permissions are required.");
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showError("Permission Blocked", "Please enable permissions from settings.");
      return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // 3. CORE LOCATION FUNCTIONS
  // ---------------------------------------------------------------------------

  Future<void> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      currentLocation.value = LatLng(position.latitude, position.longitude);
      start = currentLocation.value;
      _updateMarkers();

      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(currentLocation.value, 15),
      );
    } catch (e) {
      debugPrint("Error fetching current location: $e");
      _showError("Location Error", "Could not get current position.");
    }
  }

  Future<LatLng?> getLatLngFromAddress(String address) async {
    if (address.trim().isEmpty) return null;

    try {
      final trimmed = address.trim().toLowerCase();
      if (trimmed == "your location") {
        if (currentLocation.value.latitude != 0) return currentLocation.value;
        await getCurrentLocation();
        return currentLocation.value;
      }

      final locations = await locationFromAddress(address.trim());
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (e) {
      debugPrint("Geocoding error for '$address': $e");
      _showError("Address Not Found", "Could not locate: $address");
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 4. ROUTE CALCULATION & DRAWING
  // ---------------------------------------------------------------------------

  Future<void> setPoint(String address, bool isStart) async {
    final point = await getLatLngFromAddress(address);
    if (point == null) return;

    if (isStart) {
      start = point;
      startAddress.value = address;
    } else {
      end = point;
      endAddress.value = address;
    }

    _updateMarkers();

    if (start != null && end != null) {
      await _updateRouteByMode();
      showStepsBottomSheet();
    }
  }

  Future<void> changeTravelMode(TravelModeData mode) async {
    if (selectedMode.value == mode) return;
    if (isLoadingRoute.value) return;

    selectedMode.value = mode;

    if (mode == TravelModeData.car) {
      travelMode.value = "driving";
    }

    if (start != null && end != null) {
      await _updateRouteByMode();
    }
  }

  Future<void> calculateAndDrawRoute() async {
    if (start == null || end == null) return;

    isLoadingRoute.value = true;
    steps.clear();
    currentStepIndex.value = 0;

    try {
      final url = _buildDirectionsUrl(
        origin: start!,
        destination: end!,
        mode: travelMode.value,
        alternatives: false,
      );

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        _showError("Network Error", "HTTP ${response.statusCode}");
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      if (data == null || data['status'] != 'OK') {
        _showError("Route Error", data?['status'] ?? 'Unknown API response');
        return;
      }

      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        _showError("No Route", "No routes found");
        return;
      }

      final route = routes[0] as Map<String, dynamic>;

      final legs = route['legs'] as List?;
      if (legs == null || legs.isEmpty) {
        _showError("Invalid Route", "No legs in route");
        return;
      }

      final leg = legs[0] as Map<String, dynamic>;

      distance.value = (leg['distance'] as Map?)?['text'] as String? ?? 'Unknown';
      duration.value = (leg['duration'] as Map?)?['text'] as String? ?? 'Unknown';

      final rawSteps = leg['steps'] as List?;
      final parsedSteps = (rawSteps ?? []).map((dynamic s) {
        final step = s as Map<String, dynamic>;
        return RouteStep(
          instruction: _stripHtml(step['html_instructions'] as String? ?? ''),
          distance: (step['distance'] as Map?)?['text'] as String? ?? '',
          duration: (step['duration'] as Map?)?['text'] as String? ?? '',
          maneuver: step['maneuver'] as String? ?? 'straight',
        );
      }).toList();

      steps.assignAll(parsedSteps);

      routeInfoData.value = RouteInfo(
        totalDistance: distance.value,
        totalDuration: duration.value,
        steps: steps,
      );

      final encoded = (route['overview_polyline'] as Map?)?['points'] as String?;
      if (encoded == null || encoded.isEmpty) {
        debugPrint("No polyline points returned");
        return;
      }

      var polylinePoints = _decodePolyline(encoded);

      if (polylinePoints.length < 50 && _estimateDistance(start!, end!) > 200000) {
        final improved = await _getImprovedPolylineForLongRoute(
          start!,
          end!,
          travelMode.value,
        );
        if (improved != null && improved.isNotEmpty) {
          polylinePoints = improved;
        }
      }

      _drawPolylineOnMap(polylinePoints);
      _zoomToFit();
    } catch (e, stack) {
      debugPrint("calculateAndDrawRoute failed: $e\n$stack");
      _showError("Error", "Failed to load route");
    } finally {
      isLoadingRoute.value = false;
    }
  }

  Future<void> _updateRouteByMode() async {
    if (selectedMode.value == TravelModeData.car) {
      await calculateAndDrawRoute();
      return;
    }

    if (startAddress.isEmpty || endAddress.isEmpty) return;

    isLoadingRoute.value = true;
    steps.clear();
    currentStepIndex.value = 0;

    try {
      if (_routeCache.containsKey(selectedMode.value)) {
        final cached = _routeCache[selectedMode.value]!;
        distance.value = cached.totalDistance;
        duration.value = cached.totalDuration;
        steps.assignAll(cached.steps);
        routeInfoData.value = cached;

        final cachedPolyline = _polylineCache[selectedMode.value];
        if (cachedPolyline != null) {
          _drawPolylineOnMap(cachedPolyline);
          _zoomToFit();
        } else {
          await _drawPolylineForSelectedMode();
        }
        return;
      }

      RouteInfo? route;

      switch (selectedMode.value) {
        case TravelModeData.walk:
          route = await _walkRouteController.getRoute(
            startAddress: startAddress.value,
            endAddress: endAddress.value,
          );
          break;
        case TravelModeData.train:
          route = await _trainRouteController.getRoute(
            startAddress: startAddress.value,
            endAddress: endAddress.value,
          );
          break;
        default:
          return;
      }

      if (route == null) return;

      _routeCache[selectedMode.value] = route;

      distance.value = route.totalDistance;
      duration.value = route.totalDuration;
      steps.assignAll(route.steps);
      routeInfoData.value = route;

      await _drawPolylineForSelectedMode();
    } catch (e) {
      debugPrint("_updateRouteByMode failed: $e");
      _showError("Route Error", "Failed for ${selectedMode.value.name}");
    } finally {
      isLoadingRoute.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  // POLYLINE HELPERS
  // ---------------------------------------------------------------------------

  String _buildDirectionsUrl({
    required LatLng origin,
    required LatLng destination,
    required String mode,
    bool alternatives = true,
    List<LatLng> waypoints = const [],
  }) {
    final originStr = "${origin.latitude},${origin.longitude}";
    final destStr = "${destination.latitude},${destination.longitude}";

    String wpParam = '';
    if (waypoints.isNotEmpty) {
      wpParam = "&waypoints=${waypoints.map((p) => "${p.latitude},${p.longitude}").join("|")}";
    }

    return "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=$originStr"
        "&destination=$destStr"
        "&mode=$mode"
        "$wpParam"
        "${alternatives ? '&alternatives=true' : ''}"
        "&key=$apiKey";
  }

  double _estimateDistance(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  Future<List<LatLng>?> _getImprovedPolylineForLongRoute(
      LatLng origin,
      LatLng destination,
      String mode,
      ) async {
    try {
      final roughUrl = _buildDirectionsUrl(
        origin: origin,
        destination: destination,
        mode: mode,
        alternatives: false,
      );

      final response = await http.get(Uri.parse(roughUrl));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      if (data == null || data['status'] != 'OK') return null;

      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes[0] as Map<String, dynamic>;
      final encoded = (route['overview_polyline'] as Map?)?['points'] as String?;
      if (encoded == null || encoded.isEmpty) return null;

      var points = _decodePolyline(encoded);
      if (points.length > 120) return points;

      // Sample intermediate points
      final intermediate = <LatLng>[];
      var accumulated = 0.0;

      for (var i = 1; i < points.length; i++) {
        final segDist = Geolocator.distanceBetween(
          points[i - 1].latitude,
          points[i - 1].longitude,
          points[i].latitude,
          points[i].longitude,
        );
        accumulated += segDist;

        if (accumulated >= _maxSegmentDistanceMeters) {
          intermediate.add(points[i]);
          accumulated = 0;
          if (intermediate.length >= _maxWaypointCount) break;
        }
      }

      if (intermediate.isEmpty) return points;

      final detailedUrl = _buildDirectionsUrl(
        origin: origin,
        destination: destination,
        mode: mode,
        waypoints: intermediate,
        alternatives: false,
      );

      final detailedResponse = await http.get(Uri.parse(detailedUrl));
      if (detailedResponse.statusCode != 200) return points;

      final detailedData = jsonDecode(detailedResponse.body) as Map<String, dynamic>?;
      if (detailedData == null || detailedData['status'] != 'OK') return points;

      final detailedRoutes = detailedData['routes'] as List?;
      if (detailedRoutes == null || detailedRoutes.isEmpty) return points;

      final detailedRoute = detailedRoutes[0] as Map<String, dynamic>;
      final newEncoded = (detailedRoute['overview_polyline'] as Map?)?['points'] as String?;

      return newEncoded != null && newEncoded.isNotEmpty
          ? _decodePolyline(newEncoded)
          : points;
    } catch (e) {
      debugPrint("Long route improvement failed: $e");
      return null;
    }
  }

  Future<void> _drawPolylineForSelectedMode() async {
    if (start == null || end == null || isLoadingRoute.value) return;

    String modeParam = '';
    String extraParams = '';

    switch (selectedMode.value) {
      case TravelModeData.car:
        modeParam = 'driving';
        break;
      case TravelModeData.walk:
        modeParam = 'walking';
        break;
      case TravelModeData.train:
        modeParam = 'transit';
        extraParams = '&transit_mode=train';
        break;
      default:
        return;
    }

    try {
      var url = _buildDirectionsUrl(
        origin: start!,
        destination: end!,
        mode: modeParam,
        alternatives: true,
      ) + extraParams;

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      if (data == null || data['status'] != 'OK') return;

      final routesList = data['routes'] as List?;
      if (routesList == null || routesList.isEmpty) return;

      Map<String, dynamic>? bestRoute;

      bestRoute = routesList.firstWhere(
            (dynamic r) {
          final routeMap = r as Map<String, dynamic>?;
          final legs = routeMap?['legs'] as List?;
          return legs != null && legs.length == 1;
        },
        orElse: () => null,
      );

      bestRoute ??= routesList.reduce((dynamic a, dynamic b) {
        final ra = a as Map<String, dynamic>;
        final rb = b as Map<String, dynamic>;
        final stepsA = ((ra['legs']?[0]?['steps'] as List?)?.length ?? 0);
        final stepsB = ((rb['legs']?[0]?['steps'] as List?)?.length ?? 0);
        return stepsA > stepsB ? a : b;
      });

      bestRoute ??= routesList[0] as Map<String, dynamic>;

      final encoded = (bestRoute['overview_polyline'] as Map?)?['points'] as String?;
      if (encoded == null || encoded.isEmpty) return;

      var points = _decodePolyline(encoded);

      if (points.length < 60 && _estimateDistance(start!, end!) > 250000) {
        final improved = await _getImprovedPolylineForLongRoute(start!, end!, modeParam);
        if (improved != null && improved.length > points.length) {
          points = improved;
        }
      }

      _polylineCache[selectedMode.value] = points;
      polylines.clear();
      _drawPolylineOnMap(points);
      _zoomToFit();
    } catch (e) {
      debugPrint("_drawPolylineForSelectedMode failed: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // 5. DRAWING & UTILITIES
  // ---------------------------------------------------------------------------

  void _drawPolylineOnMap(List<LatLng> points) {
    if (points.isEmpty) return;

    polylines.value = {
      Polyline(
        polylineId: const PolylineId("main_route"),
        color: AppColor.blue.withOpacity(0.88),
        width: 7,
        points: points,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        geodesic: true,
      ),
    };
  }

  List<LatLng> _decodePolyline(String encoded) {
    if (encoded.isEmpty) return [];
    try {
      final polylinePoints = PolylinePoints();
      final result = polylinePoints.decodePolyline(encoded);
      return result.map((p) => LatLng(p.latitude, p.longitude)).toList();
    } catch (e) {
      debugPrint("Decode polyline error: $e");
      return [];
    }
  }

  String _stripHtml(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ').trim();
  }

  double calculateBearing(LatLng startPoint, LatLng endPoint) {
    final lat1 = startPoint.latitude * math.pi / 180.0;
    final lon1 = startPoint.longitude * math.pi / 180.0;
    final lat2 = endPoint.latitude * math.pi / 180.0;
    final lon2 = endPoint.longitude * math.pi / 180.0;

    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final radians = math.atan2(y, x);
    return (radians * 180.0 / math.pi + 360.0) % 360.0;
  }

  void _zoomToFit() {
    if (mapController == null || start == null || end == null) return;

    final swLat = math.min(start!.latitude, end!.latitude);
    final swLng = math.min(start!.longitude, end!.longitude);
    final neLat = math.max(start!.latitude, end!.latitude);
    final neLng = math.max(start!.longitude, end!.longitude);

    final bounds = LatLngBounds(
      southwest: LatLng(swLat, swLng),
      northeast: LatLng(neLat, neLng),
    );

    mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _updateMarkers() {
    markers.clear();

    if (start != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("origin"),
          position: start!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    if (end != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("destination"),
          position: end!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 6. NAVIGATION & UI
  // ---------------------------------------------------------------------------

  Future<void> loadVehiclesIfNeeded() async {
    if (vehicles.isNotEmpty || isLoadingVehicles.value) return;
    isLoadingVehicles.value = true;
    try {
      final list = await VehicleService.instance.fetchVehicleList();
      vehicles.assignAll(list);
    } catch (e) {
      debugPrint("Vehicle load failed: $e");
    } finally {
      isLoadingVehicles.value = false;
    }
  }

  Future<void> startNavigation() async {
    if (isNavigationStarted.value) return;
    isNavigationStarted.value = true;

    if (start != null && end != null) {
      await _updateRouteByMode();
    }
  }

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

  void focusOnStep(int index) {
    if (index < 0 || index >= steps.length) return;
    _showStepHighlight(index);
  }

  void _showStepHighlight(int index) {
    debugPrint("Step ${index + 1}: ${steps[index].instruction}");
  }

  void showStepsBottomSheet() {
    if (isBottomSheetOpen.value) return;
    if (steps.isEmpty || routeInfoData.value == null) return;

    isBottomSheetOpen.value = true;

    Get.bottomSheet(
      DirectionStepsBottomSheet(
        data: routeInfoData.value!,
        travelModedata: selectedMode.value,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      isDismissible: false,
    ).then((_) => isBottomSheetOpen.value = false);
  }

  void _showError(String title, String msg) {
    Get.snackbar(
      title,
      msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.redAccent,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 4),
    );
  }

  void clearRoute() {
    start = null;
    end = null;
    startAddress.value = '';
    endAddress.value = '';
    markers.clear();
    polylines.clear();
    steps.clear();
    distance.value = "0 km";
    duration.value = "0 min";
    routeInfoData.value = null;
    _routeCache.clear();
    _polylineCache.clear();
  }

  @override
  void onClose() {
    mapController?.dispose();
    super.onClose();
  }
}