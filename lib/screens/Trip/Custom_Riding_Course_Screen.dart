// lib/screens/trip/Custom_Riding_Course.dart
import 'package:flutter/material.dart';
import 'package:triprider/screens/Trip/widgets/My_Course_Card.dart';
import 'package:triprider/screens/trip/Custom_Choice_Screen.dart';

class CustomRidingCourse extends StatefulWidget {
  const CustomRidingCourse({super.key});
  @override
  State<CustomRidingCourse> createState() => _CustomRiding_Course_State();
}

class _CustomRiding_Course_State extends State<CustomRidingCourse> {
  void _onCreateCoursePressed() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CustomChoiceScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(   // ✅ Column을 스크롤 가능하게 감쌈
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CreateCourseButton(onTap: _onCreateCoursePressed),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                '여행 코스',
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 23,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const MyCourseCardList(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
            ),
          ],
        ),
      ),
    );
  }
}

class CreateCourseButton extends StatelessWidget {
  final VoidCallback onTap;
  const CreateCourseButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: Colors.black12,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  const TextSpan(
                    children: [
                      TextSpan(text: '나의 취향을 담은 ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      TextSpan(text: '여행 코스', style: TextStyle(color: Color(0XFFFF4E6B), fontSize: 20, fontWeight: FontWeight.w600)),
                      TextSpan(text: '를 생성해보세요', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
