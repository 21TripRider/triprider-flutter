import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triprider/screens/MyPage/Ride_Record_Detail.dart';

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
              return _buildRideCard(
                date: date,
                location: null,
                distance: distKm.toStringAsFixed(1),
                avgSpeed: avg.toStringAsFixed(1),
                maxSpeed: max.toStringAsFixed(1),
                time: time,
                imagePath: imagePath,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RideRecordDetail(record: r),
                    ),
                  );
                },
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
