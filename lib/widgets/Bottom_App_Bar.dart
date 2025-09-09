//Bottom_App_Bar.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:triprider/screens/Map/KakaoMapScreen.dart';
import 'package:triprider/screens/MyPage/Mypage_Screen.dart';
import 'package:triprider/screens/RiderGram/RiderGram_Screen.dart';
import 'package:triprider/screens/home/HomeScreen.dart';
import 'package:triprider/screens/trip/Riding_Course_Screen.dart';

class BottomAppBarWidget extends StatelessWidget {
  final int currentIndex;
  const BottomAppBarWidget({super.key, required this.currentIndex});

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;
    Widget page;

    switch (index) {
      case 0:
        page = Homescreen();
        break;
      case 1:
        page = KakaoMapScreen();
        break;
      case 2:
        page = RidingCourse();
        break;
      case 3:
        page = RidergramScreen();
        break;
      case 4:
        page = MypageScreen();
        break;
      default:
        return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color active = Color(0xFFFF4E6B);
    const Color inactive = Color(0x40000000);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Builder(
          builder: (context) => Container(
            height: 1 / MediaQuery.of(context).devicePixelRatio,
            color: const Color(0x0A000000),
          ),
        ),
        BottomAppBar(
          color: const Color(0xB3FFFFFF),
          surfaceTintColor: Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                onPressed: () => _onItemTapped(context, 0),
                icon: Icon(Icons.home_rounded, size: 32, color: currentIndex == 0 ? active : inactive),
              ),
              IconButton(
                onPressed: () => _onItemTapped(context, 1),
                icon: Icon(Icons.location_on_rounded, size: 32, color: currentIndex == 1 ? active : inactive),
              ),
              IconButton(
                onPressed: () => _onItemTapped(context, 2),
                icon: Icon(Icons.map_rounded, size: 32, color: currentIndex == 2 ? active : inactive),
              ),
              IconButton(
                onPressed: () => _onItemTapped(context, 3),
                icon: Icon(Icons.chat_bubble_rounded, size: 32, color: currentIndex == 3 ? active : inactive),
              ),
              IconButton(
                onPressed: () => _onItemTapped(context, 4),
                icon: Icon(Icons.person, size: 32, color: currentIndex == 4 ? active : inactive),
              ),
            ],
          ),
        ),
      ],
    );
  }
}