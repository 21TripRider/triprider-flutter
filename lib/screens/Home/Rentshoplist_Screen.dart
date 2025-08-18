import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class RentshopList extends StatelessWidget {
  const RentshopList({super.key});

  @override
  Widget build(BuildContext context) {
    // 실제 데이터
    final shops = [
      {
        'name': '제주 고고스쿠더',
        'addr': '제주 제주시 성화로1길 9 제주 고고스쿠터',
        'rating': 4.62,
        'image': 'assets/image/logo.png',
        'url': 'https://map.naver.com/p/entry/place/38526625',
      },
      {
        'name': '준바이크',
        'addr': '제주 제주시 오라로 7',
        'rating': 4.68,
        'image': 'assets/image/logo.png',
        'url': 'https://map.naver.com/p/entry/place/13436124',
      },
      {
        'name': '바이크제주',
        'addr': '제주 제주시 용해로 99 1층 바이크제주',
        'rating': 4.89,
        'image': 'assets/image/logo.png',
        'url': 'https://map.naver.com/p/search/바이크제주/place/1130472425',
      },
      {
        'name': '망고 스쿠터',
        'addr': '제주 제주시 서광로 164',
        'rating': 4.43,
        'image': 'assets/image/logo.png',
        'url': 'https://map.naver.com/p/entry/place/11870133',
      },
      {
        'name': '제주스쿠터천국',
        'addr': '제주 제주시 성화로1길 9 1층 제주도스쿠터천국',
        'rating': 4.95,
        'image': 'assets/image/logo.png',
        'url': 'https://map.naver.com/p/entry/place/37537642',
      },
      {
        'name': '우도하이킹레저',
        'addr': '제주 제주시 우도면 우도해안길 352',
        'rating': 3.76,
        'image': 'assets/image/logo.png',
        'url': 'https://map.naver.com/p/entry/place/34761886',
      },
      {
        'name': '천진낭만',
        'addr': '제주 제주시 우도면 우도해안길 108',
        'rating': 4.48,
        'image': 'assets/image/logo.png',
        'url': 'https://map.naver.com/p/entry/place/819045181',
      },
      {
        'name': '광장바이크',
        'addr': '제주 제주시 서부두길 18',
        'rating': 4.32,
        'image': 'assets/image/logo.png',
        'url': 'https://map.naver.com/p/search/광장바이크/place/1586578791',
      },
      {
        'name': '걸리버 여행기',
        'addr': '제주 제주시 우도면 우도로 1',
        'rating': 4.06,
        'image': 'assets/image/logo.png',
        'url': 'https://map.naver.com/p/search/오토바이 렌트/place/842060671',
      },
      {
        'name': '꽃길만걷차 성산본점',
        'addr': '제주 서귀포시 성산읍 성산등용로17번길 55 상가동 57호',
        'rating': 5.0,
        'image': 'assets/image/logo.png',
        'url': 'https://map.naver.com/p/entry/place/1147964344',
      },
    ];

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
          const Sort(), // 현재는 UI만. 실제 정렬은 추후 연동
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
                    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
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
                                      '(${(s['rating'] as double).toStringAsFixed(2)})',
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
      backgroundColor: const Color(0xFFF9F3FF),
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

/// 정렬 드롭다운 (현재는 UI만 동작)
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
              // TODO: 실제 정렬 로직은 나중에 리스트 상태와 연동
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