import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart' hide Response;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:map_creted/controller/vehicalselecor_controller.dart';

class VehicleTrackingController extends GetxController {
  // ───────────────────────────────────────────────
  //  CORE MAP & LOCATION STATE
  // ───────────────────────────────────────────────
  GoogleMapController? mapController;
  ImageSelectionController? _imageController;
  final Dio _dio = Dio(); // Add Dio instance
  
  // Lazy getter for image controller
  ImageSelectionController get imageController {
    _imageController ??= Get.find<ImageSelectionController>();
    return _imageController!;
  }
  
  // Vehicle tracking state
  final Rx<Marker?> vehicleMarker = Rx<Marker?>(null);
  final Rx<Polyline?> routePolyline = Rx<Polyline?>(null);
  final RxBool isTracking = false.obs;
  final RxBool isMovingAlongRoute = false.obs;
  final RxDouble currentBearing = 0.0.obs;
  
  // Location tracking
  StreamSubscription<Position>? positionStreamSubscription;
  final Rx<LatLng> currentVehiclePosition = const LatLng(0.0, 0.0).obs;
  final Rx<LatLng> previousVehiclePosition = const LatLng(0.0, 0.0).obs;
  
  // Route data
  final RxList<LatLng> routeCoordinates = <LatLng>[].obs;
  final RxInt currentRouteIndex = 0.obs;
  
  // Enhanced route polylines for vehicle tracking
  final RxList<Polyline> vehicleRoutePolylines = <Polyline>[].obs;
  final RxList<Polyline> traveledRoutePolylines = <Polyline>[].obs;
  final RxList<Polyline> remainingRoutePolylines = <Polyline>[].obs;
  
  // Route styling for different sections
  static const Color _traveledRouteColor = Color(0xFF4CAF50); // Green for completed
  static const Color _remainingRouteColor = Color(0xFF2196F3); // Blue for remaining
  static const Color _vehicleRouteColor = Color(0xFFFF9800); // Orange for current vehicle route
  
  // Route drawing variables
  LatLng? start;
  LatLng? end;
  final RxString selectedMode = 'driving'.obs;
  final RxString distanceText = ''.obs;
  final RxString durationText = ''.obs;
  final RxList<Map<String, dynamic>> stepsList = <Map<String, dynamic>>[].obs;
  final RxBool isNavigating = false.obs;
  final RxList<Polyline> polylines = <Polyline>[].obs;
  
  // Animation controllers
  AnimationController? animationController;
  Animation<double>? animation;
  
  // ───────────────────────────────────────────────
  //  DYNAMIC VEHICLE SIZING & ZOOM MANAGEMENT
  // ───────────────────────────────────────────────
  final RxDouble currentZoom = 14.0.obs;
  final RxDouble vehicleSize = 110.0.obs;
  final RxDouble targetVehicleSize = 110.0.obs;
  static const double _minVehicleSize = 90.0;
  static const double _maxVehicleSize = 150.0;
  static const double _baseZoomLevel = 14.0;
  static const double _sizeSensitivity = 2.0;
  
  // ───────────────────────────────────────────────
  //  SMOOTH ROTATION & MOVEMENT
  // ───────────────────────────────────────────────
  final RxDouble targetBearing = 0.0.obs;
  final RxDouble rotationSpeed = 0.15.obs; // Smooth rotation speed
  final RxDouble movementSpeed = 0.1.obs; // Smooth movement speed
  
  // Position interpolation for smooth movement
  final Rx<LatLng> interpolatedPosition = const LatLng(0.0, 0.0).obs;
  Timer? _movementTimer;
  Timer? _rotationTimer;
  
  // API constants
  static const String _googleApiKey = 'AIzaSyB4OsZKR2hF7xBBCJR8sM2b6xf17v5DWZs'; // Replace with your API key
  final PolylinePoints polylinePoints = PolylinePoints();
  
  @override
  void onInit() {
    super.onInit();
    _initializeVehicleMarker();
  }
  
  // ───────────────────────────────────────────────
  //  INITIALIZE VEHICLE MARKER WITH SELECTED IMAGE
  // ───────────────────────────────────────────────
  void _initializeVehicleMarker() {
    // This will be called whenever the selected image changes
    ever(imageController.selectedImagePath, (String imagePath) {
      if (isTracking.value) {
        _updateVehicleMarkerIcon();
      }
    });
  }
  
  Future<void> _updateVehicleMarkerIcon() async {
    if (currentVehiclePosition.value.latitude == 0.0) return;
    
    try {
      // Get the selected vehicle image from ImageSelectionController
      final String selectedImagePath = imageController.currentImage;
      
      // Create custom marker from selected image
      final MarkerId markerId = const MarkerId('vehicle');
      final BitmapDescriptor markerIcon = await _getMarkerIconFromImage(selectedImagePath);
      
      final Marker newMarker = Marker(
        markerId: markerId,
        position: currentVehiclePosition.value,
        icon: markerIcon,
        rotation: currentBearing.value,
        anchor: const Offset(0.5, 0.5), // Center of the marker
        zIndexInt: 2,
      );
      
      vehicleMarker.value = newMarker;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating vehicle marker icon: $e');
      }
      // Fallback to default marker
      _createDefaultVehicleMarker();
    }
  }
  
  Future<BitmapDescriptor> _getMarkerIconFromImage(String imagePath) async {
    try {
      // If it's an asset path
      if (imagePath.startsWith('assets/')) {
        return await BitmapDescriptor.asset(
          ImageConfiguration(size: const Size(10, 10)),
          imagePath,
        );
      }
      // If it's a file path or network image, you might need to handle differently
      // For now, fallback to default
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error creating marker icon from image: $e');
      }
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }
  
  void _createDefaultVehicleMarker() {
    final MarkerId markerId = const MarkerId('vehicle');
    final Marker marker = Marker(
      markerId: markerId,
      position: currentVehiclePosition.value,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      rotation: currentBearing.value,
      anchor: const Offset(0.5, 0.5),
      zIndexInt: 2,
    );
    vehicleMarker.value = marker;
  }
  
  // ───────────────────────────────────────────────
  //  TRIP CONTROL FUNCTIONS
  // ───────────────────────────────────────────────
  Future<void> startTrip({LatLng? startPosition, List<LatLng>? routeCoords}) async {
    try {
      // Request location permissions
      bool hasPermission = await _requestLocationPermission();
      if (!hasPermission) return;
      
      // Get initial position
      if (startPosition != null) {
        currentVehiclePosition.value = startPosition;
      } else {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        currentVehiclePosition.value = LatLng(position.latitude, position.longitude);
      }
      
      previousVehiclePosition.value = currentVehiclePosition.value;
      
      // Setup route if provided
      if (routeCoords != null && routeCoords.isNotEmpty) {
        routeCoordinates.assignAll(routeCoords);
        currentRouteIndex.value = 0;
        isMovingAlongRoute.value = true;
        _createPerfectRoadPolylines(routeCoords);
      }
      
      // Initialize vehicle marker
      await _updateVehicleMarkerIcon();
      
      // Start tracking
      isTracking.value = true;
      
      // Start location updates
      _startLocationUpdates();
      
      // Setup 3D map
      _setup3DMap();
      
      // Move camera to vehicle
      _moveCameraToVehicle();
      
      Get.snackbar('Trip Started', 'Vehicle tracking enabled', backgroundColor: Colors.green);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error starting trip: $e');
      }
      Get.snackbar('Error', 'Failed to start trip: $e', backgroundColor: Colors.red);
    }
  }
  
  Future<void> stopTrip() async {
    try {
      isTracking.value = false;
      isMovingAlongRoute.value = false;
      
      // Stop location updates
      await positionStreamSubscription?.cancel();
      positionStreamSubscription = null;
      
      // Clear route
      routeCoordinates.clear();
      routePolyline.value = null;
      
      // Reset animation
      animationController?.stop();
      animationController?.dispose();
      animationController = null;
      
      Get.snackbar('Trip Ended', 'Vehicle tracking stopped', backgroundColor: Colors.blue);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error stopping trip: $e');
      }
    }
  }
  
  // ───────────────────────────────────────────────
  //  LOCATION UPDATES
  // ───────────────────────────────────────────────
  Future<bool> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Get.snackbar('Location Services', 'Please enable location services');
      return false;
    }
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        Get.snackbar('Permission Denied', 'Location permission is required');
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      Get.snackbar('Permission Denied Forever', 'Please enable from settings');
      return false;
    }
    
    return true;
  }
  
  void _startLocationUpdates() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );
    
    positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      updateVehiclePosition(LatLng(position.latitude, position.longitude));
    });
  }
  
  // ───────────────────────────────────────────────
  //  VEHICLE POSITION UPDATES
  // ───────────────────────────────────────────────
  Future<void> updateVehiclePosition(LatLng newPosition) async {
    if (!isTracking.value) return;
    
    previousVehiclePosition.value = currentVehiclePosition.value;
    currentVehiclePosition.value = newPosition;
    
    // Calculate bearing for rotation
    double bearing = calculateBearing(previousVehiclePosition.value, newPosition);
    targetBearing.value = bearing;
    
    // Start smooth rotation
    _startSmoothRotation();
    
    // Start smooth movement
    _startSmoothMovement(newPosition);
    
    // Update marker with current interpolated position
    await _updateVehicleMarker();
  }
  
  // ───────────────────────────────────────────────
  //  DYNAMIC VEHICLE SIZING BASED ON ZOOM
  // ───────────────────────────────────────────────
  void setMapController(GoogleMapController controller) {
    mapController = controller;
    _setupZoomListener();
  }
  
  void _setupZoomListener() {
    // Listen to zoom changes
    mapController?.getVisibleRegion().then((region) {
      currentZoom.value = 14.0; // Default zoom
    });
    
    // Start zoom monitoring timer
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mapController != null && isTracking.value) {
        _updateZoomLevel();
      }
    });
  }
  
  Future<void> _updateZoomLevel() async {
    try {
      final zoom = await mapController!.getZoomLevel();
      
      if (zoom != currentZoom.value) {
        currentZoom.value = zoom;
        _calculateVehicleSize();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating zoom level: $e');
      }
    }
  }
  
  // Public method to trigger zoom update from UI
  void triggerZoomUpdate() {
    _updateZoomLevel();
  }
  
  void _calculateVehicleSize() {
    // Calculate size based on zoom level
    // When zoom increases (zoom in), size decreases
    // When zoom decreases (zoom out), size increases
    
    double zoomFactor = (_baseZoomLevel - currentZoom.value) * _sizeSensitivity;
    double newSize = _maxVehicleSize - zoomFactor;
    
    // Apply min/max limits
    newSize = newSize.clamp(_minVehicleSize, _maxVehicleSize);
    
    targetVehicleSize.value = newSize;
    
    // Start smooth size transition
    _startSmoothSizeTransition();
  }
  
  void _startSmoothSizeTransition() {
    Timer.periodic(const Duration(milliseconds: 16), (timer) {
      double diff = targetVehicleSize.value - vehicleSize.value;
      
      if (diff.abs() < 0.5) {
        vehicleSize.value = targetVehicleSize.value;
        timer.cancel();
      } else {
        vehicleSize.value += diff * 0.2; // Smooth transition
      }
    });
  }
  
  // ───────────────────────────────────────────────
  //  SMOOTH ROTATION SYSTEM
  // ───────────────────────────────────────────────
  void _startSmoothRotation() {
    _rotationTimer?.cancel();
    
    _rotationTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      double diff = targetBearing.value - currentBearing.value;
      
      // Handle angle wrapping (-180 to 180)
      if (diff > 180) diff -= 360;
      if (diff < -180) diff += 360;
      
      if (diff.abs() < 1.0) {
        currentBearing.value = targetBearing.value;
        timer.cancel();
      } else {
        currentBearing.value += diff * rotationSpeed.value;
      }
    });
  }
  
  // ───────────────────────────────────────────────
  //  SMOOTH MOVEMENT SYSTEM
  // ───────────────────────────────────────────────
  void _startSmoothMovement(LatLng targetPosition) {
    _movementTimer?.cancel();
    
    interpolatedPosition.value = currentVehiclePosition.value;
    
    _movementTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      double latDiff = targetPosition.latitude - interpolatedPosition.value.latitude;
      double lngDiff = targetPosition.longitude - interpolatedPosition.value.longitude;
      
      double distance = sqrt(latDiff * latDiff + lngDiff * lngDiff);
      
      if (distance < 0.00001) { // Very close to target
        interpolatedPosition.value = targetPosition;
        timer.cancel();
      } else {
        // Smooth interpolation
        double newLat = interpolatedPosition.value.latitude + latDiff * movementSpeed.value;
        double newLng = interpolatedPosition.value.longitude + lngDiff * movementSpeed.value;
        interpolatedPosition.value = LatLng(newLat, newLng);
      }
    });
  }
  
  // ───────────────────────────────────────────────
  //  ROUTE-BASED MOVEMENT
  // ───────────────────────────────────────────────
  Future<void> moveAlongRoute() async {
    if (routeCoordinates.isEmpty || !isMovingAlongRoute.value) return;
    
    if (currentRouteIndex.value < routeCoordinates.length - 1) {
      currentRouteIndex.value++;
      
      LatLng nextPoint = routeCoordinates[currentRouteIndex.value];
      await updateVehiclePosition(nextPoint);
      
      // Update enhanced route polylines
      updateRouteProgress();
      
      // Check if reached destination
      if (currentRouteIndex.value >= routeCoordinates.length - 1) {
        isMovingAlongRoute.value = false;
        Get.snackbar('Destination Reached', 'You have arrived at your destination');
      }
    }
  }
  
  // ───────────────────────────────────────────────
  //  ENHANCED MARKER UPDATES
  // ───────────────────────────────────────────────
  Future<void> _updateVehicleMarker() async {
    if (currentVehiclePosition.value.latitude == 0.0) return;
    
    try {
      final String selectedImagePath = imageController.currentImage;
      final MarkerId markerId = const MarkerId('vehicle');
      final BitmapDescriptor markerIcon = await _getDynamicMarkerIcon(selectedImagePath);
      
      final Marker newMarker = Marker(
        markerId: markerId,
        position: interpolatedPosition.value, // Use interpolated position for smooth movement
        icon: markerIcon,
        rotation: currentBearing.value, // Use smooth rotation
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 2,
      );
      
      vehicleMarker.value = newMarker;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating vehicle marker: $e');
      }
      _createDefaultVehicleMarker();
    }
  }

  Future<BitmapDescriptor> _getDynamicMarkerIcon(String imagePath) async {
    try {
      double size = vehicleSize.value;

      final ByteData data = await rootBundle.load(imagePath);
      final Uint8List bytes = data.buffer.asUint8List();

      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: size.toInt(),
        targetHeight: size.toInt(),
      );

      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ByteData? byteData =
      await frameInfo.image.toByteData(format: ui.ImageByteFormat.png);

      final Uint8List resizedBytes = byteData!.buffer.asUint8List();

      return BitmapDescriptor.bytes(resizedBytes);
    } catch (e) {
      debugPrint("Marker resize error: $e");
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    }
  }
  
  // ───────────────────────────────────────────────
  //  CAMERA FOLLOW & ROUTE PROGRESS
  // ───────────────────────────────────────────────
  Future<void> _updateCameraToFollowVehicle() async {
    if (mapController == null || !isTracking.value) return;
    
    try {
      // 3D camera follow with smooth transitions
      await mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: interpolatedPosition.value,
            zoom: currentZoom.value,
            tilt: 60.0, // 3D view
            bearing: currentBearing.value, // Follow vehicle direction
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating camera: $e');
      }
    }
  }
  
  void _updateRouteProgress() {
    if (routeCoordinates.isEmpty) return;
    
    // Calculate progress along route
    double totalDistance = 0.0;
    double coveredDistance = 0.0;
    
    for (int i = 0; i < routeCoordinates.length - 1; i++) {
      double segmentDistance = _calculateDistance(
        routeCoordinates[i],
        routeCoordinates[i + 1],
      );
      
      if (i < currentRouteIndex.value) {
        coveredDistance += segmentDistance;
      }
      totalDistance += segmentDistance;
    }
    
    double progress = totalDistance > 0 ? coveredDistance / totalDistance : 0.0;
    
    // Auto-move to next route point if close enough
    if (currentRouteIndex.value < routeCoordinates.length - 1) {
      LatLng nextPoint = routeCoordinates[currentRouteIndex.value + 1];
      double distanceToNext = _calculateDistance(
        interpolatedPosition.value,
        nextPoint,
      );
      
      if (distanceToNext < 10.0) { // Within 10 meters
        moveAlongRoute();
      }
    }
  }
  
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    double lat1Rad = point1.latitude * pi / 180;
    double lat2Rad = point2.latitude * pi / 180;
    double deltaLatRad = (point2.latitude - point1.latitude) * pi / 180;
    double deltaLngRad = (point2.longitude - point1.longitude) * pi / 180;
    
    double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c; // Distance in meters
  }
  
  // ───────────────────────────────────────────────
  //  SMOOTH MARKER ANIMATION
  // ───────────────────────────────────────────────
  Future<void> animateMarker(LatLng targetPosition, double bearing) async {
    if (mapController == null) return;
    
    // Cancel any existing animation
    animationController?.stop();
    animationController?.dispose();
    
    // Create new animation
    animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: Get.find<TickerProvider>(),
    );
    
    animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: animationController!, curve: Curves.easeInOut),
    );
    
    animation?.addListener(() {
      if (animation!.value < 1.0) {
        // Interpolate position
        LatLng interpolatedPosition = _interpolatePosition(
          previousVehiclePosition.value,
          targetPosition,
          animation!.value,
        );
        
        // Update marker
        final Marker updatedMarker = Marker(
          markerId: const MarkerId('vehicle'),
          position: interpolatedPosition,
          icon: vehicleMarker.value?.icon ?? BitmapDescriptor.defaultMarker,
          rotation: bearing,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 2,
        );
        
        vehicleMarker.value = updatedMarker;
      }
    });
    
    // Start animation
    animationController?.forward();
    
    // Update final position after animation
    await Future.delayed(const Duration(milliseconds: 500));
    await _updateVehicleMarkerIcon();
  }
  
  LatLng _interpolatePosition(LatLng start, LatLng end, double t) {
    double lat = start.latitude + (end.latitude - start.latitude) * t;
    double lng = start.longitude + (end.longitude - start.longitude) * t;
    return LatLng(lat, lng);
  }
  
  // ───────────────────────────────────────────────
  //  BEARING CALCULATION
  // ───────────────────────────────────────────────
  double calculateBearing(LatLng start, LatLng end) {
    double startLat = _toRadians(start.latitude);
    double startLng = _toRadians(start.longitude);
    double endLat = _toRadians(end.latitude);
    double endLng = _toRadians(end.longitude);
    
    double dLng = endLng - startLng;
    double y = sin(dLng) * cos(endLat);
    double x = cos(startLat) * sin(endLat) - sin(startLat) * cos(endLat) * cos(dLng);
    
    double bearing = atan2(y, x);
    bearing = _toDegrees(bearing);
    bearing = (bearing + 360) % 360;
    
    return bearing;
  }
  
  double _toRadians(double degrees) => degrees * (pi / 180);
  double _toDegrees(double radians) => radians * (180 / pi);
  
  // ───────────────────────────────────────────────
  //  PERFECT ROAD-FOLLOWING POLYLINE SYSTEM
  // ───────────────────────────────────────────────
  
  /// Public method to fetch and draw route between two points
  Future<void> fetchRoute(LatLng origin, LatLng destination) async {
    // Set start and end points
    start = origin;
    end = destination;
    
    // Call the enhanced route drawing method
    await _drawRoute();
  }
  
  /// Enhanced route drawing with perfect road alignment
  Future<void> _drawRoute() async {
    if (start == null || end == null) return;

    String transitParams = selectedMode.value == "transit" ? "&departure_time=now" : "";
    final url = "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=${start!.latitude},${start!.longitude}"
        "&destination=${end!.latitude},${end!.longitude}"
        "&mode=${selectedMode.value}"
        "$transitParams"
        "&alternatives=false"
        "&key=$_googleApiKey";

    try {
      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body);

      if (data["status"] != "OK" || data["routes"].isEmpty) {
        Get.snackbar("Route Error", "No route found");
        return;
      }

      final route = data["routes"][0];
      final leg = route["legs"][0];

      distanceText.value = leg["distance"]["text"];
      durationText.value = leg["duration"]["text"];

      stepsList.clear();
      List<LatLng> detailedCoordinates = [];
      
      // Process each step with perfect road alignment
      for (var step in leg["steps"]) {
        stepsList.add({
          "instruction": step["html_instructions"]
              .replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ""),
          "distance": step["distance"]["text"],
          "maneuver": step["maneuver"] ?? "straight",
        });

        // Decode step polyline with enhanced precision
        var stepPoints = _decodePolyline(step["polyline"]["points"]);
        
        // Apply smooth curves for better road following
        stepPoints = _applySmoothCurves(stepPoints);
        
        // Optimize points to prevent overlapping
        stepPoints = _optimizePolylinePoints(stepPoints);
        
        detailedCoordinates.addAll(stepPoints);
      }

      // Apply final route optimization for long distances
      detailedCoordinates = _optimizeForLongRoute(detailedCoordinates);

      // Create enhanced polylines with perfect rendering
      _createPerfectRoadPolylines(detailedCoordinates);

      if (!isNavigating.value) {
        _fitRoute(detailedCoordinates);
      }

    } catch (e) {
      Get.snackbar("Error", "Failed to fetch directions");
    }
  }
  
  /// Decode polyline with enhanced precision
  List<LatLng> _decodePolyline(String encoded) {
    if (encoded.isEmpty) return [];
    
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }
  
  /// Apply smooth curves for natural road following
  List<LatLng> _applySmoothCurves(List<LatLng> points, {double smoothingFactor = 0.3}) {
    if (points.length < 3) return points;

    List<LatLng> smoothedPoints = [points.first];

    for (int i = 1; i < points.length - 1; i++) {
      LatLng prev = points[i - 1];
      LatLng current = points[i];
      LatLng next = points[i + 1];

      // Calculate control points for smooth curve
      double lat1 = prev.latitude + (current.latitude - prev.latitude) * smoothingFactor;
      double lng1 = prev.longitude + (current.longitude - prev.longitude) * smoothingFactor;

      double lat2 = current.latitude + (next.latitude - current.latitude) * smoothingFactor;
      double lng2 = current.longitude + (next.longitude - current.longitude) * smoothingFactor;

      // Add intermediate points for smooth curve
      for (double t = 0.1; t <= 0.9; t += 0.2) {
        double lat = _bezierInterpolate(prev.latitude, lat1, lat2, next.latitude, t);
        double lng = _bezierInterpolate(prev.longitude, lng1, lng2, next.longitude, t);
        smoothedPoints.add(LatLng(lat, lng));
      }

      smoothedPoints.add(current);
    }

    smoothedPoints.add(points.last);
    return smoothedPoints;
  }
  
  /// Bezier interpolation for smooth curves
  double _bezierInterpolate(double p0, double p1, double p2, double p3, double t) {
    double u = 1 - t;
    return (u * u * u * p0) + (3 * u * u * t * p1) + (3 * u * t * t * p2) + (t * t * t * p3);
  }
  
  /// Optimize polyline points to prevent overlapping and improve performance
  List<LatLng> _optimizePolylinePoints(List<LatLng> points, {double minDistance = 2.0}) {
    if (points.isEmpty) return [];

    List<LatLng> optimized = [points.first];

    for (int i = 1; i < points.length; i++) {
      double distance = _calculateDistance(optimized.last, points[i]);
      if (distance >= minDistance) {
        optimized.add(points[i]);
      }
    }

    return optimized;
  }
  
  /// Optimize for long-distance routes
  List<LatLng> _optimizeForLongRoute(List<LatLng> points) {
    if (points.length <= 100) return points;
    
    // For very long routes, sample points to maintain performance
    int step = (points.length / 100).ceil();
    List<LatLng> sampled = [];
    
    for (int i = 0; i < points.length; i += step) {
      sampled.add(points[i]);
    }
    
    // Ensure last point is included
    if (sampled.last != points.last) {
      sampled.add(points.last);
    }
    
    return sampled;
  }
  
  /// Create perfect road polylines with enhanced rendering
  void _createPerfectRoadPolylines(List<LatLng> coordinates) {
    if (coordinates.isEmpty) return;
    
    // Calculate optimal width based on zoom level
    double optimalWidth = _calculateOptimalWidth();
    
    // Clear existing polylines
    polylines.clear();
    
    // Create main route polyline with perfect configuration
    Polyline mainRoute = Polyline(
      polylineId: const PolylineId("perfect_route"),
      points: coordinates,
      color: const Color(0xFF2196F3), // Material Blue
      width: optimalWidth.toInt(),
      jointType: JointType.round, // Smooth joints for natural turns
      startCap: Cap.roundCap,     // Round start points
      endCap: Cap.roundCap,       // Round end points
      geodesic: true,             // Follow Earth's curvature
      patterns: [],               // Solid line for driving
      visible: true,
    );
    
    polylines.add(mainRoute);
    
    // Add border for better visibility (only for solid lines)
    Polyline borderRoute = Polyline(
      polylineId: const PolylineId("route_border"),
      points: coordinates,
      color: const Color(0xFF1976D2), // Darker blue for border
      width: (optimalWidth + 2).toInt(),
      jointType: JointType.round,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      geodesic: true,
      visible: true,
    );
    
    polylines.add(borderRoute);
  }
  
  /// Calculate optimal polyline width based on zoom level
  double _calculateOptimalWidth() {
    double zoom = currentZoom.value;
    
    if (zoom < 10) {
      return 4.0; // Thinner for far zoom
    } else if (zoom < 14) {
      return 6.0; // Medium for city zoom
    } else if (zoom < 18) {
      return 8.0; // Thicker for street zoom
    } else {
      return 10.0; // Thickest for close zoom
    }
  }
  
  /// Fit route to map bounds with proper padding
  void _fitRoute(List<LatLng> coordinates) async {
    if (mapController == null || coordinates.isEmpty) return;

    // Calculate bounds
    double minLat = coordinates.first.latitude;
    double maxLat = coordinates.first.latitude;
    double minLng = coordinates.first.longitude;
    double maxLng = coordinates.first.longitude;

    for (var point in coordinates) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    // Create bounds with padding
    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    // Animate camera to fit bounds with proper padding
    await mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100), // 100px padding
    );
  }
  
  // ───────────────────────────────────────────────
  //  ENHANCED ROUTE MANAGEMENT
  // ───────────────────────────────────────────────
  
  /// Set enhanced route with proper road alignment and multiple polyline sections
  void setEnhancedRoute(List<LatLng> newRoute) {
    if (newRoute.isEmpty) return;
    
    routeCoordinates.assignAll(newRoute);
    currentRouteIndex.value = 0;
    
    // Clear existing polylines
    vehicleRoutePolylines.clear();
    traveledRoutePolylines.clear();
    remainingRoutePolylines.clear();
    
    // Create enhanced route polylines
    _createEnhancedRoutePolylines();
  }
  
  /// Create multiple polylines for different route sections
  void _createEnhancedRoutePolylines() {
    if (routeCoordinates.isEmpty) return;
    
    // Create remaining route polyline (full route initially)
    Polyline remainingRoute = Polyline(
      polylineId: const PolylineId('remaining_route'),
      points: routeCoordinates,
      color: _remainingRouteColor,
      width: 6,
      jointType: JointType.round,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      geodesic: true,
      patterns: [],
    );
    
    remainingRoutePolylines.add(remainingRoute);
    
    // Create vehicle route polyline (empty initially)
    Polyline vehicleRoute = Polyline(
      polylineId: const PolylineId('vehicle_route'),
      points: [],
      color: _vehicleRouteColor,
      width: 8,
      jointType: JointType.round,
      startCap: Cap.roundCap,
      endCap: Cap.roundCap,
      geodesic: true,
      patterns: [],
    );
    
    vehicleRoutePolylines.add(vehicleRoute);
  }
  
  /// Update route polylines based on vehicle progress
  void updateRouteProgress() {
    if (routeCoordinates.isEmpty || currentRouteIndex.value >= routeCoordinates.length) return;
    
    // Get traveled and remaining coordinates
    List<LatLng> traveledCoords = routeCoordinates.sublist(0, currentRouteIndex.value + 1);
    List<LatLng> remainingCoords = routeCoordinates.sublist(currentRouteIndex.value);
    
    // Update traveled route polyline
    if (traveledCoords.isNotEmpty) {
      Polyline traveledRoute = Polyline(
        polylineId: const PolylineId('traveled_route'),
        points: traveledCoords,
        color: _traveledRouteColor,
        width: 6,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        geodesic: true,
        patterns: [],
      );
      
      traveledRoutePolylines.clear();
      traveledRoutePolylines.add(traveledRoute);
    }
    
    // Update remaining route polyline
    if (remainingCoords.isNotEmpty) {
      Polyline remainingRoute = Polyline(
        polylineId: const PolylineId('remaining_route'),
        points: remainingCoords,
        color: _remainingRouteColor,
        width: 6,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        geodesic: true,
        patterns: [],
      );
      
      remainingRoutePolylines.clear();
      remainingRoutePolylines.add(remainingRoute);
    }
    
    // Update vehicle route polyline (current position to next few points)
    if (currentRouteIndex.value < routeCoordinates.length - 1) {
      int endIndex = math.min(currentRouteIndex.value + 5, routeCoordinates.length - 1);
      List<LatLng> vehicleRouteCoords = routeCoordinates.sublist(currentRouteIndex.value, endIndex + 1);
      
      Polyline vehicleRoute = Polyline(
        polylineId: const PolylineId('vehicle_route'),
        points: vehicleRouteCoords,
        color: _vehicleRouteColor,
        width: 8,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        geodesic: true,
        patterns: [],
      );
      
      vehicleRoutePolylines.clear();
      vehicleRoutePolylines.add(vehicleRoute);
    }
  }
  
  /// Get all route polylines for map display
  List<Polyline> getAllRoutePolylines() {
    List<Polyline> allPolylines = [];
    allPolylines.addAll(traveledRoutePolylines);
    allPolylines.addAll(remainingRoutePolylines);
    allPolylines.addAll(vehicleRoutePolylines);
    return allPolylines;
  }
  
  /// Clear all route polylines
  void clearRoutePolylines() {
    vehicleRoutePolylines.clear();
    traveledRoutePolylines.clear();
    remainingRoutePolylines.clear();
  }
  
  // ───────────────────────────────────────────────
  //  3D MAP SETUP
  // ───────────────────────────────────────────────
  void _setup3DMap() {
    if (mapController == null) return;
    
    // Enable 3D buildings and set initial 3D view
    mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: currentVehiclePosition.value,
          zoom: 18,
          tilt: 60, // 3D perspective
          bearing: currentBearing.value,
        ),
      ),
    );
  }
  
  // ───────────────────────────────────────────────
  //  CAMERA CONTROL
  // ───────────────────────────────────────────────
  void _moveCameraToVehicle() {
    if (mapController == null) return;
    
    mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: currentVehiclePosition.value,
          zoom: 18,
          tilt: 60,
          bearing: currentBearing.value,
        ),
      ),
    );
  }
  
  // ───────────────────────────────────────────────
  //  CLEANUP & DISPOSE
  // ───────────────────────────────────────────────
  @override
  void onClose() {
    // Cancel timers
    _movementTimer?.cancel();
    _rotationTimer?.cancel();
    positionStreamSubscription?.cancel();
    
    // Dispose animation controller
    animationController?.dispose();
    
    // Clear markers
    vehicleMarker.value = null;
    routePolyline.value = null;
    
    super.onClose();
  }
}
