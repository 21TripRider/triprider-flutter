import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:triprider/screens/Login/Social_Nickname.dart';
import 'package:triprider/screens/home/HomeScreen.dart';
import 'package:triprider/screens/Login/widgets/Login_Screen_Button.dart';

class Loginscreen extends StatefulWidget {
  const Loginscreen({super.key});

  @override
  State<Loginscreen> createState() => _LoginscreenState();
}

class _LoginscreenState extends State<Loginscreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // =================== UI ===================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          '로그인',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InputField(
              label: "이메일 주소",
              controller: emailController,
              onClear: () => emailController.clear(),
            ),
            _InputField(
              label: "비밀번호",
              controller: passwordController,
              onClear: () => passwordController.clear(),
              obscure: true,
            ),
            LoginScreenButton(
              T: 20,
              B: 80,
              L: 17,
              R: 17,
              color: const Color(0XFFFF4E6B),
              onPressed: _loginWithEmail,
              child: const Text(
                '로그인',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const _Or(),
            const SizedBox(height: 30),
            // 소셜 로그인 버튼들 (아래쪽에 배치)
            Padding(
              padding: const EdgeInsets.only(left: 20,right: 20),
              child: GestureDetector(
                onTap: _loginWithKakao,
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE500), // 카카오 노란색
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/image/kakao_login.png', height: 50),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 20,right: 20),
              child: GestureDetector(
                onTap: _loginWithGoogle,
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F2), // 구글 버튼 배경
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/image/google_login.png', height: 50),
                        const SizedBox(width: 12),
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
  }

  // =================== 이메일 로그인 ===================
  Future<void> _loginWithEmail() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showPopup('입력 오류', '이메일과 비밀번호를 입력하세요.', type: PopupType.warn);
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('https://trip-rider.com/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      await _handleAuthResponse(res);
    } catch (e) {
      _showPopup('네트워크 오류', '서버와 연결할 수 없습니다.\n$e', type: PopupType.error);
    }
  }

  // =================== 카카오 로그인 ===================
  Future<void> _loginWithKakao() async {
    try {
      OAuthToken token;

      if (await isKakaoTalkInstalled()) {
        try {
          token = await UserApi.instance.loginWithKakaoTalk();
        } on PlatformException catch (e) {
          if (e.code == 'CANCELED' || e.code == 'CANCELLED') return;
          rethrow;
        } on KakaoAuthException catch (e) {
          if (e.error == AuthErrorCause.accessDenied) return;
          rethrow;
        } on KakaoClientException catch (e) {
          if (e.reason == ClientErrorCause.cancelled) return;
          rethrow;
        }
      } else {
        try {
          token = await UserApi.instance.loginWithKakaoAccount();
        } on PlatformException catch (e) {
          if (e.code == 'CANCELED' || e.code == 'CANCELLED') return;
          rethrow;
        } on KakaoAuthException catch (e) {
          if (e.error == AuthErrorCause.accessDenied) return;
          rethrow;
        } on KakaoClientException catch (e) {
          if (e.reason == ClientErrorCause.cancelled) return;
          rethrow;
        }
      }

      final accessToken = token.accessToken;
      if (accessToken.isEmpty) {
        _showPopup('로그인 오류', '카카오 access token을 가져올 수 없습니다.', type: PopupType.error);
        return;
      }

      final res = await http.post(
        Uri.parse('https://trip-rider.com/api/auth/kakao'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'accessToken': accessToken}),
      );
      await _handleAuthResponse(res);
    } on KakaoAuthException catch (e) {
      if (e.error == AuthErrorCause.accessDenied) return;
      _showPopup('카카오 로그인 오류', '${e.error}', type: PopupType.error);
    } on KakaoClientException catch (e) {
      if (e.reason == ClientErrorCause.cancelled) return;
      _showPopup('카카오 로그인 오류', '${e.reason}', type: PopupType.error);
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED' || e.code == 'CANCELLED') return;
      _showPopup('카카오 로그인 오류', e.message ?? e.code, type: PopupType.error);
    } catch (e) {
      _showPopup('카카오 로그인 오류', '$e', type: PopupType.error);
    }
  }

  // =================== 구글 로그인 ===================
  Future<void> _loginWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      if (accessToken == null) {
        _showPopup('로그인 오류', 'Google access token을 가져올 수 없습니다.', type: PopupType.error);
        return;
      }

      final res = await http.post(
        Uri.parse('https://trip-rider.com/api/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'accessToken': accessToken}),
      );
      await _handleAuthResponse(res);
    } catch (e) {
      _showPopup('구글 로그인 오류', '$e', type: PopupType.error);
    }
  }

  // =================== 공통 응답 처리 ===================

  // 응답 본문에서 사람이 읽을 수 있는 메시지 추출
  String? _extractMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final v = decoded['message'] ?? decoded['error'] ?? decoded['detail'];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _handleAuthResponse(http.Response res) async {
    if (!mounted) return;

    // 성공
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = (data['token'] ?? '') as String;
      final needNickname = (data['needNickname'] ?? false) as bool;
      final isNewUser = (data['isNewUser'] ?? false) as bool;
      final nickname = (data['nickname'] ?? '') as String;

      if (token.isEmpty) {
        _showPopup('로그인 오류', '토큰이 비어있습니다.', type: PopupType.error);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt', token);
      await prefs.setString('nickname', nickname);

      if (isNewUser || needNickname) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SocialNickname()),
        );
      } else {
        await _goHome();
      }
      return;
    }

    // 실패: 사용자 친화 메시지 매핑
    String msg;
    switch (res.statusCode) {
      case 401:
      case 403:
        msg = '이메일 혹은 비밀번호가 잘못되었습니다.';
        break;
      case 400:
        msg = _extractMessage(res.body) ?? '요청 형식이 올바르지 않습니다.';
        break;
      case 429:
        msg = '요청이 너무 많아요. 잠시 후 다시 시도해 주세요.';
        break;
      case 500:
      case 502:
      case 503:
      case 504:
        msg = '서버 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.';
        break;
      default:
        msg = _extractMessage(res.body) ?? '로그인에 실패했어요. 잠시 후 다시 시도해 주세요.';
    }
    _showPopup('로그인 실패', msg, type: PopupType.error);
  }

  Future<void> _goHome() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('nickname')?.trim();
    final display = (raw != null && raw.isNotEmpty) ? raw : '라이더';

    _showPopup('환영합니다', '$display님, 오늘도 안전 라이딩 하세요!', type: PopupType.success);
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 400));
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const Homescreen()),
    );
  }

  // =================== 커스텀 팝업(중상단) ===================
  void _showPopup(String title, String message, {PopupType type = PopupType.info}) {
    showTripriderPopup(context, title: title, message: message, type: type);
  }
}

// =================== 재사용 위젯 ===================
class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onClear;
  final bool obscure;

  const _InputField({
    super.key,
    required this.label,
    required this.controller,
    required this.onClear,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          TextField(
            controller: controller,
            obscureText: obscure,
            style: const TextStyle(fontSize: 20),
            decoration: InputDecoration(
              suffixIcon: IconButton(
                icon: const Icon(Icons.close),
                onPressed: onClear,
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.black87, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Or extends StatelessWidget {
  const _Or({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          Expanded(child: Divider(thickness: 2, color: Colors.black, endIndent: 10)),
          Text("or", style: TextStyle(fontSize: 25)),
          Expanded(child: Divider(thickness: 2, color: Colors.black, indent: 10)),
        ],
      ),
    );
  }
}

class SocialLoginButton extends StatelessWidget {
  final Color color;
  final String assetPath;
  final String text;
  final Color textColor;
  final VoidCallback onPressed;

  const SocialLoginButton({
    super.key,
    required this.color,
    required this.assetPath,
    required this.text,
    required this.textColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return LoginScreenButton(
      T: 0,
      B: 30,
      L: 17,
      R: 17,
      color: color,
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(assetPath, height: 34, width: 34),
          const SizedBox(width: 20),
          Text(
            text,
            style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// =================== 커스텀 팝업 구현부 (수정본) ===================
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

  // 포인트 컬러 (아이콘에만 사용)
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
      accent = const Color(0xFFFF4E6B); // 브랜드 핑크 톤
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
          // 탭하면 닫힘
          // 중상단 위치 → 상단 고정
          Positioned(
            top: 0, // 상태바 아래 8px
            left: 16,
            right: 16,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              builder: (_, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * -8), // 위에서 살짝 내려오는 느낌
                  child: child,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  // ⛔ width는 이제 필요 없음 (left/right로 폭 지정됨)
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
                      // 헤더 (아이콘 + 제목)
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
                      // 카드 안 회색 구분선
                      const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                      const SizedBox(height: 10),
                      // 본문 메시지
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