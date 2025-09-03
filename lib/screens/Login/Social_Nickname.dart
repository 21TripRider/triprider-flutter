// lib/screens/Login/Social_Nickname.dart
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:triprider/screens/home/HomeScreen.dart';
import 'package:triprider/screens/Login/widgets/Login_Screen_Button.dart';
import 'package:triprider/screens/Login/widgets/Next_Button_Widget_Child.dart';

class SocialNickname extends StatefulWidget {
  const SocialNickname({super.key});

  @override
  State<SocialNickname> createState() => _SocialNicknameState();
}

class _SocialNicknameState extends State<SocialNickname> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;

  // ✅ 닉네임 규칙: 2–12자, 한글/영문/숫자만
  final RegExp _nicknameReg = RegExp(r'^[a-zA-Z0-9가-힣]{2,12}$');

  Future<void> _saveNickname() async {
    final nickname = _controller.text.trim();

    // === 닉네임 검증 (닉네임 입력 화면과 동일 문구) ===
    if (nickname.isEmpty) {
      _showPopup('입력 오류', '닉네임을 입력해주세요.', type: PopupType.warn);
      return;
    }
    if (!_nicknameReg.hasMatch(nickname)) {
      _showPopup('입력 오류', '닉네임은 2–12자, 한글/영문/숫자만 사용할 수 있어요.', type: PopupType.warn);
      return;
    }

    if (_loading) return;
    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final jwt = prefs.getString('jwt') ?? '';

      final res = await http.patch(
        Uri.parse('http://10.0.2.2:8080/api/users/me/nickname'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({'nickname': nickname}),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        String updatedNick = nickname;
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body['nickname'] is String) {
            updatedNick = body['nickname'] as String;
          }
        } catch (_) {}

        await prefs.setString('nickname', updatedNick);

        // 성공 팝업
        _showPopup('설정 완료', '$updatedNick 님, 닉네임이 저장되었습니다.', type: PopupType.success);
        await Future.delayed(const Duration(milliseconds: 450));
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const Homescreen()),
              (route) => false,
        );
      } else if (res.statusCode == 409) {
        _showPopup('입력 오류', '이미 사용중인 닉네임입니다.', type: PopupType.warn);
      } else if (res.statusCode == 400) {
        _showPopup('입력 오류', '닉네임은 2–12자, 한글/영문/숫자만 사용할 수 있어요.', type: PopupType.warn);
      } else {
        _showPopup('저장 실패', '저장 실패: ${res.statusCode}', type: PopupType.error);
      }
    } catch (e) {
      if (mounted) {
        _showPopup('오류', '오류: $e', type: PopupType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearText() => _controller.clear();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
      ),
      body: Column(
        children: [
          _ConfirmNickname(
            controller: _controller,
            onPressed: _clearText,
          ),
          const Expanded(child: SizedBox()),
          LoginScreenButton(
            T: 0,
            B: 55,
            L: 17,
            R: 17,
            color: const Color(0XFFFF4E6B),
            onPressed: () {
              if (_loading) return;
              _saveNickname();
            },
            child: Next_Widget_Child(),
          ),
        ],
      ),
    );
  }

  // ===== 팝업 헬퍼 =====
  void _showPopup(String title, String message, {PopupType type = PopupType.info}) {
    showTripriderPopup(context, title: title, message: message, type: type);
  }
}

class _ConfirmNickname extends StatelessWidget {
  final VoidCallback onPressed;
  final TextEditingController controller;

  const _ConfirmNickname({
    super.key,
    required this.onPressed,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 35, left: 16, bottom: 25),
          child: Text(
            '닉네임을 입력해주세요.',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 16, bottom: 10),
          child: Text('닉네임'),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20),
          child: TextField(
            controller: controller,
            style: const TextStyle(fontSize: 20),
            decoration: InputDecoration(
              suffixIcon: IconButton(
                padding: EdgeInsets.zero,
                onPressed: onPressed,
                icon: const Icon(Icons.close),
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.black87, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
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