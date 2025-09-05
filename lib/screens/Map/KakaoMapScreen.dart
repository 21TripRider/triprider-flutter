// lib/screens/Map/KakaoMapScreen.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:triprider/controllers/map_controller.dart';
import 'package:triprider/data/kakao_local_api.dart';
import 'package:triprider/screens/Map/Rider_Tracking_Screen.dart';
// import 'package:triprider/screens/Map/API/Ride_Api.dart';

import 'package:triprider/state/map_view_model.dart';
import 'package:triprider/state/rider_tracker_service.dart';
import 'package:triprider/utils/kakao_map_channel.dart';
import 'package:triprider/widgets/Bottom_App_Bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:url_launcher/url_launcher.dart';

/// =======================
/// ✅ 커스텀 팝업 유틸
/// =======================
enum PopupType { info, success, warn, error }

void showTripriderPopup(
    BuildContext context, {
      required String title,
      required String message,
      PopupType type = PopupType.info,
      Duration duration = const Duration(milliseconds: 2500),
    }) {
  final overlay = Overlay.of(context);
  if (overlay == null) return;

  Color accent;
  switch (type) {
    case PopupType.success:
      accent = const Color(0xFF39C172);
      break;
    case PopupType.warn:
      accent = const Color(0xFFFFA000);
      break;
    case PopupType.error:
      accent = const Color(0xFFE74C3C);
      break;
    case PopupType.info:
    default:
      accent = const Color(0xFFFF4E6B);
      break;
  }

  late OverlayEntry entry;
  bool closed = false;
  void safeRemove() {
    if (!closed && entry.mounted) {
      closed = true;
      entry.remove();
    }
  }

  entry = OverlayEntry(
    builder: (ctx) => SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 16,
            right: 16,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              builder: (_, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * -8),
                  child: child,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 6)),
                    ],
                    border: Border.all(color: Color(0xFFE9E9EE)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.sports_motorsports_rounded, color: Colors.pink),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Colors.black.withOpacity(0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              message,
                              style: const TextStyle(
                                fontSize: 14.5,
                                height: 1.35,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  overlay.insert(entry);
  Future.delayed(duration, safeRemove);
}

class KakaoMapScreen extends StatefulWidget {
  const KakaoMapScreen({super.key, this.overlayFromTracking = false});
  final bool overlayFromTracking; // 트래킹 화면 위에 얹혀진 맵인지 여부

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

  // Tracking state (별도 RideTrackingScreen으로 이동)
  bool _tracking = false; // HUD/버튼 색상 등 과거 용도, 현재는 사용 안 함
  StreamSubscription<Position>? _posSub; // 사용자 위치 아이콘 업데이트만 유지
  StreamSubscription<Position>? _userPosSub;
  int _lastRenderedPointCount = 0;

  // 저장 연타 방지 (사용 안 함)
  // bool _savingRide = false;

  // POI/라벨 관련
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
  // Google Static Map API (Static Map에만 사용)
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

  // ======================= 공통 유틸 =======================

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
      final d = haversine(lat, lon, (m['lat'] as num).toDouble(),
          (m['lon'] as num).toDouble());
      final n = Map<String, dynamic>.from(m);
      n['distance'] = d;
      out.add(n);
    }
    out.sort((a, b) =>
    ((a['distance'] as num).compareTo((b['distance'] as num))));
    return out;
  }

  // ======================= POI/필터 UI =======================

  Widget _filterButton({required String label, required String value}) {
    final active = _activeFilter == value;
    return GestureDetector(
      onTap: () async {
        // 토글
        final willDeactivate = _activeFilter == value;
        if (willDeactivate) {
          setState(() {
            _activeFilter = 'none';
            _pois = [];
          });
          try {
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
          border: Border.all(
              color: active ? Colors.blue : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(color: active ? Colors.white : Colors.black)),
      ),
    );
  }

  // ======================= 위치 초기화 =======================

  Future<void> _initLocation() async {
    // 기본 좌표(제주공항)로 먼저 렌더
    setState(() {
      _lat = 33.510414;
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

      final pos = await Geolocator
          .getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 5));

      setState(() {
        _lat = pos.latitude;
        _lon = pos.longitude;
      });

      try {
        await _channel.animateCamera(
            lat: pos.latitude,
            lon: pos.longitude,
            zoomLevel: _zoomLevel,
            durationMs: 350);
        await _channel.setUserLocation(
            lat: pos.latitude, lon: pos.longitude);
      } catch (_) {}

      _startUserLocationUpdates();

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

  // ======================= 빌드 =======================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: (_lat != null && _lon != null)
          ? FloatingActionButton(
        heroTag: 'recenter',
        onPressed: () async {
          try {
            _suppressPoiOnce = true;
            await _channel.animateCamera(
                lat: _lat!, lon: _lon!, zoomLevel: _zoomLevel, durationMs: 300);
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
        // 주행 HUD는 별도 화면에서 표시 (기존 HUD 제거)
        // 상단 필터
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
                    title: Text(name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle:
                    dist > 0 ? Text('${(dist / 1000).toStringAsFixed(2)} km') : null,
                    onTap: () async {
                      final lat = (m['lat'] as num).toDouble();
                      final lon = (m['lon'] as num).toDouble();
                      final name = (m['name'] as String?) ?? '';
                      try {
                        _suppressPoiOnce = true;
                        await _channel.animateCamera(
                            lat: lat, lon: lon, zoomLevel: 16, durationMs: 350);
                        try {
                          await _channel.clearMarkers();
                        } catch (_) {}
                        await _channel.setMarkers([
                          {
                            'id': 999001,
                            'lat': lat,
                            'lon': lon,
                            'title': name,
                            'type': 'poi',
                            'color': 'blue',
                          }
                        ]);
                      } catch (_) {}
                    },
                  );
                },
              ),
            ),
          ),
        // 하단 중앙 버튼
        Positioned(
          left: 0,
          right: 0,
          bottom: 24 + kBottomNavigationBarHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TrackingPlayButton(onPressed: _onPlayPressed),
            ],
          ),
        ),
      ],
    );
  }

  void _onPlayPressed() async {
    // 서비스 상태 복원 후 동작 결정
    final svc = RideTrackerService.instance;
    await svc.tryRestore();
    if (svc.isActive) {
      // 트래킹 화면 위에 얹힌 맵이면 현재 맵을 닫아 기존 트래킹 화면으로 복귀
      if (widget.overlayFromTracking) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      // 일반 맵에서라도 기존 트래킹이 있다면 새로 만들지 말고 같은 트래킹 화면을 맨 위로
      // (간단 처리: 동일 화면을 push 하지 않고 그대로 재사용하도록 pop-if-possible)
      _openRideTrackingScreen();
      return;
    }
    // 세션이 없으면 새로 시작
    await svc.start();
    _openRideTrackingScreen();
  }

  Future<void> _openRideTrackingScreen() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RideTrackingScreen(),
        fullscreenDialog: true,
      ),
    );
    if (!mounted) return;
    if (result is Map<String, dynamic>) {
      showTripriderPopup(
        context,
        title: '주행 기록',
        message: '주행 기록 저장 완료',
        type: PopupType.success,
      );
      try {
        await _channel.removeAllSpotLabel();
      } catch (_) {}
    }
  }

  // 기존 HUD 제거됨

  // 트래킹 로직은 전부 RideTrackingScreen에서만 동작합니다

  // 과거 트래킹 종료 로직은 RideTrackingScreen으로 이관됨

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

  // ======================= 플랫폼 뷰/콜백 =======================

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
          final title = (raw['name']?.toString() ??
              m['name']?.toString() ??
              '')
              .replaceFirst('⛽ ', '');
          final address = raw['address']?.toString();
          final phone = raw['phone']?.toString();
          final url = raw['url']?.toString();
          if (!mounted) return;
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
                borderRadius:
                BorderRadius.vertical(top: Radius.circular(16))),
            builder: (_) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  if (address != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(address)),
                  const SizedBox(height: 12),
                  Row(children: [
                    if (phone != null && phone.isNotEmpty)
                      TextButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse('tel:$phone');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                          icon: const Icon(Icons.call),
                          label: const Text('전화')),
                    if (url != null && url.isNotEmpty)
                      TextButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.link),
                          label: const Text('상세')),
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

  void _applyVmPoisToLocal(double lat, double lon) {
    final maps = <Map<String, dynamic>>[];
    int id = 200000;
    for (final p in _vm.pois) {
      maps.add({'name': p.name, 'lat': p.lat, 'lon': p.lon, 'id': id++});
    }
    _pois = _withDistance(lat, lon, maps);
    setState(() {});

    final labels = <Map<String, dynamic>>[];
    final prefix =
    (_activeFilter == 'gas') ? '⛽ ' : (_activeFilter == 'moto') ? '🏍️ ' : '';
    for (final m in maps) {
      labels.add({
        'name': '$prefix${m['name']}',
        'lat': m['lat'],
        'lon': m['lon'],
        'id': m['id']
      });
    }
    () async {
      try {
        await _channel.setLabels(labels);
      } catch (_) {}
      if (_lat != null && _lon != null) {
        try {
          await _channel.setUserLocation(lat: _lat!, lon: _lon!);
        } catch (_) {}
      }
    }();
  }

  // Static Map 생성 로직 제거됨(주행 종료 로직 이관)

  @override
  void dispose() {
    _posSub?.cancel();
    _userPosSub?.cancel();
    super.dispose();
  }

}

class _TrackingPlayButton extends StatefulWidget {
  const _TrackingPlayButton({required this.onPressed});
  final VoidCallback onPressed;
  @override
  State<_TrackingPlayButton> createState() => _TrackingPlayButtonState();
}

class _TrackingPlayButtonState extends State<_TrackingPlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac =
  AnimationController(vsync: this, duration: const Duration(seconds: 2))
    ..repeat();
  final RideTrackerService _svc = RideTrackerService.instance;
  bool _trackingActive = false;
  bool _trackingPaused = false;

  @override
  void initState() {
    super.initState();
    _loadFlag();
    _svc.addListener(_onSvc);
  }

  Future<void> _loadFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _trackingActive = prefs.getBool('tracking_active') ?? false;
        _trackingPaused = prefs.getBool('tracking_paused') ?? false;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // 애니메이션 on/off 제어
    if (_trackingActive) {
      if (!_ac.isAnimating) _ac.repeat();
    } else {
      if (_ac.isAnimating) _ac.stop(canceled: false);
    }
    return GestureDetector(
      onTap: widget.onPressed,
      child: SizedBox(
        width: 88,
        height: 88,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 회전하는 스트로크(주행중일 때만)
            if (_trackingActive)
              RotationTransition(
                turns: _ac,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.transparent, width: 4),
                    gradient: const SweepGradient(
                      colors: [
                        Color(0x00FFFFFF),
                        Color(0x55FFFFFF),
                        Color(0x00FFFFFF),
                      ],
                    ),
                  ),
                ),
              ),
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: Color(0xFFFF4E6B),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _trackingActive
                    ? (_trackingPaused ? Icons.play_arrow : Icons.pause)
                    : Icons.play_arrow,
                color: Colors.white,
                size: 40,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _svc.removeListener(_onSvc);
    _ac.dispose();
    super.dispose();
  }

  void _onSvc() {
    setState(() {
      _trackingActive = _svc.isActive;
      _trackingPaused = _svc.isPaused;
    });
  }
}
