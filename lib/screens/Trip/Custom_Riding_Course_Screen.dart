// lib/screens/trip/Custom_Riding_Course.dart
import 'package:flutter/material.dart';
import 'package:triprider/screens/Trip/widgets/My_Course_Card.dart';
import 'package:triprider/screens/trip/Custom_Choice_Screen.dart';

class CustomRidingCourse extends StatefulWidget {
  const CustomRidingCourse({
    super.key,
    this.asPage = false,
    this.title = '맞춤형 여행 코스',
  });

  /// true이면 Scaffold(AppBar 포함)로 감싸 단독 화면처럼 사용
  final bool asPage;
  final String title;

  @override
  State<CustomRidingCourse> createState() => _CustomRiding_Course_State();
}

class _CustomRiding_Course_State extends State<CustomRidingCourse> {
  Key _listKey = UniqueKey();

  void _onCreateCoursePressed() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CustomChoiceScreen()),
    );
  }

  Future<void> _refresh() async {
    setState(() => _listKey = UniqueKey());
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  Widget _contentCore({required bool scrollable}) {
    // scrollable=false (섹션용) : Column만, 리스트는 shrinkWrap + NeverScrollable
    final inner = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          MyCourseCardList(
            key: _listKey,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );

    if (!scrollable) return inner;

    // scrollable=true (단독 페이지) : RefreshIndicator + SingleChildScrollView
    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: inner,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asPage) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          scrolledUnderElevation: 0,             // ✅ 스크롤 시 색상 틴트 제거
          surfaceTintColor: Colors.transparent,  // ✅ 머터리얼3 자동 틴트 제거
          title: Text(widget.title),
          centerTitle: true,
        ),
        body: SafeArea(bottom: false, child: _contentCore(scrollable: true)),
      );
    }

    // 탭/섹션 내부
    return Container(
      color: Colors.white,
      child: _contentCore(scrollable: false),
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
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                      TextSpan(text: '나의 취향을 담은 ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      TextSpan(
                        text: '여행 코스',
                        style: TextStyle(color: Color(0XFFFF4E6B), fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: '를 생성해보세요', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
