// lib/screens/RiderGram/Comment_Model.dart
class CommentModel {
  final int id;
  final String user;           // 닉네임
  final String content;
  final DateTime createdAt;
  final bool mine;

  // 작성자 식별/이미지 (있으면 사용)
  final int? userId;
  final String? profileImage;

  // 좋아요
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
    this.userId,
    this.profileImage,
  });

  factory CommentModel.fromJson(Map<String, dynamic> j) {
    // createdAt 파싱
    final createdStr = (j['createdAt'] ?? '') as String;
    DateTime created;
    try {
      created = DateTime.parse(createdStr);
    } catch (_) {
      try {
        created = DateTime.parse(createdStr.replaceFirst(' ', 'T'));
      } catch (_) {
        created = DateTime.now();
      }
    }

    // 🔎 다양한 필드/중첩에서 userId 찾기
    int? parseInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    Map<String, dynamic>? asMap(dynamic v) =>
        (v is Map) ? v.cast<String, dynamic>() : null;

    final nestedUser = asMap(j['user']) ?? asMap(j['author']) ?? asMap(j['writer']) ?? asMap(j['userInfo']);

    final int? uid = parseInt(
      j['userId'] ?? j['writerId'] ?? j['authorId'] ??
          nestedUser?['id'] ?? nestedUser?['userId'] ?? nestedUser?['writerId'],
    );

    // 🔎 프로필 이미지 키 폭넓게
    String? firstString(Map<String, dynamic> m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    String? img = firstString(j, [
      'profileImage', 'writerProfileImage', 'userProfileImage',
      'profile_image', 'avatarUrl', 'avatar', 'imageUrl', 'photoUrl', 'url'
    ]) ?? (nestedUser != null
        ? firstString(nestedUser, [
      'profileImage','profile_image','avatarUrl','imageUrl','photoUrl','url'
    ])
        : null);

    return CommentModel(
      id: (j['id'] as num).toInt(),
      user: (j['user'] ?? j['writer'] ?? j['author'] ?? nestedUser?['nickname'] ?? '익명') as String,
      content: (j['content'] ?? '') as String,
      createdAt: created,
      mine: (j['mine'] ?? false) as bool,
      likeCount: (j['likeCount'] is int)
          ? j['likeCount'] as int
          : ((j['likeCount'] as num?)?.toInt() ?? 0),
      likedByMe: (j['likedByMe'] ?? false) as bool,
      userId: uid,
      profileImage: img,
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
      userId: userId,
      profileImage: profileImage,
    );
  }
}
