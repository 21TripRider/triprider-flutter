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

  Future<void> _saveNickname() async {
    final nickname = _controller.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임을 입력해주세요.')),
      );
      return;
    }

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
        // 서버가 {"message":"OK","nickname":"설정값"} 형태로 내려줌
        String updatedNick = _controller.text.trim();
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body['nickname'] is String) {
            updatedNick = body['nickname'] as String;
          }
        } catch (_) {}

        // 닉네임 로컬에도 저장 (홈에서 환영 문구에 사용)
        await prefs.setString('nickname', updatedNick);

        // 개인화된 환영 메시지
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$updatedNick님, 오늘도 안전 라이딩 하세요!')),
        );

        // 홈으로 이동
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const Homescreen()),
              (route) => false,
        );
      } else if (res.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 사용중인 닉네임입니다.')),
        );
      } else if (res.statusCode == 400) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('닉네임 형식이 올바르지 않습니다.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: ${res.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
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
            onPressed: _clearText, // 우측 X 버튼 동작
          ),
          const Expanded(child: SizedBox()),
          LoginScreenButton(
            T: 0,
            B: 55,
            L: 17,
            R: 17,
            color: const Color(0XFFFF4E6B),
            // 방법 1: 래핑해서 void 콜백으로 전달
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
