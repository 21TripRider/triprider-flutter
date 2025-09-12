import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ⬅ 추가
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:triprider/screens/Home/HomeScreen.dart';
import 'package:triprider/screens/Login/LoginScreen.dart';
import 'package:triprider/screens/Login/WelcomeScreen.dart';
import 'package:triprider/state/rider_tracker_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  // ✅ 세로 고정
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown, // 필요 없으면 빼도 됨
  ]);

  KakaoSdk.init(
    nativeAppKey: '857552ba819176e757da967cea31fc13', // ✅ 네이티브 키만
  );

  // 앱 시작 시 주행 상태 복원(있다면 불러오기)
  await RideTrackerService.instance.tryRestore();


  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      fontFamily: 'Pretendard',
    ),
    home: Welcomescreen(),
  ));
}