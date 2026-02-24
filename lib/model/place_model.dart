import 'review_model.dart';

class PlaceModel {
  final String placeId;
  final String name;
  final String address;
  final String? phone;
  final String? website;
  final double? rating;
  final int? totalRatings;
  final bool? isOpen;
  final double latitude;
  final double longitude;
  final String? photoUrl;
  final List<ReviewModel> reviews;
  final List<String> types;

  PlaceModel({
    required this.placeId, required this.name, required this.address,
    this.phone, this.website, this.rating, this.totalRatings,
    this.isOpen, required this.latitude, required this.longitude,
    this.photoUrl, required this.reviews, required this.types,
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json, String apiKey) {
    var photos = json['photos'] as List?;
    String? pUrl;
    if (photos != null && photos.isNotEmpty) {
      String ref = photos[0]['photo_reference'];
      pUrl = "https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$ref&key=$apiKey";
    }

    return PlaceModel(
      placeId: json['place_id'],
      name: json['name'] ?? "",
      address: json['formatted_address'] ?? "",
      phone: json['formatted_phone_number'],
      website: json['website'],
      rating: (json['rating'] ?? 0).toDouble(),
      totalRatings: json['user_ratings_total'],
      isOpen: json['opening_hours']?['open_now'],
      latitude: json['geometry']['location']['lat'],
      longitude: json['geometry']['location']['lng'],
      photoUrl: pUrl,
      reviews: (json['reviews'] as List? ?? []).map((e) => ReviewModel.fromJson(e)).toList(),
      types: List<String>.from(json['types'] ?? []),
    );
  }
}