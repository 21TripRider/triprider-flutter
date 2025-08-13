// lib/screens/RiderGram/Post.dart
class PostModel {
  final int id;
  final String content;
  final String? imageUrl;
  final String? location;
  final String? hashtags;
  final String writer;
  final int likeCount;
  final bool liked; // ★ 추가

  PostModel({
    required this.id,
    required this.content,
    required this.writer,
    required this.likeCount,
    this.imageUrl,
    this.location,
    this.hashtags,
    this.liked = false,
  });

  factory PostModel.fromJson(Map<String, dynamic> j) => PostModel(
    id: j['id'],
    content: j['content'] ?? '',
    imageUrl: j['imageUrl'],
    location: j['location'],
    hashtags: j['hashtags'],
    writer: j['writer'] ?? '익명',
    likeCount: j['likeCount'] ?? 0,
    liked: j['liked'] ?? false, // ★ 서버값 사용
  );

  PostModel copyWith({int? likeCount, bool? liked}) => PostModel(
    id: id,
    content: content,
    writer: writer,
    likeCount: likeCount ?? this.likeCount,
    imageUrl: imageUrl,
    location: location,
    hashtags: hashtags,
    liked: liked ?? this.liked,
  );
}
