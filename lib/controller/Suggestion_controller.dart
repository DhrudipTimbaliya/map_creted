import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SuggestionController extends GetxController {
  final String apiKey = "AIzaSyB4OsZKR2hF7xBBCJR8sM2b6xf17v5DWZs"; // replace with your key
  var suggestions = <String>[].obs; // suggestions list

  /// Fetch place suggestions from Google Places API as user types
  Future<void> searchPlace(String input) async {
    if (input.isEmpty) {
      suggestions.clear();
      return;
    }

    final url =
        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$apiKey&types=geocode";

    try {
      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body);

      if (data["status"] == "OK") {
        final predictions = data["predictions"] as List;
        suggestions.value =
            predictions.map((e) => e["description"].toString()).toList();
      } else {
        suggestions.clear();
      }
    } catch (e) {
      suggestions.clear();
    }
  }

  /// Optional: Convert selected address to LatLng
  Future<LatLng?> getLatLngFromAddress(String address) async {
    final url =
        "https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$apiKey";

    final response = await http.get(Uri.parse(url));
    final data = jsonDecode(response.body);

    if (data["status"] == "OK" && data["results"].isNotEmpty) {
      final location = data["results"][0]["geometry"]["location"];
      return LatLng(location["lat"], location["lng"]);
    }
    return null;
  }
}