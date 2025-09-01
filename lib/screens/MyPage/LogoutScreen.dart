import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:triprider/screens/Login/WelcomeScreen.dart';

class LogoutScreen extends StatelessWidget {
  const LogoutScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt'); // 저장된 JWT

    try {
      if (token != null && token.isNotEmpty) {
        // ✅ 백엔드 로그아웃 호출
        final res = await http.post(
          Uri.parse("http://10.0.2.2:8080/api/auth/logout"),
          headers: {"Authorization": "Bearer $token"},
        );

        if (res.statusCode == 200) {
          debugPrint("서버 로그아웃 성공: ${res.body}");
        } else {
          debugPrint("서버 로그아웃 실패: ${res.statusCode} ${res.body}");
        }
      }
    } catch (e) {
      debugPrint("로그아웃 API 호출 오류: $e");
    }

    // ✅ 토큰 삭제 (서버 성공/실패와 무관하게 프론트에서는 삭제)
    await prefs.clear();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("로그아웃 되었습니다.")),
    );

    // 로그인 화면으로 이동
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => Welcomescreen()),
          (route) => false, // 뒤로가기 방지
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("로그아웃 확인"),
        content: const Text("정말 로그아웃 하시겠습니까?\n저장된 로그인 정보가 모두 삭제됩니다."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _logout(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("로그아웃"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("로그아웃"),
        centerTitle: true,
        backgroundColor: const Color(0xFFFF4E6B),
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, size: 100, color: Colors.redAccent),
            const SizedBox(height: 24),
            const Text(
              "로그아웃 하시겠습니까?",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _confirmLogout(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              icon: const Icon(Icons.exit_to_app),
              label: const Text("로그아웃 하기"),
            ),
          ],
        ),
      ),
    );
  }
}
