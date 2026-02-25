import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dio/dio.dart' as dio_pkg;
import '../api/place_serviece.dart'; // તમારી API Key માટે

class ShowDirectionController extends GetxController {
  final dio_pkg.Dio _dio = dio_pkg.Dio();
  final String apiKey = PlacesService().apiKey;

  RxList<dynamic> steps = <dynamic>[].obs;
  RxString totalDistance = "".obs;
  RxString totalDuration = "".obs;
  RxBool isStepLoading = false.obs;

  // નેવિગેશન માટે ડેસ્ટિનેશન સ્ટોર કરવા
  LatLng? destinationLatLng;

  Future<void> fetchDirections(LatLng origin, LatLng destination) async {
    isStepLoading.value = true;
    destinationLatLng = destination; // સેવ ડેસ્ટિનેશન
    steps.clear();

    try {
      final response = await _dio.get(
        "https://maps.googleapis.com/maps/api/directions/json",
        queryParameters: {
          'origin': "${origin.latitude},${origin.longitude}",
          'destination': "${destination.latitude},${destination.longitude}",
          'mode': 'driving', // તમે અહીં બાઈક માટે 'two-wheeler' (Google Specific) પણ ટ્રાય કરી શકો
          'key': apiKey,
        },
      );

      if (response.data['status'] == 'OK') {
        var route = response.data['routes'][0]['legs'][0];
        totalDistance.value = route['distance']['text'];
        totalDuration.value = route['duration']['text'];
        steps.assignAll(route['steps']);
      }
    } catch (e) {
      print("Direction Error: $e");
    } finally {
      isStepLoading.value = false;
    }
  }

  // HTML ટેગ્સ કાઢવા માટે (જૂની એરર ફિક્સ)
  String cleanHtml(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>|&nbsp;'), ' ');
  }
}