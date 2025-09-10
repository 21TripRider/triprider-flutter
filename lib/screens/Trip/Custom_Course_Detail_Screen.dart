// lib/screens/Trip/Custom_Course_Detail_Screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:triprider/screens/Trip/Custom_Riding_Course_Screen.dart';
import 'package:triprider/screens/trip/models.dart';

class CustomCourseDetailScreen extends StatefulWidget {
  final CoursePreview preview;

  const CustomCourseDetailScreen({
    super.key,
    required this.preview,
  });

  @override
  State<CustomCourseDetailScreen> createState() =>
      _CustomCourseDetailScreenState();
}

class _CustomCourseDetailScreenState extends State<CustomCourseDetailScreen> {
  GoogleMapController? _map;

  void _goToCustomRidingCourse() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const CustomRidingCourse()),
    );
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('저장 완료')));
  }

  @override
  Widget build(BuildContext context) {
    final wps = widget.preview.waypoints;
    final center = wps.isEmpty
        ? const LatLng(33.3846, 126.5535)
        : LatLng(wps.first.lat, wps.first.lng);

    return Scaffold(
      backgroundColor: Colors.white, // ✅ 전체 흰색
      appBar: AppBar(
        title: const Text('코스 미리보기'),
        centerTitle: true,
        backgroundColor: Colors.white, // ✅ 상단바 흰색
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize( // ✅ 연한 하단 구분선
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEDEDED)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: _goToCustomRidingCourse,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 0,
              ),
              child: const Text('저장', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 지도
          SizedBox(
            height: 300,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: center, zoom: 11),
              onMapCreated: (c) => _map = c,
              markers: _buildMarkers(wps),
              polylines: _buildPolyline(wps),
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),
          const SizedBox(height: 8),

          // 요약 (흰색 배경 유지)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '총 ${widget.preview.distanceKm.toStringAsFixed(1)} km / '
                      '약 ${widget.preview.durationMin} 분',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // 스텝 리스트 (흰색 배경 유지)
          Expanded(
            child: ListView.separated(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: wps.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _StepTile(i: i + 1, w: wps[i]),
            ),
          ),
        ],
      ),
    );
  }

  Set<Marker> _buildMarkers(List<Waypoint> wps) {
    return wps.asMap().entries.map((e) {
      final i = e.key + 1;
      final w = e.value;
      return Marker(
        markerId: MarkerId('wp$i'),
        position: LatLng(w.lat, w.lng),
        infoWindow: InfoWindow(title: '$i. ${w.title}'),
      );
    }).toSet();
  }

  Set<Polyline> _buildPolyline(List<Waypoint> wps) {
    if (wps.length < 2) return {};
    final pts = wps.map((w) => LatLng(w.lat, w.lng)).toList();
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        width: 5,
        points: pts,
        patterns: [PatternItem.dash(24), PatternItem.gap(10)],
        color: Colors.red,
      ),
    };
  }
}

class _StepTile extends StatelessWidget {
  final int i;
  final Waypoint w;
  const _StepTile({required this.i, required this.w});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        // ✅ 연한 회색 스트로크
        border: Border.all(color: const Color(0xFFE6E8EC), width: 1),
        // 살짝만 그림자
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE6EA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '$i',
              style: const TextStyle(
                color: Color(0xFFFF4E6B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
