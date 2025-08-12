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
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () {}, child: const Text('비밀번호 찾기')),
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
            SocialLoginButton(
              color: Colors.yellow,
              assetPath: 'assets/image/kakaotalk.png',
              text: '카카오로 로그인',
              textColor: Colors.black,
              onPressed: _loginWithKakao,
            ),
            SocialLoginButton(
              color: Colors.white,
              assetPath: 'assets/image/Google.png',
              text: 'Google로 로그인',
              textColor: Colors.black,
              onPressed: _loginWithGoogle,
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
      await _handleAuthResponse(res); // ← 서버의 needNickname 판단에 따름
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
      await _handleAuthResponse(res); // ← 서버의 needNickname 판단에 따름
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
      await _handleAuthResponse(res); // ← 서버의 needNickname 판단에 따름
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
    final nickname = (data['nickname'] ?? '') as String; // ⬅️ 추가

    if (token.isEmpty) {
      _showSnackBar('토큰이 비어있습니다.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt', token);
    await prefs.setString('nickname', nickname); // ⬅️ 추가 (기존 유저 환영 문구용)

    if (isNewUser || needNickname) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SocialNickname()),
      );
    } else {
      _goHome();
    }
  }

  Future<void> _goHome() async {
    // ⬅️ async로 변경
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('nickname')?.trim();
    final display = (raw != null && raw.isNotEmpty) ? raw : '라이더';

    _showSnackBar('$display님, 오늘도 안전 라이딩 하세요!'); // ⬅️ 개인화 인사
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const Homescreen()));
  }

  // =================== 공용 UI helpers ===================
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
          Expanded(
            child: Divider(thickness: 2, color: Colors.black, endIndent: 10),
          ),
          Text("or", style: TextStyle(fontSize: 25)),
          Expanded(
            child: Divider(thickness: 2, color: Colors.black, indent: 10),
          ),
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
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
