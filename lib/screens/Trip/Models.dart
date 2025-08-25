// lib/screens/trip/models.dart
import 'dart:convert';

/// ===== Category Tree =====
class CategoryNode {
  final String code;
  final String name;
  final List<CategoryNode> cat2;
  final List<CategoryNode> cat3;
  CategoryNode({
    required this.code,
    required this.name,
    this.cat2 = const [],
    this.cat3 = const [],
  });

  factory CategoryNode.fromJson(Map<String, dynamic> j) => CategoryNode(
    code: j['code'] ?? '',
    name: j['name'] ?? '',
    cat2: ((j['cat2'] ?? []) as List)
        .map((e) => CategoryNode.fromJson(e))
        .toList(),
    cat3: ((j['cat3'] ?? []) as List)
        .map((e) => CategoryNode.fromJson(e))
        .toList(),
  );
}

class CategoryTreeDto {
  final int contentTypeId; // 12/14/15/28/32/38/39 ...
  final List<CategoryNode> cat1;
  CategoryTreeDto({required this.contentTypeId, required this.cat1});
  factory CategoryTreeDto.fromJson(Map<String, dynamic> j) => CategoryTreeDto(
    contentTypeId: j['contentTypeId'] ?? 0,
    cat1: ((j['cat1'] ?? []) as List)
        .map((e) => CategoryNode.fromJson(e))
        .toList(),
  );
}

/// ===== Nearby Place =====
class NearbyPlace {
  final String? contentId;
  final String title;
  final String addr;
  final String? image;
  final double lat;
  final double lng;
  final int? distMeters;
  final int? contentTypeId;
  final String? cat1, cat2, cat3;
  NearbyPlace({
    this.contentId,
    required this.title,
    required this.addr,
    required this.lat,
    required this.lng,
    this.image,
    this.distMeters,
    this.contentTypeId,
    this.cat1,
    this.cat2,
    this.cat3,
  });

  factory NearbyPlace.fromJson(Map<String, dynamic> j) => NearbyPlace(
    contentId: (j['contentId']?.toString()),
    title: j['title'] ?? '',
    addr: j['addr'] ?? '',
    image: j['image'],
    lat: (j['lat'] ?? 0).toDouble(),
    lng: (j['lng'] ?? 0).toDouble(),
    distMeters: j['distMeters'],
    contentTypeId: j['contentTypeId'],
    cat1: j['cat1'],
    cat2: j['cat2'],
    cat3: j['cat3'],
  );
}

/// ===== Course =====
class Waypoint {
  final int order;
  final String? contentId;
  final String? type;
  final String title;
  final double lat, lng;
  final String? cat1, cat2, cat3;
  final int? contentTypeId;
  Waypoint({
    required this.order,
    required this.title,
    required this.lat,
    required this.lng,
    this.contentId,
    this.type,
    this.cat1,
    this.cat2,
    this.cat3,
    this.contentTypeId,
  });

  factory Waypoint.fromJson(Map<String, dynamic> j) => Waypoint(
    order: j['order'] ?? 0,
    contentId: j['contentId'],
    type: j['type'],
    title: j['title'] ?? '',
    lat: (j['lat'] ?? 0).toDouble(),
    lng: (j['lng'] ?? 0).toDouble(),
    cat1: j['cat1'],
    cat2: j['cat2'],
    cat3: j['cat3'],
    contentTypeId: j['contentTypeId'],
  );

  Map<String, dynamic> toJson() => {
    'order': order,
    'contentId': contentId,
    'type': type,
    'title': title,
    'lat': lat,
    'lng': lng,
    'cat1': cat1,
    'cat2': cat2,
    'cat3': cat3,
    'contentTypeId': contentTypeId,
  };
}

class CoursePreview {
  final List<Waypoint> waypoints;
  final double distanceKm;
  final int durationMin;
  final String? polyline;
  CoursePreview({
    required this.waypoints,
    required this.distanceKm,
    required this.durationMin,
    this.polyline,
  });

  factory CoursePreview.fromJson(Map<String, dynamic> j) => CoursePreview(
    waypoints: ((j['waypoints'] ?? []) as List)
        .map((e) => Waypoint.fromJson(e))
        .toList(),
    distanceKm: (j['distanceKm'] ?? 0).toDouble(),
    durationMin: j['durationMin'] ?? 0,
    polyline: j['polyline'],
  );
}

class CourseView {
  final String id;
  final String title;
  final List<Waypoint> waypoints;
  final double distanceKm;
  final int durationMin;
  final String? polyline;
  final String? createdAt;
  CourseView({
    required this.id,
    required this.title,
    required this.waypoints,
    required this.distanceKm,
    required this.durationMin,
    this.polyline,
    this.createdAt,
  });

  factory CourseView.fromJson(Map<String, dynamic> j) => CourseView(
    id: j['id'] ?? '',
    title: j['title'] ?? '나의 여행 코스',
    waypoints: ((j['waypoints'] ?? []) as List)
        .map((e) => Waypoint.fromJson(e))
        .toList(),
    distanceKm: (j['distanceKm'] ?? 0).toDouble(),
    durationMin: j['durationMin'] ?? 0,
    polyline: j['polyline'],
    createdAt: j['createdAt'],
  );
}

class CourseCard {
  final String id;
  final String title;
  final String stopsPreview;
  final String? createdAt;
  CourseCard({
    required this.id,
    required this.title,
    required this.stopsPreview,
    this.createdAt,
  });

  factory CourseCard.fromJson(Map<String, dynamic> j) => CourseCard(
    id: j['id'] ?? '',
    title: j['title'] ?? '',
    stopsPreview: j['stopsPreview'] ?? '',
    createdAt: j['createdAt'],
  );
}

/// ===== 선택 섹터 =====
/// 백엔드 검색과 완전 연동: (cat1/2/3) 또는 presetKey 로 조회
class CategoryOption {
  final String type; // 'tour' | 'food' | 'leports' | 'culture' | 'event' | 'shop'
  final String? cat1;
  final String? cat2;
  final String? cat3;
  final String label; // UI 표시명
  /// PresetResolver 키 (예: 'food.korean', 'culture.museum' ...)
  final String? presetKey;

  CategoryOption({
    required this.type,
    required this.label,
    this.cat1,
    this.cat2,
    this.cat3,
    this.presetKey,
  });

  @override
  String toString() =>
      'CategoryOption($type, ${cat1 ?? "-"}, ${cat2 ?? "-"}, ${cat3 ?? "-"}, preset=$presetKey)';
}
