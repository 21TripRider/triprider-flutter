// lib/screens/Trip/widgets/My_Course_card.dart
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
      builder: (ctx) => AlertDialog(
        title: const Text(
          "코스 삭제",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: Text("'${c.title}'를 삭제하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소", style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "삭제",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
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
      _showTopToast(context, message: "코스가 삭제되었습니다.", iconColor: Colors.redAccent);
    } catch (e) {
      if (!mounted) return;
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
    Widget child;
    if (_loading) {
      child = const Center(child: CircularProgressIndicator());
    } else if (_error.isNotEmpty) {
      child = Center(child: Text(_error));
    } else if (_items.isEmpty) {
      child = const Center(child: Text('저장된 코스가 없습니다.'));
    } else {
      child = ListView.separated(
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final c = _items[i];
          return _SwipeableCard(
            key: Key(c.id.toString()),
            course: c,
            onDelete: () => _deleteCourse(c),
            onTap: () async {
              try {
                final res = await ApiClient.get('/api/custom/courses/${c.id}');
                final view = CourseView.fromJson(jsonDecode(res.body));
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CourseDetailScreen.view(view: view),
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
          );
        },
      );
    }

    // ✅ 리스트 영역을 항상 "흰색"으로
    return Container(color: Colors.white, child: child);
  }
}

class _SwipeableCard extends StatefulWidget {
  final CourseCard course;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _SwipeableCard({
    super.key,
    required this.course,
    required this.onDelete,
    required this.onTap,
  });

  @override
  State<_SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<_SwipeableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  double _dragExtent = 0.0;
  static const double _maxDragExtent = 60.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) => _animationController.stop();

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent = (_dragExtent - details.delta.dx).clamp(0.0, _maxDragExtent);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragExtent > _maxDragExtent * 0.5) {
      _showDeleteDialog();
    } else {
      _resetPosition();
    }
  }

  void _resetPosition() {
    _animation = Tween<double>(begin: _dragExtent, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward().then((_) {
      setState(() => _dragExtent = 0.0);
    });
  }

  void _showDeleteDialog() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white, // ✅ 여기서 원하는 색으로 변경
        title: const Text("코스 삭제",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        content: Text("'${widget.course.title}'를 삭제하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("취소", style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("삭제",
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      widget.onDelete();
    } else {
      _resetPosition();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Stack(
        children: [
          // 삭제 배경
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 20),
                  child: Icon(Icons.delete, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
          // 카드
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(-_dragExtent, 0),
                child: _CourseCardTile(
                  title: widget.course.title,
                  preview: widget.course.stopsPreview,
                  onTap: widget.onTap,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CourseCardTile extends StatelessWidget {
  final String title;
  final String preview;
  final VoidCallback onTap;

  const _CourseCardTile({
    required this.title,
    required this.preview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // 왼쪽 포인트 바
              Container(
                width: 5,
                height: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF4E6B),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
              ),
              // 카드 본문 (연한 회색 스트로크)
              Expanded(
                child: Container(
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    border: const Border(
                      top: BorderSide(color: Color(0xFFEEEEEE)),
                      right: BorderSide(color: Color(0xFFEEEEEE)),
                      bottom: BorderSide(color: Color(0xFFEEEEEE)),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.black45),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ───── 화면 중상단 오버레이 토스트 ───── */

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

  late OverlayEntry entry;
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
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
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
                          style:
                          const TextStyle(fontWeight: FontWeight.w700),
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
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 260))
    ..forward();
  late final Animation<Offset> _offset =
  Tween(begin: const Offset(0, -0.06), end: Offset.zero)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
  late final Animation<double> _opacity =
  CurvedAnimation(parent: _c, curve: Curves.easeOut);

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
