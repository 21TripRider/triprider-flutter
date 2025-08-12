import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:triprider/screens/Login/Email_Input_Screen.dart';
import 'package:triprider/screens/Login/LoginScreen.dart';
import 'package:triprider/screens/Login/widgets/Login_Screen_Button.dart';
import 'package:triprider/screens/Login/widgets/Next_Button_Widget_Child.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;

Future<bool> registerUser(
    String email,
    String password,
    String nickname,
    ) async {
  final url = Uri.parse("http://10.0.2.2:8080/api/auth/signup"); // ← 실제 API 주소
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': email,
      'password': password,
      'nickname': nickname,
    }),
  );

  return response.statusCode == 200;
}

class NicknameInputScreen extends StatefulWidget {
  final String email; // 이전 화면에서 전달받을 이메일
  final String originalPassword; // 이전 화면에서 전달받을 비밀번호

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: Arrow_Back_ios_Pressed,
          icon: Icon(Icons.arrow_back_ios_new),
        ),
      ),

      body: Column(
        children: [
          _ConfirmNickname(
            onPressed: Close_Button_Pressed,
            controller: nicknameController,
          ),

          Expanded(child: SizedBox()),

          LoginScreenButton(
            T: 0,
            B: 55,
            L: 17,
            R: 17,
            child: Next_Widget_Child(),
            color: Color(0XFFFF4E6B),
            onPressed: Next_Button_Pressed,
          ),
        ],
      ),
    );
  }

  Close_Button_Pressed() {}

  Arrow_Back_ios_Pressed() {
    Navigator.of(context).pop();
  }

  Next_Button_Pressed() async {
    final nickname = nicknameController.text.trim();
    final email = widget.email;
    final password = widget.originalPassword;

    if (nickname.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("닉네임을 입력해주세요.")));
      return;
    }

    final success = await registerUser(email, password, nickname);

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (BuildContext context) {
            return Loginscreen();
          },
        ),
            (route) => false,
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("회원가입에 실패했습니다.")));
    }
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
        Padding(
          padding: const EdgeInsets.only(top: 35, left: 16, bottom: 25),
          child: Text(
            '닉네임을 입력해주세요.',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 10),
          child: Text('닉네임'),
        ),

        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20),
          child: TextField(
            controller: controller,
            style: TextStyle(fontSize: 20),
            decoration: InputDecoration(
              suffixIcon: Container(
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: onPressed,
                  icon: Icon(Icons.close),
                ),
              ),

              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
            ),
          ),
        ),
      ],
    );
  }
}