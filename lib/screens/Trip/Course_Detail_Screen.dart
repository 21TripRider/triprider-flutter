import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
<<<<<<< HEAD
import 'package:triprider/core/network/Api_client.dart'; // 저장 API 호출
=======
import 'package:triprider/screens/RiderGram/Api_client.dart'; // 저장 API 호출
>>>>>>> f760e026460b07402064732649d558994b487b74
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
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getInt('userId') ?? prefs.getInt('id');

      final body = {
        'title': '나의 여행 코스',
        'distanceKm': widget.preview!.distanceKm,
        'durationMin': widget.preview!.durationMin,
        'waypoints': _wps.map((w) => w.toJson()).toList(),
      };

      await ApiClient.post(
        '/api/custom/courses',
        headers: {if (uid != null) 'X-USER-ID': '$uid'},
        body: body,
      );

      if (!mounted) return;

      // ✅ 중상단 오토바이 팝업
      showMotoPopup(
        context,
        title: '저장 완료',
        message: '나의 여행 코스가 저장되었습니다.',
      );

      // 팝업 잠깐 보여주고 이동
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RidingCourse()),
            (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      showMotoPopup(
        context,
        title: '저장 실패',
        message: '$e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
    _isPreview ? '코스 미리보기' : (widget.view?.title ?? '여행 코스');
    final km = (_isPreview ? widget.preview!.distanceKm : widget.view!.distanceKm)
        .toStringAsFixed(1);
    final min =
    _isPreview ? widget.preview!.durationMin : widget.view!.durationMin;

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
                  backgroundColor: const Color(0xFFFF4E6B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onPressed: _saving ? null : _saveAndGo,
                child: _saving
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : const Text('저장',
                    style: TextStyle(fontWeight: FontWeight.bold)),
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
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 3)),
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
            child: Text(
              w.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}


/// =================== 오토바이 컨셉 중상단 팝업  ===================
/// - 카드: 흰색 + 투명도 0.7, 라운드, 그림자, 얇은 테두리
/// - 제목/본문 구분선(회색 Divider)
/// - 아이콘: 저장 아이콘 (save_rounded)
void showMotoPopup(
    BuildContext context, {
      required String title,
      required String message,
<<<<<<< HEAD
      bool isError = false,
      Duration duration = const Duration(milliseconds: 2400),
    }) {
  // 2) 루트 오버레이 사용 → 키보드/다이얼로그 위에도 뜸
  final overlay = Overlay.of(context, rootOverlay: true);
=======
      bool isError = false, // 현재 스타일에서는 색 변경 안 하고 동일 처리
      Duration duration = const Duration(milliseconds: 2400),
    }) {
  final overlay = Overlay.of(context);
>>>>>>> f760e026460b07402064732649d558994b487b74
  if (overlay == null) return;

  late OverlayEntry entry;
  bool closed = false;
  void safeRemove() {
<<<<<<< HEAD
    if (!closed && entry.mounted) { closed = true; entry.remove(); }
  }

  entry = OverlayEntry(
    builder: (ctx) {
      // 3) 노치/상태바 고려: viewPadding.top 사용
      final topInset = MediaQuery.of(ctx).viewPadding.top;

      return Stack(
        children: [
          // (옵션) 빈 곳 탭하면 닫기
=======
    if (!closed && entry.mounted) {
      closed = true;
      entry.remove();
    }
  }

  entry = OverlayEntry(
    builder: (ctx) => SafeArea(
      child: Stack(
        children: [
          // 바깥 터치시 닫힘
>>>>>>> f760e026460b07402064732649d558994b487b74
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: safeRemove,
            ),
          ),
<<<<<<< HEAD

          // 1) 상단 고정
          Positioned(
            top: topInset + 8,
            left: 16,
            right: 16,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              builder: (_, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * -8),
                  child: child,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 6)),
                    ],
                    border: Border.all(color: const Color(0xFFE9E9EE)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // 저장 아이콘 등 원하는 아이콘으로
                          Icon(Icons.save_rounded, color: Colors.pink),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Colors.black.withOpacity(0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                      const SizedBox(height: 10),
                      Text(
                        message,
                        style: const TextStyle(fontSize: 14.5, height: 1.35, color: Colors.black87),
                      ),
                    ],
=======
          // 중상단 정렬
          Positioned.fill(
            child: Align(
              alignment: const Alignment(0, -0.35),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (_, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 12),
                    child: child,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.88,
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                    decoration: BoxDecoration(
                      // ✅ 로그인 팝업과 동일: 흰색 + 살짝 투명
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFE9E9EE)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 헤더 (저장 아이콘 + 제목)
                        Row(
                          children: [
                            const Icon(Icons.save_rounded, color: Colors.pink),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                // ✅ 로그인 팝업과 동일한 타이틀 스타일
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black.withOpacity(0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // ✅ 내부 회색 구분선
                        const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                        const SizedBox(height: 10),
                        // 본문 메시지
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            // 로그인 팝업과 동일하게 본문은 텍스트만 (아이콘 X)
                          ],
                        ),
                        Text(
                          message,
                          style: const TextStyle(
                            fontSize: 14.5,
                            height: 1.35,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
>>>>>>> f760e026460b07402064732649d558994b487b74
                  ),
                ),
              ),
            ),
          ),
        ],
<<<<<<< HEAD
      );
    },
=======
      ),
    ),
>>>>>>> f760e026460b07402064732649d558994b487b74
  );

  overlay.insert(entry);
  Future.delayed(duration, safeRemove);
}
