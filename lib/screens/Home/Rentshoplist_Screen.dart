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
        'image': 'assets/image/Rentshop1.png',
        'url': 'https://map.naver.com/p/entry/place/38526625',
      },
      {
        'name': '준바이크',
        'addr': '제주 제주시 오라로 7',
        'rating': 4.68,
        'image': 'assets/image/Rentshop2.png',
        'url': 'https://map.naver.com/p/entry/place/13436124',
      },
      {
        'name': '바이크제주',
        'addr': '제주 제주시 용해로 99 1층 바이크제주',
        'rating': 4.89,
        'image': 'assets/image/Rentshop3.png',
        'url': 'https://map.naver.com/p/search/바이크제주/place/1130472425',
      },
      {
        'name': '망고 스쿠터',
        'addr': '제주 제주시 서광로 164',
        'rating': 4.43,
        'image': 'assets/image/Rentshop4.png',
        'url': 'https://map.naver.com/p/entry/place/11870133',
      },
      {
        'name': '제주스쿠터천국',
        'addr': '제주 제주시 성화로1길 9 1층 제주도스쿠터천국',
        'rating': 4.95,
        'image': 'assets/image/Rentshop5.png',
        'url': 'https://map.naver.com/p/entry/place/37537642',
      },
      {
        'name': '우도하이킹레저',
        'addr': '제주 제주시 우도면 우도해안길 352',
        'rating': 3.76,
        'image': 'assets/image/Rentshop6.png',
        'url': 'https://map.naver.com/p/entry/place/34761886',
      },
      {
        'name': '천진낭만',
        'addr': '제주 제주시 우도면 우도해안길 108',
        'rating': 4.48,
        'image': 'assets/image/Rentshop7.png',
        'url': 'https://map.naver.com/p/entry/place/819045181',
      },
      {
        'name': '광장바이크',
        'addr': '제주 제주시 서부두길 18',
        'rating': 4.32,
        'image': 'assets/image/Rentshop8.png',
        'url': 'https://map.naver.com/p/search/광장바이크/place/1586578791',
      },
      {
        'name': '걸리버 여행기',
        'addr': '제주 제주시 우도면 우도로 1',
        'rating': 4.06,
        'image': 'assets/image/Rentshop9.png',
        'url': 'https://map.naver.com/p/search/오토바이 렌트/place/842060671',
      },
      {
        'name': '꽃길만걷차 성산본점',
        'addr': '제주 서귀포시 성산읍 성산등용로17번길 55 상가동 57호',
        'rating': 5.0,
        'image': 'assets/image/Rentshop10.png',
        'url': 'https://map.naver.com/p/entry/place/1147964344',
      },
    ];

    List<Widget> stars(double r) {
      final full = r.floor();
      final half = (r - full) >= 0.5;
      final list = <Widget>[];
      for (var i = 0; i < full && i < 5; i++) {
        list.add(const Icon(Icons.star_rounded, size: 20, color: Color(0xFFFFD400)));
      }
      if (half && list.length < 5) {
        list.add(const Icon(Icons.star_half_rounded, size: 20, color: Color(0xFFFFD400)));
      }
      while (list.length < 5) {
        list.add(const Icon(Icons.star_border_rounded, size: 20, color: Color(0xFFFFD400)));
      }
      return list;
    }

    return Scaffold(
      appBar:
      const RentAppBar(),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
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
                    child: SizedBox(
                      height: 140, // ✅ 모든 카드 동일 높이
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                            child: SizedBox(
                              width: 140,
                              child: Image.asset(
                                s['image'] as String,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    s['name'] as String,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1, // ✅ 길면 말줄임
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    s['addr'] as String,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    maxLines: 1, // ✅ 한 줄로 고정
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
      backgroundColor: const Color(0xFFF5F5F5),
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
      scrolledUnderElevation: 0,            // ✅ 스크롤 시 색상 변하지 않음
      surfaceTintColor: Colors.transparent, // ✅ 머터리얼3 틴트 제거
      centerTitle: true,
      title: const Text(
        '오토바이 렌트',
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      ),
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
      ),
    );
  }
}
