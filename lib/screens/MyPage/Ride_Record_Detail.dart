import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

class RideRecordDetail extends StatelessWidget {
  final Map<String, dynamic> record;
  const RideRecordDetail({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final startedAt = DateTime.tryParse(record['startedAt'] ?? '') ?? DateTime.now();
    final endedAt = DateTime.tryParse(record['endedAt'] ?? '') ?? DateTime.now();
    final elapsedSeconds = (record['elapsedSeconds'] as num?)?.toInt() ?? 0;
    final distanceMeters = (record['distanceMeters'] as num?)?.toDouble() ?? 0.0;
    final avgSpeed = (record['avgSpeedKmh'] as num?)?.toDouble() ?? 0.0;
    final maxSpeed = (record['maxSpeedKmh'] as num?)?.toDouble() ?? 0.0;
    final imagePath = record['imagePath'] as String?;

    String formatHms(int seconds) {
      final hh = (seconds ~/ 3600).toString().padLeft(2, '0');
      final mm = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
      final ss = (seconds % 60).toString().padLeft(2, '0');
      return '$hh:$mm:$ss';
    }

    final header = AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        color: Colors.black12,
        child: (imagePath != null && File(imagePath).existsSync())
            ? Image.file(File(imagePath), fit: BoxFit.cover)
            : Center(
                child: Text(
                  '이미지 없음',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('주행 기록'),
      ),
      body: ListView(
        children: [
            header,
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${startedAt.year}.${startedAt.month.toString().padLeft(2, '0')}.${startedAt.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _row('주행 시간', formatHms(elapsedSeconds)),
                  _row('거리', '${(distanceMeters / 1000).toStringAsFixed(2)} km'),
                  _row('평균 속도', '${avgSpeed.toStringAsFixed(1)} km/h'),
                  _row('최고 속도', '${maxSpeed.toStringAsFixed(1)} km/h'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
