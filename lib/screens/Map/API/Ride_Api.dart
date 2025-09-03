import 'dart:convert';
import 'dart:io';
import 'package:triprider/core/network/api_client.dart';

/// 주행기록 백엔드 연동 API
class RideApi {
  // 1) 라이딩 시작
  static Future<int> startRide() async {
    final res = await ApiClient.post('/api/rides/start');
    final Map<String, dynamic> data = jsonDecode(res.body) as Map<String, dynamic>;
    // 백엔드의 키 이름이 확정되면 아래를 단일 키로 교체
    final dynamic anyId = data['rideId'] ?? data['id'];
    if (anyId is int) return anyId;
    if (anyId is String) return int.tryParse(anyId) ?? anyId.hashCode;
    return data.hashCode;
  }

  // 2) 포인트 배치 업로드
  static Future<void> uploadPoints({required int rideId, required List<Map<String, dynamic>> points}) async {
    if (points.isEmpty) return;
    await ApiClient.post('/api/rides/$rideId/points', body: {
      'points': points,
    });
  }

  // 3) 라이딩 종료 + 스냅샷 업로드
  static Future<Map<String, dynamic>> finishRide({
    required int rideId,
    required Map<String, dynamic> body,
    File? snapshot,
  }) async {
    if (snapshot == null) {
      final res = await ApiClient.post('/api/rides/$rideId/finish', body: body);
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    final res = await ApiClient.multipart('/api/rides/$rideId/finish',
        fields: {'body': jsonEncode(body)}, files: {'snapshot': snapshot});
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // 4) 목록
  static Future<List<Map<String, dynamic>>> listRides() async {
    final res = await ApiClient.get('/api/rides');
    final List data = jsonDecode(res.body) as List;
    return data.cast<Map<String, dynamic>>();
  }

  // 5) 상세(withPolyline)
  static Future<Map<String, dynamic>> getRideDetail(int rideId, {bool withPolyline = false}) async {
    final res = await ApiClient.get('/api/rides/$rideId', query: {'withPolyline': withPolyline});
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // 6) 요약 통계
  static Future<Map<String, dynamic>> getSummary() async {
    final res = await ApiClient.get('/api/rides/stats/summary');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

