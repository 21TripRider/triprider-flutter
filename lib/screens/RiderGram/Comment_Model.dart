class CommentModel {
  final int id;
  final String user;
  final String content;
  final DateTime createdAt;
  final bool mine;

  // ✅ 추가
  final int likeCount;
  final bool likedByMe;

  CommentModel({
    required this.id,
    required this.user,
    required this.content,
    required this.createdAt,
    required this.mine,
    required this.likeCount,
    required this.likedByMe,
  });

  factory CommentModel.fromJson(Map<String, dynamic> j) {
    final createdStr = (j['createdAt'] ?? '') as String;
    DateTime created;
    try {
      created = DateTime.parse(createdStr); // ISO면 그대로
    } catch (_) {
      // 백엔드 "yyyy-MM-dd HH:mm" 형태 대응
      try {
        created = DateTime.parse(createdStr.replaceFirst(' ', 'T'));
      } catch (_) {
        created = DateTime.now();
      }
    }

    return CommentModel(
      id: (j['id'] as num).toInt(),
      user: j['user'] as String,
      content: j['content'] as String,
      createdAt: created,
      mine: (j['mine'] ?? false) as bool,
      likeCount: (j['likeCount'] is int)
          ? j['likeCount'] as int
          : ((j['likeCount'] as num?)?.toInt() ?? 0),
      likedByMe: (j['likedByMe'] ?? false) as bool,
    );
  }

  CommentModel copyWith({
    int? likeCount,
    bool? likedByMe,
  }) {
    return CommentModel(
      id: id,
      user: user,
      content: content,
      createdAt: createdAt,
      mine: mine,
      likeCount: likeCount ?? this.likeCount,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }
}
