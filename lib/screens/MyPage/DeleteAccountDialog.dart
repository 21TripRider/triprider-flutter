import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DeleteAccountDialog extends StatelessWidget {
  const DeleteAccountDialog({super.key});

  Future<void> _openGoogleForm() async {
    final Uri url = Uri.parse("https://forms.gle/uhXiqUvq8zdxjrBh8");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw "구글폼을 열 수 없습니다: $url";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "회원탈퇴 안내",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "회원탈퇴 요청을 클릭하시면\n구글폼으로 회원탈퇴 요청을 할 수 있습니다.\n\n"
                  "등록되어 있던 모든 정보가 삭제되며,\n회원탈퇴 처리에는 약 일주일 정도\n소요될 수 있습니다.\n\n"
                  "정말로 회원탈퇴 요청 구글폼으로 가시겠습니까?",
              style: TextStyle(fontSize: 15, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 취소 버튼
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "취소",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
                // 확인 버튼
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context, true);
                    await _openGoogleForm();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "회원탈퇴 요청",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
