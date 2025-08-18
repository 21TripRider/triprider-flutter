import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:triprider/screens/Home/HomeScreen.dart';
import 'package:triprider/screens/Login/LoginScreen.dart';
import 'package:triprider/screens/Login/WelcomeScreen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  KakaoSdk.init(
    nativeAppKey: '857552ba819176e757da967cea31fc13', // ✅ 네이티브 키만
  );


  runApp(MaterialApp(home: Welcomescreen()));
}