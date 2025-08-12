import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:triprider/screens/Trip/widgets/D_Course_Card.dart';
import 'package:triprider/screens/home/HomeScreen.dart';
import 'package:triprider/screens/trip/Custom_Riding_Course_Screen.dart';
import 'package:triprider/screens/trip/widgets/P_Course_Card.dart';
import 'package:triprider/widgets/Bottom_App_Bar.dart';

class RidingCourse extends StatefulWidget {
  const RidingCourse({super.key});

  @override
  State<RidingCourse> createState() => _RidingCourseState();
}

class _RidingCourseState extends State<RidingCourse> {
  int selectedIndex = 0; // 0: 라이딩 코스, 1: 맞춤형 여행 코스

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          '라이딩 코스 추천',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
        ),
      ),

      body: ListView(
        children: [
          Column(
            children: [
              // 선택 섹션
              Select_Section(
                selectedIndex: selectedIndex,
                onSelect: (index) {
                  setState(() => selectedIndex = index);

                  // 나중에 화면 전환 로직 넣기
                  if (index == 1) {
                    // Navigator.push(...);
                  }
                },
              ),

              const SizedBox(height: 30),

              // 선택된 탭에 따라 내용 표시
              if (selectedIndex == 0) ...[
                // 라이딩 코스 화면
                const Padding(
                  padding: EdgeInsets.only(right: 300, bottom: 30, top: 20),
                  child: Text(
                    '인기코스',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
                  ),
                ),

                ///인기코스 화면
                Center(
                  child: Popular_Course(favorite_Pressed: Favorite_Pressed),
                ),

                ///거리순 화면
                Distance_Course(
                  represh_Pressed: Refresh_Pressed,
                  course_Pressed: Course_Pressed,
                  favorite_Pressed: Favorite_Pressed,
                ),
              ] else ...[
                CustomRidingCourse(),
              ],
            ],
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBarWidget(),
    );
  }

  // 기존 콜백 그대로 유지
  static void Favorite_Pressed() {}
  static void Course_Pressed() {}
  static void Refresh_Pressed() {}
}

/// 라이딩 코스 or 맞춤형 여행 코스
class Select_Section extends StatelessWidget {
  final int selectedIndex; // 현재 선택된 버튼
  final ValueChanged<int> onSelect; // 선택 시 부모에게 알림

  const Select_Section({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 라이딩 코스 버튼 (index 0)
            TextButton(
              onPressed: () => onSelect(0),
              child: Text(
                '라이딩 코스',
                style: TextStyle(
                  fontSize: 20,
                  color: selectedIndex == 0 ? Colors.pink : Colors.black,
                ),
              ),
            ),

            const SizedBox(width: 50),

            // 맞춤형 여행 코스 버튼 (index 1)
            TextButton(
              onPressed: () => onSelect(1),
              child: Text(
                '맞춤형 여행 코스',
                style: TextStyle(
                  fontSize: 20,
                  color: selectedIndex == 1 ? Colors.pink : Colors.black,
                ),
              ),
            ),
          ],
        ),

        // 밑줄 표시
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 2,
              color: selectedIndex == 0 ? Colors.pink : Colors.transparent,
            ),
            const SizedBox(width: 50),
            Container(
              width: 160,
              height: 2,
              color: selectedIndex == 1 ? Colors.pink : Colors.transparent,
            ),
          ],
        ),
      ],
    );
  }
}

/// 인기 코스
class Popular_Course extends StatefulWidget {
  final VoidCallback favorite_Pressed;

  const Popular_Course({super.key, required this.favorite_Pressed});

  @override
  State<Popular_Course> createState() => _Popular_CourseState();
}

class _Popular_CourseState extends State<Popular_Course> {
  late PageController _pageController;
  int _currentPage = 1000;
  final int _totalPages = 2;

  late final Timer _timer;

  // 🔹 이미지 경로 리스트
  final List<String> imagePaths = [
    'assets/image/courseview1.png',
    'assets/image/courseview2.png',
  ];

  // 🔹 좋아요 상태 배열
  List<bool> isFavoriteList = [false, false];
  List<int> likeCounts = [0, 0];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);

    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (!mounted) return;
      setState(() {
        _currentPage++;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          _currentPage = index;
        },
        itemBuilder: (context, index) {
          final realIndex = index % _totalPages;
          final isFav = isFavoriteList[realIndex];
          final likes = likeCounts[realIndex];

          return P_CourseCard(
            imagePath: imagePaths[realIndex], // 🔹 경로만 다르게
            isFavorite: isFav,
            likeCount: likes,
            favorite_Pressed: () {
              setState(() {
                isFavoriteList[realIndex] = !isFav;
                likeCounts[realIndex] += isFav ? -1 : 1;
              });
              widget.favorite_Pressed();
            },
          );
        },
      ),
    );
  }
}

class Distance_Course extends StatelessWidget {
  final VoidCallback represh_Pressed;
  final VoidCallback course_Pressed;
  final VoidCallback favorite_Pressed;

  const Distance_Course({
    super.key,
    required this.course_Pressed,
    required this.represh_Pressed,
    required this.favorite_Pressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 15, top: 25),
          child: Row(
            children: [
              Text(
                '거리순',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
              ),

              IconButton(onPressed: represh_Pressed, icon: Icon(Icons.refresh)),
            ],
          ),
        ),

        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,

              children: [
                DCourseCard(
                  favorite_Pressed: favorite_Pressed,
                  course_Pressed: course_Pressed,
                ),

                DCourseCard(
                  favorite_Pressed: favorite_Pressed,
                  course_Pressed: course_Pressed,
                ),
              ],
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,

              children: [
                DCourseCard(
                  favorite_Pressed: favorite_Pressed,
                  course_Pressed: course_Pressed,
                ),

                DCourseCard(
                  favorite_Pressed: favorite_Pressed,
                  course_Pressed: course_Pressed,
                ),
              ],
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,

              children: [
                DCourseCard(
                  favorite_Pressed: favorite_Pressed,
                  course_Pressed: course_Pressed,
                ),

                DCourseCard(
                  favorite_Pressed: favorite_Pressed,
                  course_Pressed: course_Pressed,
                ),
              ],
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,

              children: [
                DCourseCard(
                  favorite_Pressed: favorite_Pressed,
                  course_Pressed: course_Pressed,
                ),

                DCourseCard(
                  favorite_Pressed: favorite_Pressed,
                  course_Pressed: course_Pressed,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
