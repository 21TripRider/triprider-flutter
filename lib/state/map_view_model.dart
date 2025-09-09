// lib/state/map_view_model.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import '../data/kakao_local_api.dart';
import '../models/place.dart';
import '../controllers/map_controller.dart';

class MapViewModel {
  MapViewModel({required this.api, required this.controller});
  final KakaoLocalApi api;
  final MapController controller;

  String activeFilter = 'none';
  List<Place> pois = <Place>[];
  bool loading = false;
  Timer? _debounce;
  String? lastError;

  Future<void> recenter(double lat, double lon, int zoom) async {
    await controller.animateTo(lat, lon, zoom);
    await controller.setUser(lat, lon);
  }

  Future<void> refreshPois(double lat, double lon) async {
    if (activeFilter == 'none') return;
    if (loading) return;
    loading = true;
    try {
      if (activeFilter == 'gas') {
        pois = await api.fetchCategory(code: 'OL7', lat: lat, lon: lon);
        final labels = <Map<String, dynamic>>[];
        int id = 200000;
        for (final p in pois) {
          labels.add({'name': '⛽ ${p.name}', 'lat': p.lat, 'lon': p.lon, 'id': id++});
        }
        await controller.setLabels(labels);
      } else if (activeFilter == 'moto') {
        final keys = ['오토바이', '바이크', '모터사이클', '스쿠터', '오토바이 정비', '오토바이 렌트'];
        final futures = keys.map((q) => api.fetchKeyword(query: q, lat: lat, lon: lon));
        final lists = await Future.wait(futures);
        final seen = <String>{};
        final out = <Place>[];
        for (final list in lists) {
          for (final p in list) {
            final key = '${p.lat},${p.lon},${p.name}';
            if (seen.add(key)) out.add(p);
          }
        }
        pois = out;
        final labels = <Map<String, dynamic>>[];
        int id = 230000;
        for (final p in pois) {
          labels.add({'name': '🏍️ ${p.name}', 'lat': p.lat, 'lon': p.lon, 'id': id++});
        }
        await controller.setLabels(labels);
      }
    } finally {
      loading = false;
    }
  }

  List<Map<String, dynamic>> toMapList() {
    final out = <Map<String, dynamic>>[];
    int id = 200000;
    for (final p in pois) {
      out.add({'name': p.name, 'lat': p.lat, 'lon': p.lon, 'id': id++});
    }
    return out;
  }
}
