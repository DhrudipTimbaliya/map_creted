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
  final String? photoUrl; // આ પહેલા ફોટા માટે
  final List<ReviewModel> reviews;
  final List<String> types;
  final List<String> photoUrls; // આ બધા ફોટા માટે

  PlaceModel({
    required this.placeId,
    required this.name,
    required this.address,
    this.phone,
    this.website,
    this.rating,
    this.totalRatings,
    this.isOpen,
    required this.latitude,
    required this.longitude,
    this.photoUrl,
    required this.reviews,
    required this.types,
    this.photoUrls = const [],
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json, String apiKey) {
    var photosList = json['photos'] as List?;
    List<String> urls = [];
    String? firstPhoto;

    if (photosList != null && photosList.isNotEmpty) {
      urls = photosList.map((photo) {
        String ref = photo['photo_reference'];
        return "https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$ref&key=$apiKey";
      }).toList();

      // પ્રથમ ફોટો સેટ કરવો (બેકવર્ડ સુસંગતતા માટે)
      firstPhoto = urls.first;
    }

    return PlaceModel(
      placeId: json['place_id'] ?? "",
      name: json['name'] ?? "",
      address: json['formatted_address'] ?? "",
      phone: json['formatted_phone_number'],
      website: json['website'],
      rating: (json['rating'] ?? 0).toDouble(),
      totalRatings: json['user_ratings_total'],
      isOpen: json['opening_hours']?['open_now'],
      latitude: json['geometry']?['location']?['lat'] ?? 0.0,
      longitude: json['geometry']?['location']?['lng'] ?? 0.0,
      photoUrl: firstPhoto, // pUrl ને બદલે firstPhoto વાપર્યું
      photoUrls: urls,      // આખું લિસ્ટ પાસ કર્યું
      reviews: (json['reviews'] as List? ?? [])
          .map((e) => ReviewModel.fromJson(e))
          .toList(),
      types: List<String>.from(json['types'] ?? []),
    );
  }
}