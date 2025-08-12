import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:triprider/screens/Login/Email_Input_Screen.dart';
import 'package:triprider/screens/Login/Confirm_Password_Screen.dart';
import 'package:triprider/screens/Login/widgets/Login_Screen_Button.dart';
import 'package:triprider/screens/Login/widgets/Next_Button_Widget_Child.dart';

class PasswordInputScreen extends StatefulWidget {
  final String email; // 이전 화면에서 전달받을 이메일
  const PasswordInputScreen({super.key,required this.email});

  @override
  State<PasswordInputScreen> createState() => _PasswordInputScreenState();
}

class _PasswordInputScreenState extends State<PasswordInputScreen> {
  final TextEditingController passwordController = TextEditingController();

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InputPassword(
            onPressed: Close_Button_Pressed,
            controller: passwordController,
          ),

          _PasswordCondition(controller: passwordController),

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
    String password = passwordController.text.trim();

    ///비밀번호 조건
    bool isValidPassword(String password) {
      final bool hasMinLength = password.length >= 10;
      final bool hasLowercase = password.contains(RegExp(r'[a-z]'));
      final bool hasNumber = password.contains(RegExp(r'[0-9]'));
      final bool hasSpecialChar = password.contains(
        RegExp(r'[!@#\$%^&*(),.?":{}|<>]'),
      );

      return hasMinLength && hasLowercase && hasNumber && hasSpecialChar;
    }

    if (!isValidPassword(password)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("유효한 비밀번호 형식을 입력해주세요.")));
      return; //
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) {
          return ConfirmPasswordScreen(
            email: widget.email,
            originalPassword: passwordController.text.trim(),
          );
        },
      ),
    );
  }
}

class _InputPassword extends StatelessWidget {
  final VoidCallback onPressed;
  final TextEditingController controller;

  const _InputPassword({
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
            '비밀번호를 입력해주세요.',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 10),
          child: Text('비밀번호'),
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

class _PasswordCondition extends StatefulWidget {
  final TextEditingController controller;
  const _PasswordCondition({super.key, required this.controller});

  @override
  State<_PasswordCondition> createState() => _PasswordConditionState();
}

class _PasswordConditionState extends State<_PasswordCondition> {
  bool hasMinLength = false;
  bool hasLowercase = false;
  bool hasNumber = false;
  bool hasSpecialChar = false;

  void _validatePassword() {
    final password = widget.controller.text;

    setState(() {
      hasMinLength = password.length >= 10;
      hasLowercase = RegExp(r'[a-z]').hasMatch(password);
      hasNumber = RegExp(r'[0-9]').hasMatch(password);
      hasSpecialChar = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password);
    });
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_validatePassword);
  }

  ///메모리 누수 방지
  @override
  void dispose() {
    widget.controller.removeListener(_validatePassword);
    super.dispose();
  }

  Widget _buildCheckRow(bool condition, String text) {
    return Row(
      children: [
        Icon(
          condition ? Icons.check_circle : Icons.check_circle_outline,
          color: condition ? Colors.green : Colors.black,
        ),
        SizedBox(width: 8),
        Text(text),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 20),
      child: Column(
        children: [
          _buildCheckRow(hasMinLength, '10자리 이상'),
          _buildCheckRow(hasLowercase, '영어 소문자'),
          _buildCheckRow(hasNumber, '숫자'),
          _buildCheckRow(hasSpecialChar, '특수문자'),
        ],
      ),
    );
  }
}