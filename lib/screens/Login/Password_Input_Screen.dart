import 'package:flutter/material.dart';
import 'package:triprider/screens/Login/Confirm_Password_Screen.dart';
import 'package:triprider/screens/Login/widgets/Login_Screen_Button.dart';
import 'package:triprider/screens/Login/widgets/Next_Button_Widget_Child.dart';

class PasswordInputScreen extends StatefulWidget {
  final String email;
  const PasswordInputScreen({super.key, required this.email});

  @override
  State<PasswordInputScreen> createState() => _PasswordInputScreenState();
}

class _PasswordInputScreenState extends State<PasswordInputScreen> {
  final TextEditingController passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    passwordController.dispose();
    super.dispose();
  }

  void _goBack() => Navigator.of(context).pop();
  void _clear() => passwordController.clear();

  bool _isValidPassword(String password) {
    final hasMinLength = password.length >= 10;
    final hasLowercase = RegExp(r'[a-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecialChar = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password);
    return hasMinLength && hasLowercase && hasNumber && hasSpecialChar;
  }

  void _next() {
    final password = passwordController.text.trim();
    if (!_isValidPassword(password)) {
      _showPopup('입력 오류', '유효한 비밀번호 형식을 입력해주세요.', type: PopupType.warn);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConfirmPasswordScreen(
          email: widget.email,
          originalPassword: password,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
      ),
      body: SingleChildScrollView( // ← 키보드가 올라와도 스크롤 가능하게
        padding: const EdgeInsets.only(bottom: 80), // 버튼 영역과 겹치지 않게 여백
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 35, left: 16, bottom: 25),
              child: Text(
                '비밀번호를 입력해주세요.',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 10),
              child: Text('비밀번호'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: passwordController,
                builder: (_, value, __) => TextField(
                  controller: passwordController,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  style: const TextStyle(fontSize: 20),
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
            _PasswordCondition(controller: passwordController),
          ],
        ),
      ),

      // ✅ 버튼을 bottomNavigationBar에 넣음
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: LoginScreenButton(
          T: 0,
          B: 0,
          L: 0,
          R: 0,
          color: const Color(0XFFFF4E6B),
          child: const Next_Widget_Child(),
          onPressed: _next,
        ),
      ),
    );
  }


  // 로그인 화면과 동일한 상단 팝업 사용
  void _showPopup(String title, String message, {PopupType type = PopupType.info}) {
    showTripriderPopup(context, title: title, message: message, type: type);
  }
}

class _PasswordCondition extends StatefulWidget {
  final TextEditingController controller;
  const _PasswordCondition({super.key, required this.controller});

  @override
  State<_PasswordCondition> createState() => _PasswordConditionState();
}

class _PasswordConditionState extends State<_PasswordCondition> {
  bool hasMinLength = false;
  bool hasLowercase = false;
  bool hasNumber = false;
  bool hasSpecialChar = false;

  void _validate() {
    final p = widget.controller.text;
    setState(() {
      hasMinLength = p.length >= 10;
      hasLowercase = RegExp(r'[a-z]').hasMatch(p);
      hasNumber = RegExp(r'[0-9]').hasMatch(p);
      hasSpecialChar = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(p);
    });
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_validate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_validate);
    super.dispose();
  }

  Widget _row(bool ok, String text) => Row(
    children: [
      Icon(ok ? Icons.check_circle : Icons.check_circle_outline,
          color: ok ? Colors.green : Colors.black),
      const SizedBox(width: 8),
      Text(text),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 20),
      child: Column(
        children: [
          _row(hasMinLength, '10자리 이상'),
          _row(hasLowercase, '영어 소문자'),
          _row(hasNumber, '숫자'),
          _row(hasSpecialChar, '특수문자'),
        ],
      ),
    );
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

  // (타입별 색 변수는 스타일 유지용 — 현재 아이콘은 고정 핑크 사용)
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
