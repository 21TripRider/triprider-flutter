// lib/screens/Login/Nickname_Input_Screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:triprider/screens/Login/LoginScreen.dart';
import 'package:triprider/screens/Login/widgets/Login_Screen_Button.dart';
import 'package:triprider/screens/Login/widgets/Next_Button_Widget_Child.dart';
import 'package:http/http.dart' as http;

Future<bool> registerUser(
    String email,
    String password,
    String nickname,
    ) async {
  final url = Uri.parse('https://trip-rider.com/api/auth/signup');
  final res = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password, 'nickname': nickname}),
  );
  return res.statusCode == 200;
}

class NicknameInputScreen extends StatefulWidget {
  final String email;
  final String originalPassword;

  const NicknameInputScreen({
    super.key,
    required this.email,
    required this.originalPassword,
  });

  @override
  State<NicknameInputScreen> createState() => _NicknameInputScreenState();
}

class _NicknameInputScreenState extends State<NicknameInputScreen> {
  final TextEditingController nicknameController = TextEditingController();

  @override
  void dispose() {
    nicknameController.dispose();
    super.dispose();
  }

  void _goBack() => Navigator.of(context).pop();
  void _clear() => nicknameController.clear();

  // ✅ 닉네임 규칙: 2–12자, 한글/영문/숫자만 (공백/특수문자 불가)
  final RegExp _nicknameReg = RegExp(r'^[a-zA-Z0-9가-힣]{2,12}$');

  Future<void> _next() async {
    final nickname = nicknameController.text.trim();

    if (nickname.isEmpty) {
      _showPopup('입력 오류', '닉네임을 입력해주세요.', type: PopupType.warn);
      return;
    }
    if (!_nicknameReg.hasMatch(nickname)) {
      _showPopup('입력 오류', '닉네임은 2–12자, 한글/영문/숫자만 사용할 수 있어요.', type: PopupType.warn);
      return;
    }

    final ok = await registerUser(widget.email, widget.originalPassword, nickname);
    if (!mounted) return;

    if (ok) {
      _showPopup('회원가입 완료', '가입이 완료되었습니다. 로그인해 주세요!', type: PopupType.success);
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const Loginscreen()),
            (route) => false,
      );
    } else {
      _showPopup('닉네임 중복', '이미 사용중인 닉네임입니다.', type: PopupType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        leading: IconButton(onPressed: _goBack, icon: const Icon(Icons.arrow_back_ios_new)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 35, left: 16, bottom: 25),
            child: Text('닉네임을 입력해주세요.', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 16, bottom: 10),
            child: Text('닉네임'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: nicknameController,
              builder: (_, value, __) => TextField(
                controller: nicknameController,
                textInputAction: TextInputAction.done,
                style: const TextStyle(fontSize: 20),
                onSubmitted: (_) => _next(),
                decoration: InputDecoration(
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: _clear,
                    icon: const Icon(Icons.close),
                  ),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black87, width: 2)),
                ),
              ),
            ),
          ),
          const Spacer(),
          LoginScreenButton(
            T: 0, B: 55, L: 17, R: 17,
            color: const Color(0XFFFF4E6B),
            child: const Next_Widget_Child(),
            onPressed: _next,
          ),
        ],
      ),
    );
  }

  // 로그인/확인 화면과 동일 팝업 헬퍼
  void _showPopup(String title, String message, {PopupType type = PopupType.info}) {
    showTripriderPopup(context, title: title, message: message, type: type);
  }
}

/// ===== 팝업(로그인 화면과 동일, 상단 고정) =====
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
    builder: (_) => SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 0, left: 16, right: 16,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              builder: (_, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(offset: Offset(0, (1 - t) * -8), child: child),
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 6))],
                    border: Border.all(color: const Color(0xFFE9E9EE)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.sports_motorsports_rounded, color: Colors.pink),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.black.withOpacity(0.9)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                      const SizedBox(height: 10),
                      Text(message, style: const TextStyle(fontSize: 14.5, height: 1.35, color: Colors.black87)),
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