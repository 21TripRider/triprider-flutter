// lib/screens/Login/Email_Input_Screen.dart
import 'package:flutter/material.dart';
import 'package:triprider/screens/Login/Password_Input_Screen.dart';
import 'package:triprider/screens/Login/widgets/Next_Button_Widget_Child.dart';
import 'package:triprider/screens/Login/widgets/Login_Screen_Button.dart';

class EmailInputScreen extends StatefulWidget {
  const EmailInputScreen({super.key});

  @override
  State<EmailInputScreen> createState() => _EmailInputScreenState();
}

class _EmailInputScreenState extends State<EmailInputScreen> {
  final TextEditingController emailController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  void _clearEmail() => emailController.clear();
  void _goBack() => Navigator.of(context).pop();

  bool _isValidEmail(String email) {
    final RegExp emailReg = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailReg.hasMatch(email);
  }

  void _next() {
    final email = emailController.text.trim();
    if (!_isValidEmail(email)) {
      _showPopup('입력 오류', '유효한 이메일 형식을 입력해주세요.', type: PopupType.warn);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PasswordInputScreen(email: email)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: _goBack, icon: const Icon(Icons.arrow_back_ios_new)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 35, left: 16, bottom: 25),
            child: Text('이메일을 입력해주세요.', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 16, bottom: 10),
            child: Text('이메일'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: emailController,
              builder: (_, value, __) => TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                style: const TextStyle(fontSize: 20),
                decoration: InputDecoration(
                  hintText: 'abc123456@XXXXX.com',
                  hintStyle: const TextStyle(color: Colors.grey),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: _clearEmail,
                    icon: const Icon(Icons.close),
                  ),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black87, width: 2)),
                ),
              ),
            ),
          ),
          const Spacer(),
          LoginScreenButton(
            T: 0, B: 55, L: 17, R: 17,
            color: const Color(0xFFFF4E6B),
            child: const Next_Widget_Child(),
            onPressed: _next,
          ),
        ],
      ),
    );
  }

  // 로그인 팝업과 동일 사용
  void _showPopup(String title, String message, {PopupType type = PopupType.info}) {
    showTripriderPopup(context, title: title, message: message, type: type);
  }
}

/// ===== 팝업(로그인 화면과 동일, 상단 고정) =====
enum PopupType { info, success, warn, error }

void showTripriderPopup(
    BuildContext context, {
      required String title,
      required String message,
      PopupType type = PopupType.info,
      Duration duration = const Duration(milliseconds: 2500),
    }) {
  final overlay = Overlay.of(context);
  if (overlay == null) return;

  Color accent;
  switch (type) {
    case PopupType.success:
      accent = const Color(0xFF39C172);
      break;
    case PopupType.warn:
      accent = const Color(0xFFFFA000);
      break;
    case PopupType.error:
      accent = const Color(0xFFE74C3C);
      break;
    case PopupType.info:
    default:
      accent = const Color(0xFFFF4E6B);
      break;
  }

  late OverlayEntry entry;
  bool closed = false;
  void safeRemove() {
    if (!closed && entry.mounted) {
      closed = true;
      entry.remove();
    }
  }

  entry = OverlayEntry(
    builder: (_) => SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 0, left: 16, right: 16,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              builder: (_, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(offset: Offset(0, (1 - t) * -8), child: child),
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 6))],
                    border: Border.all(color: const Color(0xFFE9E9EE)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.sports_motorsports_rounded, color: Colors.pink),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(title,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.black.withOpacity(0.9)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                      const SizedBox(height: 10),
                      Text(message, style: const TextStyle(fontSize: 14.5, height: 1.35, color: Colors.black87)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  overlay.insert(entry);
  Future.delayed(duration, safeRemove);
}