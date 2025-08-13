import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:triprider/screens/RiderGram/Api_client.dart';
import 'package:triprider/screens/RiderGram/Comment_Sheet.dart';
import 'package:triprider/screens/RiderGram/Post.dart';
import 'package:triprider/screens/RiderGram/Upload.dart';
import 'package:triprider/screens/RiderGram/Search.dart';
import 'package:triprider/widgets/Bottom_App_Bar.dart';

class RidergramScreen extends StatefulWidget {
  const RidergramScreen({super.key});

  @override
  State<RidergramScreen> createState() => _RidergramScreenState();
}

class _RidergramScreenState extends State<RidergramScreen> {
  late Future<List<PostModel>> _future;
  final _posts = <PostModel>[];

  @override
  void initState() {
    super.initState();
    _future = _fetchPosts();
  }

  Future<List<PostModel>> _fetchPosts() async {
    final res = await ApiClient.get('/api/posts');
    final List list = jsonDecode(res.body);
    final items = list.map((e) => PostModel.fromJson(e)).toList().cast<PostModel>();
    _posts
      ..clear()
      ..addAll(items);
    return _posts;
  }

  Future<void> _refresh() async {
    await _fetchPosts();
    if (mounted) setState(() {});
  }

  Future<void> _openUpload() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const Upload()),
    );
    if (ok == true) {
      await _refresh();
    }
  }

  Future<void> _toggleLike(int index) async {
    final p = _posts[index];
    try {
      if (p.liked) {
        final res = await ApiClient.delete('/api/posts/${p.id}/likes');
        final m = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _posts[index] = p.copyWith(
            likeCount: (m['likeCount'] ?? p.likeCount),
            liked: false,
          );
        });
      } else {
        final res = await ApiClient.post('/api/posts/${p.id}/likes');
        final m = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _posts[index] = p.copyWith(
            likeCount: (m['likeCount'] ?? p.likeCount),
            liked: true,
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('좋아요 처리 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _openUpload,
            icon: const Icon(Icons.add_box_outlined, size: 30),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const Search()));
            },
            icon: const Icon(Icons.search, size: 28),
          ),
        ],
      ),
      body: FutureBuilder<List<PostModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && _posts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('불러오기 실패: ${snap.error}'));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: _posts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, i) => _PostCard(
                post: _posts[i],
                onToggleLike: () => _toggleLike(i),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomAppBarWidget(),
    );
  }
}

class _PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback onToggleLike;

  const _PostCard({
    super.key,
    required this.post,
    required this.onToggleLike,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = (post.imageUrl != null && post.imageUrl!.trim().isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 작성자
        Row(
          children: [
            const Icon(Icons.account_circle, size: 25),
            const SizedBox(width: 10),
            Expanded(
              child: Text(post.writer, style: const TextStyle(fontSize: 17)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 이미지
        if (hasImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              post.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 180,
                alignment: Alignment.center,
                color: const Color(0x11000000),
                child: const Text('이미지 로드 실패'),
              ),
            ),
          ),

        // 액션바 (좋아요)
        Row(
          children: [
            IconButton(
              onPressed: onToggleLike,
              icon: Icon(
                post.liked ? Icons.favorite : Icons.favorite_border,
                color: post.liked ? Colors.red : null,
              ),
            ),
            Text('${post.likeCount}', style: const TextStyle(fontSize: 14, color: Colors.grey)),

            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.mode_comment_outlined),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => CommentSheet(postId: post.id),
                );
              },
            ),
          ],
        ),

        // 본문
        if (post.content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(post.content),
          ),

        // 위치
        if ((post.location ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('📍 ${post.location!}', style: const TextStyle(color: Colors.grey)),
          ),

        // 태그
        if ((post.hashtags ?? '').isNotEmpty)
          Wrap(
            spacing: 10,
            children: (post.hashtags!.trim().split(RegExp(r'\s+')))
                .where((w) => w.isNotEmpty)
                .map((t) => Text(t, style: const TextStyle(color: Color(0xFF0088FF))))
                .toList(),
          ),

        const SizedBox(height: 24),
      ],
    );
  }
}
