import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:triprider/utils/kakao_map_channel.dart';
import 'package:triprider/widgets/Bottom_App_Bar.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:triprider/data/kakao_local_api.dart';
import 'package:triprider/controllers/map_controller.dart';
import 'package:triprider/state/map_view_model.dart';

class KakaoMapScreen extends StatefulWidget {
  const KakaoMapScreen({super.key});

  @override
  State<KakaoMapScreen> createState() => _KakaoMapScreenState();
}

class _KakaoMapScreenState extends State<KakaoMapScreen> {
  final KakaoMapChannel _channel = KakaoMapChannel();

  bool _loading = true;
  String? _warning;

  double? _lat;
  double? _lon;
  final int _zoomLevel = 16;

  // POI
  String _activeFilter = 'none'; // none | gas | moto
  List<Map<String, dynamic>> _pois = <Map<String, dynamic>>[];
  Timer? _poiDebounce;
  int _lastIdleZoom = 16;
  double? _lastIdleLat;
  double? _lastIdleLon;

  // Tracking
  bool _tracking = false;
  DateTime? _startTime;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  StreamSubscription<Position>? _posSub;
  StreamSubscription<Position>? _userPosSub;
  final List<List<double>> _path = <List<double>>[];
  double _totalDistanceMeters = 0.0;
  double _maxSpeedKmh = 0.0;
  double? _currentSpeedKmh;

  // ViewModel/Controller
  static const String _kakaoRestApiKey = '471ee3eec0b9d8a5fc4eb86fb849e524';
  late final KakaoLocalApi _api = KakaoLocalApi(_kakaoRestApiKey);
  late final MapController _mapController = MapController(_channel);
  late final MapViewModel _vm = MapViewModel(api: _api, controller: _mapController);

  bool _suppressPoiOnce = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  // ─────────────────────────────────────────────────────────
  // 위치 초기화
  Future<void> _initLocation() async {
    // 기본 제주 공항 좌표로 먼저 그리기
    setState(() {
      _lat = 33.510414;
      _lon = 126.491353;
      _loading = false;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _warning = '위치 서비스가 꺼져 있어 기본 위치로 표시합니다.';
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        _warning = '위치 권한이 없어 기본 위치로 표시합니다.';
        return;
      }

      final pos = await Geolocator
          .getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 5));

      setState(() {
        _lat = pos.latitude;
        _lon = pos.longitude;
      });

      await _channel.animateCamera(
        lat: pos.latitude,
        lon: pos.longitude,
        zoomLevel: _zoomLevel,
        durationMs: 350,
      );
      await _channel.setUserLocation(lat: pos.latitude, lon: pos.longitude);

      _startUserLocationUpdates();

      if (_activeFilter != 'none') {
        _vm.activeFilter = _activeFilter;
        await _vm.refreshPois(pos.latitude, pos.longitude);
        _applyVmPoisToLocal(pos.latitude, pos.longitude);
      }
    } on TimeoutException {
      _warning = '현재 위치를 가져오지 못해 기본 위치로 표시합니다.';
    } catch (_) {
      _warning = '위치 정보를 가져오지 못해 기본 위치로 표시합니다.';
    } finally {
      if (mounted) setState(() {});
    }
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

  // ─────────────────────────────────────────────────────────
  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading ? const Center(child: CircularProgressIndicator()) : _buildBody(),
      floatingActionButton: (_lat != null && _lon != null)
          ? FloatingActionButton(
        heroTag: 'recenter',
        onPressed: () async {
          try {
            _suppressPoiOnce = true;
            await _channel.animateCamera(
              lat: _lat!,
              lon: _lon!,
              zoomLevel: _zoomLevel,
              durationMs: 300,
            );
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
    final safeTop = MediaQuery.of(context).padding.top + 12;
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

        // 상단 필터 버튼
        Positioned(
          top: safeTop + 44,
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

        // 하단 POI 패널
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
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
              ),
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _pois.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (_, i) {
                  final m = _pois[i];
                  final name = (m['name'] as String?) ?? '-';
                  final dist = (m['distance'] as double?) ?? 0.0;
                  final lat = (m['lat'] as num).toDouble();
                  final lon = (m['lon'] as num).toDouble();
                  return ListTile(
                    dense: true,
                    title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: dist > 0 ? Text('${(dist / 1000).toStringAsFixed(2)} km') : null,
                    onTap: () async {
                      try {
                        await _channel.setMarkers([
                          {
                            'lat': lat,
                            'lon': lon,
                            'id': 900000 + i,
                            'title': name,
                            'type': 'poi',
                            'color': 'red',
                          }
                        ]);
                        await _channel.animateCamera(
                          lat: lat,
                          lon: lon,
                          zoomLevel: 17,
                          durationMs: 350,
                        );
                      } catch (_) {}
                    },
                  );
                },
              ),
            ),
          ),

        // 하단 플레이/스톱 버튼
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

  Widget _buildPlatformView(double lat, double lon) {
    final creationParams = <String, dynamic>{'lat': lat, 'lon': lon, 'zoomLevel': _zoomLevel};

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
        final raw = (args['raw'] as Map?) ?? {};
        final title = (raw['name']?.toString() ?? args['name']?.toString() ?? '').replaceFirst('⛽ ', '');
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
                    TextButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse('tel:$phone');
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      },
                      icon: const Icon(Icons.call),
                      label: const Text('전화'),
                    ),
                  if (url != null && url.isNotEmpty)
                    TextButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.link),
                      label: const Text('상세'),
                    ),
                ]),
              ],
            ),
          ),
        );
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
            if (_lat != null && _lon != null) {
              try {
                await _channel.setUserLocation(lat: _lat!, lon: _lon!);
              } catch (_) {}
            }
          }
        });
      }
    });
  }

  // ─────────────────────────────────────────────────────────
  // Tracking
  void _onPlayPressed() => _tracking ? _stopTracking() : _startTracking();

  void _startTracking() async {
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

    // 이전 오버레이 정리
    await _channel.clearRoutePolyline();
    await _channel.clearMarkers();
    await _channel.setUserLocationVisible(true);

    setState(() {
      _tracking = true;
      _startTime = DateTime.now();
      _elapsed = Duration.zero;
      _path.clear();
      _totalDistanceMeters = 0.0;
      _maxSpeedKmh = 0.0;
      _currentSpeedKmh = null;
    });

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startTime != null) {
        setState(() => _elapsed = DateTime.now().difference(_startTime!));
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
      final speedKmh = (pos.speed.isFinite ? pos.speed : 0.0) * 3.6;

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

      // 카메라 팔로우 + 점진 폴리라인 업데이트
      try {
        await _channel.animateCamera(lat: lat, lon: lon, zoomLevel: _zoomLevel, durationMs: 350);
        await _channel.setUserLocation(lat: lat, lon: lon);
      } catch (_) {}

      try {
        final start = _path.length > 500 ? _path.length - 500 : 0;
        final pts = <Map<String, double>>[];
        for (int i = start; i < _path.length; i++) {
          final p = _path[i];
          pts.add({'lat': p[0], 'lon': p[1]});
        }
        await _channel.updatePolyline(pts); // 실시간 가느다란 라인(네이티브 구현)
      } catch (_) {}
    });
  }

  void _stopTracking() async {
    _posSub?.cancel();
    _ticker?.cancel();

    setState(() => _tracking = false);

    final elapsedSec = _elapsed.inSeconds.toDouble().clamp(1, double.infinity);
    final hours = elapsedSec / 3600.0;
    final avgSpeedKmh = hours > 0 ? (_totalDistanceMeters / 1000.0) / hours : 0.0;

    // 전체 경로 포인트
    final pts = _path.map((p) => {'lat': p[0], 'lon': p[1]}).toList();

    // 1) 경로를 굵은 파란색 라인으로 다시 그려서 남김
    try {
      await _channel.setRoutePolyline(points: pts, color: '#1a73e8', width: 8, outlineWidth: 1.5, outlineColor: '#1456b8');
    } catch (_) {}

    // 2) 시작/종료 핀 마커
    if (_path.isNotEmpty) {
      final start = _path.first;
      final end = _path.last;
      try {
        await _channel.setMarkers([
          {
            'lat': start[0],
            'lon': start[1],
            'id': 700001,
            'title': '출발',
            'type': 'start',
            'color': 'green',
          },
          {
            'lat': end[0],
            'lon': end[1],
            'id': 700002,
            'title': '도착',
            'type': 'end',
            'color': 'red',
          },
        ]);
      } catch (_) {}
    }

    // 3) 사용자 블루닷 가리기(핀에 시선 집중)
    await _channel.setUserLocationVisible(false);

    // 4) 화면을 경로에 맞게 맞춤
    if (pts.isNotEmpty) {
      try {
        await _channel.fitBounds(points: pts, paddingPx: 36);
      } catch (_) {}
    }

    // 5) 저장
    final record = <String, dynamic>{
      'startedAt': _startTime?.toIso8601String(),
      'endedAt': DateTime.now().toIso8601String(),
      'elapsedSeconds': _elapsed.inSeconds,
      'distanceMeters': _totalDistanceMeters,
      'maxSpeedKmh': _maxSpeedKmh,
      'avgSpeedKmh': avgSpeedKmh,
      'path': pts,
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('ride_records') ?? <String>[];

      // 스냅샷(오버레이가 그려진 상태로)
      String? imagePath;
      try {
        await Future.delayed(const Duration(milliseconds: 300));
        imagePath = await _channel.captureSnapshot();
      } catch (_) {}

      final withImage = Map<String, dynamic>.from(record);
      if (imagePath != null) withImage['imagePath'] = imagePath;

      list.add(jsonEncode(withImage));
      await prefs.setStringList('ride_records', list);
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('주행 기록 저장 완료')));
  }

  Widget _trackingHUD() {
    String two(int n) => n.toString().padLeft(2, '0');
    final hh = two(_elapsed.inHours);
    final mm = two(_elapsed.inMinutes.remainder(60));
    final ss = two(_elapsed.inSeconds.remainder(60));
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

  // ─────────────────────────────────────────────────────────
  // POI 관련
  Widget _filterButton({required String label, required String value}) {
    final active = _activeFilter == value;
    return GestureDetector(
      onTap: () async {
        final willDeactivate = _activeFilter == value;
        if (willDeactivate) {
          setState(() {
            _activeFilter = 'none';
            _pois = [];
          });
          try {
            await _channel.clearMarkers();
            await _channel.removeAllSpotLabel();
          } catch (_) {}
          if (_lat != null && _lon != null) {
            try {
              await _channel.setUserLocation(lat: _lat!, lon: _lon!);
            } catch (_) {}
          }
          return;
        }

        setState(() {
          _activeFilter = value;
          _pois = [];
        });
        _vm.activeFilter = value;
        if (_lat != null && _lon != null) {
          await _vm.refreshPois(_lat!, _lon!);
          _applyVmPoisToLocal(_lat!, _lon!);
          try {
            await _channel.setUserLocation(lat: _lat!, lon: _lon!);
          } catch (_) {}
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

  void _applyVmPoisToLocal(double lat, double lon) {
    final out = <Map<String, dynamic>>[];
    for (final p in _vm.pois) {
      out.add({'name': p.name, 'lat': p.lat, 'lon': p.lon});
    }
    _pois = _withDistance(lat, lon, out);
    setState(() {});
  }

  List<Map<String, dynamic>> _withDistance(
      double lat, double lon, List<Map<String, dynamic>> items) {
    double haversine(double lat1, double lon1, double lat2, double lon2) {
      const R = 6371000.0;
      final dLat = (lat2 - lat1) * math.pi / 180.0;
      final dLon = (lon2 - lon1) * math.pi / 180.0;
      final a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
          math.cos(lat1 * math.pi / 180.0) *
              math.cos(lat2 * math.pi / 180.0) *
              (math.sin(dLon / 2) * math.sin(dLon / 2));
      final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      return R * c;
    }

    final out = <Map<String, dynamic>>[];
    for (final m in items) {
      final d = haversine(
        lat,
        lon,
        (m['lat'] as num).toDouble(),
        (m['lon'] as num).toDouble(),
      );
      final n = Map<String, dynamic>.from(m);
      n['distance'] = d;
      out.add(n);
    }
    out.sort((a, b) => ((a['distance'] as num).compareTo((b['distance'] as num))));
    return out;
  }
}
