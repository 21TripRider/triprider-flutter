import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:triprider/screens/Login/Email_Input_Screen.dart';
import 'package:triprider/screens/Login/LoginScreen.dart';
import 'package:triprider/screens/Login/widgets/Login_Screen_Button.dart';

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
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TripRider_logo(),

            SizedBox(height: 100),

            Login_Button(onPressed: Login_Pressed),

            SizedBox(height: 20),

            Account_Button(onPressed: Account_Pressed),
          ],
        ),
      ),
    );
  }

  Login_Pressed() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) {
          return Loginscreen();
        },
      ),
    );
  }

  Account_Pressed() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) {
          return EmailInputScreen();
        },
      ),
    );
  }
}

///첫 로고 화면
///첫 로고 화면
/// 첫 로고 화면 (좌측으로 살짝 시각 보정)
class TripRider_logo extends StatelessWidget {
  const TripRider_logo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Transform.translate(
            // ⬅️ 시각 중심 보정: 필요하면 -6 ~ -16 사이로 미세 조정
            offset: const Offset(-42, 0),
            child: SizedBox(
              width: 380,
              height: 380,
              child: SvgPicture.asset(
                'assets/image/triprider_logo_3D.svg',
                fit: BoxFit.contain,
                alignment: Alignment.center,
              ),
            ),
          ),
        ),

        Column(
          children: const [
            Text(
              '트립라이더가 처음이신가요?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 10),
            Text('계정이 없으시다면', textAlign: TextAlign.center),
            Text('앱서비스 이용을 위해 회원가입해주세요', textAlign: TextAlign.center),
          ],
        ),
      ],
    );
  }
}



///로그인 버튼
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
      child: LoginButton_Child(),
      color: Color(0XFFFF426B),
      onPressed: onPressed,
    );
  }
}

///회원가입 버튼
class Account_Button extends StatelessWidget {
  final VoidCallback onPressed;

  const Account_Button({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, left: 17, right: 17),
      child: Container(
        width: double.infinity,
        height: 68,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
          onPressed: onPressed,
          child: Text(
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
    return Text(
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
    return Text(
      '로그인',
      style: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}