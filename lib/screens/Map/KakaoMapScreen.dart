// lib/screens/Map/KakaoMapScreen.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:triprider/controllers/map_controller.dart';
import 'package:triprider/data/kakao_local_api.dart';
import 'package:triprider/screens/Map/Rider_Tracking_Screen.dart';
import 'package:triprider/state/map_view_model.dart';
import 'package:triprider/state/rider_tracker_service.dart';
import 'package:triprider/utils/kakao_map_channel.dart';
import 'package:triprider/widgets/Bottom_App_Bar.dart';

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
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                    border: Border.all(color: Color(0xFFE9E9EE)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.sports_motorsports_rounded,
                              color: Colors.pink),
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
                      const Divider(
                          height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                      const SizedBox(height: 10),
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.35,
                          color: Colors.black87,
                        ),
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

/// =======================
/// ✅ 메인 맵 스크린
/// =======================
class KakaoMapScreen extends StatefulWidget {
  const KakaoMapScreen({super.key, this.overlayFromTracking = false});
  final bool overlayFromTracking;

  @override
  State<KakaoMapScreen> createState() => _KakaoMapScreenState();
}

class _KakaoMapScreenState extends State<KakaoMapScreen> {
  final KakaoMapChannel _channel = KakaoMapChannel();

  bool _loading = true;
  double? _lat;
  double? _lon;
  final int _zoomLevel = 16;
  String? _warning;

  StreamSubscription<Position>? _userPosSub;

  String _activeFilter = 'none';
  List<Map<String, dynamic>> _pois = [];
  final Map<int, Map<String, dynamic>> _labelById = {};

  bool _suppressPoiOnce = false;
  Timer? _poiDebounce;

  static const String _kakaoRestApiKey = '471ee3eec0b9d8a5fc4eb86fb849e524';
  late final KakaoLocalApi _api = KakaoLocalApi(_kakaoRestApiKey);
  late final MapController _mapController = MapController(_channel);
  late final MapViewModel _vm =
  MapViewModel(api: _api, controller: _mapController);

  // follow-me 모드
  final bool _followMe = true;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
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

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _lat = pos.latitude;
        _lon = pos.longitude;
      });

      // ✅ 초기 카메라 중앙 이동
      await _channel.animateCamera(
          lat: pos.latitude,
          lon: pos.longitude,
          zoomLevel: _zoomLevel,
          durationMs: 350);

      // ✅ 기본 파란 점 숨김 (커스텀 마커 사용)
      await _channel.setUserLocationVisible(false);
      // 좌표는 계속 동기화(내부 기능 유지)
      await _channel.setUserLocation(lat: pos.latitude, lon: pos.longitude);

      // ✅ 스트림 구독 시작 (항상 중앙 유지)
      _startUserLocationUpdates();
    } catch (_) {
      setState(() {
        _warning = '위치 정보를 가져오지 못해 기본 위치로 표시합니다.';
      });
    }
  }

  /// ======================= 필터 버튼 =======================
  Widget _filterButton({required String label, required String value}) {
    final active = _activeFilter == value;
    return GestureDetector(
      onTap: () async {
        if (_activeFilter == value) {
          setState(() {
            _activeFilter = 'none';
            _pois = [];
          });
          try {
            await _channel.removeAllSpotLabel();
          } catch (_) {}
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
          _showPoiBottomSheet(); // ✅ 리스트 바텀시트 표시
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: active ? Colors.pinkAccent : Colors.white,
          borderRadius: BorderRadius.circular(50),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value == 'gas' ? Icons.local_gas_station : Icons.motorcycle,
              color: active ? Colors.white : Colors.pinkAccent,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ======================= POI 바텀시트 =======================
  Future<void> _showPoiBottomSheet() async {
    if (_pois.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.4,
          minChildSize: 0.2,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return ListView.separated(
              controller: controller,
              itemCount: _pois.length,
              separatorBuilder: (_, __) => const Divider(
                  height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
              itemBuilder: (_, i) {
                final m = _pois[i];
                final name = (m['name'] as String?) ?? '-';
                final dist = (m['distance'] as double?) ?? 0.0;

                return InkWell(
                  onTap: () async {
                    final lat = (m['lat'] as num).toDouble();
                    final lon = (m['lon'] as num).toDouble();
                    _suppressPoiOnce = true;
                    await _channel.animateCamera(
                        lat: lat, lon: lon, zoomLevel: 16, durationMs: 350);

                    // ✅ POI만 마커로 표시
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

                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                    child: Row(
                      children: [
                        Icon(
                          _activeFilter == 'moto'
                              ? Icons.motorcycle
                              : Icons.local_gas_station,
                          color: _activeFilter == 'moto'
                              ? Colors.pinkAccent
                              : Colors.redAccent,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (dist > 0)
                          Text(
                            '${(dist / 1000).toStringAsFixed(2)} km',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// ======================= UI =======================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: (_lat != null && _lon != null)
          ? Padding(
        padding: const EdgeInsets.only(bottom: 45, right: 16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            _suppressPoiOnce = true;
            if (_lat != null && _lon != null) {
              await _channel.animateCamera(
                  lat: _lat!, lon: _lon!, zoomLevel: _zoomLevel);
            }
          },
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(
              color: const Color(0xB3F5F5F5),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 3)),
              ],
            ),
            child: const Icon(Icons.gps_fixed,
                color: Colors.black, size: 28),
          ),
        ),
      )
          : null,
      bottomNavigationBar: const BottomAppBarWidget(currentIndex: 1),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final safeTop = MediaQuery.of(context).padding.top + 12;

    return Stack(
      children: [
        _buildPlatformView(_lat!, _lon!),

        // ✅ 중앙 커스텀 "내 위치" 마커 (파란 점 대체)
        const IgnorePointer(
          ignoring: true,
          child: Center(child: _MyLocationDot()),
        ),

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
                child:
                Text(_warning!, style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),
        /// 상단 필터 버튼
        Positioned(
          top: safeTop + 15,
          left: 16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _filterButton(label: '주유소', value: 'gas'),
              const SizedBox(width: 12),
              _filterButton(label: '오토바이', value: 'moto'),
            ],
          ),
        ),
        /// 하단 중앙 재생 버튼
        Positioned(
          left: 0,
          right: 0,
          bottom: 0 + kBottomNavigationBarHeight + 1,
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

  Future<void> _onPlayPressed() async {
    final svc = RideTrackerService.instance;
    await svc.tryRestore();
    if (svc.isActive) {
      if (widget.overlayFromTracking) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      _openRideTrackingScreen();
      return;
    }
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
      showTripriderPopup(context,
          title: '주행 기록', message: '주행 기록 저장 완료', type: PopupType.success);
      try {
        await _channel.removeAllSpotLabel();
      } catch (_) {}
    }
  }

  /// ======================= 위치 스트림 (항상 중앙 고정)
  void _startUserLocationUpdates() {
    _userPosSub?.cancel();

    DateTime lastMove = DateTime.fromMillisecondsSinceEpoch(0);

    _userPosSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3,
      ),
    ).listen((pos) async {
      _lat = pos.latitude;
      _lon = pos.longitude;

      // 좌표 동기화(경로 등 내부 로직 유지용)
      await _channel.setUserLocation(lat: _lat!, lon: _lon!);

      // 항상 가운데 유지
      final now = DateTime.now();
      if (_followMe && now.difference(lastMove).inMilliseconds > 350) {
        lastMove = now;
        await _channel.animateCamera(
          lat: _lat!,
          lon: _lon!,
          zoomLevel: _zoomLevel,
          durationMs: 300,
        );
      }
      setState(() {}); // 필요 시 UI 갱신
    });
  }

  Widget _buildPlatformView(double lat, double lon) {
    final creationParams = <String, dynamic>{
      'lat': lat,
      'lon': lon,
      'zoomLevel': _zoomLevel
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
  }

  void _applyVmPoisToLocal(double lat, double lon) {
    final maps = <Map<String, dynamic>>[];
    int id = 200000;
    for (final p in _vm.pois) {
      maps.add({
        'name': p.name,
        'lat': p.lat,
        'lon': p.lon,
        'id': id++,
      });
    }
    _pois = _withDistance(lat, lon, maps);
    setState(() {});
  }

  List<Map<String, dynamic>> _withDistance(
      double lat, double lon, List<Map<String, dynamic>> items) {
    double haversine(double lat1, double lon1, double lat2, double lon2) {
      const R = 6371000.0; // m
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
    out.sort((a, b) =>
    ((a['distance'] as num).compareTo((b['distance'] as num))));
    return out;
  }

  @override
  void dispose() {
    _userPosSub?.cancel();
    super.dispose();
  }
}

/// =======================
/// ✅ 재생 버튼 위젯
/// =======================
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
    _svc.addListener(_onSvc);
  }

  @override
  Widget build(BuildContext context) {
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
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

/// =======================
/// ✅ 중앙 커스텀 내 위치 마커
/// =======================
class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 퍼지는 파동
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1800),
            curve: Curves.easeOut,
            onEnd: () {},
            builder: (ctx, t, _) {
              final r = 28.0 * (0.6 + 0.6 * t);
              final opacity = (1 - t).clamp(0.0, 1.0);
              return Container(
                width: r,
                height: r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF4F6B).withOpacity(0.20 * opacity),
                ),
              );
            },
          ),
          // 하얀 링
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4F6B).withOpacity(.45),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
          // 핑크 코어
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFF4F6B),
            ),
          ),
        ],
      ),
    );
  }
}
