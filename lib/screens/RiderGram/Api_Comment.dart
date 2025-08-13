// lib/screens/RiderGram/api_comment.dart
import 'dart:convert';
import 'package:triprider/screens/RiderGram/Api_client.dart';
import 'package:triprider/screens/RiderGram/Comment_Model.dart';

class CommentApi {
  /// 댓글 목록 조회
  static Future<List<CommentModel>> list(int postId) async {
    final res = await ApiClient.get('/api/posts/$postId/comments');
    final List data = jsonDecode(res.body);
    return data.map((e) => CommentModel.fromJson(e)).toList();
  }

  /// 댓글 작성
  static Future<void> create(int postId, String content) async {
    await ApiClient.post(
      '/api/posts/$postId/comments',
      body: {'content': content}, // ApiClient가 JSON 인코딩 + 헤더 처리
    );
  }

  /// 댓글 삭제 (본인만 가능)
  static Future<void> delete(int postId, int commentId) async {
    await ApiClient.delete('/api/posts/$postId/comments/$commentId');
  }
}
