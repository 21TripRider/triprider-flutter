//lib/screens/Trip/Place_Pick_Screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:triprider/core/network/Api_client.dart';
import 'package:triprider/screens/Trip/Course_Detail_Screen.dart';
import 'package:triprider/screens/trip/models.dart';

class PlacePickScreen extends StatefulWidget {
  final List<CategoryOption> options;
  const PlacePickScreen({super.key, required this.options});

  @override
  State<PlacePickScreen> createState() => _PlacePickScreenState();
}

class _PlacePickScreenState extends State<PlacePickScreen>
    with SingleTickerProviderStateMixin {
  static const _jeju = LatLng(33.3846, 126.5535);

  late final TabController _tab;
  String? _selectionId;
  bool _loading = true;
  bool _optimize = true;

  int _selectedIndex = 0;

  final _results = <int, List<NearbyPlace>>{};
  final _picked = <NearbyPlace>[];

  GoogleMapController? _map;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: widget.options.length, vsync: this);
    _initSessionAndLoad();
  }

  @override
  void dispose() {
    _tab.dispose();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _initSessionAndLoad() async {
    try {
      final res = await ApiClient.post('/api/custom/selection/sessions');
      final sid = (jsonDecode(res.body) as Map<String, dynamic>)['selectionId'] as String;
      _selectionId = sid;

      await _loadTab(_tab.index);
      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('세션 생성 실패: $e')),
      );
    }
  }

  Future<void> _loadTab(int i) async {
    if (_results.containsKey(i)) return;
    final opt = widget.options[i];

    try {
      List items;
      if ((opt.presetKey ?? '').isNotEmpty) {
        final res = await ApiClient.get(
          '/api/custom/places/preset',
          query: {'key': opt.presetKey!, 'page': 1, 'limit': 20},
        );
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        items = (data['items'] ?? []);
      } else {
        final res = await ApiClient.get(
          '/api/custom/places',
          query: {
            'type': opt.type,
            'lat': _jeju.latitude,
            'lng': _jeju.longitude,
            'radius': 3000,
            'scope': 'jeju',
            if (opt.cat1 != null) 'cat1': opt.cat1!,
            if (opt.cat2 != null) 'cat2': opt.cat2!,
            if (opt.cat3 != null) 'cat3': opt.cat3!,
            'page': 1,
            'limit': 20,
          },
        );
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        items = (data['items'] ?? []);
      }

      _results[i] = items.map((e) => NearbyPlace.fromJson(e)).toList().cast<NearbyPlace>();
      setState(() {});
    } catch (e) {
      _results[i] = [];
      setState(() {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('장소 로드 실패: $e')),
      );
    }
  }

  Future<void> _add(NearbyPlace p) async {
    if (_selectionId == null) return;
    final opt = widget.options[_tab.index];
    try {
      await ApiClient.post(
        '/api/custom/selection/${_selectionId!}/picks',
        body: {
          'contentId': p.contentId ?? p.title,
          'type': opt.type,
          'title': p.title,
          'lat': p.lat,
          'lng': p.lng,
          'cat1': p.cat1,
          'cat2': p.cat2,
          'cat3': p.cat3,
          'contentTypeId': p.contentTypeId,
          'addr': p.addr,
          'image': p.image,
        },
      );
      setState(() => _picked.add(p));
      _fitMap();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('추가 실패: $e')),
      );
    }
  }

  Future<void> _remove(NearbyPlace p) async {
    if (_selectionId == null) return;
    try {
      await ApiClient.delete(
        '/api/custom/selection/${_selectionId!}/picks/${p.contentId ?? p.title}',
      );
      setState(() {
        _picked.removeWhere(
              (e) => (e.contentId ?? e.title) == (p.contentId ?? p.title),
        );
      });
      _fitMap();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('제거 실패: $e')),
      );
    }
  }

  void _fitMap() async {
    if (_map == null || _picked.isEmpty) return;
    double? minLat, maxLat, minLng, maxLng;
    for (final p in _picked) {
      minLat = (minLat == null) ? p.lat : (p.lat < minLat ? p.lat : minLat);
      maxLat = (maxLat == null) ? p.lat : (p.lat > maxLat ? p.lat : maxLat);
      minLng = (minLng == null) ? p.lng : (p.lng < minLng ? p.lng : minLng);
      maxLng = (maxLng == null) ? p.lng : (p.lng > maxLng ? p.lng : maxLng);
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
    await _map!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  Future<void> _preview() async {
    // ✅ 스낵바 → 중상단 배너형 팝업(다른 디자인)
    if (_selectionId == null || _picked.length < 2) {
      showMinPickPopup(context, message: '두 곳 이상 선택해 주세요.');
      return;
    }
    try {
      final res = await ApiClient.post(
        '/api/custom/courses/auto',
        body: {'selectionId': _selectionId!, 'optimize': _optimize},
      );
      final preview = CoursePreview.fromJson(jsonDecode(res.body));
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CourseDetailScreen.preview(preview: preview),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('코스 생성 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('장소 선택'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4E6B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              elevation: 0,
            ),
            onPressed: _preview,
            child: const Text(
              '완료',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
        // 카테고리 버튼(Chip)
        SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: List.generate(widget.options.length, (i) {
            final selected = i == _selectedIndex;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIndex = i;
                    _tab.index = i;
                    _loadTab(i);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFFF4E6B) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.options[i].label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
      SizedBox(
          height: 220,
          child: GoogleMap(
              initialCameraPosition: const CameraPosition(target: _jeju, zoom: 10.8),
              onMapCreated: (c) => _map = c,
              markers: {
              ..._picked.asMap().entries.map((e) {
            final idx = e.key + 1;
            final p = e.value;
            return Marker(
              markerId: MarkerId('p$idx'),
              position: LatLng(p.lat, p.lng),
              infoWindow: InfoWindow(title: '$idx. ${p.title}', snippet: p.addr),
            );
          }),
          },
          polylines: _buildPolyline(),
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
    ),
    ),
    const SizedBox(height: 8),
    // 컨트롤 바 (최단거리 토글 + 물음표 아이콘)
    Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
    child: Row(
    children: [
    const Text('최단거리', style: TextStyle(fontSize: 13)),
    const SizedBox(width: 8),
    _CustomSwitch(
    value: _optimize,
    onChanged: (v) => setState(() => _optimize = v),
    activeColor: Colors.white,
    activeTrackColor: Colors.blue,
    inactiveThumbColor: Colors.white,
    inactiveTrackColor: const Color(0xFFD9D9D9),
    ),
    const Spacer(),
    IconButton(
    icon: const Icon(Icons.help_outline, size: 20, color: Colors.grey),
    onPressed: () {
    showDialog(
    context: context,
    builder: (ctx) {
    return Dialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    const Text(
    '최단거리 모드 안내',
    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
    ),
    const SizedBox(height: 16),
    const Text('• ON: 선택한 장소들을 최적화하여\n   최단 경로 순서대로 코스를 생성합니다.',
    style: TextStyle(fontSize: 15, height: 1.5)),
    const SizedBox(height: 8),
    const Text('• OFF: 사용자가 선택한 순서를 그대로 반영합니다.',
    style: TextStyle(fontSize: 15, height: 1.5)),
    const SizedBox(height: 12),
    Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
    color: Color(0xFFFFEBEE),
    borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
    children: [
    Icon(Icons.info_outline, color: Colors.pinkAccent, size: 20),
    SizedBox(width: 8),
    Expanded(
    child: Text(
    '두 곳 이상 선택해야 코스를 미리볼 수 있습니다.',
    style: TextStyle(fontSize: 14, color: Colors.black87),
    ),
    ),
    ],
    ),
    ),
    const SizedBox(height: 20),
    Align(
    alignment: Alignment.centerRight,
    child: TextButton(
    onPressed: () => Navigator.pop(ctx),
    child: const Text(
    '확인',
    style: TextStyle(color: Colors.black87),
    ),
    ),
    ),
    ],
    ),
    ),
    );
    },
    );
    },
    ),
    ],
    ),
    ),
    Expanded(
    child: TabBarView(
    controller: _tab,
    physics: const NeverScrollableScrollPhysics(), // ⛔
    children: List.generate(widget.options.length, (i) {
    final list = _results[i] ?? [];
    if (list.isEmpty) {
    return const Center(child: Text('검색 결과가 없습니다.'));
    }
    return ListView.separated(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    itemCount: list.length,
    separatorBuilder: (_, __) => const Divider(height: 16, thickness: 0.7),
    itemBuilder: (_, idx) {
    final p = list[idx];
    final isPicked = _picked.any(
    (e) => (e.contentId ?? e.title) == (p.contentId ?? p.title),
    );
    return _PlaceTile(
    place: p,
    picked: isPicked,
    onAdd: () => _add(p),
    onRemove: () => _remove(p),
    );
    },
    );
    }),
    ),
    ),
    ],
    ),
    );
  }

  Set<Polyline> _buildPolyline() {
    if (_picked.length < 2) return {};
    final pts = _picked.map((e) => LatLng(e.lat, e.lng)).toList();
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: pts,
        width: 4,
        // const 사용 금지 (메서드 호출이라 에러)
        patterns: <PatternItem>[
          PatternItem.dash(20),
          PatternItem.gap(8),
        ],
        color: Colors.red,
      ),
    };
  }
}

class _PlaceTile extends StatelessWidget {
  final NearbyPlace place;
  final bool picked;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  const _PlaceTile({
    required this.place,
    required this.picked,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _buildImage(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  place.addr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
                if (place.distMeters != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${place.distMeters} m',
                      style: const TextStyle(color: Colors.black45, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          picked
              ? ElevatedButton.icon(
            onPressed: onRemove,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4E6B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              elevation: 0,
            ),
            icon: const Icon(Icons.remove, size: 16),
            label: const Text('제거'),
          )
              : ElevatedButton.icon(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              elevation: 0,
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('추가'),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    final img = place.image ?? '';
    if (img.isNotEmpty) {
      return Image.network(
        img,
        width: 84,
        height: 84,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Image.asset(_defaultImage(), width: 84, height: 84, fit: BoxFit.cover),
      );
    }
    return Image.asset(_defaultImage(), width: 84, height: 84, fit: BoxFit.cover);
  }

  String _defaultImage() {
    switch (place.contentTypeId) {
      case 12:
        return 'assets/image/tour.png';
      case 14:
        return 'assets/image/culture.png';
      case 15:
        return 'assets/image/event.png';
      case 28:
        return 'assets/image/leports.png';
      case 32:
        return 'assets/image/stay.png';
      case 38:
        return 'assets/image/shop.png';
      case 39:
        return 'assets/image/food.png';
      default:
        return 'assets/image/tour.png';
    }
  }
}

/// ===================================================================
/// ✅ 커스텀 토글 스위치 (스트로크 색상 변경 가능)
/// ===================================================================
class _CustomSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final Color activeTrackColor;
  final Color inactiveThumbColor;
  final Color inactiveTrackColor;

  const _CustomSwitch({
    required this.value,
    required this.onChanged,
    required this.activeColor,
    required this.activeTrackColor,
    required this.inactiveThumbColor,
    required this.inactiveTrackColor,
  });

  @override
  State<_CustomSwitch> createState() => _CustomSwitchState();
}

class _CustomSwitchState extends State<_CustomSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    if (widget.value) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_CustomSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (widget.value) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onChanged(!widget.value),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final trackColor = Color.lerp(
            widget.inactiveTrackColor,
            widget.activeTrackColor,
            _animation.value,
          )!;
          final thumbColor = Color.lerp(
            widget.inactiveThumbColor,
            widget.activeColor,
            _animation.value,
          )!;

          return Container(
            width: 52,
            height: 32,
            decoration: BoxDecoration(
              color: trackColor,
              borderRadius: BorderRadius.circular(16),
              border: widget.value ? Border.all(
                color: Colors.grey.withOpacity(0.2),
                width: 0.5,
              ) : null,
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOutCubic,
                  left: _animation.value * 20 + 2,
                  top: 2,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: thumbColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// ===================================================================
/// ✅ "두 곳 이상 선택해 주세요" 전용 팝업 (다른 디자인, 중상단)
/// - 라이트 옐로우 카드 + 앰버 경고 아이콘
/// - 이 파일 안에 포함 (새 파일 X)
/// ===================================================================
void showMinPickPopup(
    BuildContext context, {
      required String message,
      Duration duration = const Duration(milliseconds: 2200),
    }) {
  final overlay = Overlay.of(context);
  if (overlay == null) return;

  const cardBg = Color(0xFFFFF8E1);   // 라이트 옐로우
  const border = Color(0xFFFFE082);   // 연노랑 보더
  const iconC  = Color(0xFFFFB300);   // 앰버 경고
  const shadow = Colors.black26;

  late OverlayEntry entry;
  bool closed = false;

  void safeRemove() {
    if (!closed && entry.mounted) {
      closed = true;
      entry.remove();
    }
  }

  entry = OverlayEntry(
    builder: (_) => SafeArea(
      child: Stack(
        children: [
          // 바깥 터치 시 닫기
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: safeRemove,
            ),
          ),
          // 중상단 배너
          Positioned.fill(
            child: Align(
              alignment: const Alignment(0, -0.28),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                builder: (_, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 10),
                    child: child,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border, width: 1.2),
                      boxShadow: const [
                        BoxShadow(color: shadow, blurRadius: 14, offset: Offset(0, 6)),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: iconC, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            message,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.35,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: safeRemove,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close, size: 18, color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  overlay.insert(entry);
  Future.delayed(duration, safeRemove);
}