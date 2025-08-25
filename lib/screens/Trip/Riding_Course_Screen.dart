import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

// 기존 위젯
import 'package:triprider/screens/Trip/Custom_Riding_Course_Screen.dart';
import 'package:triprider/screens/Trip/Riding_Course_Card.dart';
import 'package:triprider/screens/Trip/widgets/P_Course_Card.dart';
import 'package:triprider/widgets/Bottom_App_Bar.dart';

// API 클라이언트
import 'package:triprider/screens/RiderGram/Api_client.dart';

// ✅ 공통 유틸(중복 제거)
import 'package:triprider/screens/Trip/shared/course_cover_resolver.dart';
import 'package:triprider/screens/Trip/shared/open_course_detail.dart';

class RidingCourse extends StatefulWidget {
  const RidingCourse({super.key});

  @override
  State<RidingCourse> createState() => _Riding_CourseState();
}

class _Riding_CourseState extends State<RidingCourse> {
  int selectedIndex = 0; // 0: 라이딩 코스, 1: 맞춤형 여행 코스

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          '라이딩 코스 추천',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        children: [
          Column(
            children: [
              Select_Section(
                selectedIndex: selectedIndex,
                onSelect: (index) => setState(() => selectedIndex = index),
              ),
              const SizedBox(height: 30),

              if (selectedIndex == 0) ...[
                const Padding(
                  padding: EdgeInsets.only(right: 300, bottom: 30, top: 20),
                  child: Text(
                    '인기코스',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
                  ),
                ),
                Center(child: Popular_Course(favorite_Pressed: () {})),
                const SizedBox(height: 8),
                const _DistanceSection(),
                const SizedBox(height: 24),
              ] else ...[
                const CustomRidingCourse(),
              ],
            ],
          ),
        ],
      ),
      bottomNavigationBar: const BottomAppBarWidget(),
    );
  }
}

/// 탭 선택 영역
class Select_Section extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const Select_Section({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => onSelect(0),
              child: Text(
                '라이딩 코스',
                style: TextStyle(
                  fontSize: 20,
                  color: selectedIndex == 0 ? Colors.pink : Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 50),
            TextButton(
              onPressed: () => onSelect(1),
              child: Text(
                '맞춤형 여행 코스',
                style: TextStyle(
                  fontSize: 20,
                  color: selectedIndex == 1 ? Colors.pink : Colors.black,
                ),
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 2,
              color: selectedIndex == 0 ? Colors.pink : Colors.transparent,
            ),
            const SizedBox(width: 50),
            Container(
              width: 160,
              height: 2,
              color: selectedIndex == 1 ? Colors.pink : Colors.transparent,
            ),
          ],
        ),
      ],
    );
  }
}

/* =========================
 * DTO
 * ========================= */


/* =========================
 * 인기 코스 (커버/상세 공통 유틸 사용)
 * ========================= */

class Popular_Course extends StatefulWidget {
  final VoidCallback favorite_Pressed;
  const Popular_Course({super.key, required this.favorite_Pressed});

  @override
  State<Popular_Course> createState() => _Popular_CourseState();
}

class _Popular_CourseState extends State<Popular_Course> {
  late PageController _pageController;
  int _currentPage = 1000;
  late final Timer _timer;

  List<RidingCourseCard> _cards = [];
  List<String> _covers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);
    _load();

    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || _cards.isEmpty) return;
      _currentPage++;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _load() async {
    try {
      setState(() => _loading = true);
      final res = await ApiClient.get('/api/travel/riding/popular?limit=5');
      final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      _cards = list.map(RidingCourseCard.fromJson).toList();

      _covers = await CourseCoverResolver.prefetch<RidingCourseCard>(
        _cards,
        cover: (c) => c.coverImageUrl,
        category: (c) => c.category,
        id: (c) => c.id,
      );

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleLike(int idx) async {
    final item = _cards[idx];
    final oldLiked = item.liked ?? false;
    final oldCount = item.likeCount ?? 0;
    final newLiked = !oldLiked;
    final optimisticCount = (oldCount + (newLiked ? 1 : -1)).clamp(0, 1 << 30);

    setState(() {
      _cards[idx] = item.copyWith(likeCount: optimisticCount as int, liked: newLiked);
    });

    try {
      final path = '/api/travel/riding/${item.category}/${item.id}/likes';
      final res = newLiked ? await ApiClient.post(path) : await ApiClient.delete(path);
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final serverCount = (map['likeCount'] as num? ?? optimisticCount).toInt();
      final serverLiked = map['liked'] as bool? ?? newLiked;

      if (!mounted) return;
      setState(() {
        _cards[idx] = item.copyWith(likeCount: serverCount, liked: serverLiked);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cards[idx] = item.copyWith(likeCount: oldCount, liked: oldLiked);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('좋아요 처리 실패: $e')));
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AspectRatio(
        aspectRatio: 4 / 3,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: Center(child: Text(_error!)),
      );
    }
    if (_cards.isEmpty) {
      return const AspectRatio(
        aspectRatio: 4 / 3,
        child: Center(child: Text('표시할 코스가 없습니다.')),
      );
    }

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) => _currentPage = index,
        itemBuilder: (context, index) {
          final idx = index % _cards.length;
          final card = _cards[idx];
          final km = (card.totalDistanceMeters / 1000.0);
          final cover = _covers[idx];

          return P_CourseCard(
            imagePath: cover,
            title: card.title,
            address: '${km.toStringAsFixed(1)} km',
            isFavorite: card.liked ?? false,
            likeCount: card.likeCount ?? 0,
            favorite_Pressed: () => _toggleLike(idx),
            onTap: () => openCourseDetail(context, card.category, card.id),
          );
        },
      ),
    );
  }
}

/* =========================
 * 거리순 섹션 (긴/짧은 토글 + 공통 유틸 사용)
 * ========================= */

class _DistanceSection extends StatefulWidget {
  const _DistanceSection({super.key});

  @override
  State<_DistanceSection> createState() => _DistanceSectionState();
}

class _DistanceSectionState extends State<_DistanceSection> {
  String _order = 'desc'; // 'desc'(긴 코스 순) / 'asc'(짧은 코스 순)
  bool _loading = true;
  String? _error;
  List<RidingCourseCard> _items = [];
  List<String> _covers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() { _loading = true; _error = null; });
      final res = await ApiClient.get('/api/travel/riding/by-length?order=$_order');
      final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      _items = list.map(RidingCourseCard.fromJson).toList();

      _covers = await CourseCoverResolver.prefetch<RidingCourseCard>(
        _items,
        cover: (c) => c.coverImageUrl,
        category: (c) => c.category,
        id: (c) => c.id,
      );

      setState(() => _loading = false);
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _changeOrder(String order) async {
    if (_order == order) return;
    setState(() => _order = order);
    await _load();
  }

  Future<void> _toggleLike(int index) async {
    final item = _items[index];
    final optimisticLiked = !(item.liked ?? false);
    final optimisticCount = ((item.likeCount ?? 0) + (optimisticLiked ? 1 : -1)).clamp(0, 1 << 31);

    setState(() {
      _items[index] = item.copyWith(likeCount: optimisticCount as int, liked: optimisticLiked);
    });

    try {
      final path = '/api/travel/riding/${item.category}/${item.id}/likes';
      final res = optimisticLiked ? await ApiClient.post(path) : await ApiClient.delete(path);
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (!mounted) return;
      _items[index] = item.copyWith(
        likeCount: (data['likeCount'] as num? ?? optimisticCount).toInt(),
        liked: data['liked'] as bool? ?? optimisticLiked,
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _items[index] = item); // 롤백
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('좋아요 처리 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Text('로드 실패: $_error'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 타이틀 + 정렬 토글
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            children: [
              const Text('거리순', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
              const Spacer(),
              ChoiceChip(
                label: const Text('긴 코스 순'),
                selected: _order == 'desc',
                onSelected: (_) => _changeOrder('desc'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('짧은 코스 순'),
                selected: _order == 'asc',
                onSelected: (_) => _changeOrder('asc'),
              ),
            ],
          ),
        ),

        // 2열 그리드
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 0.86, // 텍스트 2줄 여유
          ),
          itemCount: _items.length,
          itemBuilder: (context, i) {
            final c = _items[i];
            final cover = _covers[i];
            final km = (c.totalDistanceMeters / 1000).toStringAsFixed(1);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => openCourseDetail(context, c.category, c.id),
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        children: [
                          if (cover.startsWith('http'))
                            Image.network(
                              cover,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Image.asset(
                                'assets/image/courseview1.png',
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Image.asset(
                              cover,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),

                          // 그라데이션(터치 방해 X)
                          Positioned.fill(
                            child: IgnorePointer(
                              ignoring: true,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.center,
                                    colors: [Colors.black.withOpacity(0.45), Colors.transparent],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 하트 + 숫자
                          Positioned(
                            left: 10,
                            bottom: 10,
                            child: InkWell(
                              onTap: () => _toggleLike(i),
                              borderRadius: BorderRadius.circular(20),
                              child: Row(
                                children: [
                                  Icon(
                                    (c.liked ?? false) ? Icons.favorite : Icons.favorite_border,
                                    color: (c.liked ?? false) ? Colors.red : Colors.white,
                                    size: 30,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${c.likeCount ?? 0}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  c.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text('$km km', style: const TextStyle(color: Colors.black54)),
              ],
            );
          },
        ),
      ],
    );
  }
}
