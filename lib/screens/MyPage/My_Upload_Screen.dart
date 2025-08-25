import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triprider/screens/RiderGram/Api_client.dart';
import 'package:triprider/screens/RiderGram/Post.dart';
import 'package:triprider/screens/RiderGram/Post_Detail.dart'; // ★ 상세화면 import

class MyUploadScreen extends StatefulWidget {
  const MyUploadScreen({super.key});

  @override
  State<MyUploadScreen> createState() => _MyUploadScreenState();
}

class _MyUploadScreenState extends State<MyUploadScreen> {
  late Future<List<PostModel>> _future;
  final _myPosts = <PostModel>[];
  String? _myNickname;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<PostModel>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _myNickname = prefs.getString('nickname');

    final res = await ApiClient.get('/api/posts');
    final List list = jsonDecode(res.body);
    final all = list.map((e) => PostModel.fromJson(e)).toList().cast<PostModel>();

    _myPosts
      ..clear()
      ..addAll(_myNickname == null ? all : all.where((p) => p.writer == _myNickname));
    return _myPosts;
  }

  Future<void> _refresh() async {
    await _load();
    if (mounted) setState(() {});
  }

  Future<void> _openDetail(PostModel p) async {
    // 상세에서 좋아요/댓글 변경했을 수 있으니 복귀 후 새로고침
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: p.id, initial: p),
      ),
    );
    if (!mounted) return;
    _refresh();
  }

  Future<void> _delete(PostModel p, int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('게시글 삭제'),
        content: const Text('정말 삭제하시겠어요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ApiClient.delete('/api/posts/${p.id}');
      setState(() => _myPosts.removeAt(index));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('삭제되었습니다.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final divider = const Divider(height: 16, thickness: 8, color: Color(0xFFF3F3F4));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0.5,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        centerTitle: true,
        title: const Text('나의 게시물', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: FutureBuilder<List<PostModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && _myPosts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('불러오기 실패: ${snap.error}'));
          }
          if (_myPosts.isEmpty) {
            return const Center(child: Text('작성한 게시물이 없습니다.'));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _myPosts.length,
              separatorBuilder: (_, __) => divider,
              itemBuilder: (context, index) {
                final post = _myPosts[index];
                return _MyPostCard(
                  post: post,
                  onTap: () => _openDetail(post),     // ★ 탭 시 상세로
                  onDelete: () => _delete(post, index),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _MyPostCard extends StatelessWidget {
  const _MyPostCard({
    required this.post,
    required this.onTap,
    required this.onDelete,
  });

  final PostModel post;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  List<String> _splitTags(String? hashtags) {
    if (hashtags == null || hashtags.trim().isEmpty) return const [];
    return hashtags.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  }

  Future<int> _fetchCommentCount() async {
    final res = await ApiClient.get('/api/posts/${post.id}/comments');
    final List list = jsonDecode(res.body);
    return list.length;
  }

  String _titleFromContent(String content) {
    final line = content.trim().split('\n').first;
    if (line.isEmpty) return '내 게시물';
    return line.length <= 24 ? line : '${line.substring(0, 24)}…';
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = (post.imageUrl != null && post.imageUrl!.trim().isNotEmpty);
    final tags = _splitTags(post.hashtags);

    const double gap = 14;
    const double thumb = 120;

    return Material( // ★ InkWell 효과를 위한 Material
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap, // ★ 전체 카드 탭 가능
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        post.imageUrl!,
                        width: thumb,
                        height: thumb,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: thumb,
                          height: thumb,
                          color: const Color(0xFFECECEC),
                          alignment: Alignment.center,
                          child: const Text('이미지 로드 실패',
                              style: TextStyle(fontSize: 12, color: Colors.black45)),
                        ),
                      ),
                    ),
                  if (hasImage) const SizedBox(width: gap),

                  // 오른쪽 영역
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 제목 + 휴지통
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                _titleFromContent(post.content),
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              onPressed: onDelete,
                              icon: const Icon(Icons.delete_outline, color: Colors.black54),
                              tooltip: '삭제',
                            ),
                          ],
                        ),

                        // 위치
                        if ((post.location ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, right: 8),
                            child: Text('📍 ${post.location!}',
                                style: const TextStyle(fontSize: 13, color: Colors.black38),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),

                        // 해시태그
                        if (tags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, right: 8),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              children: tags
                                  .map((t) => Text(
                                t.startsWith('#') ? t : '#$t',
                                style: const TextStyle(
                                  color: Color(0xFF2D79FF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ))
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 하단 카운트
              Row(
                children: [
                  const Icon(Icons.favorite_border, size: 22, color: Colors.black26),
                  const SizedBox(width: 6),
                  Text('${post.likeCount}',
                      style: const TextStyle(
                          fontSize: 14, color: Colors.black38, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 18),
                  FutureBuilder<int>(
                    future: _fetchCommentCount(),
                    builder: (context, snap) {
                      final count = (snap.hasData) ? snap.data! : 0;
                      return Row(
                        children: [
                          const Icon(Icons.mode_comment_outlined,
                              size: 20, color: Colors.black26),
                          const SizedBox(width: 6),
                          Text('$count',
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black38,
                                  fontWeight: FontWeight.w600)),
                        ],
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
