import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // ← JSON assets 읽기
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;

/// 사용법 요약
/// - 완전 무료:
///   1) orsJsonAssetPath: 'assets/routes/ors-route_xxx.json'  // ORS JSON 파일 경로
///      (권장: OpenRouteService에서 받은 JSON 그대로)
///   2) 또는 points: [LatLng(...), ...]
///   3) 또는 encodedPolyline: '...' (미리 인코딩한 문자열)
///
/// - 유료(Directions API 호출): fetchWithDirections=true + directionsApiKey
///   (월 $200 크레딧 내 무료)

class CourseDetailmap extends StatefulWidget {
  const CourseDetailmap({
    super.key,
    required this.start,
    required this.end,
    this.startTitle = '출발',
    this.endTitle = '도착',

    // ▽ 둘 중 하나만 주면 됨
    this.encodedPolyline, // 미리 만든 encoded polyline 문자열
    this.points, // LatLng 리스트
    this.orsJsonAssetPath, // ★ ORS JSON(또는 GeoJSON) 파일 경로 (assets)
    // ▽ 경로가 전혀 없을 때만 사용 (과금 주의)
    this.fetchWithDirections = false,
    this.directionsApiKey,
    this.travelMode = TravelMode.driving,
  });

  final LatLng start;
  final LatLng end;
  final String startTitle;
  final String endTitle;

  final String? encodedPolyline;
  final List<LatLng>? points;
  final String? orsJsonAssetPath; // ★ 추가

  final bool fetchWithDirections;
  final String? directionsApiKey;
  final TravelMode travelMode;

  @override
  State<CourseDetailmap> createState() => _CourseDetailmapState();
}

class _CourseDetailmapState extends State<CourseDetailmap> {
  GoogleMapController? _map;
  final _markers = <Marker>{};
  final _polylines = <Polyline>{};
  final _route = <LatLng>[];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    try {
      // 1) 경로 데이터 확보 (무료 우선)
      if (widget.points != null && widget.points!.isNotEmpty) {
        _route.addAll(widget.points!);
      } else if (widget.encodedPolyline != null &&
          widget.encodedPolyline!.isNotEmpty) {
        final decoded = PolylinePoints().decodePolyline(
          widget.encodedPolyline!,
        );
        _route.addAll(decoded.map((p) => LatLng(p.latitude, p.longitude)));
      } else if (widget.orsJsonAssetPath != null &&
          widget.orsJsonAssetPath!.isNotEmpty) {
        final pts = await _loadOrsRoutePoints(widget.orsJsonAssetPath!);
        _route.addAll(pts);
      } else if (widget.fetchWithDirections) {
        // ⚠️ 과금 항목 (월 $200 크레딧 내 무료)
        final encoded = await _fetchEncodedPolyline(
          widget.start,
          widget.end,
          widget.travelMode,
          widget.directionsApiKey!,
        );
        final decoded = PolylinePoints().decodePolyline(encoded);
        _route.addAll(decoded.map((p) => LatLng(p.latitude, p.longitude)));
      } else {
        throw Exception(
          '경로 데이터가 없습니다. points / encodedPolyline / orsJsonAssetPath / fetchWithDirections 중 하나를 사용하세요.',
        );
      }

      // 2) 마커 (출발/도착)
      _markers
        ..add(
          Marker(
            markerId: const MarkerId('start'),
            position: widget.start,
            infoWindow: InfoWindow(title: widget.startTitle),
          ),
        )
        ..add(
          Marker(
            markerId: const MarkerId('end'),
            position: widget.end,
            infoWindow: InfoWindow(title: widget.endTitle),
          ),
        );

      // 3) 폴리라인
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          width: 6,
          color: Colors.blue,
          points: _route,
        ),
      );

      _loading = false;
      setState(() {});

      // 카메라를 경로 전체로 맞춤
      if (_map != null) _fitBounds();
    } catch (e) {
      _loading = false;
      _error = e.toString();
      setState(() {});
    }
  }

  /// ★ ORS JSON / GeoJSON 파일에서 좌표를 읽어 LatLng 리스트로 변환
  Future<List<LatLng>> _loadOrsRoutePoints(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final data = jsonDecode(raw);

    // case A: ORS JSON (routes[0].geometry.coordinates)
    if (data is Map &&
        data['routes'] is List &&
        (data['routes'] as List).isNotEmpty) {
      final r0 = (data['routes'] as List).first;
      final geom = r0['geometry'];
      // Encoded polyline가 아니라 좌표 배열(LineString)인 경우
      if (geom is Map &&
          geom['type'] == 'LineString' &&
          geom['coordinates'] is List) {
        final coords = geom['coordinates'] as List;
        return coords.map<LatLng>((c) {
          final lng = (c[0] as num).toDouble();
          final lat = (c[1] as num).toDouble();
          return LatLng(lat, lng); // [lng, lat, (elev?)] → LatLng(lat, lng)
        }).toList();
      }
    }

    // case B: GeoJSON (features[0].geometry.coordinates)
    if (data is Map &&
        data['features'] is List &&
        (data['features'] as List).isNotEmpty) {
      final f0 = (data['features'] as List).first;
      final geom = f0['geometry'];
      if (geom is Map &&
          geom['type'] == 'LineString' &&
          geom['coordinates'] is List) {
        final coords = geom['coordinates'] as List;
        return coords.map<LatLng>((c) {
          final lng = (c[0] as num).toDouble();
          final lat = (c[1] as num).toDouble();
          return LatLng(lat, lng);
        }).toList();
      }
    }

    throw Exception('지원하지 않는 ORS/GeoJSON 형식입니다.');
  }

  // Google Directions API 호출 (과금주의)
  Future<String> _fetchEncodedPolyline(
      LatLng s,
      LatLng d,
      TravelMode mode,
      String apiKey,
      ) async {
    final origin = '${s.latitude},${s.longitude}';
    final dest = '${d.latitude},${d.longitude}';
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$dest&mode=${_mode(mode)}&key=$apiKey&language=ko';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('Directions API 실패(${res.statusCode})');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = (json['routes'] as List?) ?? [];
    if (routes.isEmpty) throw Exception('경로가 없습니다.');
    return routes[0]['overview_polyline']['points'] as String? ?? '';
  }

  String _mode(TravelMode m) {
    switch (m) {
      case TravelMode.walking:
        return 'walking';
      case TravelMode.bicycling:
        return 'bicycling';
      case TravelMode.transit:
        return 'transit';
      case TravelMode.driving:
      default:
        return 'driving';
    }
  }

  void _fitBounds() {
    if (_route.isEmpty || _map == null) return;

    double minLat = _route.first.latitude,
        maxLat = _route.first.latitude,
        minLng = _route.first.longitude,
        maxLng = _route.first.longitude;

    for (final p in _route) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _map!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 48));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          padding: const EdgeInsets.only(left: 8),
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.arrow_back_ios),
        ),
        title: const Text('코스 상세'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.start,
              zoom: 12,
            ),
            onMapCreated: (c) {
              _map = c;
              if (!_loading && _route.isNotEmpty) _fitBounds();
            },
            markers: _markers,
            polylines: _polylines,
            zoomGesturesEnabled: true,
            zoomControlsEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: false,
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 20,
              child: Material(
                color: Colors.red.withOpacity(.92),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton:
      _route.isEmpty
          ? null
          : FloatingActionButton.extended(
        onPressed: _fitBounds,
        icon: const Icon(Icons.center_focus_strong),
        label: const Text('전체 보기'),
      ),
    );
  }
}

enum TravelMode { driving, walking, bicycling, transit }
