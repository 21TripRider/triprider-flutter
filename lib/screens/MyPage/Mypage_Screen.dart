// lib/screens/MyPage/mypage_screen.dart
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'package:triprider/screens/MyPage/Badge_Style_Screen.dart';
import 'package:triprider/screens/MyPage/My_Upload_Screen.dart';
import 'package:triprider/screens/MyPage/PrivacyPolicyScreen.dart';
import 'package:triprider/screens/MyPage/Record_Screen.dart';
import 'package:triprider/screens/MyPage/Save_Course_Screen.dart';
import 'package:triprider/screens/MyPage/TermsOfServiceScreen.dart';
import 'package:triprider/screens/MyPage/LogoutScreen.dart';
import 'package:triprider/widgets/Bottom_App_Bar.dart';

/// =========================
/// 서버 API 기본 설정
/// =========================

// 플랫폼별 로컬 서버 접근 주소 자동 선택
final String kApiBase = (() {
  if (Platform.isIOS) return 'http://127.0.0.1:8080';
  return 'http://10.0.2.2:8080';
})();

Future<String?> _getJwt() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('jwt');
}

Future<Map<String, String>> _authHeaders({Map<String, String>? extra}) async {
  final token = await _getJwt();
  final headers = <String, String>{'Authorization': 'Bearer $token'};
  if (extra != null) headers.addAll(extra);
  return headers;
}

String resolveImageUrl(String? path) {
  if (path == null) return '';
  final p = path.trim();
  if (p.isEmpty) return '';
  if (p.startsWith('http://') || p.startsWith('https://')) return p;
  if (p.startsWith('/')) return '$kApiBase$p';
  return '$kApiBase/$p';
}

String withCacheBust(String url) {
  if (url.isEmpty) return url;
  final ts = DateTime.now().millisecondsSinceEpoch;
  return url.contains('?') ? '$url&ts=$ts' : '$url?ts=$ts';
}

/// =========================
/// API 모델
/// =========================
class MyPageResponse {
  final String email;
  final String nickname;
  final String? intro;
  final String? badge;
  final String? profileImage;
  final num? totalDistance;

  MyPageResponse({
    required this.email,
    required this.nickname,
    this.intro,
    this.badge,
    this.profileImage,
    this.totalDistance,
  });

  factory MyPageResponse.fromJson(Map<String, dynamic> j) => MyPageResponse(
    email: j['email'] ?? '',
    nickname: j['nickname'] ?? '',
    intro: j['intro'],
    badge: j['badge'],
    profileImage: j['profileImage'],
    totalDistance: j['totalDistance'],
  );
}

/// =========================
/// API 호출
/// =========================
Future<MyPageResponse> fetchMyPage() async {
  final uri = Uri.parse('$kApiBase/api/mypage');
  final res = await http.get(uri, headers: await _authHeaders());
  if (res.statusCode != 200) {
    throw Exception('마이페이지 조회 실패: ${res.statusCode} ${res.body}');
  }
  final data = json.decode(res.body) as Map<String, dynamic>;
  return MyPageResponse.fromJson(data);
}

Future<void> updateIntroOnServer(String intro) async {
  final uri = Uri.parse('$kApiBase/api/mypage/intro');
  final res = await http.put(
    uri,
    headers: await _authHeaders(
      extra: {'Content-Type': 'text/plain; charset=utf-8'},
    ),
    body: intro,
  );
  if (res.statusCode != 200) {
    throw Exception('한줄소개 수정 실패: ${res.statusCode} ${res.body}');
  }
}

Future<String> uploadProfileImage(File imageFile) async {
  final uri = Uri.parse('$kApiBase/api/mypage/profile-image');
  final req = http.MultipartRequest('POST', uri);
  req.headers.addAll(await _authHeaders());
  req.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
  final streamed = await req.send();
  final res = await http.Response.fromStream(streamed);
  if (res.statusCode != 200) {
    throw Exception('프로필 이미지 업로드 실패: ${res.statusCode} ${res.body}');
  }
  final raw = res.body.replaceAll('"', '').trim();
  return resolveImageUrl(raw);
}

/// =========================
/// 화면
/// =========================
class MypageScreen extends StatefulWidget {
  const MypageScreen({super.key});
  @override
  State<MypageScreen> createState() => _MypageScreenState();
}

class _MypageScreenState extends State<MypageScreen>
    with WidgetsBindingObserver {
  String _nickname = '닉네임';
  String _introText = '한줄 소개';
  String? _profileImageUrl;

  XFile? _pickedImage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMyPage();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadMyPage();
    }
  }

  Future<void> _loadMyPage() async {
    try {
      final mp = await fetchMyPage();
      setState(() {
        _nickname = (mp.nickname.isNotEmpty) ? mp.nickname : '라이더';
        _introText = (mp.intro != null && mp.intro!.trim().isNotEmpty)
            ? mp.intro!.trim()
            : '한줄 소개를 입력해보세요';
        _profileImageUrl = resolveImageUrl(mp.profileImage);
        _loading = false;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nickname', _nickname);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('마이페이지 불러오기 실패: $e')));
      }
    }
  }

  Future<void> _openEditSheet() async {
    final result = await showModalBottomSheet<_EditProfileResult>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditProfileSheet(
        initialIntro: _introText,
        initialImage: _pickedImage,
        initialNetworkImage: _profileImageUrl,
      ),
    );

    if (result == null) return;

    try {
      if (result.intro != null && result.intro!.trim() != _introText.trim()) {
        await updateIntroOnServer(result.intro!.trim());
        _introText = result.intro!.trim();
      }
      if (result.image != null) {
        final url = await uploadProfileImage(File(result.image!.path));
        _profileImageUrl = withCacheBust(url);
        _pickedImage = null;
      }
      setState(() {});
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('프로필이 업데이트됐어요.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('업데이트 실패: $e')));
    }
  }

  ImageProvider<Object> _buildProfileImageProvider() {
    if (_pickedImage != null) return FileImage(File(_pickedImage!.path));
    final url = resolveImageUrl(_profileImageUrl);
    if (url.isNotEmpty) {
      return NetworkImage(url);
    }
    return const AssetImage('assets/image/logo.png');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.grey[200],
      appBar: MyPage_AppBar(
        titleText: _loading ? '...' : _nickname,
        onEditPressed: _openEditSheet,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            MyPage_top(
              imageProvider: _buildProfileImageProvider(),
              intro: _introText,
            ),
            const SizedBox(height: 16),
            const MyPage_Bottom(),
          ],
        ),
      ),
      bottomNavigationBar: const BottomAppBarWidget(),
    );
  }
}

/// =========================
/// AppBar
/// =========================
class MyPage_AppBar extends StatelessWidget implements PreferredSizeWidget {
  const MyPage_AppBar({super.key, this.onEditPressed, required this.titleText});
  final VoidCallback? onEditPressed;
  final String titleText;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Text(titleText, style: const TextStyle(color: Colors.black)),
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
      ],
    );
  }
}

/// =========================
/// 상단 카드
/// =========================
class MyPage_top extends StatelessWidget {
  final ImageProvider<Object> imageProvider;
  final String intro;
  const MyPage_top({
    super.key,
    required this.imageProvider,
    required this.intro,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
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
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: imageProvider,
                onBackgroundImageError: (_, __) {},
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('제주도',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('2.3',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold)),
                        SizedBox(width: 4),
                        Text('바퀴',
                            style: TextStyle(color: Colors.white, fontSize: 16)),
                        Spacer(),
                        Text('누적거리 507 km',
                            style:
                            TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                    SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      child: LinearProgressIndicator(
                        value: 0.77,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 6,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('3바퀴까지 153 km 남음',
                        style:
                        TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(intro,
              style: const TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),

          // ⭐ 뱃지 & 칭호 UI 복원
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
                    Text('+6',
                        style: TextStyle(color: Colors.white, fontSize: 18)),
                    SizedBox(width: 8),
                    Text('뱃지', style: TextStyle(color: Colors.white70)),
                  ],
                ),
                const Text('|',
                    style: TextStyle(fontSize: 25, color: Colors.white)),
                Row(
                  children: const [
                    Text('제주 토박이 +2',
                        style: TextStyle(color: Colors.white, fontSize: 18)),
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


/// =========================
/// 하단 메뉴 리스트
/// =========================
class MyPage_Bottom extends StatelessWidget {
  const MyPage_Bottom({super.key});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildMenuItem(context, '주행 기록', const RecordScreen()),
        _buildMenuItem(context, '좋아요 누른 코스', const SaveCourseScreen()),
        _buildMenuItem(context, '뱃지 & 칭호 관리', const BadgeStyleScreen()),
        _buildMenuItem(context, '나의 게시물', const MyUploadScreen()),
        _buildMenuItem(context, '개인정보처리방침', const PrivacyPolicyScreen()),
        _buildMenuItem(context, '이용약관', const TermsOfServiceScreen()),
        _buildMenuItem(context, '로그아웃', const LogoutScreen()),
      ],
    );
  }

  Widget _buildMenuItem(
      BuildContext context,
      String title,
      Widget destinationPage,
      ) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => destinationPage),
      ),
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
            Text(title,
                style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            const Icon(Icons.arrow_forward_ios, size: 18),
          ],
        ),
      ),
    );
  }
}

/// =========================
/// 편집 바텀시트
/// =========================
class _EditProfileResult {
  final XFile? image;
  final String? intro;
  _EditProfileResult({this.image, this.intro});
}

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({
    super.key,
    required this.initialIntro,
    this.initialImage,
    this.initialNetworkImage,
  });

  final String initialIntro;
  final XFile? initialImage;
  final String? initialNetworkImage;

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

  Future<void> _pickImage() async {
    await Future.delayed(const Duration(milliseconds: 60));
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    if (!mounted) return;
    setState(() => _image = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    final initialNet = resolveImageUrl(widget.initialNetworkImage);

    final ImageProvider<Object> imageProvider = _image != null
        ? FileImage(File(_image!.path))
        : (initialNet.isNotEmpty
        ? NetworkImage(initialNet)
        : const AssetImage('assets/image/logo.png'));

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: bottom + 16,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            children: [
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundImage: imageProvider,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _pickImage, // 사진 선택
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.camera_alt,
                                size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Text('한줄 소개',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    _EditProfileResult(
                      image: _image,
                      intro: _controller.text.trim(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.white70,
                ),
                child: const Text(
                  '저장',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}