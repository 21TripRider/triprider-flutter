import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:triprider/screens/Home/Weather/WeatherResponse.dart';

class WeatherApi {
  static String get _baseUrl {
    if (kIsWeb) return 'https://trip-rider.com';
    if (Platform.isAndroid) return 'https://trip-rider.com';
    if (Platform.isIOS) return 'https://trip-rider.com';
    return 'https://trip-rider.com';
  }

  Future<WeatherResponse> fetchJeju() async {
    final uri = Uri.parse('$_baseUrl/api/jeju-weather');
    final res = await http.get(uri);

    final raw = utf8.decode(res.bodyBytes);

    if (res.statusCode != 200) {
      throw Exception('Weather API ${res.statusCode}: ${res.body}');
    }

    final Map<String, dynamic> decoded = jsonDecode(raw);
    final String key = decoded.containsKey('제주시')
        ? '제주시'
        : (decoded.keys.isNotEmpty ? decoded.keys.first : '');
    if (key.isEmpty) throw Exception('도시 키 없음');

    final list = (decoded[key] as List).cast<dynamic>();
    if (list.isEmpty) throw Exception('제주시 날씨 데이터 비어 있음');

    return WeatherResponse.fromJejuCategoryList(key, list);
  }
}
