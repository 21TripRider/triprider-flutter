import 'package:flutter/material.dart';
import 'package:triprider/screens/Login/Nickname_Input_Screen.dart';
import 'package:triprider/screens/Login/widgets/Login_Screen_Button.dart';
import 'package:triprider/screens/Login/widgets/Next_Button_Widget_Child.dart';

class ConfirmPasswordScreen extends StatefulWidget {
  final String email;
  final String originalPassword;
  const ConfirmPasswordScreen({
    super.key,
    required this.email,
    required this.originalPassword,
  });

  @override
  State<ConfirmPasswordScreen> createState() => _ConfirmPasswordScreenState();
}

class _ConfirmPasswordScreenState extends State<ConfirmPasswordScreen> {
  final TextEditingController confirmPasswordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _goBack() => Navigator.of(context).pop();
  void _clear() => confirmPasswordController.clear();

  void _next() {
    if (confirmPasswordController.text.trim() != widget.originalPassword) {
      _showPopup('입력 오류', '비밀번호가 일치하지 않습니다.', type: PopupType.warn);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NicknameInputScreen(
          email: widget.email,
          originalPassword: widget.originalPassword,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 35, left: 16, bottom: 25),
            child: Text(
              '한번 더 입력해주세요.',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 16, bottom: 10),
            child: Text('비밀번호 확인'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: confirmPasswordController,
              builder: (_, value, __) => TextField(
                controller: confirmPasswordController,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                style: const TextStyle(fontSize: 20),
                onSubmitted: (_) => _next(),
                decoration: InputDecoration(
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: _obscure ? '보이기' : '숨기기',
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      ),
                      if (value.text.isNotEmpty)
                        IconButton(
                          onPressed: _clear,
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black87, width: 2),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          LoginScreenButton(
            T: 0,
            B: 55,
            L: 17,
            R: 17,
            color: const Color(0XFFFF4E6B),
            child: const Next_Widget_Child(),
            onPressed: _next,
          ),
        ],
      ),
    );
  }

  // 로그인 팝업과 동일
  void _showPopup(String title, String message, {PopupType type = PopupType.info}) {
    showTripriderPopup(context, title: title, message: message, type: type);
  }
}

/// ===== 팝업(로그인 화면 동일, 상단 고정) =====
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
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Colors.black.withOpacity(0.9),
                              ),
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
