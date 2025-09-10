
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  // 에뮬레이터: Android=10.0.2.2, iOS=127.0.0.1
  static const String baseUrl = 'https://trip-rider.com';
  static const Duration _timeout = Duration(seconds: 15);
  static final http.Client _client = http.Client();

  // --- NEW: URL 보정 헬퍼 -----------------------------------------------------
  /// 서버가 '/uploads/xx.jpg' 같은 **상대경로**를 줄 때
  /// 앱에서 바로 쓸 수 있게 **절대 URL**로 변환
  static String absoluteUrl(String urlOrPath) {
    final s = urlOrPath.trim();
    if (s.isEmpty) return s;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (s.startsWith('/')) return '$baseUrl$s';
    return '$baseUrl/$s';
  }

  // ▼ 추가: JWT payload 파서 + per-user key
  static Map<String, dynamic>? _parseJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// 현재 로그인 사용자의 uid(가능한 클레임에서 탐색)
  static Future<String> currentUid() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) return 'anon';
    final p = _parseJwt(token) ?? const {};
    return (p['userId']?.toString()
        ?? p['id']?.toString()
        ?? p['uid']?.toString()
        ?? p['sub']?.toString()
        ?? p['username']?.toString()
        ?? 'anon');
  }

  /// 사용자 스코프 키 생성 (예: ride_records:<uid>)
  static Future<String> userScopedKey(String base) async {
    final uid = await currentUid();
    return '$base:$uid';
  }

  // --- Auth & Headers -------------------------------------------------------
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt'); // 저장 키명에 맞추어 사용
  }

  static Future<Map<String, String>> _defaultHeaders({
    bool json = true,
    Map<String, String>? override,
  }) async {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json';
    final token = await _getToken();
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    if (override != null) h.addAll(override);
    return h;
  }

  // ✅ 외부에서 쓸 수 있는 공개 URI 빌더
  static Uri publicUri(String path, [Map<String, dynamic>? q]) => _u(path, q);

  // 내부 전용 URI 빌더
  static Uri _u(String path, [Map<String, dynamic>? q]) {
    final base = Uri.parse('$baseUrl$path');
    return q == null
        ? base
        : base.replace(
      queryParameters: {
        ...base.queryParameters,
        ...q.map((k, v) => MapEntry(k, '$v')),
      },
    );
  }

  // --- HTTP: JSON 편의 메서드 -----------------------------------------------
  static Future<http.Response> get(
      String path, {
        Map<String, dynamic>? query,
        Map<String, String>? headers,
      }) async {
    final res = await _client
        .get(_u(path, query), headers: await _defaultHeaders(override: headers))
        .timeout(_timeout);
    _throwIfError(res);
    return res;
  }

  /// body가 String이면 그대로 전송, Map/객체면 JSON 인코딩해 전송
  static Future<http.Response> post(
      String path, {
        Object? body,
        Map<String, String>? headers,
      }) async {
    final b = (body is String) ? body : (body == null ? null : jsonEncode(body));
    final res = await _client
        .post(
      _u(path),
      headers: await _defaultHeaders(override: headers),
      body: b,
    )
        .timeout(_timeout);
    _throwIfError(res);
    return res;
  }

  static Future<http.Response> put(
      String path, {
        Object? body,
        Map<String, String>? headers,
      }) async {
    final b = (body is String) ? body : (body == null ? null : jsonEncode(body));
    final res = await _client
        .put(
      _u(path),
      headers: await _defaultHeaders(override: headers),
      body: b,
    )
        .timeout(_timeout);
    _throwIfError(res);
    return res;
  }

  static Future<http.Response> delete(
      String path, {
        Object? body,
        Map<String, String>? headers,
      }) async {
    final b = (body is String) ? body : (body == null ? null : jsonEncode(body));
    final res = await _client
        .delete(
      _u(path),
      headers: await _defaultHeaders(override: headers),
      body: b,
    )
        .timeout(_timeout);
    _throwIfError(res);
    return res;
  }

  // --- Multipart 업로드 ------------------------------------------------------
  /// 이미지 파일 업로드 → 서버가 `{ "url": "/uploads/xxx.jpg" }` 반환한다고 가정
  /// 반환값은 **절대 URL**.
  static Future<String> uploadImage(
      File file, {
        String fieldName = 'file',
      }) async {
    final uri = _u('/api/upload');
    final req = http.MultipartRequest('POST', uri);

    // Auth 헤더
    final token = await _getToken();
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }

    req.files.add(await http.MultipartFile.fromPath(fieldName, file.path));

    final streamed = await req.send().timeout(_timeout);
    final res = await http.Response.fromStream(streamed);
    _throwIfError(res);

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final path = (data['url'] ?? data['path']) as String;
    return absoluteUrl(path);
  }

  /// 임의의 엔드포인트로 멀티파트 요청을 보냄. 파일/필드 모두 지원
  static Future<http.Response> multipart(
      String path, {
        Map<String, String>? fields,
        Map<String, File>? files,
        String method = 'POST',
      }) async {
    final uri = _u(path);
    final req = http.MultipartRequest(method, uri);

    // Auth 헤더
    final token = await _getToken();
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }

    if (fields != null && fields.isNotEmpty) {
      req.fields.addAll(fields);
    }
    if (files != null && files.isNotEmpty) {
      for (final entry in files.entries) {
        req.files.add(await http.MultipartFile.fromPath(entry.key, entry.value.path));
      }
    }

    final streamed = await req.send().timeout(_timeout);
    final res = await http.Response.fromStream(streamed);
    _throwIfError(res);
    return res;
  }

  // --- 공통 에러 처리 --------------------------------------------------------
  static void _throwIfError(http.Response res) {
    if (res.statusCode >= 400) {
      throw HttpException(
        'HTTP ${res.statusCode}\n${res.request?.url}\n${res.body}',
        uri: res.request?.url,
      );
    }
  }
}
