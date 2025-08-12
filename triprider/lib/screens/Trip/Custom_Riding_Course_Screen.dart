import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:triprider/screens/trip/Custom_Choice_Screen.dart';
import 'package:triprider/screens/trip/widgets/My_Course_Card.dart';

class CustomRidingCourse extends StatefulWidget {
  const CustomRidingCourse({super.key});

  @override
  State<CustomRidingCourse> createState() => _CustomRidingCourseState();
}

class _CustomRidingCourseState extends State<CustomRidingCourse> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15), // 전체 좌우 패딩 통일
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 상단 "나의 취향을 담은 여행 코스" 버튼
          Create_Course_Button(custom_course_pressed: Custom_Course_Pressed),

          const SizedBox(height: 50),

          /// "여행 코스" 제목
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Text(
              '여행 코스',
              style: TextStyle(
                color: Colors.black,
                fontSize: 23,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          /// 나의 여행 코스 카드
          MyCourseCard(),
          MyCourseCard(),
          MyCourseCard(),
        ],
      ),
    );
  }

  void Custom_Course_Pressed() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) {
          return CustomChoiceScreen();
        },
      ),
    );
  }
}

///'나의 취향을 담은 여행코스 생성' 버튼
class Create_Course_Button extends StatelessWidget {
  final VoidCallback custom_course_pressed;

  const Create_Course_Button({super.key, required this.custom_course_pressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: custom_course_pressed,
        borderRadius: BorderRadius.circular(8),
        splashColor: Colors.black12,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              const Text(
                '나의 취향을 담은 ',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                '여행 코스',
                style: TextStyle(
                  color: Color(0XFFFF4E6B),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                '를 생성해보세요',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: Colors.black,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
