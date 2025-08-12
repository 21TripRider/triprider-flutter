import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:triprider/screens/Home/Weather/WeatherResponse.dart';

class WeatherApi {
  static String get _baseUrl {
    if (kIsWeb) return 'http://localhost:8080';
    if (Platform.isAndroid) return 'http://10.0.2.2:8080';
    if (Platform.isIOS) return 'http://127.0.0.1:8080';
    return 'http://localhost:8080';
  }

  Future<WeatherResponse> fetchJeju() async {
    final uri = Uri.parse('$_baseUrl/api/jeju-weather');
    final res = await http.get(uri);

    final raw = utf8.decode(res.bodyBytes);
    // 디버그용 로그 (원하면 주석 처리)
    // print('Weather API status: ${res.statusCode}');
    // print('Weather API raw response: $raw');

    if (res.statusCode != 200) {
      throw Exception('Weather API ${res.statusCode}: ${res.body}');
    }

    final Map<String, dynamic> decoded = jsonDecode(raw);
    // 기본 키: "제주시" (혹시 다르면 첫 키 사용)
    final String key = decoded.containsKey('제주시')
        ? '제주시'
        : (decoded.keys.isNotEmpty ? decoded.keys.first : '');
    if (key.isEmpty) throw Exception('도시 키 없음');

    final list = (decoded[key] as List).cast<dynamic>();
    if (list.isEmpty) throw Exception('제주시 날씨 데이터 비어 있음');

    // ✅ 카테고리 리스트 → WeatherResponse로 변환
    return WeatherResponse.fromJejuCategoryList(key, list);
  }
}
