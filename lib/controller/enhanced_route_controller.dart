import 'dart:convert';
import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class EnhancedRouteController extends GetxController {
  // ---------------------------------------------------------------------------
  // 1. ENHANCED ROUTE DRAWING CONFIGURATION
  // ---------------------------------------------------------------------------
  
  // Map controller
  GoogleMapController? mapController;
  
  // API Configuration
  final String apiKey = "AIzaSyB4OsZKR2hF7xBBCJR8sM2b6xf17v5DWZs";
  
  // Enhanced route observables
  final RxList<Polyline> polylines = <Polyline>[].obs;
  final RxList<Marker> markers = <Marker>[].obs;
  final RxString distanceText = "0 km".obs;
  final RxString durationText = "0 min".obs;
  final RxBool isLoadingRoute = false.obs;
  final RxBool isNavigating = false.obs;
  
  // Route data
  final RxList<Map<String, dynamic>> stepsList = <Map<String, dynamic>>[].obs;
  final RxList<LatLng> routeCoordinates = <LatLng>[].obs;
  final RxString selectedMode = "driving".obs;
  
  // Enhanced rendering configuration
  static const double _basePolylineWidth = 8.0;
  static const double _minPolylineWidth = 4.0;
  static const double _maxPolylineWidth = 12.0;
  static const double _zoomThreshold = 15.0;
  
  // Performance optimization
  final RxDouble currentZoom = 14.0.obs;
  final Set<PolylineId> _processedPolylines = <PolylineId>{};
  
  // ---------------------------------------------------------------------------
  // 2. ENHANCED POLYLINE DECODING
  // ---------------------------------------------------------------------------
  
  /// Enhanced polyline decoder with better precision
  List<LatLng> _decodePoly(String encoded) {
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
  
  /// Smooth polyline by adding intermediate points for curves
  List<LatLng> _smoothPolyline(List<LatLng> points, {double smoothingFactor = 0.3}) {
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
      for (double t = 0.1; t <= 0.9; t += 0.1) {
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
  
  /// Remove duplicate and very close points
  List<LatLng> _optimizePolyline(List<LatLng> points, {double minDistance = 2.0}) {
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
  
  /// Calculate distance between two points
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
  
  // ---------------------------------------------------------------------------
  // 3. ENHANCED ROUTE DRAWING
  // ---------------------------------------------------------------------------
  
  /// Main enhanced route drawing function
  Future<void> drawEnhancedRoute(LatLng start, LatLng end) async {
    if (isLoadingRoute.value) return;
    
    isLoadingRoute.value = true;
    polylines.clear();
    markers.clear();
    
    try {
      // Build enhanced API URL
      final url = _buildEnhancedDirectionsUrl(start, end);
      
      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body);
      
      if (data["status"] != "OK" || data["routes"].isEmpty) {
        Get.snackbar("Route Error", "No route found", 
          backgroundColor: Colors.red.withOpacity(0.9),
          colorText: Colors.blueAccent);
        return;
      }
      
      // Process route data
      await _processEnhancedRoute(data["routes"][0]);
      
    } catch (e) {
      Get.snackbar("Error", "Failed to fetch directions: $e",
        backgroundColor: Colors.red.withOpacity(0.9),
        colorText: Colors.blueAccent);
    } finally {
      isLoadingRoute.value = false;
    }
  }
  
  /// Build enhanced directions API URL
  String _buildEnhancedDirectionsUrl(LatLng start, LatLng end) {
    String transitParams = selectedMode.value == "transit" ? "&departure_time=now" : "";
    
    return "https://maps.googleapis.com/maps/api/directions/json?"
        "origin=${start.latitude},${start.longitude}"
        "&destination=${end.latitude},${end.longitude}"
        "&mode=${selectedMode.value}"
        "$transitParams"
        "&alternatives=false"
        "&avoid=highways|tolls"
        "&units=metric"
        "&key=$apiKey";
  }
  
  /// Process enhanced route data
  Future<void> _processEnhancedRoute(Map<String, dynamic> route) async {
    final leg = route["legs"][0];
    
    // Update distance and duration
    distanceText.value = leg["distance"]["text"];
    durationText.value = leg["duration"]["text"];
    
    // Process steps
    stepsList.clear();
    List<LatLng> allCoordinates = [];
    
    for (var step in leg["steps"]) {
      // Add step information
      stepsList.add({
        "instruction": _cleanHtmlInstructions(step["html_instructions"]),
        "distance": step["distance"]["text"],
        "duration": step["duration"]["text"],
        "maneuver": step["maneuver"] ?? "straight",
        "start_location": LatLng(
          step["start_location"]["lat"],
          step["start_location"]["lng"]
        ),
        "end_location": LatLng(
          step["end_location"]["lat"],
          step["end_location"]["lng"]
        ),
      });
      
      // Decode and enhance step polyline
      var stepPoints = _decodePoly(step["polyline"]["points"]);
      stepPoints = _smoothPolyline(stepPoints, smoothingFactor: 0.2);
      stepPoints = _optimizePolyline(stepPoints, minDistance: 1.5);
      
      allCoordinates.addAll(stepPoints);
    }
    
    // Store route coordinates
    routeCoordinates.assignAll(allCoordinates);
    
    // Create enhanced polylines with travel mode styling
    await _createEnhancedPolylines(allCoordinates, travelMode: selectedMode.value);
    
    // Update markers
    _updateRouteMarkers(leg["start_location"], leg["end_location"]);
    
    // Fit route if not navigating
    if (!isNavigating.value) {
      _fitRouteToBounds(allCoordinates);
    }
  }
  
  /// Create enhanced polylines with travel mode-based styling
  Future<void> _createEnhancedPolylines(List<LatLng> coordinates, {String travelMode = 'driving'}) async {
    if (coordinates.isEmpty) return;
    
    // Get styling based on travel mode
    Color routeColor = _getPolylineColorForMode(travelMode);
    double routeWidth = _getPolylineWidthForMode(travelMode);
    List<PatternItem> pattern = _getPolylinePatternForMode(travelMode);
    
    // Create main route polyline with mode-specific styling
    PolylineId mainRouteId = const PolylineId("enhanced_main_route");
    
    if (!_processedPolylines.contains(mainRouteId)) {
      Polyline mainRoute = Polyline(
        polylineId: mainRouteId,
        points: coordinates,
        color: routeColor,
        width: routeWidth.toInt(),
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        geodesic: true,
        patterns: pattern,
      );
      
      polylines.add(mainRoute);
      _processedPolylines.add(mainRouteId);
    }
    
    // Create route border for better visibility (only for solid lines)
    if (pattern.isEmpty) {
      PolylineId borderId = const PolylineId("enhanced_route_border");
      
      if (!_processedPolylines.contains(borderId)) {
        Polyline borderRoute = Polyline(
          polylineId: borderId,
          points: coordinates,
          color: const Color(0xFF1976D2), // Material Blue
          width: (routeWidth + 2).toInt(),
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          geodesic: true,
        );
        
        polylines.add(borderRoute);
        _processedPolylines.add(borderId);
      }
    }
  }
  
  /// Calculate optimal polyline width based on zoom level
  double _calculateOptimalPolylineWidth() {
    double zoom = currentZoom.value;
    
    if (zoom < 10) {
      return _minPolylineWidth;
    } else if (zoom < 14) {
      return _minPolylineWidth + (zoom - 10) * 1.0;
    } else if (zoom < 18) {
      return _basePolylineWidth + (zoom - 14) * 0.5;
    } else {
      return _maxPolylineWidth;
    }
  }
  
  /// Update route markers with enhanced styling
  void _updateRouteMarkers(Map<String, dynamic> start, Map<String, dynamic> end) {
    // Start marker
    Marker startMarker = Marker(
      markerId: const MarkerId("route_start"),
      position: LatLng(start["lat"], start["lng"]),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(
        title: "Start",
        snippet: "Route starting point",
      ),
    );
    
    // End marker
    Marker endMarker = Marker(
      markerId: const MarkerId("route_end"),
      position: LatLng(end["lat"], end["lng"]),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: "Destination",
        snippet: "Route ending point",
      ),
    );
    
    markers.addAll([startMarker, endMarker]);
  }
  
  /// Fit route to map bounds with proper padding
  void _fitRouteToBounds(List<LatLng> coordinates) async {
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
    
    // Animate camera to fit bounds
    await mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100), // 100px padding as int
    );
  }
  
  /// Clean HTML instructions
  String _cleanHtmlInstructions(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'&[^;]+;'), '') // Remove HTML entities
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }
  
  // ---------------------------------------------------------------------------
  // 4. TRAVEL MODE-BASED POLYLINE STYLING
  // ---------------------------------------------------------------------------
  
  /// Get polyline pattern based on travel mode
  List<PatternItem> _getPolylinePatternForMode(String travelMode) {
    switch (travelMode.toLowerCase()) {
      case 'driving':
        // Solid line for car mode - no pattern
        return [];
      case 'walking':
        // Dotted/dashed line for walking mode
        return [
          PatternItem.dash(10),
          PatternItem.gap(8),
        ];
      case 'transit':
        // Styled line for train/transit mode
        return [
          PatternItem.dash(20),
          PatternItem.gap(5),
        ];
      default:
        // Default to solid line
        return [];
    }
  }
  
  /// Get polyline color based on travel mode
  Color _getPolylineColorForMode(String travelMode) {
    switch (travelMode.toLowerCase()) {
      case 'driving':
        return const Color(0xFF2196F3); // Material Blue
      case 'walking':
        return const Color(0xFF4CAF50); // Green for walking
      case 'transit':
        return const Color(0xFF9C27B0); // Purple for transit
      default:
        return const Color(0xFF2196F3); // Default blue
    }
  }
  
  /// Get polyline width based on travel mode
  double _getPolylineWidthForMode(String travelMode) {
    switch (travelMode.toLowerCase()) {
      case 'driving':
        return 4.0; // Reduced thickness for driving
      case 'walking':
        return 3.0; // Reduced thickness for walking
      case 'transit':
        return 3.5; // Reduced thickness for transit
      default:
        return 4.0; // Default reduced thickness
    }
  }
  
  /// Update polylines based on zoom level
  void updatePolylinesForZoom() {
    if (polylines.isEmpty) return;
    
    double newWidth = _calculateOptimalPolylineWidth();
    
    // Recreate polylines with new width since copyWith doesn't exist
    List<Polyline> updatedPolylines = [];
    for (Polyline polyline in polylines) {
      Polyline updatedPolyline = Polyline(
        polylineId: polyline.polylineId,
        points: polyline.points,
        color: polyline.color,
        width: newWidth.toInt(),
        jointType: polyline.jointType,
        startCap: polyline.startCap,
        endCap: polyline.endCap,
        geodesic: polyline.geodesic,
        patterns: polyline.patterns,
        visible: polyline.visible,
        zIndex: polyline.zIndex,
        consumeTapEvents: polyline.consumeTapEvents,
        onTap: polyline.onTap,
      );
      updatedPolylines.add(updatedPolyline);
    }
    
    polylines.assignAll(updatedPolylines);
  }
  
  /// Set map controller and setup zoom listener  
  void setMapController(GoogleMapController controller) {
    mapController = controller;
    _setupZoomListener();
  }
  
  /// Setup zoom change listener
  void _setupZoomListener() {
    // This would be called from DirectionPage's onCameraMove
    // Update current zoom and adjust polyline width
  }
  
  /// Update current zoom level
  void updateZoomLevel(double zoom) {
    currentZoom.value = zoom;
    updatePolylinesForZoom();
  }
  
  // ---------------------------------------------------------------------------
  // 5. ROUTE MANAGEMENT
  // ---------------------------------------------------------------------------
  
  /// Clear current route
  void clearRoute() {
    polylines.clear();
    markers.clear();
    stepsList.clear();
    routeCoordinates.clear();
    _processedPolylines.clear();
    distanceText.value = "0 km";
    durationText.value = "0 min";
  }
  
  /// Start navigation mode
  void startNavigation() {
    isNavigating.value = true;
  }
  
  /// Stop navigation mode
  void stopNavigation() {
    isNavigating.value = false;
  }
  
  /// Change travel mode
  void changeTravelMode(String mode) {
    if (selectedMode.value != mode) {
      selectedMode.value = mode;
      // Redraw route with new mode if coordinates exist
      if (routeCoordinates.isNotEmpty) {
        // Redraw route with new mode
      }
    }
  }
  
  // ---------------------------------------------------------------------------
  // 6. PERFORMANCE OPTIMIZATION
  // ---------------------------------------------------------------------------
  
  @override
  void onClose() {
    polylines.clear();
    markers.clear();
    stepsList.clear();
    routeCoordinates.clear();
    _processedPolylines.clear();
    super.onClose();
  }
}
