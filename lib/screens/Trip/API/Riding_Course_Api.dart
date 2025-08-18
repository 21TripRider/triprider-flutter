import 'dart:convert';
import 'package:triprider/screens/RiderGram/Api_client.dart';
import 'package:triprider/screens/Trip/Riding_Course_Card.dart';

class LikeResult {
  final int likeCount;
  final bool liked;
  LikeResult({required this.likeCount, required this.liked});
  factory LikeResult.fromJson(Map<String, dynamic> j) => LikeResult(
    likeCount: (j['likeCount'] as num? ?? 0).toInt(),
    liked: j['liked'] as bool? ?? false,
  );
}

class RidingCourseApi {
  static const _base = '/api/travel/riding';

  /// 인기순 (이미 구현되어 있으면 그대로 써도 됨)
  static Future<List<RidingCourseCard>> fetchPopular({int limit = 10}) async {
    final res = await ApiClient.get('$_base/popular?limit=$limit');
    final List data = jsonDecode(res.body);
    return data.map((e) => RidingCourseCard.fromJson(e)).toList();
  }

  /// 총 코스 길이 기준 정렬: order = 'desc'(긴 코스 순) | 'asc'(짧은 코스 순)
  static Future<List<RidingCourseCard>> fetchByLength(String order) async {
    final res = await ApiClient.get('$_base/by-length?order=$order');
    final List data = jsonDecode(res.body);
    return data.map((e) => RidingCourseCard.fromJson(e)).toList();
  }

  static Future<LikeResult> like(String category, int id) async {
    final res = await ApiClient.post('$_base/$category/$id/likes');
    final Map<String, dynamic> data = jsonDecode(res.body);
    return LikeResult.fromJson(data);
  }

  static Future<LikeResult> unlike(String category, int id) async {
    final res = await ApiClient.delete('$_base/$category/$id/likes');
    final Map<String, dynamic> data = jsonDecode(res.body);
    return LikeResult.fromJson(data);
  }
}
