import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Comment extends StatelessWidget {
  const Comment({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(CupertinoIcons.chat_bubble),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: GestureDetector(
                onTap: () {}, // 시트 내부 탭 전달
                child: DraggableScrollableSheet(
                  initialChildSize: 0.55,
                  minChildSize: 0.35,
                  maxChildSize: 0.95,
                  builder: (context, scrollController) {
                    return _CommentSheet(scrollController: scrollController);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class CommentItem {
  String user;
  String text;
  bool liked;
  int likeCount;

  CommentItem({
    required this.user,
    required this.text,
    this.liked = false,
    this.likeCount = 0,
  });
}

/// ↓↓↓ 시트 본문

class _CommentSheet extends StatefulWidget {
  final ScrollController scrollController;
  const _CommentSheet({required this.scrollController});

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final _inputCtrl = TextEditingController();
  final _focus = FocusNode();
  bool _canSend = false; // ✅ 보낼 수 있나

  @override
  void initState() {
    super.initState();
    _inputCtrl.addListener(() {
      final can = _inputCtrl.text.trim().isNotEmpty;
      if (can != _canSend) setState(() => _canSend = can);
    });
  }

  // ✅ 로컬 댓글 리스트 (초기 목업 데이터)
  final List<CommentItem> _comments = List.generate(
    10,
    (i) => CommentItem(user: '사용자${i + 1}', text: '오토바이 진짜 멋있네요👍'),
  );

  void _addComment() {
    if (!_canSend) return;
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _comments.add(CommentItem(user: '나', text: text));
    });
    _inputCtrl.clear();
    FocusScope.of(context).unfocus(); // 키보드 닫기(선택)

    // 입력 후 리스트 하단으로 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.scrollController.animateTo(
        widget.scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom; // 키보드 높이

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset), // ✅ 키보드에 밀리지 않게
          child: Column(
            children: [
              // --- 헤더 ---
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
                child: Text(
                  '댓글',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),

              // --- 리스트 ---
              Expanded(
                child: ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: _comments.length,
                  itemBuilder: (context, index) {
                    final c = _comments[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.deepPurple[100],
                            radius: 18,
                            child: const Icon(
                              Icons.person,
                              color: Colors.deepPurple,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // 본문
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${c.user} ',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      TextSpan(
                                        text: c.text,
                                        style: const TextStyle(
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                InkWell(
                                  onTap: () {
                                    // TODO: 대댓글 작성 UI 열기
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                      '답글 달기',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 좋아요 토글 + 숫자
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  c.liked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: c.liked ? Colors.red : Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    c.liked = !c.liked;
                                    c.likeCount += c.liked ? 1 : -1;
                                    if (c.likeCount < 0) c.likeCount = 0;
                                  });
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  '${c.likeCount}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // --- 입력창 ---
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputCtrl,
                        focusNode: _focus,
                        // ⛔️ 엔터로 전송 안 함
                        textInputAction: TextInputAction.newline,
                        onSubmitted: null, // 비활성
                        decoration: InputDecoration(
                          hintText: '댓글 추가..',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
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
                    // ⬆️ 아이콘으로만 전송
                    InkWell(
                      onTap: _canSend ? _addComment : null,
                      borderRadius: BorderRadius.circular(20),
                      child: CircleAvatar(
                        backgroundColor:
                            _canSend ? Colors.black : Colors.grey[300],
                        child: Icon(
                          Icons.arrow_upward,
                          color: _canSend ? Colors.white : Colors.black54,
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
  }
}
