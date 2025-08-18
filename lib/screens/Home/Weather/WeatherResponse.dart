class WeatherResponse {
  final String location;
  final double tempC;               // °C
  final double windSpeedMs;         // m/s
  final double precipitationMm;     // mm
  final double? precipitationProb;  // 0.0 ~ 1.0

  // 아이콘 판별용 코드들
  final int? skyCode;   // 하늘 상태(1=맑음, 3=구름많음, 4=흐림)
  final int? rainCode;  // 강수 형태(0=없음, 1=비, 2=비/눈, 3=눈, 4=소나기, 5=빗방울, 6=빗방울/눈날림, 7=눈날림)
  final int? lgtCode;   // 낙뢰(0=없음, 1=있음)

  WeatherResponse({
    required this.location,
    required this.tempC,
    required this.windSpeedMs,
    required this.precipitationMm,
    this.precipitationProb,
    this.skyCode,
    this.rainCode,
    this.lgtCode,
  });

  // ----- 유틸 -----
  static double _toDouble(dynamic v, {double def = 0}) {
    if (v == null) return def;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? def;
    return def;
  }

  static double _extractNumber(String s, {double def = 0}) {
    final m = RegExp(r'[-+]?\d*\.?\d+').firstMatch(s);
    return m == null ? def : (double.tryParse(m.group(0)!) ?? def);
  }

  factory WeatherResponse.fromJson(Map<String, dynamic> j) => WeatherResponse(
    location: (j['location'] as String?) ?? '제주도',
    tempC: _toDouble(j['tempC']),
    windSpeedMs: _toDouble(j['windSpeedMs'] ?? j['windSpeed']),
    precipitationMm: _toDouble(j['precipitationMm'] ?? j['rainMm']),
    precipitationProb: j['precipitationProb'] == null
        ? null
        : _toDouble(j['precipitationProb']),
  );

  /// 제주시 응답 형태(카테고리 리스트) 전용 파서
  factory WeatherResponse.fromJejuCategoryList(
      String location,
      List<dynamic> list,
      ) {
    double? tempC;
    double? windMs;
    double? rainProb0to1;
    double? rainMm;
    int? sky; // 하늘 상태
    int? pty; // 강수 형태
    int? lgt; // 낙뢰

    // 카테고리별 최신 fcstTime 값 선택
    final latestByCat = <String, Map<String, dynamic>>{};
    for (final raw in list) {
      final m = Map<String, dynamic>.from(raw as Map);
      final cat = (m['category'] ?? '').toString();
      final t = int.tryParse((m['fcstTime'] ?? '').toString()) ?? -1;
      final v = (m['fcstValue'] ?? '').toString();
      final exists = latestByCat[cat];
      if (exists == null || t >= (exists['time'] as int)) {
        latestByCat[cat] = {'time': t, 'value': v};
      }
    }

    // 기온
    final tempStr = latestByCat['기온']?['value'] as String?;
    if (tempStr != null) tempC = _toDouble(tempStr);

    // 풍속
    final windStr = latestByCat['풍속']?['value'] as String?;
    if (windStr != null) windMs = _toDouble(windStr);

    // 강수확률: "60" → 0.6
    final probStr = latestByCat['강수확률']?['value'] as String?;
    if (probStr != null) {
      final p = _toDouble(probStr);
      rainProb0to1 = (p > 1) ? p / 100.0 : p;
    }

    // 강수량: "4.0mm" / "강수없음"
    final rainAmtStr = latestByCat['강수량']?['value'] as String?;
    if (rainAmtStr != null) {
      rainMm = rainAmtStr.contains('없음') ? 0 : _extractNumber(rainAmtStr, def: 0);
    }

    // 하늘 상태/강수 형태/낙뢰 코드
    final skyStr = latestByCat['하늘 상태']?['value'] as String?;
    if (skyStr != null) sky = int.tryParse(skyStr);

    final ptyStr = latestByCat['강수 형태']?['value'] as String?;
    if (ptyStr != null) pty = int.tryParse(ptyStr);

    final lgtStr = latestByCat['낙뢰']?['value'] as String?;
    if (lgtStr != null) lgt = int.tryParse(lgtStr);

    return WeatherResponse(
      location: location,
      tempC: tempC ?? 0,
      windSpeedMs: windMs ?? 0,
      precipitationMm: rainMm ?? 0,
      precipitationProb: rainProb0to1,
      skyCode: sky,
      rainCode: pty ?? 0,
      lgtCode: lgt,
    );
  }
}
