import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:triprider/core/network/Api_client.dart';

/// 백엔드 카테고리와 1:1 매핑된 섹터
enum NearbyCategory {
  tourist('관광지'),
  culture('문화시설'),
  event('행사/공연/축제'),
  leports('레포츠'),
  stay('숙박'),
  shop('쇼핑'),
  food('음식점');

  const NearbyCategory(this.title);
  final String title;
}

/// UI용 POI 모델
class NearbyItem {
  final String id;
  final String title;
  final String? addr;
  final String? tel;
  final String thumbUrl;
  final double lat;
  final double lng;
  final int? distanceM;
  final int? contentTypeId;

  NearbyItem({
    required this.id,
    required this.title,
    required this.lat,
    required this.lng,
    required this.thumbUrl,
    this.addr,
    this.tel,
    this.distanceM,
    this.contentTypeId,
  });
}

class NearbyApi {
  // only= 파라미터 변환
  static String _only(NearbyCategory cat) {
    switch (cat) {
      case NearbyCategory.tourist: return 'tour';
      case NearbyCategory.culture: return 'culture';
      case NearbyCategory.event:   return 'event';
      case NearbyCategory.leports: return 'leports';
      case NearbyCategory.stay:    return 'stay';
      case NearbyCategory.shop:    return 'shop';
      case NearbyCategory.food:    return 'food';
    }
  }

  /// 카테고리별 디폴트 이미지
  static String defaultImage(NearbyCategory cat) {
    switch (cat) {
      case NearbyCategory.tourist: return 'assets/image/tour.png';
      case NearbyCategory.culture: return 'assets/image/culture.png';
      case NearbyCategory.event:   return 'assets/image/event.png';
      case NearbyCategory.leports: return 'assets/image/leports.png';
      case NearbyCategory.stay:    return 'assets/image/stay.png';
      case NearbyCategory.shop:    return 'assets/image/shop.png';
      case NearbyCategory.food:    return 'assets/image/food.png';
    }
  }

  /// 코스 기준(카테고리/ID) 주변 장소
  static Future<List<NearbyItem>> fetchByCourse(
      NearbyCategory cat, {
        required String courseCategory,
        required int courseId,
        int radius = 3000,
        int size = 8,
        String mode = 'sme', // 'sme' | 'along'
        int count = 5,       // mode=along일 때 분할 포인트 수
      }) async {
    final url =
        '/api/travel/nearby/$courseCategory/$courseId'
        '?only=${_only(cat)}&radius=$radius&size=$size&mode=$mode&count=$count';
    final res = await ApiClient.get(url);
    final raw = jsonDecode(res.body);
    return _parseList(raw, cat);
  }

  /// 임의 좌표 기준 주변 장소 (지도의 중심으로 재검색할 때 사용)
  static Future<List<NearbyItem>> fetchByPoint(
      NearbyCategory cat, {
        required double lat,
        required double lng,
        int radius = 3000,
        int size = 8,
      }) async {
    final url =
        '/api/travel/nearby/point?lat=$lat&lng=$lng'
        '&only=${_only(cat)}&radius=$radius&size=$size';
    final res = await ApiClient.get(url);
    final raw = jsonDecode(res.body);
    return _parseList(raw, cat);
  }

  // ───────────────────────────── internal ─────────────────────────────

  /// 서버가 배열로 주든(Map으로 전체 카테고리를 주든) 모두 안전하게 파싱
  static List<NearbyItem> _parseList(dynamic json, NearbyCategory cat) {
    // case A: 기대 형태(리스트)
    if (json is List) {
      return json.map<NearbyItem>((e) {
        final m = (e as Map).cast<String, dynamic>();
        final contentId = m['contentId'];
        final title = (m['title'] as String?) ?? '';
        final lat = (m['lat'] as num).toDouble();
        final lng = (m['lng'] as num).toDouble();
        final id = (contentId == null || contentId == 0)
            ? 't:$title|${(lat * 1e4).round()}|${(lng * 1e4).round()}'
            : 'id:$contentId';

        // API 응답 이미지 (없으면 카테고리 기본이미지)
        final image = m['image'] as String?;
        final thumb = (image != null && image.isNotEmpty)
            ? image
            : NearbyApi.defaultImage(cat);

        return NearbyItem(
          id: id,
          title: title,
          addr: m['addr'] as String?,
          tel: m['tel'] as String?,
          thumbUrl: thumb,
          lat: lat,
          lng: lng,
          distanceM: (m['distMeters'] as num?)?.toInt(),
          contentTypeId: (m['contentTypeId'] as num?)?.toInt(),
        );
      }).toList(growable: false);
    }

    // case B: 맵 형태({"tour":[...], "food":[...]})로 온 경우 현재 카테고리 키만 뽑아서 재귀 파싱
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      final key = _only(cat);
      final val = map[key];
      if (val is List) {
        return _parseList(val, cat);
      }
    }

    return const [];
  }
}
