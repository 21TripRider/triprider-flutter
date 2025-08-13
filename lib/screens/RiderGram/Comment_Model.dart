// lib/screens/RiderGram/Comment_Model.dart
class CommentModel {
  final int id;
  final String user;
  final String content;
  final DateTime createdAt;
  final bool mine;

  CommentModel({
    required this.id,
    required this.user,
    required this.content,
    required this.createdAt,
    required this.mine,
  });

  factory CommentModel.fromJson(Map<String, dynamic> j) {
    return CommentModel(
      id: (j['id'] as num).toInt(),
      user: j['user'] as String,
      content: j['content'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
      mine: (j['mine'] ?? false) as bool,
    );
  }
}
