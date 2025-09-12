//lib/screens/RiderGram/Comment_Sheet.dart
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:triprider/core/network/Api_client.dart';
import 'package:triprider/screens/RiderGram/Comment_Model.dart';
import 'package:triprider/screens/RiderGram/Public_Profile_Screen.dart';
import 'package:triprider/screens/RiderGram/api_comment.dart';

class CommentSheet extends StatefulWidget {
  final int postId;
  const CommentSheet({super.key, required this.postId});

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final _inputCtrl = TextEditingController();
  final _focus = FocusNode();

  late Future<List<CommentModel>> _future;
  final _items = <CommentModel>[];
  bool _sending = false;

  // 좋아요 토글 중인 댓글 id
  final _liking = <int>{};

  // ==== 프로필 자동 보강/캐시 ====
  final Map<String, Map<String, dynamic>> _profileCacheByNick = {};
  final Map<int, String?> _profileUrlByCommentId = {};
  final Map<int, int?> _userIdByCommentId = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<CommentModel>> _load() async {
    final list = await CommentApi.list(widget.postId);
    _items
      ..clear()
      ..addAll(list);
    _hydrateProfiles();
    return _items;
  }

  Future<Map<String, dynamic>?> _fetchProfileFor({
    required String nickname,
    int? userId,
  }) async {
    final List<Uri> candidates = [
      if (userId != null) ApiClient.publicUri('/api/users/$userId/profile'),
      if (userId != null) ApiClient.publicUri('/api/users/$userId'),
      ApiClient.publicUri('/api/public/profile', {'nickname': nickname}),
      ApiClient.publicUri('/api/users/profile', {'nickname': nickname}),
      ApiClient.publicUri('/api/users/by-nickname', {'nickname': nickname}),
      ApiClient.publicUri('/api/profiles', {'q': nickname}),
    ];

    String? _firstString(Map<String, dynamic> m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    int? _firstInt(Map<String, dynamic> m, List<String> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v is num) return v.toInt();
        if (v is String) {
          final p = int.tryParse(v);
          if (p != null) return p;
        }
      }
      return null;
    }

    for (final uri in candidates) {
      try {
        final res = await ApiClient.get(uri.path, query: uri.queryParameters);
        final body = jsonDecode(res.body);
        final Map<String, dynamic> obj = body is List
            ? (body.isNotEmpty
            ? (body.first as Map).cast<String, dynamic>()
            : const {})
            : (body as Map).cast<String, dynamic>();

        final img = _firstString(obj, [
          'profileImage',
          'profile_image',
          'avatarUrl',
          'avatar',
          'imageUrl',
          'url',
          'photoUrl',
        ]);
        final id = _firstInt(obj, ['userId', 'id', 'writerId', 'authorId']);

        return {'profileImage': img, 'userId': id};
      } catch (_) {}
    }
    return null;
  }

  Future<void> _hydrateProfiles() async {
    final nicks = _items.map((e) => e.user).toSet().toList();

    for (final nick in nicks) {
      if (_profileCacheByNick.containsKey(nick)) continue;

      final withId = _items.firstWhere(
            (c) => c.user == nick && c.userId != null,
        orElse: () => _items.firstWhere((c) => c.user == nick),
      );

      final fetched =
      await _fetchProfileFor(nickname: nick, userId: withId.userId);
      _profileCacheByNick[nick] =
          fetched ??
              {'profileImage': withId.profileImage, 'userId': withId.userId};
    }

    for (final c in _items) {
      final cached = _profileCacheByNick[c.user];
      final img = (c.profileImage != null && c.profileImage!.isNotEmpty)
          ? c.profileImage
          : (cached?['profileImage'] as String?);
      final uid = c.userId ?? (cached?['userId'] as int?);

      _profileUrlByCommentId[c.id] = img;
      _userIdByCommentId[c.id] = uid;
    }

    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    await _load();
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await CommentApi.create(widget.postId, text);
      _inputCtrl.clear();
      await _refresh();
      _focus.unfocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('댓글 등록 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(CommentModel c) async {
    try {
      await CommentApi.delete(widget.postId, c.id);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
  }

  Future<void> _toggleLike(CommentModel c) async {
    if (_liking.contains(c.id)) return;
    setState(() => _liking.add(c.id));

    try {
      int newCount;
      bool newLiked;

      if (c.likedByMe) {
        newCount = await CommentApi.unlike(widget.postId, c.id);
        newLiked = false;
      } else {
        newCount = await CommentApi.like(widget.postId, c.id);
        newLiked = true;
      }

      final idx = _items.indexWhere((e) => e.id == c.id);
      if (idx >= 0) {
        _items[idx] = _items[idx].copyWith(
          likeCount: newCount,
          likedByMe: newLiked,
        );
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('처리 실패: $e')));
    } finally {
      if (mounted) setState(() => _liking.remove(c.id));
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ==== 새로 추가: URL 정규화 유틸 ====
  String? _absOrNull(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    return ApiClient.absoluteUrl(s);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(_items.length),
      behavior: HitTestBehavior.opaque,
      child: GestureDetector(
        onTap: () {},
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.35,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 8),
                        height: 4,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('댓글',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      const Divider(height: 1),

                      Expanded(
                        child: FutureBuilder<List<CommentModel>>(
                          future: _future,
                          builder: (context, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting &&
                                _items.isEmpty) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            if (snap.hasError) {
                              return Center(
                                  child: Text('불러오기 실패: ${snap.error}'));
                            }
                            if (_items.isEmpty) {
                              return const Center(child: Text('첫 댓글을 남겨보세요!'));
                            }

                            return RefreshIndicator(
                              onRefresh: _refresh,
                              child: ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                itemCount: _items.length,
                                itemBuilder: (context, i) {
                                  final c = _items[i];

                                  // ✅ 댓글 아바타 절대 URL 보정
                                  final raw = _profileUrlByCommentId[c.id];
                                  final abs = _absOrNull(raw);

                                  final ImageProvider avatarProvider = (abs != null)
                                      ? NetworkImage(abs)
                                      : const AssetImage('assets/image/logo.png');

                                  final avatar = CircleAvatar(
                                    radius: 18,
                                    backgroundImage: avatarProvider,
                                    onBackgroundImageError: (_, __) {
                                      // 실패시 자동으로 로고로 교체하고 싶으면 setState로 다시 그림
                                      setState(() {
                                        _profileUrlByCommentId[c.id] = '';
                                      });
                                    },
                                  );

                                  void _openProfile() {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PublicProfileScreen(
                                          userId: _userIdByCommentId[c.id],
                                          nickname: c.user,
                                        ),
                                      ),
                                    );
                                  }

                                  final contentRow = Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      InkWell(onTap: _openProfile, child: avatar),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            InkWell(
                                              onTap: _openProfile,
                                              child: Row(
                                                children: [
                                                  Text(
                                                    c.user,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                      FontWeight.bold,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    _friendlyTime(c.createdAt),
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(c.content),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            visualDensity:
                                            VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints:
                                            const BoxConstraints(),
                                            onPressed: _liking.contains(c.id)
                                                ? null
                                                : () => _toggleLike(c),
                                            icon: Icon(
                                              c.likedByMe
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              size: 22,
                                              color: c.likedByMe
                                                  ? Colors.red
                                                  : Colors.grey[700],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${c.likeCount}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );

                                  if (c.mine) {
                                    return Dismissible(
                                      key: ValueKey('c${c.id}'),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding:
                                        const EdgeInsets.only(right: 16),
                                        color: Colors.redAccent,
                                        child: const Icon(Icons.delete,
                                            color: Colors.white),
                                      ),
                                      confirmDismiss: (_) async {
                                        return await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            backgroundColor: Colors.white,
                                            title: const Text('삭제할까요?'),
                                            content: const Text(
                                                '해당 댓글이 게시글에서 삭제됩니다.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(
                                                        context, false),
                                                child: const Text('취소',style: TextStyle(color: Colors.black),),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(
                                                        context, true),
                                                child: const Text('삭제',style: TextStyle(color: Colors.black)),
                                              ),
                                            ],
                                          ),
                                        ) ??
                                            false;
                                      },
                                      onDismissed: (_) => _delete(c),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 6),
                                        child: contentRow,
                                      ),
                                    );
                                  }

                                  return Padding(
                                    padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                    child: contentRow,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),

                      Padding(
                        padding:
                        const EdgeInsets.fromLTRB(12, 8, 12, 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _inputCtrl,
                                focusNode: _focus,
                                textInputAction: TextInputAction.newline,
                                decoration: InputDecoration(
                                  hintText: '댓글 추가…',
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _sending ? null : _send,
                              borderRadius: BorderRadius.circular(20),
                              child: CircleAvatar(
                                backgroundColor: _sending
                                    ? Colors.grey[300]
                                    : Colors.black,
                                child: Icon(
                                  Icons.arrow_upward,
                                  color: _sending
                                      ? Colors.black54
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _friendlyTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '방금 전';
    if (d.inMinutes < 60) return '${d.inMinutes}분 전';
    if (d.inHours < 24) return '${d.inHours}시간 전';
    return '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')}';
  }
}
