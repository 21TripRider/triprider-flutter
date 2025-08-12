import 'package:flutter/material.dart';
import 'package:triprider/widgets/Bottom_App_Bar.dart';

class CustomChoiceScreen extends StatefulWidget {
  const CustomChoiceScreen({super.key});

  @override
  State<CustomChoiceScreen> createState() => _CustomChoiceScreenState();
}

class _CustomChoiceScreenState extends State<CustomChoiceScreen> {
  List<String> selectedCategories = []; /// 모든 선택 상태를 부모에서 관리

  // 선택 토글 함수
  void toggleCategory(String category) {
    setState(() {
      if (selectedCategories.contains(category)) {
        selectedCategories.remove(category);
      } else {
        selectedCategories.add(category);
      }
    });
  }

  // 선택된 순서를 반환 (없으면 null)
  int? getOrder(String category) {
    final idx = selectedCategories.indexOf(category);
    return idx >= 0 ? idx + 1 : null;
  }

  // 버튼 위젯 생성
  Widget buildCategoryButton(String category) {
    final selected = selectedCategories.contains(category);
    final order = getOrder(category);

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? Colors.pink[50] : Colors.grey[200],
        foregroundColor: selected ? Colors.pink : Colors.black,
        minimumSize: const Size(70, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      onPressed: () => toggleCategory(category),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(category),
          if (order != null) ...[
            const SizedBox(width: 4),
            CircleAvatar(
              radius: 10,
              backgroundColor: Colors.pink[100],
              child: Text(
                '$order',
                style: const TextStyle(fontSize: 12, color: Colors.pink),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 관광 & 음식 카테고리
  final sightseeing = ['문화', '역사', '자연', '체험', '레저'];
  final food = ['한식', '중식', '일식', '양식', '시장', '디저트'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: 250,
            width: double.infinity,
            color: const Color(0XFFFFA6B5),
          ),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // 상단 안내 문구
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '원하는 카테고리를 선택하여\n맞춤형 여행 코스를 생성해보세요',
                          style: const TextStyle(
                            fontSize: 22,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 관광 카테고리
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '관광',
                        style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: sightseeing.map(buildCategoryButton).toList(),
                      ),
                    ],
                  ),
                ),

                // 음식 카테고리
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '음식',
                        style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: food.map(buildCategoryButton).toList(),
                      ),
                    ],
                  ),
                ),

                // 다음 버튼
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 17),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0XFFFF4E6B),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      debugPrint("최종 선택: $selectedCategories");
                      // TODO: 다음 페이지 이동
                    },
                    child: const Text(
                      '다음',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomAppBarWidget(),
    );
  }
}