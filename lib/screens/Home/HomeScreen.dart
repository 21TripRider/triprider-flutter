import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:triprider/screens/home/Rentshoplist_Screen.dart';
import 'package:triprider/screens/trip/Riding_Course_Screen.dart';
import 'package:triprider/widgets/Bottom_App_Bar.dart';

import 'package:triprider/screens/Home/Weather/WeatherApi.dart';
import 'package:triprider/screens/Home/Weather/WeatherResponse.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          _Weather(),
          SizedBox(height: 15),
          _Rent(onPressed: Rent_Pressed),
          SizedBox(height: 15),
          _Record(),
        ],
      ),

      bottomNavigationBar: BottomAppBarWidget(),
    );
  }

  Rent_Pressed() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) {
          return RentshopList();
        },
      ),
    );
  }


  Home_Button_Pressed() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) {
          return Homescreen();
        },
      ),
    );
  }


  Course_Button_Pressed() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) {
          return RidingCourse();
        },
      ),
    );
  }

  Ridergram_Button_Pressed() {}
  Mypage_Button_Pressed() {}
}

///날씨 위젯
class _Weather extends StatefulWidget {
  const _Weather({super.key});

  @override
  State<_Weather> createState() => _WeatherState();
}

class _WeatherState extends State<_Weather> {
  final WeatherApi _api = WeatherApi();
  late Future<WeatherResponse> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchJeju(); // ← /api/jeju-weather 호출
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: FutureBuilder<WeatherResponse>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return _skeleton();
          }
          if (snap.hasError) {
            return _errorCard(snap.error.toString());
          }

          final w = snap.data!;
          final probPercent = ((w.precipitationProb ?? 0) * 100).toStringAsFixed(0);

          return Container(
            decoration: BoxDecoration(
              color: Colors.lightBlueAccent,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// 1. 지역명(고정: 제주도) + 온도
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '제주도',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${w.tempC.toStringAsFixed(1)}°C',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                /// 2. 날씨 아이콘 (기본 맑음 + 상태별 변경)
                Icon(
                  _pickWeatherIcon(
                    skyCode: w.skyCode,
                    rainCode: w.rainCode,
                    lightningCode: w.lgtCode,
                    precipitationMm: w.precipitationMm,
                    precipitationProb: w.precipitationProb,
                  ),
                  color: Colors.white,
                  size: 48,
                ),

                const SizedBox(height: 10),

                /// 3. 강수(확률 + 강수량) + 풍속
                const Divider(color: Colors.white),

                // 강수: 확률이 있으면 %도, 강수량은 항상 mm 표기
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('강수', style: TextStyle(color: Colors.white, fontSize: 20)),
                    Row(
                      children: [
                        if (w.precipitationProb != null)
                          Text(
                            '$probPercent%',
                            style: const TextStyle(color: Colors.white, fontSize: 20),
                          ),
                        if (w.precipitationProb != null) const SizedBox(width: 6),
                        Text(
                          '${w.precipitationMm.toStringAsFixed(1)} mm',
                          style: const TextStyle(color: Colors.white, fontSize: 20),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.water_drop, color: Colors.white),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('풍속', style: TextStyle(color: Colors.white, fontSize: 20)),
                    Row(
                      children: [
                        Text(
                          '${w.windSpeedMs.toStringAsFixed(1)} m/s',
                          style: const TextStyle(color: Colors.white, fontSize: 20),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.air, color: Colors.white),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                /// 4. 안전 메시지
                Text(
                  _advisoryMessage(w),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),
                const Center(child: Icon(Icons.circle, color: Colors.white, size: 8)),
              ],
            ),
          );
        },
      ),
    );
  }

  // 기본: 맑음(해). 우선순위: 번개 > 강수(비/눈) > 하늘상태 > 기본
  IconData _pickWeatherIcon({
    int? skyCode,
    int? rainCode,
    int? lightningCode,
    required double precipitationMm,
    double? precipitationProb,
  }) {
    final IconData fallback = Icons.wb_sunny; // 기본 맑음
    final int sky = skyCode ?? 1; // 1=맑음, 3=구름많음, 4=흐림
    final int pty = rainCode ?? 0; // 0=없음, 1=비, 2=비/눈, 3=눈, 4=소나기, 5=빗방울, 6=빗방울/눈날림, 7=눈날림
    final int lgt = lightningCode ?? 0;

    // 강수 보조판단: 강수형태가 없어도 확률/강수량으로 비 판단
    final bool likelyRaining = pty != 0 || precipitationMm > 0 || (precipitationProb ?? 0) > 0.5;

    // 1) 번개 최우선
    if (lgt > 0) {
      // 프로젝트 Flutter 버전에 따라 없으면 Icons.electric_bolt로 대체
      return Icons.thunderstorm;
    }

    // 2) 강수
    if (likelyRaining) {
      switch (pty) {
        case 3: // 눈
        case 7: // 눈날림
          return Icons.ac_unit;
        case 2: // 비/눈
        case 6: // 빗방울/눈날림
          return Icons.cloudy_snowing; // 대체 아이콘
        default: // 비, 소나기, 빗방울 등
          return Icons.umbrella;
      }
    }

    // 3) 하늘 상태
    switch (sky) {
      case 1:
        return Icons.wb_sunny; // 맑음
      case 3:
        return Icons.cloud;    // 구름 많음
      case 4:
      default:
        return Icons.cloud;    // 흐림(기본)
    }
  }

  // 로딩 스켈레톤
  Widget _skeleton() => Container(
    decoration: BoxDecoration(
      color: Colors.lightBlueAccent.withOpacity(0.6),
      borderRadius: BorderRadius.circular(24),
    ),
    padding: const EdgeInsets.all(20),
    height: 180,
    child: const Center(
      child: CircularProgressIndicator(color: Colors.white),
    ),
  );

  // 에러 카드
  Widget _errorCard(String msg) => Container(
    decoration: BoxDecoration(
      color: Colors.redAccent,
      borderRadius: BorderRadius.circular(24),
    ),
    padding: const EdgeInsets.all(20),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '날씨 정보를 불러오지 못했습니다.\n$msg',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );

  // 안전 메시지
  String _advisoryMessage(WeatherResponse w) {
    if ((w.precipitationProb ?? 0) >= 0.6 || w.precipitationMm >= 5) {
      return '비 예보가 있어 도로가 미끄러울 수 있으니 감속하세요!';
    }
    if (w.windSpeedMs >= 8) {
      return '강풍 주의! 횡풍에 대비해 주행하세요.';
    }
    if (w.tempC <= 0) {
      return '기온이 낮습니다. 노면 결빙에 주의하세요!';
    }
    return '안전한 라이딩을 위해 방어 운전하세요!';
  }
}



///랜트 위젯
class _Rent extends StatelessWidget {
  final VoidCallback onPressed;

  const _Rent({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: IconButton(
        onPressed: onPressed,
        icon: Image.asset('assets/image/RentCar.png'),
      ),
    );
  }
}

///최근 주행 기록 위젯
class _Record extends StatelessWidget {
  const _Record({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(20.0),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '최근 주행 기록',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),

                Row(
                  children: [
                    Text(
                      '57',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    Text(
                      'KM',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            Row(
              children: [
                Container(
                  width: 90,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Color(0XFFFFF4F6),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Center(
                    child: Text(
                      '2025.07.23',
                      style: TextStyle(color: Color(0XFFFF4E6B)),
                    ),
                  ),
                ),

                Container(
                  width: 140,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Color(0XFFFFF4F6),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Center(
                    child: Text(
                      '제주도 제주시 한강면',
                      style: TextStyle(color: Color(0XFFFF4E6B)),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 15),

            Divider(color: Colors.grey),

            SizedBox(height: 15),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('평균 속도', style: TextStyle(color: Colors.grey)),
                    Text('53KM', style: TextStyle(fontSize: 20)),
                  ],
                ),

                Column(
                  children: [
                    Text('최고 속도', style: TextStyle(color: Colors.grey)),
                    Text('82 KM', style: TextStyle(fontSize: 20)),
                  ],
                ),

                Column(
                  children: [
                    Text('주행 시간', style: TextStyle(color: Colors.grey)),
                    Text('01:04:32', style: TextStyle(fontSize: 20)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class bottomAppBar extends StatelessWidget {
  final VoidCallback homePressed;
  final VoidCallback coursePressed;
  final VoidCallback ridergramPressed;
  final VoidCallback mypagePressed;

  const bottomAppBar({
    super.key,
    required this.mypagePressed,
    required this.homePressed,
    required this.coursePressed,
    required this.ridergramPressed,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            onPressed: homePressed,
            icon: Icon(Icons.home_filled, size: 40),
          ),
          IconButton(
            onPressed: coursePressed,
            icon: Icon(Icons.motorcycle_sharp, size: 40),
          ),
          IconButton(
            onPressed: ridergramPressed,
            icon: Icon(Icons.message, size: 40),
          ),
          IconButton(
            onPressed: mypagePressed,
            icon: Icon(Icons.person, size: 40),
          ),
        ],
      ),
    );
  }
}