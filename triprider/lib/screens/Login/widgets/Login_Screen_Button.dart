import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:triprider/screens/Login/LoginScreen.dart';


class LoginScreenButton extends StatefulWidget {
  final double T, B, L, R;
  final Widget child;
  final Color color;
  final VoidCallback onPressed;

  const LoginScreenButton({
    super.key,
    required this.T,
    required this.B,
    required this.L,
    required this.R,
    required this.child,
    required this.color,
    required this.onPressed,
  });

  @override
  State<LoginScreenButton> createState() => _LoginScreenButtonState();
}

class _LoginScreenButtonState extends State<LoginScreenButton> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: widget.T, bottom: widget.B, left: widget.L, right: widget.R),
      child: Container(
        width: double.infinity,
        height: 68,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: widget.color),
          onPressed: widget.onPressed,
          child: widget.child,
        ),
      ),
    );
  }
}