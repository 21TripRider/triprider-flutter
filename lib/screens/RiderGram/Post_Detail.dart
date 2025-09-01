import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:triprider/screens/RiderGram/Api_client.dart';
import 'package:triprider/screens/RiderGram/Comment_Sheet.dart';
import 'package:triprider/screens/RiderGram/Post.dart';
import 'package:triprider/screens/RiderGram/Public_Profile_Screen.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.postId,
    this.initial,
  });

  final int postId;
  final PostModel? initial;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  PostModel? _post;
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _post = widget.initial;
      _loading = false;
    }
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await ApiClient.get('/api/posts/${widget.postId}');
      final Map<String, dynamic> j = jsonDecode(res.body);
      final p = PostModel.fromJson(j);
      if (!mounted) return;
      setState(() {
        _post = p;
        _loading = false;
        _error = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '불러오기 실패: $e';
      });
    }
  }

  Future<void> _toggleLike() async {
    final p = _post;
    if (p == null) return;
    try {
      if (p.liked) {
        final res = await ApiClient.delete('/api/posts/${p.id}/likes');
        final m = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _post = p.copyWith(
            likeCount: (m['likeCount'] ?? p.likeCount),
            liked: false,
          );
        });
      } else {
        final res = await ApiClient.post('/api/posts/${p.id}/likes');
        final m = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _post = p.copyWith(
            likeCount: (m['likeCount'] ?? p.likeCount),
            liked: true,
          );
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('좋아요 처리 실패: $e')));
    }
  }

  Future<void> _openComments() async {
    final p = _post;
    if (p == null) return;
    final newCount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentSheet(postId: p.id),
    );
    if (newCount != null && mounted) {
      setState(() {
        _post = p.copyWith(commentCount: newCount);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _post;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios)),
        centerTitle: true,
        title: const Text('게시물'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error.isNotEmpty)
          ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
          : (p == null)
          ? const Center(child: Text('게시물을 찾을 수 없습니다'))
          : RefreshIndicator(
        onRefresh: _fetch,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 작성자(아바타 + 이름) - 탭 → 공개 프로필
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PublicProfileScreen(
                        userId: p.writerId,
                        nickname: p.writer,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: (p.writerProfileImage != null && p.writerProfileImage!.isNotEmpty)
                          ? NetworkImage(ApiClient.absoluteUrl(p.writerProfileImage!))
                          : const AssetImage('assets/image/logo.png') as ImageProvider,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(p.writer, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // [1] 이미지
              if ((p.imageUrl ?? '').trim().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    ApiClient.absoluteUrl(p.imageUrl!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 200, alignment: Alignment.center, color: const Color(0x11000000),
                      child: const Text('이미지 로드 실패'),
                    ),
                  ),
                ),

              // [2] 본문(이미지 바로 아래)
              if (p.content.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(p.content),
              ],

              // 위치/해시태그
              if ((p.location ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('📍 ${p.location!}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
              ],
              if ((p.hashtags ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  children: (p.hashtags!.trim().split(RegExp(r'\s+')))
                      .where((w) => w.isNotEmpty)
                      .map((t) => Text(t, style: const TextStyle(color: Color(0xFF0088FF))))
                      .toList(),
                ),
              ],

              // [3] 액션바
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: _toggleLike,
                    icon: Icon(p.liked ? Icons.favorite : Icons.favorite_border,
                        color: p.liked ? Colors.red : null),
                  ),
                  Text('${p.likeCount}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(width: 12),
                  IconButton(icon: const Icon(Icons.mode_comment_outlined), onPressed: _openComments),
                  Text('${p.commentCount}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
