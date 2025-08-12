import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:triprider/screens/Login/widgets/Login_Screen_Button.dart';

class Next_Widget_Child extends StatelessWidget {


  const Next_Widget_Child({super.key,});

  @override
  Widget build(BuildContext context) {
    return Text(
      '다음',
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Colors.white,

      ),
    );
  }
}