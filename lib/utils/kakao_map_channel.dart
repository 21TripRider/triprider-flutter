// lib/utils/kakao_map_channel.dart
import 'package:flutter/services.dart';

/// Kakao Map platform channel wrapper
/// - setRoutePolyline / clearRoutePolyline / setMarkers / clearMarkers / setUserLocationVisible
class KakaoMapChannel {
  late MethodChannel channel;

  void initChannel(int id) {
    channel = MethodChannel('map-kakao/$id');
  }

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

  Future<void> setRoutePolyline({
    required List<Map<String, double>> points,
    String color = '#1a73e8',
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
      await updatePolyline(points);
    } on MissingPluginException {
      await updatePolyline(points);
    }
  }

  Future<void> clearRoutePolyline() async {
    try {
      await channel.invokeMethod('clearRoutePolyline');
    } catch (_) {}
  }

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
      try {
        await removeAllSpotLabel();
      } catch (_) {}
    }
  }

  Future<void> setUserLocationVisible(bool visible) async {
    try {
      await channel.invokeMethod('setUserLocationVisible', {'visible': visible});
    } catch (_) {}
  }

  Future<void> _fallbackMarkersToLabels(List<Map<String, dynamic>> markers) {
    final labels = <Map<String, dynamic>>[];
    for (final m in markers) {
      final title = (m['title'] as String?) ?? '';
      final type = (m['type'] as String?) ?? 'poi';
      final prefix =
      (type == 'start') ? '🔰 ' : (type == 'end') ? '🏁 ' : '📍 ';
      labels.add({
        'name': '$prefix$title',
        'lat': (m['lat'] as num).toDouble(),
        'lon': (m['lon'] as num).toDouble(),
        'id': (m['id'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      });
    }
    return setLabels(labels);
  }
}
