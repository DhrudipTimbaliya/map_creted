import 'package:dio/dio.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart' hide Response;
import 'package:flutter/foundation.dart';

class DirectionsApiService extends GetxService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  static const String _apiKey = 'YOUR_GOOGLE_MAPS_API_KEY'; // Replace with your API key
  
  final Dio _dio = Dio();
  final PolylinePoints _polylinePoints = PolylinePoints();
  
  Future<List<LatLng>> getDirections({
    required LatLng origin,
    required LatLng destination,
    String? apiKey,
    TravelMode travelMode = TravelMode.driving,
    bool alternatives = false,
    bool avoidHighways = false,
    bool avoidTolls = false,
    bool avoidFerries = false,
  }) async {
    try {
      final String effectiveApiKey = apiKey ?? _apiKey;
      
      if (effectiveApiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
        throw Exception('Please set your Google Maps API key in DirectionsApiService');
      }
      
      final Map<String, dynamic> queryParams = {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'key': effectiveApiKey,
        'alternatives': alternatives.toString(),
        'avoid': _getAvoidParameters(avoidHighways, avoidTolls, avoidFerries),
      };
      
      // Add travel mode
      queryParams['mode'] = travelMode.name;
      
      final Response response = await _dio.get(
        _baseUrl,
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          // Get the first (best) route
          final Map<String, dynamic> route = data['routes'][0];
          final String encodedPolyline = route['overview_polyline']['points'];
          
          // Decode polyline to coordinates
          List<PointLatLng> decodedPoints = _polylinePoints.decodePolyline(encodedPolyline);
          
          // Convert to LatLng list
          List<LatLng> coordinates = decodedPoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();
          
          return coordinates;
        } else {
          throw Exception('No routes found: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('Failed to fetch directions: HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Directions API Error: $e');
      }
      rethrow;
    }
  }
  
  Future<List<List<LatLng>>> getMultipleRoutes({
    required LatLng origin,
    required LatLng destination,
    String? apiKey,
    TravelMode travelMode = TravelMode.driving,
    int maxRoutes = 3,
  }) async {
    try {
      final String effectiveApiKey = apiKey ?? _apiKey;
      
      if (effectiveApiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
        throw Exception('Please set your Google Maps API key in DirectionsApiService');
      }
      
      final Map<String, dynamic> queryParams = {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'key': effectiveApiKey,
        'alternatives': 'true',
      };
      
      queryParams['mode'] = travelMode.name;
      
      final Response response = await _dio.get(
        _baseUrl,
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          List<List<LatLng>> allRoutes = [];
          
          // Process each route (up to maxRoutes)
          int routeCount = data['routes'].length < maxRoutes ? data['routes'].length : maxRoutes;
          
          for (int i = 0; i < routeCount; i++) {
            final Map<String, dynamic> route = data['routes'][i];
            final String encodedPolyline = route['overview_polyline']['points'];
            
            List<PointLatLng> decodedPoints = _polylinePoints.decodePolyline(encodedPolyline);
            List<LatLng> coordinates = decodedPoints
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList();
            
            allRoutes.add(coordinates);
          }
          
          return allRoutes;
        } else {
          throw Exception('No routes found: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('Failed to fetch directions: HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Multiple Routes API Error: $e');
      }
      rethrow;
    }
  }
  
  Future<RouteInfo> getRouteInfo({
    required LatLng origin,
    required LatLng destination,
    String? apiKey,
    TravelMode travelMode = TravelMode.driving,
  }) async {
    try {
      final String effectiveApiKey = apiKey ?? _apiKey;
      
      if (effectiveApiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
        throw Exception('Please set your Google Maps API key in DirectionsApiService');
      }
      
      final Map<String, dynamic> queryParams = {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'key': effectiveApiKey,
      };
      
      queryParams['mode'] = travelMode.name;
      
      final Response response = await _dio.get(
        _baseUrl,
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final Map<String, dynamic> route = data['routes'][0];
          final Map<String, dynamic> leg = route['legs'][0];
          
          final String encodedPolyline = route['overview_polyline']['points'];
          List<PointLatLng> decodedPoints = _polylinePoints.decodePolyline(encodedPolyline);
          List<LatLng> coordinates = decodedPoints
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();
          
          return RouteInfo(
            distance: leg['distance']['value'], // in meters
            duration: leg['duration']['value'], // in seconds
            distanceText: leg['distance']['text'],
            durationText: leg['duration']['text'],
            coordinates: coordinates,
            startAddress: leg['start_address'],
            endAddress: leg['end_address'],
          );
        } else {
          throw Exception('No routes found: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('Failed to fetch directions: HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Route Info API Error: $e');
      }
      rethrow;
    }
  }
  
  String _getAvoidParameters(bool avoidHighways, bool avoidTolls, bool avoidFerries) {
    List<String> avoidList = [];
    
    if (avoidHighways) avoidList.add('highways');
    if (avoidTolls) avoidList.add('tolls');
    if (avoidFerries) avoidList.add('ferries');
    
    return avoidList.join('|');
  }
}

enum TravelMode {
  driving,
  walking,
  bicycling,
  transit,
}

class RouteInfo {
  final int distance; // meters
  final int duration; // seconds
  final String distanceText;
  final String durationText;
  final List<LatLng> coordinates;
  final String startAddress;
  final String endAddress;
  
  RouteInfo({
    required this.distance,
    required this.duration,
    required this.distanceText,
    required this.durationText,
    required this.coordinates,
    required this.startAddress,
    required this.endAddress,
  });
  
  double get distanceInKm => distance / 1000.0;
  double get durationInMinutes => duration / 60.0;
  double get durationInHours => duration / 3600.0;
  
  @override
  String toString() {
    return 'RouteInfo(distance: $distanceText, duration: $durationText, points: ${coordinates.length})';
  }
}
