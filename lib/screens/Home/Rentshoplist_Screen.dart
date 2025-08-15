import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class RentshopList extends StatelessWidget {
  const RentshopList({super.key});

  @override
  Widget build(BuildContext context) {
    // 데모 데이터(백엔드 연동 전)
    final shops = List.generate(5, (_) => {
      'name': '준바이크',
      'addr': '제주 제주시 오라로 7',
      'rating': 4.7,
      'image': 'assets/image/logo.png', // ← 이미지 경로 확인
      'url': 'https://map.naver.com/p/entry/place/1797520528', // ← 네이버 장소/홈페이지 링크

    });

    List<Widget> stars(double r) {
      final full = r.floor();
      final half = (r - full) >= 0.5;
      final list = <Widget>[];
      for (var i = 0; i < full && i < 5; i++) {
        list.add(const Icon(Icons.star, size: 20, color: Color(0xFFFFD400)));
      }
      if (half && list.length < 5) {
        list.add(const Icon(Icons.star_half, size: 20, color: Color(0xFFFFD400)));
      }
      while (list.length < 5) {
        list.add(const Icon(Icons.star_border, size: 20, color: Color(0xFFFFD400)));
      }
      return list;
    }

    return Scaffold(
      appBar: const RentAppBar(),
      body: Column(
        children: [
          const Sort(),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: shops.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final s = shops[i];
                return InkWell(
                  onTap: () async {
                    final url = Uri.parse(s['url'] as String);
                    // 네이버앱/브라우저 외부로 열기
                    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                      // 실패 시 인앱 웹뷰로라도 열기 (선택)
                      await launchUrl(url, mode: LaunchMode.inAppWebView);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 썸네일
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              s['image'] as String,
                              width: 140,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // 텍스트영역
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['name'] as String,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  s['addr'] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    ...stars(s['rating'] as double),
                                    const SizedBox(width: 8),
                                    Text(
                                      '(${(s['rating'] as double).toStringAsFixed(1)})',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF9F3FF), // 연보라 배경(원하면 제거)
    );
  }
}

/// 상단 AppBar — AppBar만 반환 (Scaffold 금지)
class RentAppBar extends StatefulWidget implements PreferredSizeWidget {
  const RentAppBar({super.key});
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<RentAppBar> createState() => _RentAppBarState();
}

class _RentAppBarState extends State<RentAppBar> {
  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        '오토바이 렌트',
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      ),
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.black),
          onPressed: () {},
        ),
      ],
    );
  }
}

/// 정렬 드롭다운
class Sort extends StatefulWidget {
  const Sort({super.key});

  @override
  State<Sort> createState() => _SortState();
}

class _SortState extends State<Sort> {
  String selectedSort = '거리순';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          PopupMenuButton<String>(
            onSelected: (String value) {
              setState(() {
                selectedSort = value;
              });
            },
            itemBuilder: (BuildContext context) => const [
              PopupMenuItem(value: '거리순', child: Text('거리순')),
              PopupMenuItem(value: '인기순', child: Text('인기순')),
            ],
            child: Row(
              children: [
                Text(
                  selectedSort,
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, color: Colors.black),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
