import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:triprider/utils/kakao_map_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triprider/widgets/Bottom_App_Bar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:triprider/data/kakao_local_api.dart';
import 'package:triprider/controllers/map_controller.dart';
import 'package:triprider/screens/Map/API/Ride_Api.dart';
import 'package:triprider/state/map_view_model.dart';

class KakaoMapScreen extends StatefulWidget {
  const KakaoMapScreen({super.key});

  @override
  State<KakaoMapScreen> createState() => _KakaoMapScreenState();
}

class _KakaoMapScreenState extends State<KakaoMapScreen> {
  final KakaoMapChannel _channel = KakaoMapChannel();

  bool _loading = true;
  String? _error;
  double? _lat;
  double? _lon;
  final int _zoomLevel = 16;
  String? _warning;

  // Tracking state
  bool _tracking = false;
  int? _rideId; // 서버 라이딩 세션 ID
  DateTime? _startTime;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  StreamSubscription<Position>? _posSub;
  StreamSubscription<Position>? _userPosSub;
  final List<List<double>> _path = <List<double>>[]; // [lat, lon]
  final List<Map<String, dynamic>> _batchPoints = <Map<String, dynamic>>[]; // 서버 업로드용 배치
  double _totalDistanceMeters = 0.0;
  double _maxSpeedKmh = 0.0;
  double? _currentSpeedKmh;
  int _lastRenderedPointCount = 0;
  bool _loadingPois = false;
  String _activeFilter = 'none'; // none | gas | moto
  List<Map<String, dynamic>> _pois = <Map<String, dynamic>>[];
  final Map<int, Map<String, dynamic>> _labelById = <int, Map<String, dynamic>>{};
  int _lastIdleZoom = 16;
  double? _lastIdleLat;
  double? _lastIdleLon;
  Timer? _poiDebounce;
  bool _suppressPoiOnce = false;

  static const String _kakaoRestApiKey = '471ee3eec0b9d8a5fc4eb86fb849e524';
  // Google Static Map API 키(Static Map에만 사용). 필요 시 안전한 저장소로 이동하세요.
  static const String _googleStaticApiKey = 'AIzaSyA53fiKudkjSzIee7zn-gebXgJuWNuF4lc';

  // ViewModel/Controller
  late final KakaoLocalApi _api = KakaoLocalApi(_kakaoRestApiKey);
  late final MapController _mapController = MapController(_channel);
  late final MapViewModel _vm = MapViewModel(api: _api, controller: _mapController);

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _fallbackGasByKeyword(double lat, double lon, int radius) async {
    try {
      final headers = {'Authorization': 'KakaoAK $_kakaoRestApiKey'};
      final uri = Uri.parse('https://dapi.kakao.com/v2/local/search/keyword.json').replace(queryParameters: {
        'query': '주유소',
        'x': lon.toStringAsFixed(6),
        'y': lat.toStringAsFixed(6),
        'radius': '5000',
        'size': '15',
        'page': '1',
      });
      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode != 200) return;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final docs = (data['documents'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final labels = <Map<String, dynamic>>[];
      int id = 210000;
      for (final d in docs) {
        final name = d['place_name']?.toString() ?? '주유소';
        final y = double.tryParse(d['y']?.toString() ?? '') ?? 0.0;
        final x = double.tryParse(d['x']?.toString() ?? '') ?? 0.0;
        labels.add({'name': '⛽ $name', 'lat': y, 'lon': x, 'id': id++});
      }
      if (labels.isNotEmpty) {
        await _channel.setLabels(labels);
        _pois = _withDistance(lat, lon, docs.map((d) => {
          'name': d['place_name']?.toString() ?? '주유소',
          'lat': double.tryParse(d['y']?.toString() ?? '') ?? 0.0,
          'lon': double.tryParse(d['x']?.toString() ?? '') ?? 0.0,
        }).toList());
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> _withDistance(double lat, double lon, List<Map<String, dynamic>> items) {
    double haversine(double lat1, double lon1, double lat2, double lon2) {
      const R = 6371000.0;
      final dLat = (lat2 - lat1) * math.pi / 180.0;
      final dLon = (lon2 - lon1) * math.pi / 180.0;
      final a =
          (math.sin(dLat / 2) * math.sin(dLat / 2)) +
              math.cos(lat1 * math.pi / 180.0) * math.cos(lat2 * math.pi / 180.0) *
                  (math.sin(dLon / 2) * math.sin(dLon / 2));
      final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      return R * c;
    }
    final out = <Map<String, dynamic>>[];
    for (final m in items) {
      final d = haversine(lat, lon, (m['lat'] as num).toDouble(), (m['lon'] as num).toDouble());
      final n = Map<String, dynamic>.from(m);
      n['distance'] = d;
      out.add(n);
    }
    out.sort((a, b) => ((a['distance'] as num).compareTo((b['distance'] as num))));
    return out;
  }

  // removed in favor of ViewModel

  Widget _filterButton({required String label, required String value}) {
    final active = _activeFilter == value;
    return GestureDetector(
      onTap: () async {
        // 토글 토글: 같은 버튼을 다시 누르면 해제
        final willDeactivate = _activeFilter == value;
        if (willDeactivate) {
          setState(() { _activeFilter = 'none'; _pois = []; });
          try { await _channel.removeAllSpotLabel(); } catch (_) {}
          // 사용자 위치 라벨은 유지/재표시
          if (_lat != null && _lon != null) { try { await _channel.setUserLocation(lat: _lat!, lon: _lon!); } catch (_) {} }
          return;
        }

        setState(() { _activeFilter = value; _pois = []; });
        _vm.activeFilter = value;
        if (_lat != null && _lon != null) {
          await _vm.refreshPois(_lat!, _lon!);
          _applyVmPoisToLocal(_lat!, _lon!);
          // 사용자 위치 라벨 재설정(라벨 클리어 시 지워졌을 수 있음)
          try { await _channel.setUserLocation(lat: _lat!, lon: _lon!); } catch (_) {}
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.blue : Colors.white,
          border: Border.all(color: active ? Colors.blue : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.black)),
      ),
    );
  }

  Future<void> _initLocation() async {
    // 1) 먼저 기본 좌표로 맵을 즉시 렌더링합니다 (에뮬레이터 위치 지연 대비)
    setState(() {
      _lat = 33.510414; // fallback: Jeju International Airport
      _lon = 126.491353;
      _loading = false;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _warning = '위치 서비스가 꺼져 있어 기본 위치로 표시합니다.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() {
          _warning = '위치 권한이 없어 기본 위치로 표시합니다.';
        });
        return;
      }

      // 2) 현재 위치를 5초 타임아웃으로 가져옵니다 (에뮬레이터 무한 대기 방지)
      final pos = await Geolocator
          .getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 5));

      setState(() {
        _lat = pos.latitude;
        _lon = pos.longitude;
      });

      // 3) 맵이 이미 렌더링된 이후라면 카메라를 사용자의 현재 위치로 이동
      try {
        await _channel.animateCamera(lat: pos.latitude, lon: pos.longitude, zoomLevel: _zoomLevel, durationMs: 350);
        // 사용자 위치 표시
        await _channel.setUserLocation(lat: pos.latitude, lon: pos.longitude);
      } catch (_) {}

      // 패시브 사용자 위치 업데이트 시작 (항상 표시/갱신)
      _startUserLocationUpdates();
      // 주변 표시 (필터 상태에 따라) - ViewModel 경유
      if (_activeFilter != 'none') {
        _vm.activeFilter = _activeFilter;
        await _vm.refreshPois(pos.latitude, pos.longitude);
        _applyVmPoisToLocal(pos.latitude, pos.longitude);
      }
    } on TimeoutException {
      setState(() {
        _warning = '현재 위치를 가져오지 못해 기본 위치로 표시합니다.';
      });
    } catch (e) {
      setState(() {
        _warning = '위치 정보를 가져오지 못해 기본 위치로 표시합니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: (_lat != null && _lon != null)
          ? FloatingActionButton(
        heroTag: 'recenter',
        onPressed: () async {
          try {
            _suppressPoiOnce = true; // 재센터 시 POI 재조회 억제
            await _channel.animateCamera(lat: _lat!, lon: _lon!, zoomLevel: _zoomLevel, durationMs: 300);
            await _channel.setUserLocation(lat: _lat!, lon: _lon!);
          } catch (_) {}
        },
        child: const Icon(Icons.my_location),
      )
          : null,
      bottomNavigationBar: const BottomAppBarWidget(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final safeTop = MediaQuery.of(context).padding.top + 12; // 펀치홀/노치 고려 상단 여백
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Stack(
      children: [
        _buildPlatformView(_lat!, _lon!),
        if (_warning != null)
          Positioned(
            top: safeTop,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.orange.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_warning!, style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),
        if (_tracking) _trackingHUD(),
        // 상단 필터 버튼들
        Positioned(
          top: safeTop + 44, // 경고 배지 아래로, 상단 여백 강화
          left: 16,
          right: 16,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterButton(label: '주유소', value: 'gas'),
                const SizedBox(width: 8),
                _filterButton(label: '오토바이', value: 'moto'),
              ],
            ),
          ),
        ),
        // 하단 결과 패널
        if (_pois.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 24 + kBottomNavigationBarHeight + safeBottom,
            child: Container(
              height: 220,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _pois.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (_, i) {
                  final m = _pois[i];
                  final name = (m['name'] as String?) ?? '-';
                  final dist = (m['distance'] as double?) ?? 0.0;
                  return ListTile(
                    dense: true,
                    title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: dist > 0 ? Text('${(dist / 1000).toStringAsFixed(2)} km') : null,
                    onTap: () async {
                      final lat = (m['lat'] as num).toDouble();
                      final lon = (m['lon'] as num).toDouble();
                      try { await _channel.moveCamera(lat: lat, lon: lon, zoomLevel: 16); } catch (_) {}
                    },
                  );
                },
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24 + kBottomNavigationBarHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FloatingActionButton(
                onPressed: _onPlayPressed,
                backgroundColor: _tracking ? Colors.red : null,
                child: Icon(_tracking ? Icons.stop : Icons.play_arrow),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onPlayPressed() {
    if (_tracking) {
      _stopTracking();
    } else {
      _startTracking();
    }
  }

  // 네이티브에서 카메라 idle 신호를 받으면 활성 필터 재조회
  void _bindNativeCallbacks() {}

  Widget _trackingHUD() {
    final hh = _elapsed.inHours.remainder(60).toString().padLeft(2, '0');
    final mm = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final current = _currentSpeedKmh == null ? '-' : _currentSpeedKmh!.toStringAsFixed(1);
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('시간 $hh:$mm:$ss', style: const TextStyle(color: Colors.white, fontSize: 14)),
              Text('현재속도 ${current}km/h', style: const TextStyle(color: Colors.white, fontSize: 14)),
              Text('거리 ${( _totalDistanceMeters / 1000).toStringAsFixed(2)}km', style: const TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  void _startTracking() async {
    // ensure permission
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('위치 서비스가 꺼져 있습니다.')));
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('위치 권한이 필요합니다.')));
      return;
    }

    setState(() {
      _tracking = true;
      _startTime = DateTime.now();
      _elapsed = Duration.zero;
      _path.clear();
      _totalDistanceMeters = 0.0;
      _maxSpeedKmh = 0.0;
      _currentSpeedKmh = null;
      _batchPoints.clear();
    });

    // 1) 서버 세션 시작
    try {
      // ignore: unused_local_variable
      final id = await RideApi.startRide();
      _rideId = id;
    } catch (_) {
      _rideId = null; // 오프라인 모드 허용
    }

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startTime != null) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime!);
        });
      }
    });

    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((pos) async {
      final lat = pos.latitude;
      final lon = pos.longitude;
      final speedKmh = (pos.speed.isFinite ? pos.speed : 0.0) * 3.6; // m/s -> km/h
      setState(() {
        _currentSpeedKmh = speedKmh;
        if (speedKmh > _maxSpeedKmh) _maxSpeedKmh = speedKmh;
      });

      if (_path.isNotEmpty) {
        final prev = _path.last;
        final d = Geolocator.distanceBetween(prev[0], prev[1], lat, lon);
        if (d >= 1.0) {
          _totalDistanceMeters += d;
          _path.add(<double>[lat, lon]);
        }
      } else {
        _path.add(<double>[lat, lon]);
      }

      // 2) 배치 포인트 적재 (3~5초 단위로 업로드)
      _batchPoints.add({
        'seq': _path.length,
        'lat': lat,
        'lng': lon,
        'speedKmh': speedKmh,
        'epochMillis': DateTime.now().millisecondsSinceEpoch,
      });
      // 조건 업로드 (배치 5개 이상 혹은 5초 경과)
      if (_rideId != null && _batchPoints.length >= 5) {
        final sending = List<Map<String, dynamic>>.from(_batchPoints);
        _batchPoints.clear();
        try { await RideApi.uploadPoints(rideId: _rideId!, points: sending); } catch (_) {}
      }

      // follow camera softly (사용자 라벨만 갱신, 폴리라인은 종료 시에만 그립니다)
      try {
        await _channel.animateCamera(lat: lat, lon: lon, zoomLevel: _zoomLevel, durationMs: 350);
        await _channel.setUserLocation(lat: lat, lon: lon);
      } catch (_) {}
    });
  }

  void _startUserLocationUpdates() {
    _userPosSub?.cancel();
    _userPosSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((pos) async {
      try {
        await _channel.setUserLocation(lat: pos.latitude, lon: pos.longitude);
      } catch (_) {}
    });
  }

  void _stopTracking() async {
    _posSub?.cancel();
    _ticker?.cancel();
    setState(() {
      _tracking = false;
    });

    final elapsedSec = _elapsed.inSeconds.toDouble().clamp(1, double.infinity);
    final hours = elapsedSec / 3600.0;
    final avgSpeedKmh = hours > 0 ? (_totalDistanceMeters / 1000.0) / hours : 0.0;

    // 남은 배치 업로드 플러시
    if (_rideId != null && _batchPoints.isNotEmpty) {
      final sending = List<Map<String, dynamic>>.from(_batchPoints);
      _batchPoints.clear();
      try { await RideApi.uploadPoints(rideId: _rideId!, points: sending); } catch (_) {}
    }

    // persist (로컬 + 서버 종료)
    final record = <String, dynamic>{
      'startedAt': _startTime?.toIso8601String(),
      'endedAt': DateTime.now().toIso8601String(),
      'elapsedSeconds': _elapsed.inSeconds,
      'distanceMeters': _totalDistanceMeters,
      'maxSpeedKmh': _maxSpeedKmh,
      'avgSpeedKmh': avgSpeedKmh,
      'path': _path.map((p) => {'lat': p[0], 'lon': p[1]}).toList(),
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('ride_records') ?? <String>[];
      // 1) 경로 폴리라인을 지도에 그린 뒤, 카메라 프레이밍 → 캡처 (4:3)
      String? imagePath;
      try {
        // Static Map으로 확정된 썸네일 생성 (가장 확실한 방식)
        String? staticPath = await _buildGoogleStaticMapForPath(_path);
        staticPath ??= await _buildStaticMapForPath(_path);
        if (staticPath != null) {
          imagePath = staticPath;
        }
      } catch (_) {}

      // (선택) PixelCopy 캡처는 보조로만 시도
      try {
        if (imagePath == null) {
          imagePath = await _channel.captureSnapshot();
        }
      } catch (_) {}

      // 2) 기록 저장 (이미지 경로 포함)
      final withImage = Map<String, dynamic>.from(record);
      if (imagePath != null) withImage['imagePath'] = imagePath;
      list.add(jsonEncode(withImage));
      await prefs.setStringList('ride_records', list);
      // 3) 서버 종료 호출 (메타 + 스냅샷)
      if (_rideId != null) {
        final meta = <String, dynamic>{
          'title': '라이딩',
          'memo': '',
          'elapsedSeconds': _elapsed.inSeconds,
          'distanceMeters': _totalDistanceMeters,
          'avgSpeedKmh': avgSpeedKmh,
          'maxSpeedKmh': _maxSpeedKmh,
          'startedAt': _startTime?.toIso8601String(),
          'finishedAt': DateTime.now().toIso8601String(),
        };
        try {
          await RideApi.finishRide(
            rideId: _rideId!,
            body: meta,
            snapshot: imagePath != null ? File(imagePath) : null,
          );
        } catch (_) {}
      }
      // 미리보기 이동은 제거하고, 마이페이지에서 카드 썸네일로 확인
    } catch (_) {}

    if (!mounted) return;
    // 캡처/저장 완료 알림
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('주행 기록 저장 완료')));

    // optional: clear drawn dots after finish
    try { await _channel.removeAllSpotLabel(); } catch (_) {}
  }

  // Google Static Map(지도+경로) 생성
  Future<String?> _buildGoogleStaticMapForPath(List<List<double>> path) async {
    if (path.isEmpty) return null;
    final sampled = _sampleForStatic(path, 200);
    final pathParam = sampled.map((p) => '${p[0].toStringAsFixed(6)},${p[1].toStringAsFixed(6)}').join('|'); // lat,lon
    final params = {
      'size': '800x600',
      'scale': '2',
      'path': 'color:0x1565C0ff|weight:6|$pathParam',
      'key': _googleStaticApiKey,
    };
    final uri = Uri.https('maps.googleapis.com', '/maps/api/staticmap', params);
    final resp = await http.get(uri);
    if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;
    final dir = await Directory.systemTemp.createTemp('triprider_gstatic');
    final file = File('${dir.path}/route_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(resp.bodyBytes);
    return file.path;
  }

  Future<String?> _buildStaticMapForPath(List<List<double>> path) async {
    if (path.isEmpty) return null;
    // bounds 계산
    double minLat = path.first[0], maxLat = path.first[0];
    double minLon = path.first[1], maxLon = path.first[1];
    for (final p in path) {
      if (p[0] < minLat) minLat = p[0];
      if (p[0] > maxLat) maxLat = p[0];
      if (p[1] < minLon) minLon = p[1];
      if (p[1] > maxLon) maxLon = p[1];
    }
    final centerLat = (minLat + maxLat) / 2;
    final centerLon = (minLon + maxLon) / 2;
    final latSpan = (maxLat - minLat).abs().clamp(0.0001, 180.0);
    final lonSpan = (maxLon - minLon).abs().clamp(0.0001, 360.0);
    final span = latSpan > lonSpan ? latSpan : lonSpan;
    int level = 16;
    if (span > 0.5) level = 9; else if (span > 0.25) level = 10; else if (span > 0.1) level = 11; else if (span > 0.05) level = 12; else if (span > 0.02) level = 13; else if (span > 0.01) level = 14; else if (span > 0.005) level = 15; else level = 16;

    // paths 파라미터 구성
    final pts = path.map((p) => '${p[1]},${p[0]}').join('|'); // lon,lat
    final params = {
      'center': '${centerLon.toStringAsFixed(6)},${centerLat.toStringAsFixed(6)}',
      'level': level.toString(),
      'w': '800',
      'h': '600',
      'paths': 'color:0x1565C0|width:6|$pts',
    };
    final uri = Uri.https('dapi.kakao.com', '/v2/maps/staticmap', params);
    final resp = await http.get(uri, headers: {'Authorization': 'KakaoAK $_kakaoRestApiKey'});
    if (resp.statusCode != 200) return null;
    final dir = await Directory.systemTemp.createTemp('triprider_static');
    final file = File('${dir.path}/route_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(resp.bodyBytes);
    return file.path;
  }

  // URL 길이/용량 방지: 최대 n개까지 균등 샘플링
  List<List<double>> _sampleForStatic(List<List<double>> src, int maxPoints) {
    if (src.length <= maxPoints) return src;
    final out = <List<double>>[];
    final step = src.length / maxPoints;
    double acc = 0;
    for (int i = 0; i < src.length; i++) {
      if (out.isEmpty || i >= acc) {
        out.add(src[i]);
        acc += step;
      }
    }
    if (out.last != src.last) out.add(src.last);
    return out;
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _userPosSub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  Widget _buildPlatformView(double lat, double lon) {
    final creationParams = <String, dynamic>{
      'lat': lat,
      'lon': lon,
      'zoomLevel': _zoomLevel,
    };

    if (Platform.isAndroid) {
      return AndroidView(
        viewType: 'map-kakao',
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return UiKitView(
      viewType: 'map-kakao',
      onPlatformViewCreated: _onPlatformViewCreated,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
    );
  }

  void _onPlatformViewCreated(int id) {
    _channel.initChannel(id);
    _channel.channel.setMethodCallHandler((call) async {
      if (call.method == 'onLabelTabbed') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final id = (args['id'] as num?)?.toInt();
        if (id != null && _labelById.containsKey(id)) {
          final m = _labelById[id]!;
          final raw = (m['raw'] as Map?) ?? {};
          final title = (raw['name']?.toString() ?? m['name']?.toString() ?? '').replaceFirst('⛽ ', '');
          final address = raw['address']?.toString();
          final phone = raw['phone']?.toString();
          final url = raw['url']?.toString();
          if (!mounted) return;
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            builder: (_) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  if (address != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(address)),
                  const SizedBox(height: 12),
                  Row(children: [
                    if (phone != null && phone.isNotEmpty)
                      TextButton.icon(onPressed: () async { final uri = Uri.parse('tel:$phone'); if (await canLaunchUrl(uri)) { await launchUrl(uri); } }, icon: const Icon(Icons.call), label: const Text('전화')),
                    if (url != null && url.isNotEmpty)
                      TextButton.icon(onPressed: () async { final uri = Uri.parse(url); if (await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); } }, icon: const Icon(Icons.link), label: const Text('상세')),
                  ]),
                ],
              ),
            ),
          );
        }
      } else if (call.method == 'onCameraIdle') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final lat = (args['lat'] as num?)?.toDouble();
        final lon = (args['lon'] as num?)?.toDouble();
        _lastIdleZoom = (args['zoom'] as num?)?.toInt() ?? _lastIdleZoom;
        if (lat == null || lon == null) return;
        _lastIdleLat = lat;
        _lastIdleLon = lon;
        _poiDebounce?.cancel();
        _poiDebounce = Timer(const Duration(milliseconds: 400), () async {
          if (_lastIdleLat == null || _lastIdleLon == null) return;
          if (_suppressPoiOnce) {
            _suppressPoiOnce = false;
            return;
          }
          if (_activeFilter != 'none') {
            _vm.activeFilter = _activeFilter;
            await _vm.refreshPois(_lastIdleLat!, _lastIdleLon!);
            _applyVmPoisToLocal(_lastIdleLat!, _lastIdleLon!);
            // 사용자 위치 라벨 재표시 보장
            if (_lat != null && _lon != null) {
              try { await _channel.setUserLocation(lat: _lat!, lon: _lon!); } catch (_) {}
            }
          }
        });
      }
    });
  }

  void _applyVmPoisToLocal(double lat, double lon) {
    final maps = <Map<String, dynamic>>[];
    int id = 200000;
    for (final p in _vm.pois) {
      maps.add({'name': p.name, 'lat': p.lat, 'lon': p.lon, 'id': id++});
    }
    _pois = _withDistance(lat, lon, maps);
    setState(() {});
  }
}



