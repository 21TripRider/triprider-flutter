// lib/screens/trip/widgets/My_Course_Card.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triprider/screens/RiderGram/Api_client.dart';
import 'package:triprider/screens/Trip/Custom_Course_Detail_Screen.dart';
import 'package:triprider/screens/trip/models.dart';

class MyCourseCardList extends StatefulWidget {
  const MyCourseCardList({
    super.key,
    this.shrinkWrap = false,
    this.physics,
  });

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
    setState(() { _loading = true; _error = ''; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getInt('userId') ?? prefs.getInt('id');

      final res = await ApiClient.get(
        '/api/custom/courses/mine',
        headers: { if (uid != null) 'X-USER-ID': '$uid' },
        query: { 'page': 1, 'size': 50 },
      );

      final List list = jsonDecode(res.body);
      _items
        ..clear()
        ..addAll(list.map((e) => CourseCard.fromJson(e)).toList().cast<CourseCard>());

      setState(() { _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = '불러오기 실패: $e'; });
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
                MaterialPageRoute(builder: (_) => CourseDetailScreen.view(view: view)),
              );
            } catch (e) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('상세 불러오기 실패: $e')));
            }
          },
        );
      },
    );
  }
}

class _CourseCardTile extends StatelessWidget {
  final String title;
  final String preview;
  final VoidCallback onTap;
  const _CourseCardTile({required this.title, required this.preview, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0,6))],
          ),
          child: Row(children: [
            Container(width: 4, height: 48, decoration: BoxDecoration(
                color: const Color(0xFFFF4E6B), borderRadius: BorderRadius.circular(6))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black45)),
              ]),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}
