// lib/screens/RiderGram/Search.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:triprider/screens/RiderGram/Api_client.dart';
import 'package:triprider/screens/RiderGram/Post.dart';
import 'package:triprider/screens/RiderGram/Post_Detail.dart';

class Search extends StatefulWidget {
  const Search({super.key});

  @override
  State<Search> createState() => _SearchState();
}

class _SearchState extends State<Search> {
  final _controller = TextEditingController();
  Timer? _debounce;

  bool _loading = false;
  String _error = '';
  final List<PostModel> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(v.trim());
    });
  }

  List<String> _hashtagTokens(String? s) {
    if (s == null || s.trim().isEmpty) return const [];
    final raw = s.replaceAll('\n', ' ').trim();
    final parts = raw.split(RegExp(r'\s+'));
    return parts
        .map((t) => t.replaceAll('#', '').trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  List<PostModel> _clientFilter(List<PostModel> items, String keyword) {
    final kw = keyword.toLowerCase();
    return items.where((p) {
      final content = p.content.toLowerCase();
      final writer = p.writer.toLowerCase();
      final loc = (p.location ?? '').toLowerCase();
      final tags = _hashtagTokens(p.hashtags).map((e) => e.toLowerCase());

      return content.contains(kw) ||
          writer.contains(kw) ||
          loc.contains(kw) ||
          tags.any((t) => t.contains(kw));
    }).toList();
  }

  Future<void> _search(String keyword) async {
    _error = '';
    if (!mounted) return;

    if (keyword.isEmpty) {
      setState(() {
        _results.clear();
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);

    try {
      // 1) 서버 검색이 있으면 사용
      final res = await ApiClient.get('/api/posts/search', query: {'q': keyword});
      final List list = jsonDecode(res.body);
      final items =
      list.map((e) => PostModel.fromJson(e)).toList().cast<PostModel>();

      // 혹시 서버가 전체를 준 경우 대비해서 한 번 더 클라 필터
      final filtered = _clientFilter(items, keyword);

      setState(() {
        _results
          ..clear()
          ..addAll(filtered);
        _loading = false;
      });
    } catch (_) {
      // 2) 없거나 실패 → 전체 받아서 클라 필터
      try {
        final resAll = await ApiClient.get('/api/posts');
        final List all = jsonDecode(resAll.body);
        final items =
        all.map((e) => PostModel.fromJson(e)).toList().cast<PostModel>();

        final filtered = _clientFilter(items, keyword);

        setState(() {
          _results
            ..clear()
            ..addAll(filtered);
          _loading = false;
        });
      } catch (e2) {
        setState(() {
          _loading = false;
          _results.clear();
          _error = '검색 실패: $e2';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                onSubmitted: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '검색 (내용/작성자/위치/해시태그)',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[200],
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(),
      backgroundColor: Colors.white,
    );
  }

  Widget _buildBody() {
    if (_controller.text.trim().isEmpty) {
      return const _CenterHint(text: '검색어를 입력해보세요');
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) {
      return Center(child: Text(_error, style: const TextStyle(color: Colors.red)));
    }
    if (_results.isEmpty) return const _CenterHint(text: '검색 결과가 없습니다');

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 16),
      itemBuilder: (_, i) => _SearchPostTile(post: _results[i]),
    );
  }
}

class _CenterHint extends StatelessWidget {
  final String text;
  const _CenterHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(text, style: const TextStyle(color: Colors.black54)));
  }
}

class _SearchPostTile extends StatelessWidget {
  final PostModel post;
  const _SearchPostTile({required this.post});

  @override
  Widget build(BuildContext context) {
    final hasImage = (post.imageUrl != null && post.imageUrl!.trim().isNotEmpty);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(postId: post.id, initial: post),
          ),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                post.imageUrl!,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 72, height: 72,
                  alignment: Alignment.center,
                  color: const Color(0x11000000),
                  child: const Icon(Icons.broken_image),
                ),
              ),
            )
          else
            Container(
              width: 72, height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0x0F000000),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.article_outlined),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      post.writer,
                      style:
                      const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.favorite, size: 14, color: Colors.redAccent),
                  const SizedBox(width: 2),
                  Text('${post.likeCount}',
                      style:
                      const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 8),
                  const Icon(Icons.mode_comment_outlined, size: 14),
                  const SizedBox(width: 2),
                  Text('${post.commentCount}',
                      style:
                      const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
                const SizedBox(height: 4),
                if (post.content.isNotEmpty)
                  Text(post.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                if ((post.location ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('📍 ${post.location!}',
                        style:
                        const TextStyle(fontSize: 12, color: Colors.grey),
                        overflow: TextOverflow.ellipsis),
                  ),
                if ((post.hashtags ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      post.hashtags!,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF0088FF)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
