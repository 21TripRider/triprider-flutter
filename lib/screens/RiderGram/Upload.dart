// lib/RiderGram/Upload.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:triprider/core/network/Api_client.dart';

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
  final _locationCtrl = TextEditingController();

  bool _posting = false;

  bool get _canPost =>
      (_image != null) || _contentCtrl.text.trim().isNotEmpty;

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _image = picked);
  }

  String _tagsToServerString(String raw) {
    // "#제주 #바다" → "#제주 #바다"
    final r = RegExp(r'#([^\s#]+)');
    final found = r.allMatches(raw).map((m) => m.group(1)!).toSet();
    if (found.isEmpty) return '';
    return found.map((t) => '#$t').join(' ');
  }

  Future<void> _submit() async {
    if (!_canPost || _posting) return;
    setState(() => _posting = true);

    try {
      String? imageUrl;
      if (_image != null) {
        // 1) 이미지 먼저 업로드 → 절대 URL 획득
        imageUrl = await ApiClient.uploadImage(File(_image!.path));
      }

      // 2) 게시글 생성
      final body = {
        "content": _contentCtrl.text.trim(),
        "imageUrl": imageUrl, // 이미지 있을 때만 값 존재
        "location": _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        "hashtags": _tagsToServerString(_tagCtrl.text),
      };

      await ApiClient.post('/api/posts', body: body);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('업로드 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _tagCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grey = Colors.grey.shade300;

    return Scaffold(
      backgroundColor: Colors.white, // ← 전체 배경 흰색
      appBar: AppBar(
        elevation: 0.5,
        scrolledUnderElevation: 0,            // 스크롤 시 틴트 방지
        backgroundColor: Colors.white,         // ← 앱바 흰색
        surfaceTintColor: Colors.transparent,  // 머티리얼3 틴트 제거
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,              // 상태바 배경 흰색
          statusBarIconBrightness: Brightness.dark,  // 안드로이드 아이콘 어둡게
          statusBarBrightness: Brightness.light,     // iOS 아이콘 어둡게
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.close, size: 28, color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: _canPost && !_posting ? _submit : null,
            child: Text(
              _posting ? '게시 중...' : '게시',
              style: TextStyle(
                color: (_canPost && !_posting) ? Colors.black : Colors.black26,
                fontSize: 18,
                fontWeight: FontWeight.w600,
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
                // 이미지 선택
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
                        Text('사진 추가',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ],
                    )
                        : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(_image!.path),
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 본문
                TextField(
                  controller: _contentCtrl,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: '글쓰기..',
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),

                // 위치(선택)
                TextField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(
                    hintText: '위치 (선택)',
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 8),

                // 해시태그
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
