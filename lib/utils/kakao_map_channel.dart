import 'package:flutter/services.dart';

/// Kakao Map platform channel wrapper
/// - 새로 추가: setRoutePolyline / clearRoutePolyline / setMarkers / clearMarkers / setUserLocationVisible
/// - 네이티브에 메서드가 없어도 동작하도록 폴백 처리(라벨/기존 폴리라인 사용)
class KakaoMapChannel {
  late MethodChannel channel;

  void initChannel(int id) {
    channel = MethodChannel('map-kakao/$id');
  }

  // ── 기존 메서드들 ─────────────────────────────────────────────────────────
  Future<void> animateCamera({
    required double lat,
    required double lon,
    required int zoomLevel,
    int durationMs = 300,
  }) =>
      channel.invokeMethod('animateCamera', {
        'lat': lat,
        'lon': lon,
        'zoom': zoomLevel,
        'durationMs': durationMs,
      });

  Future<void> moveCamera({
    required double lat,
    required double lon,
    required int zoomLevel,
  }) =>
      channel.invokeMethod('moveCamera', {
        'lat': lat,
        'lon': lon,
        'zoom': zoomLevel,
      });

  Future<void> fitBounds({
    required List<Map<String, double>> points,
    int paddingPx = 32,
  }) =>
      channel.invokeMethod('fitBounds', {
        'points': points,
        'padding': paddingPx,
      });

  Future<void> setUserLocation({required double lat, required double lon}) =>
      channel.invokeMethod('setUserLocation', {'lat': lat, 'lon': lon});

  /// 기존 실시간 그리기용(폴백에 사용)
  Future<void> updatePolyline(List<Map<String, double>> points) =>
      channel.invokeMethod('updatePolyline', {'points': points});

  Future<String?> captureSnapshot() async {
    final r = await channel.invokeMethod('captureSnapshot');
    if (r is String) return r;
    return null;
  }

  Future<void> setLabels(List<Map<String, dynamic>> labels) =>
      channel.invokeMethod('setLabels', {'labels': labels});

  Future<void> removeAllSpotLabel() =>
      channel.invokeMethod('removeAllSpotLabel');

  // ── 새로 추가된 고급 오버레이 API ───────────────────────────────────────────
  /// 파란 경로 라인(굵게) 표시. 네이티브에 없으면 updatePolyline로 폴백.
  Future<void> setRoutePolyline({
    required List<Map<String, double>> points,
    String color = '#1a73e8', // 구글맵 파랑 느낌
    double width = 8,
    double outlineWidth = 1.5,
    String outlineColor = '#1456b8',
  }) async {
    try {
      await channel.invokeMethod('setRoutePolyline', {
        'points': points,
        'color': color,
        'width': width,
        'outlineWidth': outlineWidth,
        'outlineColor': outlineColor,
      });
    } on PlatformException {
      // 폴백: 기존 폴리라인 API
      await updatePolyline(points);
    } on MissingPluginException {
      await updatePolyline(points);
    }
  }

  Future<void> clearRoutePolyline() async {
    try {
      await channel.invokeMethod('clearRoutePolyline');
    } catch (_) {
      // 무시
    }
  }

  /// 핀 마커 세팅. 네이티브에 없으면 📍라벨로 대체.
  /// markers: [{lat, lon, id, title, type: 'start'|'end'|'poi', color: 'red'|'green'|'blue'}]
  Future<void> setMarkers(List<Map<String, dynamic>> markers) async {
    try {
      await channel.invokeMethod('setMarkers', {'markers': markers});
    } on PlatformException {
      await _fallbackMarkersToLabels(markers);
    } on MissingPluginException {
      await _fallbackMarkersToLabels(markers);
    }
  }

  Future<void> clearMarkers() async {
    try {
      await channel.invokeMethod('clearMarkers');
    } catch (_) {
      // 폴백: 라벨 지우기
      try {
        await removeAllSpotLabel();
      } catch (_) {}
    }
  }

  Future<void> setUserLocationVisible(bool visible) async {
    try {
      await channel.invokeMethod('setUserLocationVisible', {'visible': visible});
    } catch (_) {
      // 네이티브 없으면 무시
    }
  }

  // ── 폴백: 마커를 라벨로 흉내내기 ─────────────────────────────────────────────
  Future<void> _fallbackMarkersToLabels(List<Map<String, dynamic>> markers) {
    final labels = <Map<String, dynamic>>[];
    for (final m in markers) {
      final title = (m['title'] as String?) ?? '';
      final type = (m['type'] as String?) ?? 'poi';
      final prefix = (type == 'start')
          ? '🔰 '
          : (type == 'end')
          ? '🏁 '
          : '📍 ';
      labels.add({
        'name': '$prefix$title',
        'lat': (m['lat'] as num).toDouble(),
        'lon': (m['lon'] as num).toDouble(),
        'id': (m['id'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      });
    }
    return setLabels(labels);
  }
}
