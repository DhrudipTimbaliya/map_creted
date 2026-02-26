import 'dart:convert';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../model/route_step_model.dart';

typedef LatLngFromAddress = Future<LatLng?> Function(String address);

class BusRouteController extends GetxController {
  final LatLngFromAddress latLngFromAddress;
  final String apiKey;

  BusRouteController({
    required this.latLngFromAddress,
    required this.apiKey,
  });

  Future<RouteInfo> getRoute({
    required String startAddress,
    required String endAddress,
  }) async {
    final LatLng? start = await latLngFromAddress(startAddress);
    final LatLng? end = await latLngFromAddress(endAddress);

    if (start == null || end == null) {
      throw Exception('Invalid start or end address');
    }

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=${start.latitude},${start.longitude}'
          '&destination=${end.latitude},${end.longitude}'
          '&mode=transit'
          '&transit_mode=bus'
          '&key=$apiKey',
    );

    final response = await http.get(uri);
    final Map<String, dynamic> data = jsonDecode(response.body);

    if (data['status'] != 'OK') {
      throw Exception('Directions API failed: ${data['status']}');
    }

    final leg = data['routes'][0]['legs'][0];

    final String totalDistance = leg['distance']['text'];
    final String totalDuration = leg['duration']['text'];
    final List rawSteps = leg['steps'] as List;

    final steps = rawSteps
        .map((s) => RouteStep(
      instruction: _stripHtml(s['html_instructions'] as String),
      distance: s['distance']['text'] as String,
      duration: s['duration']['text'] as String,
      maneuver: (s['maneuver'] ?? 'bus') as String,
    ))
        .toList();

    return RouteInfo(
      totalDistance: totalDistance,
      totalDuration: totalDuration,
      steps: steps,
    );
  }

  String _stripHtml(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ').trim();
  }
}