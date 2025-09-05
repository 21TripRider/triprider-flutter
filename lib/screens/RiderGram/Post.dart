// lib/screens/RiderGram/Post.dart
class PostModel {
  final int id;
  final String content;
  final String? imageUrl;
  final String? location;
  final String? hashtags;

  // 작성자 관련
  final int? writerId;                 // 서버에 있으면 사용
  final String writer;                 // 표시용 이름
  final String? writerProfileImage;    // 프로필 이미지 URL

  // 상태
  final int likeCount;
  final bool liked;
  final int commentCount;

  PostModel({
    required this.id,
    required this.content,
    required this.writer,
    required this.likeCount,
    required this.commentCount,
    this.imageUrl,
    this.location,
    this.hashtags,
    this.writerId,
    this.writerProfileImage,
    this.liked = false,
  });

  // 안전한 int? 파서
  static int? _asIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  factory PostModel.fromJson(Map<String, dynamic> j) {
    final wid = _asIntOrNull(
      j['writerId'] ?? j['authorId'] ?? j['userId'] ?? j['uid'] ?? j['ownerId'],
    );

    return PostModel(
      id: (j['id'] as num).toInt(),
      content: (j['content'] ?? '') as String,
      imageUrl: j['imageUrl'] as String?,
      location: j['location'] as String?,
      hashtags: j['hashtags'] as String?,

      // 작성자
      writerId: wid,
      writer: (j['writer'] ?? j['author'] ?? '익명') as String,
      writerProfileImage: (j['writerProfileImage'] ??
          j['writerImage'] ??
          j['profileImage']) as String?,

      // 상태
      likeCount: (j['likeCount'] ?? 0 as num).toInt(),
      liked: (j['liked'] ?? false) as bool,
      commentCount: (j['commentCount'] ?? 0 as num).toInt(),
    );
  }

  PostModel copyWith({
    int? likeCount,
    bool? liked,
    int? commentCount,
  }) =>
      PostModel(
        id: id,
        content: content,
        writer: writer,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        imageUrl: imageUrl,
        location: location,
        hashtags: hashtags,
        liked: liked ?? this.liked,
        writerId: writerId,
        writerProfileImage: writerProfileImage,
      );
}
