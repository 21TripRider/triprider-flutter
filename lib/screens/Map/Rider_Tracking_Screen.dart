// lib/screens/Map/Ride_Tracking_Screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triprider/screens/Map/API/Ride_Api.dart';
import 'package:triprider/state/rider_tracker_service.dart';
import 'package:triprider/utils/kakao_map_channel.dart';
import 'package:triprider/screens/Map/KakaoMapScreen.dart';

class RideTrackingScreen extends StatefulWidget {
  const RideTrackingScreen({super.key});

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  final KakaoMapChannel _channel = KakaoMapChannel();
  final RideTrackerService svc = RideTrackerService.instance;

  bool _initialized = false;
  String? _error;
  double? _lat;
  double? _lon;
  final int _zoomLevel = 16;
  static const String _kakaoRestApiKey = '471ee3eec0b9d8a5fc4eb86fb849e524';
  static const String _googleStaticApiKey = 'AIzaSyA53fiKudkjSzIee7zn-gebXgJuWNuF4lc';

  // 상단 미니맵 "follow-me" 전용
  StreamSubscription<Position>? _mapPosSub;
  bool _mapReady = false;
  final bool _followMe = true;

  // UI interactions
  DateTime? _stopHoldStart; // 종료 길게누름 시작 시간
  bool _stopPressed = false; // ✅ 눌림 모션 상태
  // UI 색상 스위치(일시정지 상태에 따라 변경)
  Color get _labelColor => svc.isPaused ? const Color(0xFFCCCCCC) : const Color(0xFFB73047);
  Color get _bannerColor => svc.isPaused ? Colors.white : const Color(0xFFFF4E6B);

  @override
  void initState() {
    super.initState();
    svc.addListener(_onSvc);
    _initAndStart();
  }

  void _onSvc() {
    if (mounted) setState(() {});
  }

  Future<void> _initAndStart() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _error = '위치 서비스가 꺼져 있습니다.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() => _error = '위치 권한이 필요합니다.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);
      setState(() {
        _lat = pos.latitude;
        _lon = pos.longitude;
        _initialized = true;
      });

      // 지도 준비가 되어 있으면 즉시 싱크
      await _ensureMiniMapSynced();

      // 주행 세션 복구/시작
      await svc.tryRestore();
      if (!svc.isActive) {
        await svc.start();
      }
    } catch (e) {
      setState(() => _error = '현재 위치를 가져올 수 없습니다.');
    }
  }

  Future<String> _prefsKeyRideRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('jwt') ?? '';
    final suffix = jwt.isEmpty ? '' : '_${jwt.hashCode.toRadixString(16)}';
    return 'ride_records$suffix';
  }

  // ── 상단 미니맵: PlatformView 생성 콜백 ────────────────────────────
  void _onPlatformViewCreated(int id) {
    _channel.initChannel(id);
    _mapReady = true;
    _ensureMiniMapSynced(); // 위치/카메라 초기 싱크 + 팔로우 스트림 시작
  }

  // 미니맵 초기화 및 팔로우 시작
  Future<void> _ensureMiniMapSynced() async {
    if (!_mapReady || _lat == null || _lon == null) return;
    try {
      await _channel.setUserLocationVisible(false); // ✅ 기본 파란 점 숨김
      await _channel.setUserLocation(lat: _lat!, lon: _lon!); // 좌표 동기화(기능 유지)
      await _channel.animateCamera(
        lat: _lat!,
        lon: _lon!,
        zoomLevel: _zoomLevel,
        durationMs: 350,
      );
    } catch (_) {}

    _startMiniMapFollow();
  }

  // 위치 스트림으로 상단 미니맵이 사용자를 계속 따라오게
  void _startMiniMapFollow() {
    _mapPosSub?.cancel();
    DateTime lastMove = DateTime.fromMillisecondsSinceEpoch(0);

    _mapPosSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3,
      ),
    ).listen((pos) async {
      _lat = pos.latitude;
      _lon = pos.longitude;

      if (!_mapReady) return;
      try {
        await _channel.setUserLocation(lat: _lat!, lon: _lon!);
      } catch (_) {}

      final now = DateTime.now();
      if (_followMe && now.difference(lastMove).inMilliseconds > 350) {
        lastMove = now;
        try {
          await _channel.animateCamera(
            lat: _lat!,
            lon: _lon!,
            zoomLevel: _zoomLevel,
            durationMs: 300,
          );
        } catch (_) {}
      }

      if (mounted) setState(() {});
    });
  }

  Widget _buildPlatformView(double lat, double lon) {
    // 지도는 배경만 표시가 아니라, 이제 follow-me로 갱신됨
    if (Platform.isAndroid) {
      return AndroidView(
        viewType: 'map-kakao',
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParams: {
          'lat': lat,
          'lon': lon,
          'zoomLevel': _zoomLevel,
        },
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return UiKitView(
      viewType: 'map-kakao',
      onPlatformViewCreated: _onPlatformViewCreated,
      creationParams: {
        'lat': lat,
        'lon': lon,
        'zoomLevel': _zoomLevel,
      },
      creationParamsCodec: const StandardMessageCodec(),
    );
  }

  void _startTracking() async {
    await svc.start();
    setState(() {});
  }

  Future<void> _finishAndPop() async {
    final elapsedSec =
    svc.elapsed.inSeconds.toDouble().clamp(1, double.infinity);
    final hours = elapsedSec / 3600.0;
    final avgSpeedKmh =
    hours > 0 ? (svc.totalMeters / 1000.0) / hours : 0.0;

    // 썸네일 생성: Google Static → Kakao Static → 캡처
    String? imagePath;
    try {
      String? staticPath = await _buildGoogleStaticMapForPath(svc.path);
      staticPath ??= await _buildStaticMapForPath(svc.path);
      if (staticPath != null) imagePath = staticPath;
    } catch (_) {}
    try {
      if (imagePath == null) {
        imagePath = await _channel.captureSnapshot();
      }
    } catch (_) {}

    final record = <String, dynamic>{
      'startedAt': svc.startedAt?.toIso8601String(),
      'endedAt': DateTime.now().toIso8601String(),
      'elapsedSeconds': svc.elapsed.inSeconds,
      'distanceMeters': svc.totalMeters,
      'maxSpeedKmh': 0.0,
      'avgSpeedKmh': avgSpeedKmh,
      'path': svc.path.map((p) => {'lat': p[0], 'lon': p[1]}).toList(),
    };
    if (imagePath != null) {
      record['imagePath'] = imagePath;
    }

    // 로컬 저장(기존 정책 유지)
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _prefsKeyRideRecords();
      final list = prefs.getStringList(key) ?? <String>[];

      bool merged = false;
      final ended = DateTime.tryParse(record['endedAt'] ?? '');
      final newKm =
          ((record['distanceMeters'] as num?)?.toDouble() ?? 0.0) / 1000.0;
      for (int i = 0; i < list.length; i++) {
        try {
          final m = jsonDecode(list[i]) as Map<String, dynamic>;
          final e = DateTime.tryParse(m['endedAt'] ?? '');
          if (ended != null && e != null) {
            final sameMinute = (ended.millisecondsSinceEpoch ~/ 60000) ==
                (e.millisecondsSinceEpoch ~/ 60000);
            final km =
                ((m['distanceMeters'] as num?)?.toDouble() ?? 0.0) / 1000.0;
            if (sameMinute && ((newKm - km).abs() < 0.1)) {
              list[i] = jsonEncode(record);
              merged = true;
              break;
            }
          }
        } catch (_) {}
      }
      if (!merged) list.add(jsonEncode(record));
      await prefs.setStringList(key, list);
    } catch (_) {}

    // 서버 업로드 잔여분
    await svc.uploadPendingPoints();

    // 서버 종료(스냅샷 첨부)
    if (svc.rideId != null) {
      final meta = <String, dynamic>{
        'title': '라이딩',
        'memo': '',
        'elapsedSeconds': svc.elapsed.inSeconds,
        'distanceMeters': svc.totalMeters,
        'avgSpeedKmh': avgSpeedKmh,
        'maxSpeedKmh': 0.0,
        'startedAt': svc.startedAt?.toIso8601String(),
        'finishedAt': DateTime.now().toIso8601String(),
      };
      try {
        await RideApi.finishRide(
          rideId: svc.rideId!,
          body: meta,
          snapshot: imagePath != null ? File(imagePath) : null,
        );
      } catch (_) {}
    }

    if (!mounted) return;
    await svc.finish();
    Navigator.of(context).pop(record);
  }

  void _minimizeToMap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const KakaoMapScreen(overlayFromTracking: true),
      ),
    );
  }

  // ======================= Static Map 생성 =======================

  // Google Static
  Future<String?> _buildGoogleStaticMapForPath(List<List<double>> path) async {
    if (path.length < 2) return null;
    final sampled = _sampleForStatic(path, 80);
    final pathParam = sampled
        .map((p) => '${p[0].toStringAsFixed(5)},${p[1].toStringAsFixed(5)}')
        .join('|'); // lat,lon
    final params = {
      'size': '800x600',
      'scale': '2',
      'path': 'color:0x1565C0ff|weight:6|$pathParam',
      'key': _googleStaticApiKey,
    };
    final uri =
    Uri.https('maps.googleapis.com', '/maps/api/staticmap', params);
    final resp = await http.get(uri);
    if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;
    final dir = await Directory.systemTemp.createTemp('triprider_gstatic');
    final file =
    File('${dir.path}/route_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(resp.bodyBytes);
    return file.path;
  }

  // Kakao Static
  Future<String?> _buildStaticMapForPath(List<List<double>> path) async {
    if (path.length < 2) return null;
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
    if (span > 0.5) {
      level = 9;
    } else if (span > 0.25) {
      level = 10;
    } else if (span > 0.1) {
      level = 11;
    } else if (span > 0.05) {
      level = 12;
    } else if (span > 0.02) {
      level = 13;
    } else if (span > 0.01) {
      level = 14;
    } else if (span > 0.005) {
      level = 15;
    } else {
      level = 16;
    }

    final sampled = _sampleForStatic(path, 120);
    final pts = sampled
        .map((p) => '${p[1].toStringAsFixed(5)},${p[0].toStringAsFixed(5)}')
        .join('|'); // lon,lat
    final params = {
      'center':
      '${centerLon.toStringAsFixed(6)},${centerLat.toStringAsFixed(6)}',
      'level': level.toString(),
      'w': '800',
      'h': '600',
      'paths': 'color:0x1565C0|width:6|$pts',
    };
    final uri = Uri.https('dapi.kakao.com', '/v2/maps/staticmap', params);
    final resp = await http.get(uri,
        headers: {'Authorization': 'KakaoAK $_kakaoRestApiKey'});
    if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;
    final dir = await Directory.systemTemp.createTemp('triprider_static');
    final file =
    File('${dir.path}/route_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(resp.bodyBytes);
    return file.path;
  }

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
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    if (!_initialized) {
      return Scaffold(
        body: Center(
          child: _error != null
              ? Text(_error!)
              : const CircularProgressIndicator(),
        ),
      );
    }

    final mapHeight = 220.0;
    final elapsedText = _formatElapsed(svc.elapsed);
    final currentKmh = svc.currentSpeedKmh;
    final avgKmh = svc.elapsed.inSeconds > 0
        ? (svc.totalMeters / 1000.0) / (svc.elapsed.inSeconds / 3600.0)
        : 0.0;
    final distanceKm =
    (svc.totalMeters / 1000.0).clamp(0.0, double.infinity);

    return WillPopScope(
      onWillPop: () async {
        _minimizeToMap();
        return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            Column(
              children: [
                SizedBox(
                  height: mapHeight + padding.top,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        top: padding.top,
                        child: _buildPlatformView(_lat!, _lon!),
                      ),
                      // ✅ 미니맵 중앙 커스텀 위치 마커 (하얀 링 + 핑크 코어)
                      Positioned.fill(
                        top: padding.top,
                        child: const IgnorePointer(
                          ignoring: true,
                          child: Center(child: _MyLocationDot()),
                        ),
                      ),
                      // 닫기 버튼(상단 좌측)
                      Positioned(
                        top: padding.top + 8,
                        left: 12,
                        child: GestureDetector(
                          onTap: _minimizeToMap,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black12, blurRadius: 8)
                              ],
                            ),
                            child: const Icon(Icons.arrow_back_ios_new,
                                color: Colors.black87),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 하단 패널
                Expanded(
                  child: Container(
                    color: _bannerColor,
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _metric(
                                  big: _formatInt(currentKmh),
                                  unit: 'km/h',
                                  label: '현재 속도'),
                              _metric(
                                  big: _formatInt(avgKmh),
                                  unit: 'km/h',
                                  label: '평균 속도'),
                              _metric(
                                  big: _formatInt(distanceKm),
                                  unit: 'km',
                                  label: '주행 거리'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Spacer(),
                        _buildControls(),
                        SizedBox(height: padding.bottom + 80),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // 화면 전체 기준 중앙에 주행 시간 표시
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    elapsedText,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1C1B1F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '주행 시간',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _labelColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatElapsed(Duration d) {
    final hh = d.inHours.remainder(60).toString().padLeft(2, '0');
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  String _formatInt(double v) {
    if (!v.isFinite) return '0';
    return v.round().toString();
  }

  Widget _metric({required String big, required String unit, required String label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              big,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1B1F),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1C1B1F),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: _labelColor,
          ),
        ),
      ],
    );
  }

  void _togglePause() => svc.isPaused ? _resumeTracking() : _pauseTracking();

  void _pauseTracking() {
    svc.pause();
    setState(() {});
  }

  void _resumeTracking() {
    svc.resume();
    setState(() {});
  }

  Widget _buildControls() {
    if (!svc.isPaused) {
      // 러닝 상태: 중앙 원형 일시정지 버튼
      return Center(
        child: GestureDetector(
          onTap: _togglePause,
          child: Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: Colors.black87,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pause, color: Colors.white, size: 40),
          ),
        ),
      );
    }

    // 일시정지 상태: 좌(종료), 우(재생)
    final size = MediaQuery.of(context).size;
    final gap = size.width * (72.0 / 375.0); // 375 기준 72px 비례 간격
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ✅ 종료 버튼: 탭 → 팝업, 길게(2초) → 종료, 눌림 모션
        GestureDetector(
          onTapDown: (_) {
            setState(() {
              _stopPressed = true;
              _stopHoldStart = DateTime.now();
            });
          },
          onTapUp: (_) async {
            final held = (_stopHoldStart != null)
                ? DateTime.now().difference(_stopHoldStart!)
                : Duration.zero;
            setState(() {
              _stopPressed = false;
              _stopHoldStart = null;
            });
            if (held >= const Duration(seconds: 2)) {
              await _finishAndPop();
            } else {
              // 안내 팝업
              showTripriderPopup(
                context,
                title: "종료 안내",
                message: "길게 누르면 종료됩니다.",
                type: PopupType.info,
              );
            }
          },
          onTapCancel: () {
            setState(() {
              _stopPressed = false;
              _stopHoldStart = null;
            });
          },
          child: AnimatedScale(
            scale: _stopPressed ? 0.94 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            child: Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: Color(0xFF1F1F23),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.stop, color: Colors.white, size: 36),
            ),
          ),
        ),
        SizedBox(width: gap),

        // ▶️ 재생 버튼
        GestureDetector(
          onTap: _togglePause,
          child: Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: Color(0xFFFF4E6B),
              shape: BoxShape.circle,
            ),
            child:
            const Icon(Icons.play_arrow, color: Colors.white, size: 40),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    svc.removeListener(_onSvc);
    _mapPosSub?.cancel(); // 미니맵 follow 스트림 정리
    super.dispose();
  }
}

/// ✅ 중앙 커스텀 내 위치 마커 (하얀 링 + 핑크 코어 + 은은한 퍼짐)
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
