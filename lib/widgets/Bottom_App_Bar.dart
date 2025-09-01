import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:triprider/screens/Map/KakaoMapScreen.dart';
import 'package:triprider/screens/MyPage/Mypage_Screen.dart';
import 'package:triprider/screens/RiderGram/RiderGram_Screen.dart';
import 'package:triprider/screens/home/HomeScreen.dart';
import 'package:triprider/screens/trip/Riding_Course_Screen.dart';

class BottomAppBarWidget extends StatelessWidget {
  const BottomAppBarWidget({super.key});

  void _onItemTapped(BuildContext context, int index) {
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
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            onPressed: () => _onItemTapped(context, 0),
            icon: Icon(Icons.home_filled, size: 40),
          ),
          IconButton(
            onPressed: () => _onItemTapped(context, 1),
            icon: Icon(Icons.gps_fixed, size: 40),
          ),
          IconButton(
            onPressed: () => _onItemTapped(context, 2),
            icon: Icon(Icons.motorcycle_sharp, size: 40),
          ),
          IconButton(
            onPressed: () => _onItemTapped(context, 3),
            icon: Icon(Icons.message, size: 40),
          ),
          IconButton(
            onPressed: () => _onItemTapped(context, 4),
            icon: Icon(Icons.person, size: 40),
          ),
        ],
      ),
    );
  }
}