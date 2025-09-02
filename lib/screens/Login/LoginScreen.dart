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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 이메일 / 비밀번호 입력
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
            const SizedBox(height: 30),

            // 로그인 버튼
            LoginScreenButton(
              T: 15,
              B: 15,
              L: 0,
              R: 0,
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

            const SizedBox(height: 40),

            // 구분선
            const _Or(),
            const SizedBox(height: 30),

            // 소셜 로그인 버튼들 (아래쪽에 배치)
            GestureDetector(
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
            const SizedBox(height: 16),
            GestureDetector(
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
      _showErrorDialog('입력 오류', '이메일과 비밀번호를 입력하세요.');
      return;
    }

    try {
      final res = await http.post(
        Uri.parse('http://10.0.2.2:8080/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      await _handleAuthResponse(res);
    } catch (e) {
      _showErrorDialog('네트워크 오류', '서버와 연결할 수 없습니다.\n$e');
    }
  }

  // =================== 카카오 로그인 ===================
  Future<void> _loginWithKakao() async {
    try {
      OAuthToken token;

      if (await isKakaoTalkInstalled()) {
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }

      final accessToken = token.accessToken;
      if (accessToken.isEmpty) {
        _showSnackBar('카카오 access token을 가져올 수 없습니다.');
        return;
      }

      final res = await http.post(
        Uri.parse('http://10.0.2.2:8080/api/auth/kakao'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'accessToken': accessToken}),
      );
      await _handleAuthResponse(res);
    } catch (e) {
      _showSnackBar('카카오 로그인 오류: $e');
    }
  }

  // =================== 구글 로그인 ===================
  Future<void> _loginWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      if (accessToken == null) {
        _showSnackBar('Google access token을 가져올 수 없습니다.');
        return;
      }

      final res = await http.post(
        Uri.parse('http://10.0.2.2:8080/api/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'accessToken': accessToken}),
      );
      await _handleAuthResponse(res);
    } catch (e) {
      _showSnackBar('구글 로그인 오류: $e');
    }
  }

  // =================== 공통 응답 처리 ===================
  Future<void> _handleAuthResponse(http.Response res) async {
    if (!mounted) return;

    if (res.statusCode != 200) {
      _showSnackBar('로그인 실패: ${res.statusCode}\n${res.body}');
      return;
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final token = (data['token'] ?? '') as String;
    final needNickname = (data['needNickname'] ?? false) as bool;
    final isNewUser = (data['isNewUser'] ?? false) as bool;
    final nickname = (data['nickname'] ?? '') as String;

    if (token.isEmpty) {
      _showSnackBar('토큰이 비어있습니다.');
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
      _goHome();
    }
  }

  Future<void> _goHome() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('nickname')?.trim();
    final display = (raw != null && raw.isNotEmpty) ? raw : '라이더';

    _showSnackBar('$display님, 오늘도 안전 라이딩 하세요!');
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const Homescreen()));
  }

  // =================== 공용 UI helpers ===================
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          TextField(
            controller: controller,
            obscureText: obscure,
            style: const TextStyle(fontSize: 18),
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
    return const Row(
      children: [
        Expanded(child: Divider(thickness: 1.5, color: Colors.black, endIndent: 12)),
        Text("or", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        Expanded(child: Divider(thickness: 1.5, color: Colors.black, indent: 12)),
      ],
    );
  }
}
