// lib/screens/trip/course_detail_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triprider/screens/RiderGram/Api_client.dart';
import 'package:triprider/screens/trip/models.dart';

class CourseDetailScreen extends StatefulWidget {
  final CourseView? view; // 저장된 코스일 때
  final CoursePreview? preview; // 미리보기일 때

  const CourseDetailScreen.view({super.key, required CourseView view})
    : view = view,
      preview = null;

  const CourseDetailScreen.preview({super.key, required CoursePreview preview})
    : view = null,
      preview = preview;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  GoogleMapController? _map;
  late final List<Waypoint> _wps;
  late final bool _isPreview;

  @override
  void initState() {
    super.initState();
    _isPreview = widget.preview != null;
    _wps = widget.preview?.waypoints ?? widget.view?.waypoints ?? [];
  }

  Future<void> _save() async {
    if (!_isPreview) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getInt('userId') ?? prefs.getInt('id');

      final res = await ApiClient.post(
        '/api/custom/courses',
        headers: {if (uid != null) 'X-USER-ID': '$uid'},
        body: {
          'title': '나의 여행 코스',
          'waypoints': _wps.map((e) => e.toJson()).toList(),
          'distanceKm': widget.preview!.distanceKm,
          'durationMin': widget.preview!.durationMin,
          'polyline': null,
        },
      );
      final view = CourseView.fromJson(jsonDecode(res.body));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => CourseDetailScreen.view(view: view)),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장 완료')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isPreview ? '코스 미리보기' : (widget.view?.title ?? '여행 코스');
    final km = (_isPreview
            ? widget.preview!.distanceKm
            : widget.view!.distanceKm)
        .toStringAsFixed(1);
    final min =
        _isPreview ? widget.preview!.durationMin : widget.view!.durationMin;

    final center =
        _wps.isEmpty
            ? const LatLng(33.3846, 126.5535)
            : LatLng(_wps.first.lat, _wps.first.lng);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios),
        ),
        centerTitle: true,
        title: Text(title),
        actions: [
          if (_isPreview) TextButton(onPressed: _save, child: const Text('저장')),
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
              markers: _buildMarkers(),
              polylines: _buildPolyline(),
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
                  '총 $km km / 약 $min 분',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // 스텝 리스트
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _wps.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _StepTile(i: i + 1, w: _wps[i]),
            ),
          ),
        ],
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    return _wps.asMap().entries.map((e) {
      final i = e.key + 1;
      final w = e.value;
      return Marker(
        markerId: MarkerId('wp$i'),
        position: LatLng(w.lat, w.lng),
        infoWindow: InfoWindow(title: '$i. ${w.title}'),
      );
    }).toSet();
  }

  Set<Polyline> _buildPolyline() {
    if (_wps.length < 2) return {};
    final pts = _wps.map((w) => LatLng(w.lat, w.lng)).toList();
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
                const SizedBox(height: 2),
                if (w.cat1 != null || w.cat2 != null)
                  Text(
                    '${w.cat1 ?? ''} ${w.cat2 ?? ''}',
                    style: const TextStyle(color: Colors.black45),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
