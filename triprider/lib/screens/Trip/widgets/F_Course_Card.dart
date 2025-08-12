import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FCourseCard extends StatefulWidget {
  final VoidCallback course_Pressed;
  final VoidCallback favorite_Pressed;

  const FCourseCard({
    super.key,
    required this.favorite_Pressed,
    required this.course_Pressed,
  });

  @override
  State<FCourseCard> createState() => _FCourseCard1State();
}

class _FCourseCard1State extends State<FCourseCard> {
  bool isFavorite = false; // 하트 상태

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Stack(
            children: [
              IconButton(
                onPressed: widget.course_Pressed,
                icon: Image.asset(
                  'assets/image/courseview1.png',
                  width: 195,
                  height: 195,
                ),
              ),

              Positioned(
                bottom: 16,
                left: 16,
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      isFavorite = !isFavorite;
                    });
                    widget.favorite_Pressed();
                  },
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.white,
                    size: 35,
                  ),
                ),
              ),
            ],
          ),
        ),

        const Padding(
          padding: EdgeInsets.only(right: 25.0),
          child: Text(
            '용담이호해안도로',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),

        const Text('제주 제주시 용담삼동 2571-2'),
      ],
    );
  }
}