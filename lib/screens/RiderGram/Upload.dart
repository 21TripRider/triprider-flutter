import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';


class Upload extends StatefulWidget {
  const Upload({super.key});

  @override
  State<Upload> createState() => _UploadState();
}

class _UploadState extends State<Upload> {
  final _picker = ImagePicker();
  XFile? _image;
  final _contentCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();

  bool get _canPost {
    // 최소: 사진 또는 글이 있어야 게시 가능 (원하면 규칙 바꿔도 됨)
    return (_image != null) || _contentCtrl.text.trim().isNotEmpty;
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _image = picked);
  }

  List<String> _parseTags(String raw) {
    // " #라이딩  #제주도  #바다 " → ["라이딩","제주도","바다"]
    final r = RegExp(r'#([^\s#]+)');
    return r.allMatches(raw).map((m) => m.group(1)!).toList();
  }

  void _submit() {
    if (!_canPost) return;
    final data = PostData(
      image: _image,
      content: _contentCtrl.text.trim(),
      tags: _parseTags(_tagCtrl.text),
    );
    Navigator.of(context).pop(data); // ← 결과 되돌리기
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grey = Colors.grey.shade300;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, size: 28),
        ),
        actions: [
          TextButton(
            onPressed: _canPost ? _submit : null,
            child: Text(
              '게시',
              style: TextStyle(
                color: _canPost ? Colors.black : Colors.black26,
                fontSize: 18, fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(thickness: 1, color: Colors.grey),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // 사진 영역
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: grey,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: _image == null
                        ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.image_outlined, size: 72),
                        SizedBox(height: 8),
                        Text('사진 추가', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    )
                        : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(File(_image!.path),
                          height: 220, width: double.infinity, fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 글쓰기
                TextField(
                  controller: _contentCtrl,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: '글쓰기..',
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState((){}),
                ),
                const SizedBox(height: 8),

                // 해시태그 (예: #라이딩 #제주도)
                TextField(
                  controller: _tagCtrl,
                  decoration: const InputDecoration(
                    hintText: '#해시태그 추가 (예: #라이딩 #제주도)',
                    border: InputBorder.none,
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


class PostData {
  final XFile? image;      // 갤러리에서 고른 사진
  final String content;    // 글 본문
  final List<String> tags; // #태그 리스트

  PostData({this.image, required this.content, required this.tags});
}

