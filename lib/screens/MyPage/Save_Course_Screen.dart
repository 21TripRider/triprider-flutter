import 'dart:convert';
import 'package:flutter/material.dart';

// API
import 'package:triprider/screens/RiderGram/Api_client.dart';
import 'package:triprider/screens/Trip/Shared/Open_Course_Detail.dart';

// 공통 유틸(이미지 URL 처리 & 지도 상세로 이동)
import 'package:triprider/screens/Trip/shared/course_cover_resolver.dart';

class SaveCourseScreen extends StatefulWidget {
  const SaveCourseScreen({super.key});

  @override
  State<SaveCourseScreen> createState() => _SaveCourseScreenState();
}

class _SaveCourseScreenState extends State<SaveCourseScreen> {
  bool _loading = true;
  String? _error;

  List<_LikedCourse> _items = [];
  List<String> _covers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // 전체 카드 요청 → 내가 누른 것만 필터
      final res = await ApiClient.get('/api/travel/riding/cards');
      final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      final all = list.map(_LikedCourse.fromJson).toList();
      _items = all.where((e) => e.liked == true).toList();

      // 커버 사전탐색(인기/거리순과 동일 방식)
      _covers = await CourseCoverResolver.prefetch<_LikedCourse>(
        _items,
        cover: (c) => c.coverImageUrl,
        category: (c) => c.category,
        id: (c) => c.id,
      );

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _toggleLike(int index) async {
    final item = _items[index];

    // 현재 화면은 "좋아요한 코스"이므로, 하트를 끄면 리스트에서 제거되는 UX가 자연스러움
    // 낙관적 제거
    setState(() {
      _items.removeAt(index);
      _covers.removeAt(index);
    });

    try {
      final path = '/api/travel/riding/${item.category}/${item.id}/likes';
      await ApiClient.delete(path); // unlike
      // 성공 시 끝. (필요하면 스낵바로 알림)
    } catch (e) {
      // 실패 시 롤백
      if (!mounted) return;
      setState(() {
        _items.insert(index, item);
        _covers.insert(index, _covers.length > index ? _covers[index] : CourseCoverResolver.fallback);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('좋아요 해제 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 28),
        ),
        centerTitle: true,
        title: const Text('저장한 코스', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('불러오기 실패: $_error'));
    }
    if (_items.isEmpty) {
      return const Center(child: Text('좋아요한 코스가 없습니다.'));
    }

    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            '내가 좋아요한 코스',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 0.86, // 제목 2줄 여유
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
                  onTap: () => openCourseDetail(
                    context,
                    c.category,
                    c.id,
                    mode: CourseDetailMode.fullMap,
                  ),
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
                                CourseCoverResolver.fallback,
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

                          // 하단 그라데이션
                          Positioned.fill(
                            child: IgnorePointer(
                              ignoring: true,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.center,
                                    colors: [
                                      Colors.black.withOpacity(0.45),
                                      Colors.transparent
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // ♥ 버튼(해제)
                          Positioned(
                            left: 10,
                            bottom: 10,
                            child: InkWell(
                              onTap: () => _toggleLike(i),
                              borderRadius: BorderRadius.circular(20),
                              child: const Icon(
                                Icons.favorite,
                                color: Colors.red,
                                size: 30,
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
        const SizedBox(height: 24),
      ],
    );
  }
}

/// 이 화면에서 쓰는 가벼운 카드 모델
class _LikedCourse {
  final int id;
  final String category;
  final String title;
  final String? coverImageUrl;
  final int totalDistanceMeters;
  final bool? liked;

  _LikedCourse({
    required this.id,
    required this.category,
    required this.title,
    required this.coverImageUrl,
    required this.totalDistanceMeters,
    required this.liked,
  });

  factory _LikedCourse.fromJson(Map<String, dynamic> j) => _LikedCourse(
    id: (j['id'] as num).toInt(),
    category: j['category'] as String,
    title: (j['title'] as String?) ?? 'Riding Course',
    coverImageUrl: j['coverImageUrl'] as String?,
    totalDistanceMeters: (j['totalDistanceMeters'] as num?)?.toInt() ?? 0,
    liked: j['liked'] as bool?,
  );
}
