// lib/screens/trip/models/riding_course_card.dart
class RidingCourseCard {
  final int id;
  final String category;            // ex) coastal-course
  final String title;
  final String? coverImageUrl;      // /images/... or http...
  final int totalDistanceMeters;
  final int likeCount;
  final bool liked;

  RidingCourseCard({
    required this.id,
    required this.category,
    required this.title,
    required this.coverImageUrl,
    required this.totalDistanceMeters,
    required this.likeCount,
    required this.liked,
  });

  factory RidingCourseCard.fromJson(Map<String, dynamic> j) {
    return RidingCourseCard(
      id: (j['id'] as num).toInt(),
      category: j['category'] ?? '',
      title: j['title'] ?? '',
      coverImageUrl: j['coverImageUrl'],
      totalDistanceMeters: (j['totalDistanceMeters'] as num? ?? 0).toInt(),
      likeCount: (j['likeCount'] as num? ?? 0).toInt(),
      liked: j['liked'] as bool? ?? false,
    );
  }

  RidingCourseCard copyWith({int? likeCount, bool? liked}) {
    return RidingCourseCard(
      id: id,
      category: category,
      title: title,
      coverImageUrl: coverImageUrl,
      totalDistanceMeters: totalDistanceMeters,
      likeCount: likeCount ?? this.likeCount,
      liked: liked ?? this.liked,
    );
  }
}
