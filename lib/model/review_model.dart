class ReviewModel {
  final String authorName;
  final double rating;
  final String text;
  final String relativeTime;

  ReviewModel({
    required this.authorName,
    required this.rating,
    required this.text,
    required this.relativeTime,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      authorName: json['author_name'] ?? "Anonymous",
      rating: (json['rating'] ?? 0).toDouble(),
      text: json['text'] ?? "",
      relativeTime: json['relative_time_description'] ?? "",
    );
  }
}