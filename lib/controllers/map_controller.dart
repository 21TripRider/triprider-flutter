import 'package:triprider/utils/kakao_map_channel.dart';

class MapController {
  MapController(this._channel);
  final KakaoMapChannel _channel;

  Future<void> animateTo(double lat, double lon, int zoom, {int durationMs = 300}) =>
      _channel.animateCamera(lat: lat, lon: lon, zoomLevel: zoom, durationMs: durationMs);

  Future<void> fitBounds(List<Map<String, double>> pts, {int padding = 32}) =>
      _channel.fitBounds(points: pts, paddingPx: padding);

  Future<void> setUser(double lat, double lon) => _channel.setUserLocation(lat: lat, lon: lon);

  Future<void> setLabels(List<Map<String, dynamic>> labels) => _channel.setLabels(labels);

  Future<void> clearLabels() => _channel.removeAllSpotLabel();

  // 새로 추가된 고급 오버레이 헬퍼
  Future<void> setRoutePolyline(List<Map<String, double>> pts) =>
      _channel.setRoutePolyline(points: pts);

  Future<void> clearRoute() => _channel.clearRoutePolyline();

  Future<void> setMarkers(List<Map<String, dynamic>> markers) => _channel.setMarkers(markers);

  Future<void> clearMarkers() => _channel.clearMarkers();
}
