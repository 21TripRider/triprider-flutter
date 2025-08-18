import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 카테고리(칩 라벨)
enum NearbyCategory {
  tourist('관광지'),
  culture('문화시설'),
  festival('축제공연행사'),
  leports('레포츠'),
  lodging('숙박'),
  shopping('쇼핑'),
  food('음식점');

  const NearbyCategory(this.title);
  final String title;
}

/// 화면에 뿌릴 POI 모델(간단 버전)
class NearbyItem {
  final String id;
  final String title;
  final String? addr;
  final double lat;
  final double lng;
  final String? thumbUrl;
  final double? distanceM;

  NearbyItem({
    required this.id,
    required this.title,
    required this.lat,
    required this.lng,
    this.addr,
    this.thumbUrl,
    this.distanceM,
  });
}

/// 백엔드 붙이기 전까지 더미 생성기
class NearbyApi {
  /// 실제로는 백엔드로 bounds/center 넘겨서 카테고리별 페이징 조회하면 됨.
  static Future<List<NearbyItem>> fetch(
      NearbyCategory cat, LatLngBounds bounds) async {
    // 더미: bounds 안에서 무작위 좌표 10개
    final rnd = Random(cat.index + DateTime.now().millisecondsSinceEpoch);
    final double minLat = min(bounds.southwest.latitude, bounds.northeast.latitude);
    final double maxLat = max(bounds.southwest.latitude, bounds.northeast.latitude);
    final double minLng = min(bounds.southwest.longitude, bounds.northeast.longitude);
    final double maxLng = max(bounds.southwest.longitude, bounds.northeast.longitude);

    List<NearbyItem> items = List.generate(10, (i) {
      final lat = minLat + rnd.nextDouble() * (maxLat - minLat);
      final lng = minLng + rnd.nextDouble() * (maxLng - minLng);
      return NearbyItem(
        id: '${cat.name}-$i',
        title: '${cat.title} 샘플 ${i + 1}',
        addr: '제주특별자치도 어딘가 ${100 + i}',
        lat: lat,
        lng: lng,
        thumbUrl: 'https://picsum.photos/seed/${cat.name}-$i/200/200',
        distanceM: rnd.nextDouble() * 15000, // 0~15km
      );
    });

    await Future.delayed(const Duration(milliseconds: 300));
    return items;
  }
}
