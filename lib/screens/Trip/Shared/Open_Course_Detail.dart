// lib/screens/Trip/shared/open_course_detail.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:triprider/screens/RiderGram/Api_client.dart';
import 'package:triprider/screens/Trip/Course_Detail_WithNearby.dart';
import 'package:triprider/screens/Trip/Course_Detailmap.dart';


enum CourseDetailMode { withNearby, fullMap }

/// 코스 상세 열기(공통)
Future<void> openCourseDetail(
    BuildContext context,
    String category,
    int id, {
      CourseDetailMode mode = CourseDetailMode.withNearby,
    }) async {
  try {
    final res = await ApiClient.get('/api/travel/riding/$category/$id');
    final map = jsonDecode(res.body) as Map<String, dynamic>;

    // polyline: [{lat, lng}, ...]
    final list = (map['polyline'] as List<dynamic>? ?? const []);
    final pts = <LatLng>[];
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      pts.add(LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble()));
    }
    if (pts.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('경로 데이터가 없습니다.')),
      );
      return;
    }

    if (!context.mounted) return;
    if (mode == CourseDetailMode.fullMap) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CourseDetailmap(
            start: pts.first,
            end: pts.last,
            startTitle: '출발',
            endTitle: '도착',
            points: pts,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CourseDetailWithNearby(
            points: pts,
            start: pts.first,
            end: pts.last,
            startTitle: '출발',
            endTitle: '도착',
            courseCategory: category,
            courseId: id,
          ),
        ),
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('상세 불러오기 실패: $e')),
    );
  }
}
