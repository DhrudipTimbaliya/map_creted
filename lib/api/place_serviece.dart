import 'package:dio/dio.dart';
import '../model/place_model.dart';


class PlacesService {
  final Dio _dio = Dio();
  final String apiKey = "AIzaSyB4OsZKR2hF7xBBCJR8sM2b6xf17v5DWZs";

  Future<PlaceModel> getPlaceDetails(String placeId) async {
    try {
      final response = await _dio.get(
        "https://maps.googleapis.com/maps/api/place/details/json",
        queryParameters: {
          'place_id': placeId,
          'fields': 'place_id,name,formatted_address,formatted_phone_number,rating,user_ratings_total,opening_hours,website,geometry,photos,reviews,types',
          'key': apiKey,
        },
      );

      if (response.data['status'] == 'OK') {
        return PlaceModel.fromJson(response.data['result'], apiKey);
      } else {
        throw Exception("API Error: ${response.data['status']}");
      }
    } catch (e) {
      throw Exception("Failed to load place details: $e");
    }
  }
}