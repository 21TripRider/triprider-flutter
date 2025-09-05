//lib/state/ride_tracker_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triprider/screens/Map/API/Ride_Api.dart';

class RideTrackerService extends ChangeNotifier {
  RideTrackerService._();
  static final RideTrackerService instance = RideTrackerService._();

  // Session state
  bool isActive = false;
  bool isPaused = false;
  int? rideId;
  DateTime? startedAt;
  DateTime? _segmentStart;
  Duration elapsedAccumulated = Duration.zero;

  double totalMeters = 0.0;
  double currentSpeedKmh = 0.0;
  final List<List<double>> path = <List<double>>[];
  int _persistCounter = 0;
  final List<Map<String, dynamic>> _batchPoints = <Map<String, dynamic>>[];

  StreamSubscription<Position>? _posSub;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  Duration get elapsed => _elapsed;

  Future<void> tryRestore() async {
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getBool('tracking_active') ?? false;
    if (!active) return;
    isActive = true;
    isPaused = prefs.getBool('tracking_paused') ?? false;
    final startedIso = prefs.getString('tracking_startedAt');
    final accMs = prefs.getInt('tracking_elapsed_acc') ?? 0;
    final rid = prefs.getInt('tracking_ride_id');
    if (rid != null) rideId = rid;
    startedAt = startedIso != null ? DateTime.tryParse(startedIso) : DateTime.now();
    elapsedAccumulated = Duration(milliseconds: accMs);
    // 경로/거리 복원(선택): 간단히 유지, 정밀 복원은 로컬 저장 구조 필요
    totalMeters = prefs.getDouble('tracking_total_meters') ?? totalMeters;
    final pathJson = prefs.getString('tracking_path_json');
    if (pathJson != null && path.isEmpty) {
      try {
        final List d = jsonDecode(pathJson) as List;
        for (final e in d) {
          if (e is List && e.length >= 2) {
            path.add([(e[0] as num).toDouble(), (e[1] as num).toDouble()]);
          }
        }
      } catch (_) {}
    }
    if (!isPaused) {
      // 진행 중이었으면 segmentStart에서 지금까지 경과분을 누적
      final segIso = prefs.getString('tracking_segment_start');
      if (segIso != null) {
        final seg = DateTime.tryParse(segIso);
        if (seg != null) {
          elapsedAccumulated += DateTime.now().difference(seg);
        }
      }
      // 누적 반영 후 재개
      _elapsed = elapsedAccumulated;
      await _persist(active: true, paused: false, segmentStart: DateTime.now());
      _resumeInternal();
    } else {
      _elapsed = elapsedAccumulated;
      notifyListeners();
    }
  }

  Future<void> start() async {
    if (isActive) return;
    isActive = true;
    isPaused = false;
    startedAt = DateTime.now();
    elapsedAccumulated = Duration.zero;
    totalMeters = 0;
    currentSpeedKmh = 0;
    path.clear();

    try {
      rideId = await RideApi.startRide();
    } catch (_) {
      rideId = null;
    }

    await _persist(active: true, paused: false, segmentStart: null);
    _resumeInternal();
  }

  void pause() {
    if (!isActive || isPaused) return;
    isPaused = true;
    if (_segmentStart != null) {
      elapsedAccumulated += DateTime.now().difference(_segmentStart!);
      _segmentStart = null;
    }
    _ticker?.cancel();
    _posSub?.cancel();
    _persist(active: true, paused: true, segmentStart: null);
    notifyListeners();
  }

  void resume() {
    if (!isActive || !isPaused) return;
    isPaused = false;
    _persist(active: true, paused: false, segmentStart: DateTime.now());
    _resumeInternal();
  }

  Future<void> finish() async {
    if (!isActive) return;
    _posSub?.cancel();
    _ticker?.cancel();
    if (_segmentStart != null) {
      elapsedAccumulated += DateTime.now().difference(_segmentStart!);
      _segmentStart = null;
    }
    _elapsed = elapsedAccumulated;
    // 업로드 잔여분은 화면 단에서 하던 로직을 재사용(여기서는 생략)
    await _persist(active: false, paused: false, segmentStart: null);
    isActive = false;
    notifyListeners();
  }

  void _resumeInternal() {
    _segmentStart = DateTime.now();
    // segmentStart 영속화(앱 이동/재시작 시 이어서 계산)
    _persist(active: true, paused: false, segmentStart: _segmentStart);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_segmentStart != null) {
        _elapsed = elapsedAccumulated + DateTime.now().difference(_segmentStart!);
        notifyListeners();
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
      final sp = (pos.speed.isFinite ? pos.speed : 0.0) * 3.6;
      currentSpeedKmh = sp;
      if (path.isNotEmpty) {
        final prev = path.last;
        final d = Geolocator.distanceBetween(prev[0], prev[1], lat, lon);
        if (d >= 1.0) {
          totalMeters += d;
          path.add(<double>[lat, lon]);
          _batchPoints.add({
            'seq': path.length,
            'lat': lat,
            'lng': lon,
            'speedKmh': sp,
            'epochMillis': DateTime.now().millisecondsSinceEpoch,
          });
        }
      } else {
        path.add(<double>[lat, lon]);
        _batchPoints.add({
          'seq': path.length,
          'lat': lat,
          'lng': lon,
          'speedKmh': sp,
          'epochMillis': DateTime.now().millisecondsSinceEpoch,
        });
      }
      // 앱 이동/재시작 대비 경량 영속화(10포인트마다)
      _persistCounter = (_persistCounter + 1) % 10;
      if (_persistCounter == 0) {
        await _persist(active: true, paused: isPaused);
      }
      if (rideId != null && _batchPoints.length >= 5) {
        await uploadPendingPoints();
      }
      notifyListeners();
    });
  }

  Future<void> uploadPendingPoints() async {
    if (rideId == null || _batchPoints.isEmpty) return;
    final sending = List<Map<String, dynamic>>.from(_batchPoints);
    _batchPoints.clear();
    try {
      await RideApi.uploadPoints(rideId: rideId!, points: sending);
    } catch (_) {
      // 실패 시 되돌려 재시도
      _batchPoints.insertAll(0, sending);
    }
  }

  Future<void> _persist({required bool active, required bool paused, DateTime? segmentStart}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tracking_active', active);
    await prefs.setBool('tracking_paused', paused);
    await prefs.setString('tracking_startedAt', (startedAt ?? DateTime.now()).toIso8601String());
    await prefs.setInt('tracking_elapsed_acc', elapsedAccumulated.inMilliseconds);
    await prefs.setDouble('tracking_total_meters', totalMeters);
    if (rideId != null) await prefs.setInt('tracking_ride_id', rideId!);
    // 경로를 샘플링해 저장(용량/성능 고려)
    final sampled = _samplePath(path, 400);
    await prefs.setString('tracking_path_json', jsonEncode(sampled));
    if (active && !paused && (segmentStart ?? _segmentStart) != null) {
      await prefs.setString('tracking_segment_start', (segmentStart ?? _segmentStart)!.toIso8601String());
    } else {
      await prefs.remove('tracking_segment_start');
    }
  }

  List<List<double>> _samplePath(List<List<double>> src, int maxPoints) {
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
}


