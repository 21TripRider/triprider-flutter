import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triprider/core/network/Api_client.dart';
import 'package:triprider/screens/Trip/Course_Detail_Screen.dart';

import 'package:triprider/screens/trip/models.dart';

class MyCourseCardList extends StatefulWidget {
  const MyCourseCardList({super.key, this.shrinkWrap = false, this.physics});

  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  State<MyCourseCardList> createState() => _MyCourseCardListState();
}

class _MyCourseCardListState extends State<MyCourseCardList> {
  bool _loading = true;
  String _error = '';
  final _items = <CourseCard>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getInt('userId') ?? prefs.getInt('id');

      final res = await ApiClient.get(
        '/api/custom/courses/mine',
        headers: {if (uid != null) 'X-USER-ID': '$uid'},
        query: {'page': 1, 'size': 50},
      );

      final List list = jsonDecode(res.body);
      _items
        ..clear()
        ..addAll(
          list.map((e) => CourseCard.fromJson(e)).toList().cast<CourseCard>(),
        );

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '불러오기 실패: $e';
      });
    }
  }

  Future<void> _deleteCourse(CourseCard c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("코스 삭제"),
            content: Text("'${c.title}' 코스를 삭제하시겠습니까?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("취소", style: TextStyle(color: Colors.black)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50]),
                child: const Text("삭제", style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      await ApiClient.delete('/api/custom/courses/${c.id}');
      setState(() {
        _items.removeWhere((e) => e.id == c.id);
      });
      if (!mounted) return;

      // ✅ 하단 스낵바 대신, 화면 중상단 오버레이 토스트
      _showTopToast(
        context,
        message: "코스가 삭제되었습니다.",
        iconColor: Colors.redAccent,
      );
    } catch (e) {
      if (!mounted) return;

      // 실패 토스트(빨간 에러 아이콘)
      _showTopToast(
        context,
        message: "삭제 실패: $e",
        icon: Icons.error_rounded,
        iconColor: Colors.redAccent,
        duration: const Duration(milliseconds: 2200),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) return Center(child: Text(_error));
    if (_items.isEmpty) return const Center(child: Text('저장된 코스가 없습니다.'));

    return ListView.separated(
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final c = _items[i];
        return _CourseCardTile(
          title: c.title,
          preview: c.stopsPreview,
          onTap: () async {
            try {
              final res = await ApiClient.get('/api/custom/courses/${c.id}');
              final view = CourseView.fromJson(jsonDecode(res.body));
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) => CourseDetailScreen.view(
                        view: view,
                      ), // <-- 저장된 코스는 view
                ),
              );
            } catch (e) {
              if (!mounted) return;
              _showTopToast(
                context,
                message: '상세 불러오기 실패: $e',
                icon: Icons.error_outline_rounded,
                iconColor: Colors.redAccent,
              );
            }
          },
          onDelete: () => _deleteCourse(c),
        );
      },
    );
  }
}

class _CourseCardTile extends StatelessWidget {
  final String title;
  final String preview;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _CourseCardTile({
    required this.title,
    required this.preview,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // ✅ 살짝 밝은 카드 배경
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE9E9EE)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFF4E6B),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black45),
                    ),
                  ],
                ),
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onDelete,
                tooltip: '삭제',
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

/* ──────────────────────────────────────────────────────────────
 * 여기부터: 화면 중상단 오버레이 토스트 구현 (이 파일만으로 동작)
 * 사용: _showTopToast(context, message: '완료');
 * ────────────────────────────────────────────────────────────── */

void _showTopToast(
  BuildContext context, {
  required String message,
  IconData icon = Icons.check_circle_rounded,
  Color iconColor = const Color(0xFFFF4D6D),
  Duration duration = const Duration(milliseconds: 1800),
  double? topOffset,
}) {
  final overlay = Overlay.of(context);
  if (overlay == null) return;

  late OverlayEntry entry; // ✅ 먼저 선언

  entry = OverlayEntry(
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      final double top = topOffset ?? media.padding.top + 72;

      return Positioned(
        top: top,
        left: 0,
        right: 0,
        child: _ToastAnimated(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: ShapeDecoration(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    color: Colors.white,
                    shadows: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: iconColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);

  Future.delayed(duration, () {
    if (entry.mounted) entry.remove();
  });
}

class _ToastAnimated extends StatefulWidget {
  final Widget child;
  const _ToastAnimated({required this.child});

  @override
  State<_ToastAnimated> createState() => _ToastAnimatedState();
}

class _ToastAnimatedState extends State<_ToastAnimated>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();
  late final Animation<Offset> _offset = Tween(
    begin: const Offset(0, -0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOut,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}
