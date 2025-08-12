// RidergramScreen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:triprider/screens/RiderGram/Comment.dart';
import 'package:triprider/screens/RiderGram/Search.dart';
import 'package:triprider/screens/RiderGram/Upload.dart';
import 'package:triprider/widgets/Bottom_App_Bar.dart';

class RidergramScreen extends StatefulWidget {
  const RidergramScreen({super.key});

  @override
  State<RidergramScreen> createState() => _RidergramScreenState();
}

class _RidergramScreenState extends State<RidergramScreen> {
  final List<PostData> _posts = [
    // 초기 더미 (원하면 비워도 됨)
    PostData(image: null, content: '25.05.19 라이딩 기록(글쓰기)', tags: ['라이딩','해시테그']),
  ];

  Future<void> _openUpload() async {
    final PostData? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const Upload()),
    );
    if (result != null) {
      setState(() => _posts.insert(0, result)); // 맨 위에 추가
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
            icon: const Icon(Icons.search, size: 30),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ListView.builder(
          itemCount: _posts.length,
          itemBuilder: (_, i) => UploadCard(post: _posts[i]),
        ),
      ),
      bottomNavigationBar: BottomAppBarWidget(),
    );
  }
}

class UploadCard extends StatefulWidget {
  final PostData post;
  const UploadCard({super.key, required this.post});

  @override
  State<UploadCard> createState() => _UploadCardState();
}

class _UploadCardState extends State<UploadCard> {
  bool _isLiked = false;
  int _likeCount = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.post;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 프로필
        Row(
          children: const [
            Icon(Icons.account_circle, size: 25),
            SizedBox(width: 10),
            Text('사용자 닉네임', style: TextStyle(fontSize: 17)),
          ],
        ),
        const SizedBox(height: 20),

        // 이미지
        if (p.image != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: Image.file(File(p.image!.path), fit: BoxFit.cover),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: Image.asset("assets/image/courseview2.png"),
          ),

        // 액션바
        Row(
          children: [
            IconButton(
              padding: const EdgeInsets.only(left: 10),
              onPressed: () {
                setState(() {
                  _isLiked = !_isLiked;
                  _likeCount += _isLiked ? 1 : -1;
                  if (_likeCount < 0) _likeCount = 0;
                });
              },
              icon: Icon(
                _isLiked ? Icons.favorite : Icons.favorite_border,
                color: _isLiked ? Colors.red : null,
              ),
            ),
            Text('$_likeCount', style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(width: 13),
            const Comment(),
          ],
        ),

        // 본문
        if (p.content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(p.content),
          ),

        // 태그
        if (p.tags.isNotEmpty)
          Wrap(
            spacing: 10,
            children: p.tags
                .map((t) => Text('#$t', style: const TextStyle(color: Color(0xFF0088FF))))
                .toList(),
          ),

        const SizedBox(height: 40),
      ],
    );
  }
}
