import 'package:flutter/material.dart';

class MyUploadScreen extends StatefulWidget {
  const MyUploadScreen({super.key});

  @override
  State<MyUploadScreen> createState() => _MyUploadScreenState();
}

class _MyUploadScreenState extends State<MyUploadScreen> {
  // 데모 데이터
  final List<MyPost> posts = [
    MyPost(
      dateLabel: '25.05.19 라이딩 기록',
      content:
      '제가 이번에 제주도에서 처음으로 스쿠터 렌트해서 여행해보려고 하는데 경치 좋은 라이딩 코스 추천 부탁드려요!',
      tags: ['트립라이더', '라이딩', '바이크', 'motorcycle'],
      imagePath: 'assets/image/courseview1.png',
      likes: 22,
      comments: 3,
    ),
    MyPost(
      dateLabel: '25.05.18 라이딩 기록',
      content:
      '제가 이번에 제주도에서 처음으로 스쿠터 렌트해서 여행해보려고 하는데 경치 좋은 라이딩 코스 추천 부탁드려요! 코스 난이도는 초보 기준이면 좋겠어요. 장비 추천도 부탁!',
      tags: ['트립라이더', '라이딩', '드라이브', '라이딩 코스'],
      imagePath: null, // 텍스트만 있는 카드
      likes: 4,
      comments: 1,
    ),
    MyPost(
      dateLabel: '25.05.17 라이딩 기록',
      content: '한라산 북측 코스 달려봤는데 생각보다 바람이… 더보기',
      tags: ['라이딩', '한라산', '야경'],
      imagePath: 'assets/image/courseview2.png',
      likes: 9,
      comments: 2,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        centerTitle: true,
        title: const Text('나의 게시물', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: posts.length,
        separatorBuilder: (_, __) => const Divider(height: 16, thickness: 8, color: Color(0xFFF3F3F4)),
        itemBuilder: (context, index) {
          final post = posts[index];
          return _PostCard(
            post: post,
            onToggleLike: () {
              setState(() {
                post.liked = !post.liked;
                post.likes += post.liked ? 1 : -1;
              });
            },
            onMore: (value) {
              // TODO: 수정/삭제/공유 로직
            },
          );
        },
      ),
    );
  }
}

class MyPost {
  MyPost({
    required this.dateLabel,
    required this.content,
    required this.tags,
    required this.likes,
    required this.comments,
    this.imagePath,
    this.liked = false,
  });

  final String dateLabel;
  final String content;
  final List<String> tags;
  final String? imagePath; // 있으면 썸네일 표시
  int likes;
  int comments;
  bool liked;
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.onToggleLike,
    required this.onMore,
  });

  final MyPost post;
  final VoidCallback onToggleLike;
  final void Function(String?) onMore;

  @override
  Widget build(BuildContext context) {
    final hasImage = post.imagePath != null && post.imagePath!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 상단: 이미지 썸네일 + 제목/날짜 + 더보기
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 썸네일 (optional)
              if (hasImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    post.imagePath!,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              if (hasImage) const SizedBox(width: 14),

              // 날짜/제목
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: hasImage ? 6 : 0),
                  child: Text(
                    post.dateLabel,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // 더보기(⋯)
              PopupMenuButton<String>(
                onSelected: onMore,
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('수정')),
                  PopupMenuItem(value: 'delete', child: Text('삭제')),
                  PopupMenuItem(value: 'share', child: Text('공유')),
                ],
                icon: const Icon(Icons.more_horiz, color: Colors.black54),
              ),
            ],
          ),

          // 본문 (텍스트형/이미지형 둘 다 표시)
          if (!hasImage) const SizedBox(height: 12),
          if (post.content.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: hasImage ? 0 : 4, right: 4, top: 8),
              child: Text(
                post.content,
                style: const TextStyle(fontSize: 15, height: 1.4),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          const SizedBox(height: 10),

          // 해시태그
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: post.tags
                .map(
                  (t) => Text(
                '#$t',
                style: const TextStyle(
                  color: Color(0xFF2D79FF),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
                .toList(),
          ),

          const SizedBox(height: 12),

          // 하단: 좋아요/댓글 카운트
          Row(
            children: [
              InkWell(
                onTap: onToggleLike,
                borderRadius: BorderRadius.circular(20),
                child: Row(
                  children: [
                    Icon(
                      post.liked ? Icons.favorite : Icons.favorite_border,
                      size: 22,
                      color: post.liked ? Colors.pink : Colors.black26,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${post.likes}',
                      style: TextStyle(
                        fontSize: 14,
                        color: post.liked ? Colors.pink : Colors.black38,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Row(
                children: [
                  const Icon(Icons.mode_comment_outlined, size: 20, color: Colors.black26),
                  const SizedBox(width: 6),
                  Text('${post.comments}',
                      style: const TextStyle(fontSize: 14, color: Colors.black38, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
