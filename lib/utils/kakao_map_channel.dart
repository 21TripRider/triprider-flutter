import 'package:flutter/services.dart';

class KakaoMapChannel {
  late MethodChannel _channel;

  void initChannel(int id) {
    _channel = MethodChannel('map-kakao/$id');
  }

  MethodChannel get channel => _channel;

  Future<void> moveCamera({
    required double lat,
    required double lon,
    required int zoomLevel,
  }) async {
    await _channel.invokeMethod('moveCamera', {
      'lat': lat,
      'lon': lon,
      'zoomLevel': zoomLevel,
    });
  }

  Future<void> addSpotLabel({
    required double lat,
    required double lon,
    required String name,
    required int id,
  }) async {
    await _channel.invokeMethod('addSpotLabel', {
      'lat': lat,
      'lon': lon,
      'name': name,
      'id': id,
    });
  }

  Future<void> removeAllSpotLabel() async {
    await _channel.invokeMethod('removeAllSpotLabel');
  }

  Future<void> setLabels(List<Map<String, dynamic>> data) async {
    await _channel.invokeMethod('setLabels', {
      'labels': data,
    });
  }

  Future<void> updatePolyline(List<Map<String, double>> points) async {
    await _channel.invokeMethod('updatePolyline', {
      'points': points,
    });
  }

  Future<String?> captureSnapshot() async {
    final path = await _channel.invokeMethod('captureSnapshot');
    return path as String?;
  }

  Future<void> zoomBy(int delta) async {
    await _channel.invokeMethod('zoomBy', {
      'delta': delta,
    });
  }

  Future<void> animateCamera({
    required double lat,
    required double lon,
    required int zoomLevel,
    int durationMs = 300,
  }) async {
    await _channel.invokeMethod('animateCamera', {
      'lat': lat,
      'lon': lon,
      'zoomLevel': zoomLevel,
      'durationMs': durationMs,
    });
  }

  Future<void> fitBounds({
    required List<Map<String, double>> points,
    int paddingPx = 24,
  }) async {
    await _channel.invokeMethod('fitBounds', {
      'points': points,
      'padding': paddingPx,
    });
  }

  Future<void> setUserLocation({
    required double lat,
    required double lon,
  }) async {
    await _channel.invokeMethod('setUserLocation', {
      'lat': lat,
      'lon': lon,
    });
  }
}


