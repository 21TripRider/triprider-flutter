// 공통 커버(URL) 해석 & 사전탐색 유틸
import 'package:triprider/screens/RiderGram/Api_client.dart';
import 'package:http/http.dart' as http;

class CourseCoverResolver {
  static const fallback = 'assets/image/courseview1.png';
  static const _exts = ['png', 'jpg', 'jpeg', 'webp'];

  /// '/images/...' → 절대URL, 'assets/**' → 그대로, 'http(s)' → 그대로
  static String resolveOne(String? raw) {
    if (raw == null || raw.trim().isEmpty) return fallback;
    final c = raw.trim();
    if (c.startsWith('http://') || c.startsWith('https://')) return c;
    if (c.startsWith('assets/')) return c;

    final base = ApiClient.baseUrl.endsWith('/')
        ? ApiClient.baseUrl.substring(0, ApiClient.baseUrl.length - 1)
        : ApiClient.baseUrl;
    final rel = c.startsWith('/') ? c : '/$c';
    return '$base$rel';
  }

  /// 서버가 coverImageUrl을 안 줄 때:
  /// /images/course/<category>/<id>.(png|jpg|jpeg|webp) 를 HEAD로 찾아 첫 성공 URL 사용
  /// [selector] 콜백으로 필요한 필드를 뽑아오므로, 특정 DTO에 의존하지 않음(순환 import 방지).
  static Future<List<String>> prefetch<T>(
      List<T> items, {
        required String? Function(T) cover,
        required String Function(T) category,
        required int Function(T) id,
      }) async {
    final client = http.Client();
    final base = Uri.parse(ApiClient.baseUrl);
    final out = List<String>.filled(items.length, fallback, growable: false);

    for (int i = 0; i < items.length; i++) {
      final fromServer = cover(items[i]);
      if (fromServer != null && fromServer.trim().isNotEmpty) {
        out[i] = resolveOne(fromServer);
        continue;
      }

      String? found;
      for (final ext in _exts) {
        final rel = 'images/course/${category(items[i])}/${id(items[i])}.$ext';
        final url = base.resolve(rel).toString();
        try {
          final resp = await client.head(Uri.parse(url));
          if (resp.statusCode == 200) { found = url; break; }
        } catch (_) {}
      }
      out[i] = found ?? fallback;
    }

    client.close();
    return out;
  }
}
