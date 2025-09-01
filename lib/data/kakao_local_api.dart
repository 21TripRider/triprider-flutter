import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/place.dart';

class KakaoLocalApi {
  KakaoLocalApi(this.restApiKey);
  final String restApiKey;

  Map<String, String> get _headers => {
        'Authorization': 'KakaoAK $restApiKey',
      };

  Future<List<Place>> fetchCategory({
    required String code,
    required double lat,
    required double lon,
    int radius = 5000,
    int size = 15,
  }) async {
    final uri = Uri.parse('https://dapi.kakao.com/v2/local/search/category.json').replace(
      queryParameters: {
        'category_group_code': code,
        'x': lon.toStringAsFixed(6),
        'y': lat.toStringAsFixed(6),
        'radius': radius.toString(),
        'size': size.toString(),
        'page': '1',
      },
    );
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode != 200) {
      throw Exception('Kakao category ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final docs = (data['documents'] as List<dynamic>? ?? <dynamic>[]).cast<Map<String, dynamic>>();
    return docs.map(Place.fromKakaoDoc).toList();
  }

  Future<List<Place>> fetchKeyword({
    required String query,
    required double lat,
    required double lon,
    int radius = 5000,
    int size = 15,
  }) async {
    final uri = Uri.parse('https://dapi.kakao.com/v2/local/search/keyword.json').replace(
      queryParameters: {
        'query': query,
        'x': lon.toStringAsFixed(6),
        'y': lat.toStringAsFixed(6),
        'radius': radius.toString(),
        'size': size.toString(),
        'page': '1',
      },
    );
    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode != 200) {
      throw Exception('Kakao keyword ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final docs = (data['documents'] as List<dynamic>? ?? <dynamic>[]).cast<Map<String, dynamic>>();
    return docs.map(Place.fromKakaoDoc).toList();
  }
}


