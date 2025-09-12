import 'dart:io';
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// ✅ 추가: 총 주행거리 요약을 가져오기 위해 사용
import 'package:triprider/screens/Map/API/Ride_Api.dart';

import 'package:triprider/screens/MyPage/My_Upload_Screen.dart';
import 'package:triprider/screens/MyPage/PrivacyPolicyScreen.dart';
import 'package:triprider/screens/MyPage/Record_Screen.dart';
import 'package:triprider/screens/MyPage/Save_Course_Screen.dart';
import 'package:triprider/screens/MyPage/TermsOfServiceScreen.dart';
import 'package:triprider/screens/MyPage/DeleteAccountDialog.dart';
import 'package:triprider/screens/MyPage/LogoutScreen.dart';
import 'package:triprider/widgets/Bottom_App_Bar.dart';

/// =========================
/// ✅ 공통 상수
/// =========================
const String kIntroPlaceholderText = '한줄 소개를 입력해보세요';

/// =========================
/// ✅ 팝업 유틸 (로그인 화면의 스타일 그대로 복제)
/// =========================
enum PopupType { info, success, warn, error }

void showTripriderPopup(
    BuildContext context, {
      required String title,
      required String message,
      PopupType type = PopupType.info,
      Duration duration = const Duration(milliseconds: 2500),
    }) {
  final overlay = Overlay.of(context);
  if (overlay == null) return;

  Color accent;
  switch (type) {
    case PopupType.success:
      accent = const Color(0xFF39C172);
      break;
    case PopupType.warn:
      accent = const Color(0xFFFFA000);
      break;
    case PopupType.error:
      accent = const Color(0xFFE74C3C);
      break;
    case PopupType.info:
    default:
      accent = const Color(0xFFFF4E6B);
      break;
  }

  late OverlayEntry entry;
  bool closed = false;
  void safeRemove() {
    if (!closed && entry.mounted) {
      closed = true;
      entry.remove();
    }
  }

  entry = OverlayEntry(
    builder: (ctx) => SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 16,
            right: 16,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              builder: (_, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * -8),
                  child: child,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 6)),
                    ],
                    border: Border.all(color: const Color(0xFFE9E9EE)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.sports_motorsports_rounded, color: Colors.pink),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Colors.black.withOpacity(0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              message,
                              style: const TextStyle(
                                fontSize: 14.5,
                                height: 1.35,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  overlay.insert(entry);
  Future.delayed(duration, safeRemove);
}

/// =========================
/// 서버 API 기본 설정
/// =========================
final String kApiBase = (() {
  if (Platform.isIOS) return 'https://trip-rider.com';
  return 'https://trip-rider.com';
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

/// ✅ 추가: 한줄소개 제거 시 서버에 여러 방식으로 시도
Future<bool> clearIntroOnServer() async {
  final uri = Uri.parse('$kApiBase/api/mypage/intro');

  // 1) DELETE /api/mypage/intro
  try {
    final del = await http.delete(uri, headers: await _authHeaders());
    if (del.statusCode == 200) return true;
  } catch (_) {}

  // 2) PUT application/json { "intro": null }
  try {
    final putNull = await http.put(
      uri,
      headers: await _authHeaders(extra: {'Content-Type': 'application/json; charset=utf-8'}),
      body: jsonEncode({'intro': null}),
    );
    if (putNull.statusCode == 200) return true;
  } catch (_) {}

  // 3) PUT application/json { "intro": "" }
  try {
    final putEmpty = await http.put(
      uri,
      headers: await _authHeaders(extra: {'Content-Type': 'application/json; charset=utf-8'}),
      body: jsonEncode({'intro': ''}),
    );
    if (putEmpty.statusCode == 200) return true;
  } catch (_) {}

  // 실패시 false (UI는 초기화)
  return false;
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
/// 🔧 인트로 정규화
/// =========================
String? _normalizeIntro(dynamic raw) {
  if (raw == null) return null;
  final t = raw.toString().trim();
  if (t.isEmpty) return null;

  final low = t.toLowerCase();
  if (low == 'null' || low == 'undefined') return null;

  if ((t.startsWith('{') && t.endsWith('}')) || (t.startsWith('[') && t.endsWith(']'))) {
    try {
      final obj = jsonDecode(t);
      if (obj is Map) {
        final v = obj['intro'];
        if (v == null) return null;
        final s = v.toString().trim();
        if (s.isEmpty) return null;
        final sl = s.toLowerCase();
        if (sl == 'null' || sl == 'undefined') return null;
        return s;
      }
      return null;
    } catch (_) {
      if (t.contains('"intro":null') || t.contains("'intro':null")) return null;
    }
  }

  return t;
}

/// =========================
/// 화면
/// =========================
class MypageScreen extends StatefulWidget {
  const MypageScreen({super.key});
  @override
  State<MypageScreen> createState() => _MypageScreenState();
}

class _MypageScreenState extends State<MypageScreen> with WidgetsBindingObserver {
  String _nickname = '닉네임';
  String _introText = '한줄 소개';
  String? _profileImageUrl;

  // ✅ 바퀴/진행도 계산용
  static const double _lapKm = 240.0; // 한 바퀴 240km
  double _totalKm = 0.0;

  XFile? _pickedImage;
  bool _loading = true;

  bool _isPlaceholder(String s) => s.trim().isEmpty || s.trim() == kIntroPlaceholderText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMyPage();
    _loadRideSummary(); // ✅ 총 주행거리
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
      _loadRideSummary(); // ✅ 복귀 시 갱신
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<void> _loadMyPage() async {
    try {
      final mp = await fetchMyPage();
      setState(() {
        _nickname = (mp.nickname.isNotEmpty) ? mp.nickname : '라이더';

        // ✅ 인트로 정규화 적용
        final normalized = _normalizeIntro(mp.intro);
        _introText = (normalized == null || normalized.isEmpty)
            ? kIntroPlaceholderText
            : normalized;

        _profileImageUrl = resolveImageUrl(mp.profileImage);
        _loading = false;
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nickname', _nickname);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        showTripriderPopup(
          context,
          title: '불러오기 실패',
          message: '마이페이지 불러오기 실패: $e',
          type: PopupType.error,
        );
      }
    }
  }

  // ✅ Record_Screen과 동일한 서버 요약 사용
  Future<void> _loadRideSummary() async {
    try {
      final s = await RideApi.getSummary();
      final srvKm = ((s['totalKm'] as num?)?.toDouble() ?? 0.0);
      if (!mounted) return;
      setState(() {
        _totalKm = srvKm;
      });
    } catch (_) {
      // 조용히 무시
    }
  }

  Future<void> _openEditSheet() async {
    final result = await showModalBottomSheet<_EditProfileResult>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54, // ✅ 어두운 영역 표시
      builder: (ctx) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Navigator.of(ctx).pop(); // ✅ 어두운 영역 터치 시 닫기
          },
          child: GestureDetector(
            onTap: () {}, // ✅ 시트 내부 터치 시 닫히지 않도록
            child: EditProfileSheet(
              initialIntro: _introText,
              initialImage: _pickedImage,
              initialNetworkImage: _profileImageUrl,
            ),
          ),
        );
      },
    );

    if (result == null) return;

    try {
      // ── 1) 한줄소개 처리
      if (result.intro != null) {
        final newIntro = result.intro!.trim();

        if (newIntro.isEmpty) {
          await clearIntroOnServer();
          _introText = kIntroPlaceholderText;
        } else if (newIntro != _introText.trim()) {
          await updateIntroOnServer(newIntro);
          _introText = newIntro;
        }
      }

      // ── 2) 프로필 이미지 처리
      if (result.image != null) {
        final url = await uploadProfileImage(File(result.image!.path));
        _profileImageUrl = withCacheBust(url);
        _pickedImage = null;
      }

      setState(() {});

      if (!mounted) return;
      showTripriderPopup(
        context,
        title: '완료',
        message: '프로필이 업데이트됐어요.',
        type: PopupType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showTripriderPopup(
        context,
        title: '업데이트 실패',
        message: '$e',
        type: PopupType.error,
      );
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
      // ✔ AppBar 제거: 스크롤 시 닉네임/편집 아이콘이 고정되지 않도록
      backgroundColor: Colors.white,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            MyPage_top(
              titleText: _loading ? '...' : _nickname, // ✔ 상단 카드 내부에 제목/아이콘 배치
              onEditPressed: _openEditSheet,
              imageProvider: _buildProfileImageProvider(),
              intro: _introText,
              totalKm: _totalKm, // ✅ 전달
              lapKm: _lapKm, // ✅ 240km
            ),
            const SizedBox(height: 16),
            const MyPage_Bottom(),
          ],
        ),
      ),
      bottomNavigationBar: const BottomAppBarWidget(currentIndex: 4),
    );
  }
}

/// =========================
/// (참고) 기존 AppBar 클래스를 남겨두지만, 지금은 사용하지 않음
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
      title: Text(titleText, style: const TextStyle(color: Colors.white)),
      actions: [
        IconButton(
          onPressed: onEditPressed,
          icon: const Icon(
            Icons.drive_file_rename_outline,
            size: 30,
            color: Colors.white,
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

  // ✅ 추가: 누적 km & 한바퀴 km
  final double totalKm;
  final double lapKm;

  // ✔ 추가: 상단 좌측 닉네임 + 우측 편집 버튼을 카드 내부에 배치
  final String titleText;
  final VoidCallback onEditPressed;

  const MyPage_top({
    super.key,
    required this.imageProvider,
    required this.intro,
    required this.totalKm,
    required this.lapKm,
    required this.titleText,
    required this.onEditPressed,
  });

  @override
  Widget build(BuildContext context) {
    final wheels = (lapKm > 0) ? (totalKm / lapKm) : 0.0; // 예: 2.3
    final wheelText = wheels.isFinite ? wheels.toStringAsFixed(1) : '-';
    final progress = (wheels - wheels.floor()).clamp(0.0, 1.0); // 0~1
    final remainKm = ((1 - progress) * lapKm).clamp(0.0, lapKm);
    final nextLap = wheels.floor() + 1;
    final distText = '${totalKm.toStringAsFixed(0)} km';

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
          colors: [Color(0xFFFFA6B5), Color(0xFFFF4E6B), Color(0xFFFA2A55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✔ AppBar 대체 헤더(스크롤 시 함께 사라짐)
          Row(
            children: [
              Expanded(
                child: Text(
                  titleText,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                onPressed: onEditPressed,
                icon: const Icon(Icons.drive_file_rename_outline, size: 26, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: '프로필 편집',
              ),
            ],
          ),
          const SizedBox(height: 8),

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
                  children: [
                    const Text('제주도',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          wheelText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('바퀴',
                            style: TextStyle(color: Colors.white, fontSize: 16)),
                        const Spacer(),
                        Text('누적거리 $distText',
                            style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${nextLap}바퀴까지 ${remainKm.ceil()} km 남음',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
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
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w400,
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
        _buildMenuItem(context, '주행 기록', destinationPage: const RecordScreen()),
        _buildMenuItem(context, '좋아요 누른 코스', destinationPage: const SaveCourseScreen()),
        _buildMenuItem(context, '나의 게시물', destinationPage: const MyUploadScreen()),
        _buildMenuItem(context, '개인정보처리방침', destinationPage: const PrivacyPolicyScreen()),
        _buildMenuItem(context, '이용약관', destinationPage: const TermsOfServiceScreen()),
        _buildMenuItem(context, '로그아웃', destinationPage: const LogoutScreen()),
        _buildMenuItem(
          context,
          '회원탈퇴',
          onTap: () => _showDeleteDialog(context),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
      BuildContext context,
      String title, {
        Widget? destinationPage,
        VoidCallback? onTap,
      }) {
    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          onTap();
        } else if (destinationPage != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => destinationPage),
          );
        }
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
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            const Icon(Icons.arrow_forward_ios, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '회원탈퇴',
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, anim1, anim2) {
        return Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(color: Colors.black.withOpacity(0.25)),
              ),
            ),
            const Center(child: DeleteAccountDialog()),
          ],
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: .95, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 180),
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

    final initialText =
    (widget.initialIntro.trim() == kIntroPlaceholderText) ? '' : widget.initialIntro;
    _controller = TextEditingController(text: initialText);
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
                          onTap: _pickImage,
                          child: Container(
                            width: 36,
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
