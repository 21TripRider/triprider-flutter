import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:triprider/screens/Login/Email_Input_Screen.dart';
import 'package:triprider/screens/Login/Nickname_Input_Screen.dart';
import 'package:triprider/screens/Login/widgets/Login_Screen_Button.dart';
import 'package:triprider/screens/Login/widgets/Next_Button_Widget_Child.dart';

class ConfirmPasswordScreen extends StatefulWidget {
  final String email; // 이전 화면에서 전달받을 이메일
  final String originalPassword; // 이전 화면에서 전달받을 비밀번호
  const ConfirmPasswordScreen({
    super.key,
    required this.email,
    required this.originalPassword,
  });

  @override
  State<ConfirmPasswordScreen> createState() => _ConfirmPasswordScreenState();
}

class _ConfirmPasswordScreenState extends State<ConfirmPasswordScreen> {
  final TextEditingController confirmPasswordController =
  TextEditingController();

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
          _ConfirmPassword(
            onPressed: Close_Button_Pressed,
            controller: confirmPasswordController,
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

  Next_Button_Pressed() {
    if (confirmPasswordController.text.trim() != widget.originalPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("비밀번호가 일치하지 않습니다.")));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) {
          return NicknameInputScreen(
            email: widget.email,
            originalPassword: widget.originalPassword,
          );
        },
      ),
    );
  }
}

class _ConfirmPassword extends StatelessWidget {
  final VoidCallback onPressed;
  final TextEditingController controller;

  const _ConfirmPassword({
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
            '한번 더 입력해주세요.',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 10),
          child: Text('비밀번호 확인'),
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