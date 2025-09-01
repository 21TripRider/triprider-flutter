import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triprider/screens/RiderGram/Api_client.dart';            // ← 저장 API 호출
import 'package:triprider/screens/Trip/Riding_Course_Screen.dart';
import 'package:triprider/screens/trip/models.dart';

class CourseDetailScreen extends StatefulWidget {
  final CourseView? view;       // 저장된 코스 보기
  final CoursePreview? preview; // 미리보기

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

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _isPreview = widget.preview != null;
    _wps = widget.preview?.waypoints ?? widget.view?.waypoints ?? [];
  }

  /// 미리보기 → 서버 저장 → 맞춤형 여행 코스 화면으로 전환
  Future<void> _saveAndGo() async {
    if (!_isPreview || _saving) return;
    setState(() => _saving = true);

    try {
      // 선택적으로 사용자 ID 헤더 붙이기
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getInt('userId') ?? prefs.getInt('id');

      // 서버에 저장
      // 백엔드에서 사용하는 스키마에 맞춰 body 구성하세요.
      // 여기서는 waypoints 배열을 그대로 전달합니다.
      final body = {
        'title': '나의 여행 코스',
        'distanceKm': widget.preview!.distanceKm,
        'durationMin': widget.preview!.durationMin,
        'waypoints': _wps.map((w) => w.toJson()).toList(),
      };

      await ApiClient.post(
        '/api/custom/courses',           // ← 서버 저장 엔드포인트
        headers: { if (uid != null) 'X-USER-ID': '$uid' },
        body: body,
      );

      if (!mounted) return;

      // 저장 완료 토스트
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('저장 완료')));

      // 스택 정리 후 목록이 자동 로드되는 화면(Scaffold)로 이동
      // (해당 화면에서 MyCourseCardList가 initState 때 목록을 불러옵니다)
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RidingCourse()),
            (route) => route.isFirst, // 첫 화면만 남기고 밀어냄
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isPreview ? '코스 미리보기' : (widget.view?.title ?? '여행 코스');
    final km = (_isPreview ? widget.preview!.distanceKm : widget.view!.distanceKm)
        .toStringAsFixed(1);
    final min = _isPreview ? widget.preview!.durationMin : widget.view!.durationMin;

    final center = _wps.isEmpty
        ? const LatLng(33.3846, 126.5535)
        : LatLng(_wps.first.lat, _wps.first.lng);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios),
        ),
        centerTitle: true,
        title: Text(title),
        actions: [
          if (_isPreview)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: _saving ? null : _saveAndGo,
                child: _saving
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Text('저장', style: TextStyle(fontWeight: FontWeight.bold)),
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
          BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 3)),
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
                const SizedBox(height: 2),
                if (w.cat1 != null || w.cat2 != null)
                  Text('${w.cat1 ?? ''} ${w.cat2 ?? ''}', style: const TextStyle(color: Colors.black45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
