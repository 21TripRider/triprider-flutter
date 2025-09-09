// lib/utils/route_loader.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

final Map<String, List<LatLng>> _routeCache = {};

Future<List<LatLng>> loadRoute(String assetPath) async {
  if (_routeCache.containsKey(assetPath)) return _routeCache[assetPath]!;

  final raw = await rootBundle.loadString(assetPath);
  final data = jsonDecode(raw);

  if (data is Map && data['routes'] is List && (data['routes'] as List).isNotEmpty) {
    final r0 = (data['routes'] as List).first;
    final geom = r0['geometry'];
    if (geom is Map && geom['type'] == 'LineString' && geom['coordinates'] is List) {
      final coords = (geom['coordinates'] as List)
          .map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      _routeCache[assetPath] = coords;
      return coords;
    }
    if (r0['overview_polyline'] is Map && r0['overview_polyline']['points'] is String) {
      final encoded = r0['overview_polyline']['points'] as String;
      final decoded = PolylinePoints().decodePolyline(encoded);
      final coords = decoded.map((p) => LatLng(p.latitude, p.longitude)).toList();
      _routeCache[assetPath] = coords;
      return coords;
    }
  }

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

Future<Map<String, List<LatLng>>> loadRoutes(Iterable<String> assetPaths) async {
  final out = <String, List<LatLng>>{};
  for (final p in assetPaths) {
    out[p] = await loadRoute(p);
  }
  return out;
}

Future<Map<String, List<LatLng>>> loadRoutesFromIndex(String indexAssetPath) async {
  final raw = await rootBundle.loadString(indexAssetPath);
  final List files = jsonDecode(raw);
  final paths = files.cast<String>();
  return loadRoutes(paths);
}

void clearRouteCache() => _routeCache.clear();
