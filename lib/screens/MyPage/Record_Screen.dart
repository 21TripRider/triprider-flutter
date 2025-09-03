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

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _loadSummaryFromServer();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('ride_records') ?? <String>[];
    final parsed = <Map<String, dynamic>>[];
    for (final s in list) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        parsed.add(m);
      } catch (_) {}
    }
    // 최신 순 정렬 (endedAt 기준)
    parsed.sort((a, b) {
      final ad = DateTime.tryParse(a['endedAt'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = DateTime.tryParse(b['endedAt'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

    double km = 0.0;
    int secs = 0;
    for (final r in parsed) {
      km += ((r['distanceMeters'] as num?)?.toDouble() ?? 0.0) / 1000.0;
      secs += (r['elapsedSeconds'] as num?)?.toInt() ?? 0;
    }

    setState(() {
      _records = parsed;
      _totalKm = km;
      _totalSeconds = secs;
    });
  }

  Future<void> _loadSummaryFromServer() async {
    try {
      final s = await RideApi.getSummary();
      final totalKm = ((s['totalKm'] as num?)?.toDouble() ?? 0.0);
      final totalSeconds = (s['totalSeconds'] as num?)?.toInt() ?? 0;
      setState(() {
        _totalKm = totalKm; // 서버 권위값으로 덮어씀
        _totalSeconds = totalSeconds;
      });
    } catch (_) {}
    try {
      final list = await RideApi.listRides();
      // 서버 목록의 스냅샷/경로를 로컬 표시 포맷으로 매핑 (간단히 날짜/거리/시간만 반영)
      final mapped = <Map<String, dynamic>>[];
      for (final r in list) {
        mapped.add({
          'startedAt': r['startedAt'],
          'endedAt': r['finishedAt'],
          'elapsedSeconds': r['movingSeconds'] ?? r['elapsedSeconds'],
          'distanceMeters': ((r['totalKm'] as num?)?.toDouble() ?? 0.0) * 1000.0,
          'avgSpeedKmh': r['avgSpeedKmh'],
          'maxSpeedKmh': r['maxSpeedKmh'],
          'imagePath': ApiClient.absoluteUrl(r['routeImageUrl'] ?? ''),
          'path': null,
        });
      }
      if (mapped.isNotEmpty) {
        setState(() {
          _records = mapped;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final totalTime = _formatHms(_totalSeconds);
    final rides = _records.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, size: 28),
        ),
        centerTitle: true,
        title: Text('주행 기록', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: EdgeInsets.all(25),
        children: [
          // 누적 주행 정보
          Container(
            height: 170,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '누적 주행거리',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w500),
                ),
                Text(
                  '${_totalKm.toStringAsFixed(1)} km',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildStatColumn('라이딩', '$rides 회'),
                    SizedBox(width: 30),
                    _buildStatColumn('시간', totalTime),
                    SizedBox(width: 30),
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
                child: Text('아직 저장된 주행 기록이 없습니다.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ..._records.map((r) {
              final startedAt = DateTime.tryParse(r['startedAt'] ?? '') ?? DateTime.now();
              final date = '${startedAt.year}.${startedAt.month.toString().padLeft(2, '0')}.${startedAt.day.toString().padLeft(2, '0')}';
              final distKm = ((r['distanceMeters'] as num?)?.toDouble() ?? 0.0) / 1000.0;
              final avg = (r['avgSpeedKmh'] as num?)?.toDouble() ?? 0.0;
              final max = (r['maxSpeedKmh'] as num?)?.toDouble() ?? 0.0;
              final time = _formatHms((r['elapsedSeconds'] as num?)?.toInt() ?? 0);
              final imagePath = r['imagePath'] as String?;
              final routePath = (r['path'] as List?)?.cast<Map<String, dynamic>>();
              return _buildRideCard(
                date: date,
                location: null,
                distance: distKm.toStringAsFixed(1),
                avgSpeed: avg.toStringAsFixed(1),
                maxSpeed: max.toStringAsFixed(1),
                time: time,
                imagePath: imagePath,
                routePath: routePath,
                onTap: null,
              );
            }),
        ],
      ),
    );
  }

  String _overallAvgSpeedKmH() {
    if (_totalSeconds <= 0) return '-';
    final hours = _totalSeconds / 3600.0;
    final v = _totalKm / hours;
    if (v.isNaN || v.isInfinite) return '-';
    return '${v.toStringAsFixed(1)} km/h';
  }

  String _formatHms(int seconds) {
    final hh = (seconds ~/ 3600).toString().padLeft(2, '0');
    final mm = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRideCard({
    required String date,
    String? location,
    required String distance,
    required String avgSpeed,
    required String maxSpeed,
    required String time,
    String? imagePath,
    List<Map<String, dynamic>>? routePath,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: EdgeInsets.only(bottom: 20),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_buildImageWidget(imagePath) != null)
              AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildImageWidget(imagePath)!,
                ),
              )
            else if (routePath != null && routePath.isNotEmpty)
              AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CustomPaint(
                    painter: _RouteThumbPainter(routePath),
                    child: Container(color: Colors.white),
                  ),
                ),
              )
            else
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text('이미지 없음', style: TextStyle(color: Colors.grey.shade600)),
              ),
            const SizedBox(height: 12),
            // 날짜 & 거리
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(date, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('$distance km', style: TextStyle(fontSize: 20, color: Colors.black54, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),

            // 위치 태그 (선택)
            if (location != null && location.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(location, style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)),
              ),

            const SizedBox(height: 12),
            Divider(),
            const SizedBox(height: 12),

            // 속도, 시간 정보
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildRideInfo('평균 속도', '$avgSpeed km'),
                _buildRideInfo('최고 속도', '$maxSpeed km'),
                _buildRideInfo('주행 시간', time),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildImageWidget(String? path) {
    if (path == null) return null;
    final s = path.trim();
    if (s.isEmpty) return null;
    final isHttp = s.startsWith('http://') || s.startsWith('https://');
    if (isHttp) {
      return Image.network(
        s,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: Colors.black12),
      );
    }
    final f = File(s);
    if (f.existsSync()) {
      return Image.file(f, fit: BoxFit.cover);
    }
    return null;
  }

  Widget _buildRideInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _RouteThumbPainter extends CustomPainter {
  _RouteThumbPainter(this.path);
  final List<Map<String, dynamic>> path; // [{'lat':..,'lon':..}, ...]

  @override
  void paint(Canvas canvas, Size size) {
    if (path.isEmpty) return;
    double minLat = double.infinity, maxLat = -double.infinity;
    double minLon = double.infinity, maxLon = -double.infinity;
    for (final p in path) {
      final lat = (p['lat'] as num).toDouble();
      final lon = (p['lon'] as num).toDouble();
      if (lat < minLat) minLat = lat; if (lat > maxLat) maxLat = lat;
      if (lon < minLon) minLon = lon; if (lon > maxLon) maxLon = lon;
    }
    final latSpan = (maxLat - minLat).abs().clamp(1e-6, 1.0);
    final lonSpan = (maxLon - minLon).abs().clamp(1e-6, 1.0);
    final pad = 12.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    Offset project(double lat, double lon) {
      final x = ((lon - minLon) / lonSpan) * w + pad;
      final y = h - ((lat - minLat) / latSpan) * h + pad; // 위가 북쪽
      return Offset(x, y);
    }
    final paint = Paint()
      ..color = const Color(0xFF1565C0)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pathDraw = Path();
    bool first = true;
    for (final p in path) {
      final o = project((p['lat'] as num).toDouble(), (p['lon'] as num).toDouble());
      if (first) { pathDraw.moveTo(o.dx, o.dy); first = false; }
      else { pathDraw.lineTo(o.dx, o.dy); }
    }
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0,0,size.width,size.height), const Radius.circular(12)), Paint()..color=const Color(0xFFF6F6F6));
    canvas.drawPath(pathDraw, paint);
  }

  @override
  bool shouldRepaint(covariant _RouteThumbPainter oldDelegate) => oldDelegate.path != path;
}
