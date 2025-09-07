// lib/screens/MyPage/Record_Screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:triprider/screens/Map/API/Ride_Api.dart';
import 'package:triprider/core/network/Api_client.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  List<Map<String, dynamic>> _records = [];
  double _totalKm = 0.0;
  int _totalSeconds = 0;
  bool _usedServerSummary = false;

  @override
  void initState() {
    super.initState();
    _refreshRecords();
  }

  Future<void> _refreshRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await ApiClient.userScopedKey('ride_records');
    final local = (prefs.getStringList(key) ?? <String>[])
        .map((s) {
      try {
        return jsonDecode(s) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    })
        .whereType<Map<String, dynamic>>()
        .toList();

    List<Map<String, dynamic>> finalList = local;
    bool remoteOk = false;
    List<Map<String, dynamic>> remoteMapped = const [];

    try {
      final serverList = await RideApi.listRides();
      remoteOk = true;

      if (serverList.isEmpty) {
        await prefs.remove(key);
        finalList = [];
      } else {
        remoteMapped = serverList
            .map<Map<String, dynamic>>((r) => {
          'id': r['id'],
          'startedAt': r['startedAt'],
          'endedAt': r['finishedAt'],
          'elapsedSeconds': r['movingSeconds'] ?? r['elapsedSeconds'],
          'distanceMeters':
          ((r['totalKm'] as num?)?.toDouble() ?? 0.0) * 1000.0,
          'avgSpeedKmh':
          (r['avgSpeedKmh'] as num?)?.toDouble() ?? 0.0,
          'maxSpeedKmh':
          (r['maxSpeedKmh'] as num?)?.toDouble() ?? 0.0,
          // ✅ /uploads 상대경로를 절대 URL로
          'imagePath': ApiClient.absoluteUrl(r['routeImageUrl'] ?? ''),
          'title': r['title'],
          'path': null, // 서버 기본 응답엔 path 없음
        })
            .toList();

        finalList = _mergeRecords(local, remoteMapped);
      }
    } catch (_) {
      finalList = local;
    }

    finalList.sort((a, b) {
      final ad = DateTime.tryParse(a['endedAt'] ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = DateTime.tryParse(b['endedAt'] ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

    double km = 0.0;
    int secs = 0;
    for (final r in finalList) {
      km += ((r['distanceMeters'] as num?)?.toDouble() ?? 0.0) / 1000.0;
      secs += (r['elapsedSeconds'] as num?)?.toInt() ?? 0;
    }

    if (!mounted) return;
    setState(() {
      _records = finalList;
      _totalKm = km;
      _totalSeconds = secs;
      _usedServerSummary = false;
    });

    if (remoteOk && _records.isNotEmpty) {
      try {
        final s = await RideApi.getSummary();
        final srvKm = ((s['totalKm'] as num?)?.toDouble() ?? 0.0);
        final srvSec = (s['totalSeconds'] as num?)?.toInt() ?? 0;
        if (!mounted) return;
        if (srvKm > 0 || srvSec > 0) {
          setState(() {
            _totalKm = srvKm;
            _totalSeconds = srvSec;
            _usedServerSummary = true;
          });
        }
      } catch (_) {}
    }
  }

  List<Map<String, dynamic>> _mergeRecords(
      List<Map<String, dynamic>> local,
      List<Map<String, dynamic>> remote,
      ) {
    String keyOf(Map<String, dynamic> m) {
      final id = m['id']?.toString();
      if (id != null && id.isNotEmpty) return 'id:$id';
      final ended = DateTime.tryParse(m['endedAt'] ?? '');
      final bucket = ended == null
          ? 'ts:0'
          : 'ts:${ended.millisecondsSinceEpoch ~/ 60000}';
      return bucket;
    }

    final byKey = <String, Map<String, dynamic>>{};

    for (final r in remote) {
      byKey[keyOf(r)] = Map<String, dynamic>.from(r);
    }

    bool _isBlankStr(dynamic v) =>
        v == null || (v is String && v.trim().isEmpty);

    for (final l in local) {
      final k = keyOf(l);
      if (!byKey.containsKey(k)) {
        byKey[k] = Map<String, dynamic>.from(l);
        continue;
      }
      final m = byKey[k]!;
      if (_isBlankStr(m['imagePath']) && !_isBlankStr(l['imagePath'])) {
        m['imagePath'] = l['imagePath'];
      }
      final hasPath =
          (m['path'] is List) && ((m['path'] as List).isNotEmpty);
      if (!hasPath && (l['path'] is List) && (l['path'] as List).isNotEmpty) {
        m['path'] = l['path'];
      }
    }
    return byKey.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final totalTime = _formatHms(_totalSeconds);
    final rides = _records.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 28),
        ),
        centerTitle: true,
        title:
        const Text('주행 기록', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshRecords,
        child: ListView(
          padding: const EdgeInsets.all(25),
          children: [
            SizedBox(
              height: 170,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('누적 주행거리',
                      style: TextStyle(
                          fontSize: 25, fontWeight: FontWeight.w500)),
                  Text('${_totalKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                          fontSize: 40, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      _buildStatColumn('라이딩', '$rides 회'),
                      const SizedBox(width: 30),
                      _buildStatColumn('시간', totalTime),
                      const SizedBox(width: 30),
                      _buildStatColumn('평균속도', _overallAvgSpeedKmH()),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            if (_records.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Text('아직 저장된 주행 기록이 없습니다.',
                      style: TextStyle(color: Colors.grey.shade600)),
                ),
              )
            else
              ..._records.map((r) {
                final startedAt =
                    DateTime.tryParse(r['startedAt'] ?? '') ??
                        DateTime.now();
                final date =
                    '${startedAt.year}.${startedAt.month.toString().padLeft(2, '0')}.${startedAt.day.toString().padLeft(2, '0')}';
                final distKm =
                    ((r['distanceMeters'] as num?)?.toDouble() ?? 0.0) /
                        1000.0;
                final avg = (r['avgSpeedKmh'] as num?)?.toDouble() ?? 0.0;
                final max = (r['maxSpeedKmh'] as num?)?.toDouble() ?? 0.0;
                final time =
                _formatHms((r['elapsedSeconds'] as num?)?.toInt() ?? 0);
                final imagePath = r['imagePath'] as String?;
                final routePath =
                (r['path'] as List?)?.cast<Map<String, dynamic>>();

                return _buildRideCard(
                  date: date,
                  distance: distKm.toStringAsFixed(1),
                  avgSpeed: avg.toStringAsFixed(1),
                  maxSpeed: max.toStringAsFixed(1),
                  time: time,
                  imagePath: imagePath,
                  routePath: routePath,
                );
              }),
            if (_usedServerSummary) const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _overallAvgSpeedKmH() {
    if (_totalSeconds <= 0 || _totalKm <= 0) return '-';
    final hours = _totalSeconds / 3600.0;
    final v = _totalKm / hours;
    if (v.isNaN || v.isInfinite) return '-';
    return '${v.toStringAsFixed(1)} km/h';
  }

  String _formatHms(int seconds) {
    final hh = (seconds ~/ 3600).toString().padLeft(2, '0');
    final mm = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$hh:%02d:%02d'
        .replaceFirst('%02d', mm)
        .replaceFirst('%02d', ss);
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildRideCard({
    required String date,
    required String distance,
    required String avgSpeed,
    required String maxSpeed,
    required String time,
    String? imagePath,
    List<Map<String, dynamic>>? routePath,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThumb(imagePath: imagePath, routePath: routePath),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(date,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text('$distance km',
                    style: const TextStyle(
                        fontSize: 20,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildRideInfo('평균 속도', '$avgSpeed km/h'),
                _buildRideInfo('최고 속도', '$maxSpeed km/h'),
                _buildRideInfo('주행 시간', time),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ---- 이미지/경로 비율 유틸 ----

  Future<double?> _imageAspectRatioFromProvider(ImageProvider provider) async {
    final completer = Completer<double?>();
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener((ImageInfo info, bool _) {
      completer.complete(info.image.width / info.image.height);
      stream.removeListener(listener);
    }, onError: (e, st) {
      completer.complete(null);
      stream.removeListener(listener);
    });
    stream.addListener(listener);
    return completer.future;
  }

  double _pathAspectRatio(List<Map<String, dynamic>> path) {
    if (path.isEmpty) return 4 / 3;
    double minLat = double.infinity, maxLat = -double.infinity;
    double minLon = double.infinity, maxLon = -double.infinity;
    for (final p in path) {
      final lat = (p['lat'] as num).toDouble();
      final lon = (p['lon'] as num).toDouble();
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lon < minLon) minLon = lon;
      if (lon > maxLon) maxLon = lon;
    }
    final latSpan = (maxLat - minLat).abs().clamp(1e-6, 1.0);
    final lonSpan = (maxLon - minLon).abs().clamp(1e-6, 1.0);
    final ar = lonSpan / latSpan; // width / height
    if (ar.isNaN || ar.isInfinite || ar <= 0) return 4 / 3;
    return ar;
  }

  /// 서버 상대경로도 네트워크로 처리 + 실패 시 폴리라인 폴백
  Widget _buildThumb({
    required String? imagePath,
    required List<Map<String, dynamic>>? routePath,
  }) {
    final networkUrl = _resolveRemoteUrl(imagePath);
    if (networkUrl != null) {
      final provider = NetworkImage(networkUrl);
      return FutureBuilder<double?>(
        future: _imageAspectRatioFromProvider(provider),
        builder: (ctx, snap) {
          final ar = (snap.data != null && (snap.data!) > 0) ? snap.data! : 4 / 3;
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: ar!,
              child: Image(
                image: provider,
                fit: BoxFit.contain, // 비율 동일 → 여백 최소, 크롭 없음
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) {
                  if (routePath != null && routePath.isNotEmpty) {
                    final par = _pathAspectRatio(routePath);
                    return AspectRatio(
                      aspectRatio: par,
                      child: CustomPaint(
                        painter: _RouteThumbPainter(routePath),
                        child: Container(color: Colors.white),
                      ),
                    );
                  }
                  return Container(color: Colors.black12);
                },
              ),
            ),
          );
        },
      );
    }

    final local = _resolveLocalFile(imagePath);
    if (local != null && local.existsSync()) {
      final provider = FileImage(local);
      return FutureBuilder<double?>(
        future: _imageAspectRatioFromProvider(provider),
        builder: (ctx, snap) {
          final ar = (snap.data != null && (snap.data!) > 0) ? snap.data! : 4 / 3;
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: ar!,
              child: Image(
                image: provider,
                fit: BoxFit.contain,
                alignment: Alignment.center,
              ),
            ),
          );
        },
      );
    }

    if (routePath != null && routePath.isNotEmpty) {
      final par = _pathAspectRatio(routePath);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: par,
          child: CustomPaint(
            painter: _RouteThumbPainter(routePath),
            child: Container(color: Colors.white),
          ),
        ),
      );
    }

    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text('이미지 없음',
          style: TextStyle(color: Colors.grey.shade600)),
    );
  }

  /// 서버 URL 정규화
  String? _resolveRemoteUrl(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;

    if (s.startsWith('/uploads/') || s.startsWith('uploads/')) {
      s = ApiClient.absoluteUrl(s);
    }

    if (s.startsWith('http://') || s.startsWith('https://')) {
      if (Platform.isAndroid &&
          (s.contains('://localhost') ||
              s.contains('://127.0.0.1') ||
              s.contains('://0.0.0.0'))) {
        s = s.replaceFirst(RegExp(r'://(localhost|127\.0\.0\.1|0\.0\.0\.0)'),
            '://10.0.2.2');
      }
      return s;
    }
    return null;
  }

  /// 로컬 파일 경로 정규화
  File? _resolveLocalFile(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('http://') || s.startsWith('https://')) return null;
    if (s.startsWith('file://')) s = s.substring(7);
    return File(s);
  }

  Widget _buildRideInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _RouteThumbPainter extends CustomPainter {
  _RouteThumbPainter(this.path);
  final List<Map<String, dynamic>> path;

  @override
  void paint(Canvas canvas, Size size) {
    if (path.isEmpty) return;

    double minLat = double.infinity, maxLat = -double.infinity;
    double minLon = double.infinity, maxLon = -double.infinity;
    for (final p in path) {
      final lat = (p['lat'] as num).toDouble();
      final lon = (p['lon'] as num).toDouble();
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lon < minLon) minLon = lon;
      if (lon > maxLon) maxLon = lon;
    }
    final latSpan = (maxLat - minLat).abs().clamp(1e-6, 1.0);
    final lonSpan = (maxLon - minLon).abs().clamp(1e-6, 1.0);
    const pad = 12.0; // 폴리라인은 가독성을 위해 약간의 여백 유지
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;

    Offset project(double lat, double lon) {
      final x = ((lon - minLon) / lonSpan) * w + pad;
      final y = h - ((lat - minLat) / latSpan) * h + pad;
      return Offset(x, y);
    }

    final stroke = Paint()
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final bg = Paint()..color = const Color(0xFFF6F6F6);

    final pathDraw = Path();
    bool first = true;
    for (final p in path) {
      final o = project(
          (p['lat'] as num).toDouble(), (p['lon'] as num).toDouble());
      if (first) {
        pathDraw.moveTo(o.dx, o.dy);
        first = false;
      } else {
        pathDraw.lineTo(o.dx, o.dy);
      }
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(12)),
      bg,
    );
    canvas.drawPath(pathDraw, stroke);
  }

  @override
  bool shouldRepaint(covariant _RouteThumbPainter oldDelegate) =>
      oldDelegate.path != path;
}
