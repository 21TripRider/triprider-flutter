// mypage_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:triprider/screens/MyPage/Badge_Style_Screen.dart';
import 'package:triprider/screens/MyPage/My_Upload_Screen.dart';
import 'package:triprider/screens/MyPage/Record_Screen.dart';
import 'package:triprider/screens/MyPage/Save_Course_Screen.dart';
import 'package:triprider/widgets/Bottom_App_Bar.dart';
import 'package:permission_handler/permission_handler.dart';


class MypageScreen extends StatefulWidget {
  const MypageScreen({super.key});

  @override
  State<MypageScreen> createState() => _MypageScreenState();
}

class _MypageScreenState extends State<MypageScreen> {
  XFile? _profileImage; // 갤러리/카메라에서 고른 이미지
  String _introText = '퉁퉁퉁퉁퉁퉁퉁퉁퉁 한줄 소개';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.grey[200],

      appBar: MyPage_AppBar(
        onEditPressed: () async {
          final result = await showModalBottomSheet<_EditProfileResult>(
            context: context,
            useRootNavigator: true,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder:
                (_) => EditProfileSheet(
                  initialIntro: _introText,
                  initialImage: _profileImage,
                ),
          );

          if (result != null) {
            setState(() {
              _profileImage = result.image;
              _introText = result.intro;
            });
          }
        },
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            /// 상단 카드 (AppBar 공간 포함)
            MyPage_top(image: _profileImage, intro: _introText),

            const SizedBox(height: 16),

            /// 하단 버튼들
            const MyPage_Bottom(),
          ],
        ),
      ),

      bottomNavigationBar: const BottomAppBarWidget(),
    );
  }
}

class MyPage_AppBar extends StatelessWidget implements PreferredSizeWidget {
  const MyPage_AppBar({super.key, this.onEditPressed});

  final VoidCallback? onEditPressed;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight); // AppBar 높이 지정

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent, // AppBar를 투명 처리
      elevation: 0,
      automaticallyImplyLeading: false,
      title: const Text('닉네임', style: TextStyle(color: Colors.black)),
      actions: [
        IconButton(
          onPressed: onEditPressed,
          icon: const Icon(
            Icons.drive_file_rename_outline,
            size: 30,
            color: Colors.black,
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.menu, size: 30, color: Colors.black),
        ),
        const SizedBox(width: 10),
      ],
    );
  }
}

class MyPage_top extends StatelessWidget {
  final XFile? image;
  final String intro;

  const MyPage_top({super.key, required this.image, required this.intro});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10, // 상태바 + 높이
        left: 16,
        right: 16,
        bottom: 10,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF5E7E), Color(0xFFFF7E9E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 프로필 영역
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage:
                    image != null
                        ? FileImage(File(image!.path))
                        : const AssetImage('assets/image/logo.png')
                            as ImageProvider,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '제주도',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        Text(
                          '2.3',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '바퀴',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        Spacer(),
                        Text(
                          '누적거리 507 km',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: const LinearProgressIndicator(
                        value: 0.77,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '3바퀴까지 153 km 남음',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Text(
            intro,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 20),

          /// 뱃지/칭호 카드
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.star, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      '+6',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    SizedBox(width: 8),
                    Text('뱃지', style: TextStyle(color: Colors.white70)),
                  ],
                ),
                const Text(
                  '|',
                  style: TextStyle(fontSize: 25, color: Colors.white),
                ),
                Row(
                  children: const [
                    Text(
                      '제주 토박이 +2',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    SizedBox(width: 8),
                    Text('칭호', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class MyPage_Bottom extends StatelessWidget {
  const MyPage_Bottom({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildMenuItem(context, '주행 기록', const RecordScreen()),
        _buildMenuItem(context, '저장한 코스', const SaveCourseScreen()),
        _buildMenuItem(context, '뱃지 & 칭호 관리', const BadgeStyleScreen()),
        _buildMenuItem(context, '나의 게시물', const MyUploadScreen()),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    String title,
    Widget destinationPage,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destinationPage),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18),
          ],
        ),
      ),
    );
  }
}

/// =====================
/// 편집 바텀시트 위젯들
/// =====================

class _EditProfileResult {
  final XFile? image;
  final String intro;
  _EditProfileResult({required this.image, required this.intro});
}

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({
    super.key,
    required this.initialIntro,
    this.initialImage,
  });

  final String initialIntro;
  final XFile? initialImage;

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _picker = ImagePicker();
  XFile? _image;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _image = widget.initialImage;
    _controller = TextEditingController(text: widget.initialIntro);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ✅ 안드로이드 런타임 권한 요청 (T+)
  Future<bool> _ensurePhotoPermission() async {
    if (Platform.isAndroid) {
      // Android 13+ : READ_MEDIA_IMAGES, 이하 : READ_EXTERNAL_STORAGE
      final photos = await Permission.photos.request();
      final storage = await Permission.storage.request();
      return photos.isGranted || storage.isGranted;
    }
    return true;
  }

  Future<void> _pickImage() async {
    try {
      // 권한 먼저
      final ok = await _ensurePhotoPermission();
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진 접근 권한이 필요합니다. 설정에서 허용해주세요.')),
        );
        return;
      }

      // 바텀시트 위에서 띄울 때 타이밍 이슈 예방
      await Future.delayed(const Duration(milliseconds: 60));

      final XFile? picked =
      await _picker.pickImage(source: ImageSource.gallery); // 카메라: ImageSource.camera
      if (picked == null) return;

      if (!mounted) return;
      setState(() => _image = picked);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 선택 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: bottom + 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            children: [
              Center(
                child: Stack(
                  clipBehavior: Clip.none, // ✅ 겹침 허용
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundImage: _image != null
                          ? FileImage(File(_image!.path))
                          : const AssetImage('assets/image/logo.png') as ImageProvider,
                    ),
                    Positioned(
                      right: 0, // ✅ 화면 안쪽으로
                      bottom: 0,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _pickImage,
                          child: Container(
                            width: 36, // ✅ 히트박스 확장
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('한줄 소개', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                maxLength: 40,
                decoration: InputDecoration(
                  hintText: '한줄 소개를 입력하세요',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    _EditProfileResult(image: _image, intro: _controller.text.trim()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: Colors.white70,
                ),
                child: const Text('저장',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
              ),
            ],
          ),
        );
      },
    );
  }
}
