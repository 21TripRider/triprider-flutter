import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:triprider/screens/Login/Email_Input_Screen.dart';
import 'package:triprider/screens/Login/LoginScreen.dart';
import 'package:triprider/screens/Login/widgets/Login_Screen_Button.dart';
// 약관 모달 추가
import 'package:triprider/screens/Login/widgets/Terms_Agreement_Model.dart';

class Welcomescreen extends StatefulWidget {
  const Welcomescreen({super.key});

  @override
  State<Welcomescreen> createState() => _WelcomescreenState();
}

class _WelcomescreenState extends State<Welcomescreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            const SizedBox(height: 120),
            const TripRider_logo(),
            const Spacer(),
            Login_Button(onPressed: Login_Pressed),
            const SizedBox(height: 20),
            Account_Button(onPressed: Account_Pressed),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void Login_Pressed() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) {
          return const Loginscreen();
        },
      ),
    );
  }

  // ✅ 회원가입 버튼 → 약관 모달 띄우기 → 동의 시 회원가입(EmailInputScreen)으로 이동
  void Account_Pressed() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TermsAgreementModal(
        email: '',             // 아직 이메일 입력 전이므로 빈 값
        originalPassword: '',  // 아직 비밀번호 입력 전이므로 빈 값
        onAgreed: (email, password, tos, privacy) async {
          if (!mounted) return;
          // 약관 모달은 내부에서 먼저 닫히므로 여기서 추가 pop 불필요
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EmailInputScreen()),
          );
        },
      ),
    );
  }
}

/// 첫 로고 화면
class TripRider_logo extends StatelessWidget {
  const TripRider_logo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: SizedBox(
            width: 300,
            height: 200,
            child: Image.asset(
              'assets/image/triprider_welcome.png',
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
          ),
        ),
        const SizedBox(height: 80),
        Column(
          children: const [
            Text(
              '트립라이더가 처음이신가요?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 10),
            Text('계정이 없으시다면', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            Text('앱서비스 이용을 위해 회원가입해주세요', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}

/// 로그인 버튼
class Login_Button extends StatelessWidget {
  final VoidCallback onPressed;

  const Login_Button({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return LoginScreenButton(
      T: 0,
      B: 0,
      L: 17,
      R: 17,
      child: const LoginButton_Child(),
      color: const Color(0XFFFF426B),
      onPressed: onPressed,
    );
  }
}

/// 회원가입 버튼
class Account_Button extends StatelessWidget {
  final VoidCallback onPressed;

  const Account_Button({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, left: 17, right: 17),
      child: SizedBox(
        width: double.infinity,
        height: 68,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
          onPressed: onPressed,
          child: const Text(
            '회원가입',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class loginButton_Child extends StatelessWidget {
  const loginButton_Child({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      '로그인',
      style: TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class LoginButton_Child extends StatelessWidget {
  const LoginButton_Child({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      '로그인',
      style: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
