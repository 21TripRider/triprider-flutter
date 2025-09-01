import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:triprider/screens/Trip/Custom_Riding_Course_Screen.dart';
import 'package:triprider/screens/trip/models.dart';

/// 코스 상세(커스텀) 화면은 '한 화면만' 그린다.
/// 저장 버튼을 누르면 Navigator로 CustomRidingCourse 화면으로 '전환'한다.
class CustomCourseDetailScreen extends StatefulWidget {
  final CoursePreview preview; // 미리보기 데이터(경로/거리/시간/웨이포인트 등)

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
    // 화면 전환: 현재 화면을 대체하려면 pushReplacement 사용
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomRidingCourse(),
      ),
    );

    // (선택) 토스트
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('저장 완료')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wps = widget.preview.waypoints;
    final center = wps.isEmpty
        ? const LatLng(33.3846, 126.5535)
        : LatLng(wps.first.lat, wps.first.lng);

    return Scaffold(
      appBar: AppBar(
        title: const Text('코스 미리보기'),
        centerTitle: true,
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
              ),
              child: const Text(
                '저장',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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

          // 요약
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

          // 스텝 리스트
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
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
                Text(
                  w.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

