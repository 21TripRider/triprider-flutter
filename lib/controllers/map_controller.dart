import 'package:triprider/utils/kakao_map_channel.dart';

class MapController {
  MapController(this._channel);
  final KakaoMapChannel _channel;

  Future<void> animateTo(double lat, double lon, int zoom, {int durationMs = 300}) async {
    await _channel.animateCamera(lat: lat, lon: lon, zoomLevel: zoom, durationMs: durationMs);
  }

  Future<void> fitBounds(List<Map<String, double>> pts, {int padding = 32}) async {
    await _channel.fitBounds(points: pts, paddingPx: padding);
  }

  Future<void> setUser(double lat, double lon) async {
    await _channel.setUserLocation(lat: lat, lon: lon);
  }

  Future<void> setLabels(List<Map<String, dynamic>> labels) async {
    await _channel.setLabels(labels);
  }

  Future<void> clearLabels() async {
    await _channel.removeAllSpotLabel();
  }
}


