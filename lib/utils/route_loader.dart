// lib/utils/route_loader.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

/// 간단 메모리 캐시: 동일 assetPath를 여러 화면에서 반복 호출해도 디스크 I/O 최소화
final Map<String, List<LatLng>> _routeCache = {};

/// 경로 파일을 로드해 LatLng 리스트로 반환.
/// - ORS JSON: routes[0].geometry.coordinates (LineString) 또는 overview_polyline.points
/// - GeoJSON:  features[0].geometry.coordinates (LineString)
/// 좌표는 [lng, lat, (elev?)] → LatLng(lat, lng) 로 변환.
Future<List<LatLng>> loadRoute(String assetPath) async {
  if (_routeCache.containsKey(assetPath)) return _routeCache[assetPath]!;

  final raw = await rootBundle.loadString(assetPath);
  final data = jsonDecode(raw);

  // ===== ORS JSON 케이스 =====
  if (data is Map && data['routes'] is List && (data['routes'] as List).isNotEmpty) {
    final r0 = (data['routes'] as List).first;

    // (A) LineString 좌표가 있는 경우
    final geom = r0['geometry'];
    if (geom is Map && geom['type'] == 'LineString' && geom['coordinates'] is List) {
      final coords = (geom['coordinates'] as List)
          .map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      _routeCache[assetPath] = coords;
      return coords;
    }

    // (B) 인코딩된 폴리라인만 있는 경우 (overview_polyline.points)
    if (r0['overview_polyline'] is Map && r0['overview_polyline']['points'] is String) {
      final encoded = r0['overview_polyline']['points'] as String;
      final decoded = PolylinePoints().decodePolyline(encoded);
      final coords = decoded.map((p) => LatLng(p.latitude, p.longitude)).toList();
      _routeCache[assetPath] = coords;
      return coords;
    }
  }

  // ===== GeoJSON 케이스 =====
  if (data is Map && data['features'] is List && (data['features'] as List).isNotEmpty) {
    final f0 = (data['features'] as List).first;
    final geom = (f0 is Map) ? f0['geometry'] : null;
    if (geom is Map && geom['type'] == 'LineString' && geom['coordinates'] is List) {
      final coords = (geom['coordinates'] as List)
          .map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      _routeCache[assetPath] = coords;
      return coords;
    }
  }

  throw FormatException('지원하지 않는 경로 포맷 또는 좌표가 없습니다: $assetPath');
}

/// 여러 경로를 한 번에 로드하고 싶을 때 사용.
/// 반환값: { 'assetPath': [LatLng, ...], ... }
Future<Map<String, List<LatLng>>> loadRoutes(Iterable<String> assetPaths) async {
  final out = <String, List<LatLng>>{};
  for (final p in assetPaths) {
    out[p] = await loadRoute(p);
  }
  return out;
}

/// index.json 같은 파일에 ["path1.json","path2.json",...] 형태로
/// 리스트를 넣어두고, 그 파일로부터 일괄 로드하고 싶을 때.
Future<Map<String, List<LatLng>>> loadRoutesFromIndex(String indexAssetPath) async {
  final raw = await rootBundle.loadString(indexAssetPath);
  final List files = jsonDecode(raw);
  final paths = files.cast<String>();
  return loadRoutes(paths);
}

/// 필요시 캐시를 비우고 새로 로드하고 싶을 때 호출.
void clearRouteCache() => _routeCache.clear();
