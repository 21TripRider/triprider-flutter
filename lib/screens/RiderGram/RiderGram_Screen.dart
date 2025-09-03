import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:triprider/core/network/Api_client.dart';
import 'package:triprider/screens/RiderGram/Comment_Sheet.dart';
import 'package:triprider/screens/RiderGram/Post.dart';
import 'package:triprider/screens/RiderGram/Upload.dart';
import 'package:triprider/screens/RiderGram/Search.dart';
import 'package:triprider/widgets/Bottom_App_Bar.dart';
import 'package:triprider/screens/RiderGram/Public_Profile_Screen.dart';

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
                onCommentCountChanged: (newCount) {
                  setState(() {
                    _posts[i] = _posts[i].copyWith(commentCount: newCount);
                  });
                },
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
  final ValueChanged<int> onCommentCountChanged;

  const _PostCard({
    super.key,
    required this.post,
    required this.onToggleLike,
    required this.onCommentCountChanged,
  });

  void _openProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(
          userId: post.writerId,
          nickname: post.writer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = (post.imageUrl != null && post.imageUrl!.trim().isNotEmpty);

    // ✅ 프로필/본문 이미지 모두 절대 URL로 보정
    final avatarUrl = (post.writerProfileImage ?? '').trim();
    final ImageProvider avatar = avatarUrl.isNotEmpty
        ? NetworkImage(ApiClient.absoluteUrl(avatarUrl))
        : const AssetImage('assets/image/logo.png');

    final String? contentImageUrl =
    hasImage ? ApiClient.absoluteUrl(post.imageUrl!) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 작성자(아바타 + 이름) --- 탭하면 공개 프로필
        InkWell(
          onTap: () => _openProfile(context),
          child: Row(
            children: [
              CircleAvatar(radius: 16, backgroundImage: avatar),
              const SizedBox(width: 8),
              Expanded(
                child: Text(post.writer, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // [1] 이미지
        if (contentImageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              contentImageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 180,
                alignment: Alignment.center,
                color: const Color(0x11000000),
                child: const Text('이미지 로드 실패'),
              ),
            ),
          ),

        // [2] 본문(이미지 바로 아래)
        if (post.content.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(post.content),
        ],

        // 위치/태그
        if ((post.location ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('📍 ${post.location!}', style: const TextStyle(color: Colors.grey)),
        ],
        if ((post.hashtags ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            children: (post.hashtags!.trim().split(RegExp(r'\s+')))
                .where((w) => w.isNotEmpty)
                .map((t) => Text(t, style: const TextStyle(color: Color(0xFF0088FF))))
                .toList(),
          ),
        ],

        // [3] 액션바(하트/댓글)
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: onToggleLike,
              icon: Icon(post.liked ? Icons.favorite : Icons.favorite_border,
                  color: post.liked ? Colors.red : null),
            ),
            Text('${post.likeCount}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.mode_comment_outlined),
              onPressed: () async {
                final newCount = await showModalBottomSheet<int>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => CommentSheet(postId: post.id),
                );
                if (newCount != null) onCommentCountChanged(newCount);
              },
            ),
            Text('${post.commentCount}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
