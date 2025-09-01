// lib/screens/trip/Custom_Riding_Course.dart
import 'package:flutter/material.dart';
import 'package:triprider/screens/Trip/widgets/My_Course_Card.dart';
import 'package:triprider/screens/trip/Custom_Choice_Screen.dart';

/// 맞춤형 코스 영역
/// - 탭 안의 섹션으로도, 단독 페이지로도 사용할 수 있게 asPage 옵션 제공
class CustomRidingCourse extends StatefulWidget {
  const CustomRidingCourse({super.key, this.asPage = false, this.title = '맞춤형 여행 코스'});

  /// true이면 Scaffold(AppBar 포함)로 감싸 단독 화면처럼 사용
  final bool asPage;

  /// asPage=true일 때 앱바 타이틀
  final String title;

  @override
  State<CustomRidingCourse> createState() => _CustomRiding_Course_State();
}

class _CustomRiding_Course_State extends State<CustomRidingCourse> {
  /// MyCourseCardList를 강제로 재구성하기 위한 키 (Pull-to-refresh 용)
  Key _listKey = UniqueKey();

  void _onCreateCoursePressed() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CustomChoiceScreen()),
    );
  }

  Future<void> _refresh() async {
    // 간단한 재구성으로 MyCourseCardList가 initState부터 다시 로드되게 함
    setState(() => _listKey = UniqueKey());
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  @override
  Widget build(BuildContext context) {
    final content = SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // 저장된 코스 카드 목록
                MyCourseCardList(
                  key: _listKey,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.asPage) {
      // 단독 화면으로 쓰일 때
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(widget.title),
          centerTitle: true,
        ),
        body: content,
      );
    }

    // 탭/섹션 내부에 포함될 때
    return Container(
      color: Colors.white,
      child: content,
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
                      TextSpan(
                          text: '나의 취향을 담은 ',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      TextSpan(
                          text: '여행 코스',
                          style: TextStyle(
                              color: Color(0XFFFF4E6B),
                              fontSize: 20,
                              fontWeight: FontWeight.w600)),
                      TextSpan(
                          text: '를 생성해보세요',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
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
