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
          const _Weather(),
          const SizedBox(height: 15),
          _Rent(onPressed: Rent_Pressed),
          const SizedBox(height: 15),
          const _Record(),
        ],
      ),
      bottomNavigationBar: const BottomAppBarWidget(),
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
}

/// ─────────────────────────────────────────────────────────
/// 날씨 위젯
/// ─────────────────────────────────────────────────────────
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
    _future = _api.fetchJeju(); // /api/jeju-weather 호출
  }

  // 간단 야간 판정: 18시~익일 6시는 ‘밤’
  bool get _isNightNow {
    final h = DateTime.now().hour;
    return h < 6 || h >= 18;
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
                /// 1) 지역명 + 온도
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '제주도',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${w.tempC.toStringAsFixed(1)}°C',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                /// 2) 날씨 아이콘 (낮/밤 + 해/달/부분운/구름)
                _buildWeatherIcon(
                  skyCode: w.skyCode,
                  rainCode: w.rainCode,
                  lightningCode: w.lgtCode,
                  precipitationMm: w.precipitationMm,
                  precipitationProb: w.precipitationProb,
                  isNight: _isNightNow,
                  size: 48,
                  color: Colors.white,
                ),

                const SizedBox(height: 10),

                /// 3) 강수/풍속
                const Divider(color: Colors.white),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('강수', style: TextStyle(color: Colors.white, fontSize: 20)),
                    Row(
                      children: [
                        if (w.precipitationProb != null)
                          Text('$probPercent%', style: const TextStyle(color: Colors.white, fontSize: 20)),
                        if (w.precipitationProb != null) const SizedBox(width: 6),
                        Text('${w.precipitationMm.toStringAsFixed(1)} mm',
                            style: const TextStyle(color: Colors.white, fontSize: 20)),
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
                        Text('${w.windSpeedMs.toStringAsFixed(1)} m/s',
                            style: const TextStyle(color: Colors.white, fontSize: 20)),
                        const SizedBox(width: 4),
                        const Icon(Icons.air, color: Colors.white),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                /// 4) 안전 메시지
                Text(
                  _advisoryMessage(w),
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
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

  /// 아이콘 빌더: 번개 > 강수(비/눈) > 하늘상태(맑음/부분운/흐림)
  /// - 낮: 해, 해+구름, 구름
  /// - 밤: 달, 달+구름, 구름
  Widget _buildWeatherIcon({
    required int? skyCode,
    required int? rainCode,
    required int? lightningCode,
    required double precipitationMm,
    required double? precipitationProb,
    required bool isNight,
    double size = 48,
    Color color = Colors.white,
  }) {
    final int sky = skyCode ?? 1; // 1=맑음, 3=구름많음, 4=흐림
    final int pty = rainCode ?? 0; // 0=없음, 1=비,2=비/눈,3=눈,4=소나기,5=빗방울,6=빗방울/눈날림,7=눈날림
    final int lgt = lightningCode ?? 0;

    final bool precip =
        pty != 0 || precipitationMm > 0 || (precipitationProb ?? 0) > 0.5;

    // 1) 번개
    if (lgt > 0) {
      return Icon(Icons.thunderstorm, color: color, size: size);
    }

    // 2) 강수
    if (precip) {
      if (pty == 3 || pty == 7) {
        return Icon(Icons.ac_unit, color: color, size: size); // 눈
      }
      if (pty == 2 || pty == 6) {
        return Icon(Icons.cloudy_snowing, color: color, size: size); // 비/눈 혼합
      }
      return Icon(Icons.umbrella, color: color, size: size); // 비/소나기/빗방울
    }

    // 3) 하늘 상태 (비/눈 없을 때)
    final IconData sun = Icons.wb_sunny;
    final IconData moon = Icons.dark_mode;
    final IconData cloud = Icons.cloud;

    // (a) 맑음
    if (sky == 1) {
      return Icon(isNight ? moon : sun, color: color, size: size);
    }

    // (b) 부분운(해/달 + 구름) — 두 아이콘을 겹쳐서 표현
    if (sky == 3) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 2,
              top: 2,
              child: Icon(isNight ? moon : sun, color: color.withOpacity(0.9), size: size * 0.85),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Icon(cloud, color: color, size: size * 0.70),
            ),
          ],
        ),
      );
    }

    // (c) 흐림
    return Icon(cloud, color: color, size: size);
  }

  // 로딩 스켈레톤
  Widget _skeleton() => Container(
    decoration: BoxDecoration(
      color: Colors.lightBlueAccent.withOpacity(0.6),
      borderRadius: BorderRadius.circular(24),
    ),
    padding: const EdgeInsets.all(20),
    height: 180,
    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
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

/// ─────────────────────────────────────────────────────────
/// 렌트 위젯
/// ─────────────────────────────────────────────────────────
class _Rent extends StatelessWidget {
  final VoidCallback onPressed;
  const _Rent({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(onPressed: onPressed, icon: Image.asset('assets/image/RentCar.png'));
  }
}

/// ─────────────────────────────────────────────────────────
/// 최근 주행 기록 위젯
/// ─────────────────────────────────────────────────────────
class _Record extends StatelessWidget {
  const _Record({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('최근 주행 기록', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                _KmStat(),
              ],
            ),
            Row(
              children: [
                Container(
                  width: 90,
                  height: 30,
                  decoration: BoxDecoration(color: const Color(0XFFFFF4F6), borderRadius: BorderRadius.circular(50)),
                  child: const Center(child: Text('2025.07.23', style: TextStyle(color: Color(0XFFFF4E6B)))),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 140,
                  height: 30,
                  decoration: BoxDecoration(color: const Color(0XFFFFF4F6), borderRadius: BorderRadius.circular(50)),
                  child: const Center(child: Text('제주도 제주시 한강면', style: TextStyle(color: Color(0XFFFF4E6B)))),
                ),
              ],
            ),
            const SizedBox(height: 15),
            const Divider(color: Colors.grey),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _SmallStat(title: '평균 속도', value: '53KM'),
                _SmallStat(title: '최고 속도', value: '82 KM'),
                _SmallStat(title: '주행 시간', value: '01:04:32'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KmStat extends StatelessWidget {
  const _KmStat({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Text('57', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
        Text('KM', style: TextStyle(color: Colors.grey, fontSize: 20, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String title;
  final String value;
  const _SmallStat({super.key, required this.title, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 20)),
      ],
    );
  }
}
