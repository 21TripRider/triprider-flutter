import 'package:flutter/material.dart';

class BadgeStyleScreen extends StatefulWidget {
  const BadgeStyleScreen({super.key});

  @override
  State<BadgeStyleScreen> createState() => _BadgeStyleScreenState();
}

class _BadgeStyleScreenState extends State<BadgeStyleScreen> {
  int selectedIndex = 0; // 0: 뱃지, 1: 칭호

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // 투명 처리
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 28, color: Colors.white),
        ),
        centerTitle: true,
        title: const Text('', style: TextStyle(color: Colors.white)),
      ),
      body: Stack(
        children: [
          // 📌 전체 배경 그라데이션
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF7FA2),
                    Color(0xFFFF4D6D),
                  ],
                ),
              ),
            ),
          ),

          // 📌 메인 콘텐츠
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),

                  // 탭
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TabButton(
                        title: '뱃지',
                        isActive: selectedIndex == 0,
                        onTap: () => setState(() => selectedIndex = 0),
                      ),
                      const SizedBox(width: 36),
                      _TabButton(
                        title: '칭호',
                        isActive: selectedIndex == 1,
                        onTap: () => setState(() => selectedIndex = 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(top: 8, bottom: 24),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: selectedIndex == 0
                            ? _BadgeGrid(
                          items: const [
                            ('주행거리 10km', true),
                            ('주행거리 50km', true),
                            ('주행거리 100km', false),
                            ('애월읍 방문', true),
                            ('한경면 방문', true),
                            ('우도 방문', false),
                          ],
                        )
                            : const _TitlePlaceholder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 탭 버튼
class _TabButton extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.white : Colors.white.withOpacity(0.6);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

/// 뱃지 그리드
class _BadgeGrid extends StatelessWidget {
  final List<(String, bool)> items;
  const _BadgeGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,                          // 부모 스크롤 안에서 크기 맞춤
      physics: const NeverScrollableScrollPhysics(), // 스크롤은 바깥 SingleChildScrollView가 담당
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,       // 항상 3개/행
        mainAxisSpacing: 28,     // 위아래 간격
        crossAxisSpacing: 28,    // 좌우 간격
        childAspectRatio: 0.9,   // 아이콘+텍스트 비율 (원하는 느낌대로 조정)
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final (label, unlocked) = items[i];
        return _BadgeItem(label: label, unlocked: unlocked);
      },
    );
  }
}


/// 뱃지 아이템
class _BadgeItem extends StatelessWidget {
  final String label;
  final bool unlocked;
  const _BadgeItem({required this.label, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final dimmed = !unlocked;
    return SizedBox(
      width: 96,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF8A5BFF), Color(0xFF6A2CFF)],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.star_rounded,
                color: Colors.white.withOpacity(dimmed ? 0.5 : 1),
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(dimmed ? 0.6 : 0.95),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// 칭호 탭
class _TitlePlaceholder extends StatelessWidget {
  const _TitlePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(top: 60.0),
        child: Text(
          '칭호 탭 준비중',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
    );
  }
}
