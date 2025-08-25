import 'dart:convert';
import 'package:triprider/screens/RiderGram/Api_client.dart';
import 'package:triprider/screens/RiderGram/Comment_Model.dart';

class CommentApi {
  /// 댓글 목록 조회 (백엔드가 likeCount/likedByMe 포함해서 내려줌)
  static Future<List<CommentModel>> list(int postId) async {
    final res = await ApiClient.get('/api/posts/$postId/comments');
    final List data = jsonDecode(res.body);
    return data.map((e) => CommentModel.fromJson(e)).toList();
  }

  /// 댓글 작성
  static Future<void> create(int postId, String content) async {
    await ApiClient.post(
      '/api/posts/$postId/comments',
      body: {'content': content},
    );
  }

  /// 댓글 삭제 (본인만 가능)
  static Future<void> delete(int postId, int commentId) async {
    await ApiClient.delete('/api/posts/$postId/comments/$commentId');
  }

  // ================== 👍 댓글 좋아요 관련 ==================

  /// 좋아요
  static Future<int> like(int postId, int commentId) async {
    final res = await ApiClient.post('/api/posts/$postId/comments/$commentId/likes');
    return _parseCount(res.body);
  }

  /// 좋아요 취소
  static Future<int> unlike(int postId, int commentId) async {
    final res = await ApiClient.delete('/api/posts/$postId/comments/$commentId/likes');
    return _parseCount(res.body);
  }

  /// 좋아요 개수
  static Future<int> count(int postId, int commentId) async {
    final res = await ApiClient.get('/api/posts/$postId/comments/$commentId/likes/count');
    return _parseCount(res.body);
  }

  /// 내가 좋아요 눌렀는지
  static Future<bool> likedByMe(int postId, int commentId) async {
    final res = await ApiClient.get('/api/posts/$postId/comments/$commentId/likes/me');
    final body = res.body.trim();
    if (body == 'true' || body == 'false') return body == 'true';
    final decoded = jsonDecode(body);
    if (decoded is bool) return decoded;
    if (decoded is String) return decoded.toLowerCase() == 'true';
    return false;
  }

  // 서버가 long/숫자/json 등으로 응답해도 안전 파싱
  static int _parseCount(String body) {
    final s = body.trim();
    final asInt = int.tryParse(s);
    if (asInt != null) return asInt;
    final v = jsonDecode(s);
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}