// lib/screens/home/HomeScreen.dart
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:triprider/screens/home/Rentshoplist_Screen.dart';
import 'package:triprider/widgets/Bottom_App_Bar.dart';

import 'package:triprider/screens/Home/Weather/WeatherApi.dart';
import 'package:triprider/screens/Home/Weather/WeatherResponse.dart';

// ✅ 서버 최신 기록을 우선 사용
import 'package:triprider/screens/Map/API/Ride_Api.dart';

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
        children: const [
          _Weather(),
          SizedBox(height: 15),
          _RentSection(),
          SizedBox(height: 15),
          _Record(), // 최근 주행 기록 카드
        ],
      ),
      bottomNavigationBar: const BottomAppBarWidget(),
    );
  }
}

/// ─────────────────────────────────────────────────────────
/// 날씨 위젯 (기존 유지)
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
    _future = _api.fetchJeju();
  }

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
          final probPercent =
          ((w.precipitationProb ?? 0) * 100).toStringAsFixed(0);

          return Container(
            decoration: BoxDecoration(
              color: Colors.lightBlueAccent,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('제주도',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    Text(
                      '${w.tempC.toStringAsFixed(1)}°C',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
                const Divider(color: Colors.white),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('강수',
                        style: TextStyle(color: Colors.white, fontSize: 20)),
                    Row(
                      children: [
                        if (w.precipitationProb != null)
                          Text('$probPercent%',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 20)),
                        if (w.precipitationProb != null)
                          const SizedBox(width: 6),
                        Text('${w.precipitationMm.toStringAsFixed(1)} mm',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 20)),
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
                    const Text('풍속',
                        style: TextStyle(color: Colors.white, fontSize: 20)),
                    Row(
                      children: [
                        Text('${w.windSpeedMs.toStringAsFixed(1)} m/s',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 20)),
                        const SizedBox(width: 4),
                        const Icon(Icons.air, color: Colors.white),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _advisoryMessage(w),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold),
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
    final int sky = skyCode ?? 1;
    final int pty = rainCode ?? 0;
    final int lgt = lightningCode ?? 0;

    final bool precip =
        pty != 0 || precipitationMm > 0 || (precipitationProb ?? 0) > 0.5;

    if (lgt > 0) return Icon(Icons.thunderstorm, color: color, size: size);

    if (precip) {
      if (pty == 3 || pty == 7) {
        return Icon(Icons.ac_unit, color: color, size: size);
      }
      if (pty == 2 || pty == 6) {
        return Icon(Icons.cloudy_snowing, color: color, size: size);
      }
      return Icon(Icons.umbrella, color: color, size: size);
    }

    final IconData sun = Icons.wb_sunny;
    final IconData moon = Icons.dark_mode;
    final IconData cloud = Icons.cloud;

    if (sky == 1) {
      return Icon(isNight ? moon : sun, color: color, size: size);
    }
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
              child: Icon(isNight ? moon : sun,
                  color: color.withOpacity(0.9), size: size * 0.85),
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
    return Icon(cloud, color: color, size: size);
  }

  Widget _skeleton() => Container(
    decoration: BoxDecoration(
      color: Colors.lightBlueAccent.withOpacity(0.6),
      borderRadius: BorderRadius.circular(24),
    ),
    padding: const EdgeInsets.all(20),
    height: 180,
    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
  );

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
/// 렌트 배너
/// ─────────────────────────────────────────────────────────
class _RentSection extends StatelessWidget {
  const _RentSection({super.key});

  void _openRent(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RentshopList()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _openRent(context),
      icon: Image.asset('assets/image/RentCar.png'),
    );
  }
}

/// ─────────────────────────────────────────────────────────
/// 최근 주행 기록 카드 (서버 우선 + 폴백 + 1회 재시도)
/// ─────────────────────────────────────────────────────────
class _Record extends StatefulWidget {
  const _Record({super.key});

  @override
  State<_Record> createState() => _RecordState();
}

class _RecordState extends State<_Record> {
  bool _loading = true;
  Map<String, dynamic>? _latest;
  bool _retryOnceScheduled = false;

  @override
  void initState() {
    super.initState();
    _loadLatest();
  }

  // JWT가 있는 경우 계정별 키, 레거시 키도 함께 체크
  Future<String> _keyNew() async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('jwt') ?? '';
    final suffix = jwt.isEmpty ? '' : '_${jwt.hashCode.toRadixString(16)}';
    return 'ride_records$suffix';
  }

  Future<Map<String, dynamic>?> _loadFromServer() async {
    try {
      // 3초 타임아웃: 서버 재기동/네트워크 지연 대비
      final list = await RideApi.listRides()
          .timeout(const Duration(seconds: 3));

      if (list.isEmpty) return null;

      // 최신 종료시각 순
      list.sort((a, b) {
        final bd = DateTime.tryParse('${b['finishedAt'] ?? b['startedAt'] ?? ''}') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final ad = DateTime.tryParse('${a['finishedAt'] ?? a['startedAt'] ?? ''}') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });

      final r = list.first;
      return {
        'startedAt': r['startedAt'],
        'endedAt': r['finishedAt'],
        'elapsedSeconds': (r['movingSeconds'] ?? r['elapsedSeconds'] ?? 0) is num
            ? (r['movingSeconds'] ?? r['elapsedSeconds'] ?? 0).toInt()
            : int.tryParse('${r['movingSeconds'] ?? r['elapsedSeconds'] ?? 0}') ?? 0,
        'distanceMeters':
        (((r['totalKm'] as num?)?.toDouble() ?? double.tryParse('${r['totalKm'] ?? 0}') ?? 0.0) * 1000.0),
        'avgSpeedKmh': (r['avgSpeedKmh'] as num?)?.toDouble() ??
            double.tryParse('${r['avgSpeedKmh'] ?? 0}') ??
            0.0,
        'maxSpeedKmh': (r['maxSpeedKmh'] as num?)?.toDouble() ??
            double.tryParse('${r['maxSpeedKmh'] ?? 0}') ??
            0.0,
      };
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final newKey = await _keyNew();
    final legacyKey = 'ride_records'; // 레거시 호환

    List<String> raw = prefs.getStringList(newKey) ?? const <String>[];
    if (raw.isEmpty) {
      raw = prefs.getStringList(legacyKey) ?? const <String>[];
    }
    if (raw.isEmpty) return null;

    final parsed = <Map<String, dynamic>>[];
    for (final s in raw) {
      try {
        parsed.add(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {}
    }
    if (parsed.isEmpty) return null;

    parsed.sort((a, b) {
      final ad = DateTime.tryParse(a['endedAt'] ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = DateTime.tryParse(b['endedAt'] ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return parsed.first;
  }

  Future<void> _loadLatest() async {
    // 1) 서버 우선
    final fromServer = await _loadFromServer();
    if (fromServer != null) {
      if (!mounted) return;
      setState(() {
        _latest = fromServer;
        _loading = false;
      });
      return;
    }

    // 2) 로컬 폴백
    final fromLocal = await _loadFromLocal();
    if (fromLocal != null) {
      if (!mounted) return;
      setState(() {
        _latest = fromLocal;
        _loading = false;
      });
      return;
    }

    // 3) 둘 다 없으면: 빈 카드 + 1회 지연 재시도 (서버 재기동 직후 대비)
    if (!mounted) return;
    setState(() {
      _latest = null;
      _loading = false;
    });

    if (!_retryOnceScheduled) {
      _retryOnceScheduled = true;
      Future.delayed(const Duration(milliseconds: 2500), () async {
        if (!mounted) return;
        setState(() => _loading = true);
        await _loadLatest();
      });
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  String _formatHms(int seconds) {
    final hh = (seconds ~/ 3600).toString().padLeft(2, '0');
    final mm = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // 데이터 없음
    if (_latest == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _HeaderRowRightStat(label: '최근 주행 기록', valueText: '0.0', unit: 'km'),
              SizedBox(height: 12),
              Divider(color: Colors.grey),
              SizedBox(height: 12),
              Center(
                child: Text('최근 주행기록 없음',
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
              ),
            ],
          ),
        ),
      );
    }

    // 데이터 표시
    final r = _latest!;
    final startedAt = DateTime.tryParse(r['startedAt'] ?? '') ?? DateTime.now();
    final distanceKm =
        ((r['distanceMeters'] as num?)?.toDouble() ?? 0.0) / 1000.0;
    final avg = (r['avgSpeedKmh'] as num?)?.toDouble() ?? 0.0;
    final max = (r['maxSpeedKmh'] as num?)?.toDouble() ?? 0.0;
    final secs = (r['elapsedSeconds'] as num?)?.toInt() ?? 0;
    final route = (r['routeName'] ?? r['location'] ?? '') as String;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _HeaderRowRightStat(
                  label: '최근 주행 기록',
                  valueText: distanceKm.toStringAsFixed(1),
                  unit: 'km',
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Chip(text: _formatDate(startedAt)),
                    const SizedBox(width: 8),
                    if (route.isNotEmpty) _Chip(text: route),
                  ],
                ),
                const SizedBox(height: 15),
                const Divider(color: Colors.grey),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SmallStat(title: '평균 속도', value: '${avg.toStringAsFixed(1)} km/h'),
                    _SmallStat(title: '최고 속도', value: '${max.toStringAsFixed(1)} km/h'),
                    _SmallStat(title: '주행 시간', value: _formatHms(secs)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 타이틀-우측 수치
class _HeaderRowRightStat extends StatelessWidget {
  final String label;
  final String valueText; // ex) "0.4"
  final String unit; // ex) "km"
  const _HeaderRowRightStat({
    super.key,
    required this.label,
    required this.valueText,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        Row(
          children: [
            Text(valueText,
                style:
                const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
            const SizedBox(width: 4),
            Text(unit,
                style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 20,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

/// 라운드 칩
class _Chip extends StatelessWidget {
  final String text;
  const _Chip({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0XFFFFF4F6),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(text, style: const TextStyle(color: Color(0XFFFF4E6B))),
    );
  }
}

/// 작은 통계 셀
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
