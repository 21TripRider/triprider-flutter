// lib/screens/Login/widgets/Terms_Agreement_Model.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// 서비스 약관 화면 (유지)
import 'package:triprider/screens/MyPage/TermsOfServiceScreen.dart';

class TermsAgreementModal extends StatefulWidget {
  final String email;
  final String originalPassword;
  // privacyPolicyAgreed = (계정/기기 필수 && 위치정보 필수)
  final Function(
      String email,
      String password,
      bool serviceTermsAgreed,
      bool privacyPolicyAgreed,
      ) onAgreed;

  const TermsAgreementModal({
    super.key,
    required this.email,
    required this.originalPassword,
    required this.onAgreed,
  });

  @override
  State<TermsAgreementModal> createState() => _TermsAgreementModalState();
}

class _TermsAgreementModalState extends State<TermsAgreementModal>
    with TickerProviderStateMixin {
  // ===== Animations =====
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // ===== States =====
  bool _allAgreed = false;

  // (필수)
  bool _serviceTermsAgreed = false; // 서비스 이용약관
  bool _piAccountDeviceAgreed = false; // 개인정보 수집·이용(계정/기기)
  bool _locationAgreed = false; // 위치정보 수집·이용

  // (선택)
  bool _piProfilePostAgreed = false; // 개인정보 수집·이용(프로필/게시물)

  // 인라인 배너
  String? _bannerMsg;
  Timer? _bannerTimer;

  static const _kPrivacyUrl = 'https://sites.google.com/view/triprider-privacy';
  Future<void> _openPrivacyUrl() async {
    final uri = Uri.parse(_kPrivacyUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showInlineBanner('개인정보처리방침 페이지를 열 수 없어요. 잠시 후 다시 시도해주세요.');
    }
  }

  // ===== Lifecycle =====
  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 0.6).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  Future<void> _closeModal() async {
    await _slideController.reverse();
    await _fadeController.reverse();
    if (mounted) Navigator.of(context).pop();
  }

  // ===== Computed: 개인정보 블록 "모두 동의" (tristate) =====
  bool? get _privacyAllState {
    final a = _piAccountDeviceAgreed;
    final b = _locationAgreed;
    final c = _piProfilePostAgreed;
    if (a && b && c) return true;
    if (!a && !b && !c) return false;
    return null; // 일부만 체크 → indeterminate
  }

  void _togglePrivacyAll(bool? value) {
    final on = value == true;
    setState(() {
      _piAccountDeviceAgreed = on;
      _locationAgreed = on;
      _piProfilePostAgreed = on;
      _serviceTermsAgreed = on; // ✅ 개인정보 '모두 동의' 시 약관도 함께 체크 (원치 않으면 이 줄 제거)
      _updateAllAgreed();
    });
  }

  // ===== All agree =====
  void _toggleAllAgreement(bool? value) {
    setState(() {
      _allAgreed = value ?? false;
      _serviceTermsAgreed = _allAgreed;
      _piAccountDeviceAgreed = _allAgreed;
      _locationAgreed = _allAgreed;
      _piProfilePostAgreed = _allAgreed;
    });
  }

  void _updateAllAgreed() {
    // 전체 동의는 선택 포함해서 전부 체크된 경우 true
    _allAgreed = _serviceTermsAgreed &&
        _piAccountDeviceAgreed &&
        _locationAgreed &&
        _piProfilePostAgreed;
  }

  // ===== Confirm =====
  Future<void> _confirmAgreement() async {
    if (!_serviceTermsAgreed || !_piAccountDeviceAgreed || !_locationAgreed) {
      _showInlineBanner('필수 항목(이용약관, 계정/기기, 위치정보)에 모두 동의해주세요.');
      return;
    }

    final bool privacyRequiredOk = _piAccountDeviceAgreed && _locationAgreed;

    // ✅ 먼저 모달을 완전히 닫고
    await _closeModal();
    if (!mounted) return;

    // ✅ 그 다음 콜백 실행 (→ 홈 화면 이동 등)
    widget.onAgreed(
      widget.email,
      widget.originalPassword,
      _serviceTermsAgreed,
      privacyRequiredOk,
    );
  }

  // ===== Inline banner =====
  void _showInlineBanner(String message) {
    _bannerTimer?.cancel();
    setState(() => _bannerMsg = message);
    _bannerTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _bannerMsg = null);
    });
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Stack(
            children: [
              // dim background
              GestureDetector(
                onTap: _closeModal,
                child: Container(
                  color: Colors.black.withOpacity(_fadeAnimation.value),
                ),
              ),

              // bottom sheet
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // handle
                          Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),

                          const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            child: Text(
                              '약관에 동의해주세요',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w700),
                            ),
                          ),

                          if (_bannerMsg != null) ...[
                            Padding(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                              child: _buildInlineBanner(_bannerMsg!),
                            ),
                            const SizedBox(height: 8),
                          ],

                          const SizedBox(height: 12),

                          // ===== 전체 동의 =====
                          Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: const Color(0xFFE5E7EB)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: _allAgreed,
                                    onChanged: _toggleAllAgreement,
                                    activeColor: const Color(0xFFFF4E6B),
                                  ),
                                  const Expanded(
                                    child: Text(
                                      '전체 동의',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ===== 1) 서비스 이용약관 =====
                          Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildAgreementItem(
                              title: '서비스 이용약관',
                              subtitle: '서비스 이용 조건, 금지행위, 게시물 관리 등',
                              badgeText: '필수',
                              isAgreed: _serviceTermsAgreed,
                              isRequired: true,
                              onChanged: (v) {
                                setState(() {
                                  _serviceTermsAgreed = v ?? false;
                                  _updateAllAgreed();
                                });
                              },
                              showView: true,
                              onView: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const TermsOfServiceScreen(),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // ===== 2) 개인정보 수집·이용 동의 (그룹) =====
                          Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildPrivacyGroup(),
                          ),

                          const SizedBox(height: 26),

                          // 버튼
                          Padding(
                            padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _confirmAgreement,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF4E6B),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  '동의하고 계속하기',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ===== Widgets =====

  // 개인정보 그룹 카드 (헤더 + 하위 3항목)
  Widget _buildPrivacyGroup() {
    // 그룹이 전부 동의되면 테두리 강조
    final highlight = _privacyAllState == true;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border.all(
          color: highlight ? const Color(0xFF21C18C) : const Color(0xFFE5E7EB),
          width: highlight ? 1.4 : 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // 헤더: 제목 + (모두 동의) + 보기
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 그룹 "모두 동의" (tristate)
                Transform.scale(
                  scale: 1.0,
                  child: Checkbox(
                    tristate: true,
                    value: _privacyAllState,
                    onChanged: _togglePrivacyAll,
                    activeColor: const Color(0xFF21C18C),
                    materialTapTargetSize:
                    MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const Icon(Icons.folder_shared_outlined,
                    size: 20, color: Color(0xFFFF4E6B)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '개인정보 수집·이용 동의 (모두 동의)',
                    style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: _openPrivacyUrl,
                  child: const Text(
                    '보기',
                    style: TextStyle(
                        color: Color(0xFFFF4E6B), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // 캡션
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '수집 목적·항목·보유기간 등 상세 안내',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ),

          // 하위 항목 리스트
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                _buildAgreementItem(
                  title: '계정/기기 (필수)',
                  subtitle:
                  '이름·이메일·프로필사진·고유식별자, 기기/OS/광고식별자, 접속로그',
                  badgeText: '필수',
                  isAgreed: _piAccountDeviceAgreed,
                  isRequired: true,
                  onChanged: (v) {
                    setState(() {
                      _piAccountDeviceAgreed = v ?? false;
                      _updateAllAgreed();
                    });
                  },
                  isNested: true,
                  showView: false,
                ),
                const SizedBox(height: 8),
                _buildAgreementItem(
                  title: '위치정보 (필수)',
                  subtitle: 'GPS 좌표 기반 경로 추천·주행 기록 기능 제공',
                  badgeText: '필수',
                  isAgreed: _locationAgreed,
                  isRequired: true,
                  onChanged: (v) {
                    setState(() {
                      _locationAgreed = v ?? false;
                      _updateAllAgreed();
                    });
                  },
                  isNested: true,
                  showView: false,
                ),
                const SizedBox(height: 8),
                _buildAgreementItem(
                  title: '프로필/게시물 (선택)',
                  subtitle: '닉네임·프로필사진, 게시글·댓글·업로드 사진',
                  badgeText: '선택',
                  isAgreed: _piProfilePostAgreed,
                  isRequired: false,
                  onChanged: (v) {
                    setState(() {
                      _piProfilePostAgreed = v ?? false;
                      _updateAllAgreed();
                    });
                  },
                  isNested: true,
                  showView: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 인라인 배너
  Widget _buildInlineBanner(String msg) {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9ED),
        border: Border.all(color: const Color(0xFFFFBAC6)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              size: 18, color: Color(0xFFFF4E6B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                  color: Color(0xFFB00020),
                  fontSize: 13,
                  height: 1.2),
            ),
          ),
        ],
      ),
    );
  }

  // 공용 항목 빌더 (상위/하위 공용)
  Widget _buildAgreementItem({
    required String title,
    String? subtitle,
    required String badgeText,
    required bool isAgreed,
    required Function(bool?) onChanged,
    required bool isRequired,
    bool isNested = false,
    bool showView = true,
    VoidCallback? onView,
  }) {
    final EdgeInsets padding = isNested
        ? const EdgeInsets.fromLTRB(12, 10, 12, 10)
        : const EdgeInsets.all(16);
    final BorderRadius radius =
    BorderRadius.circular(isNested ? 10 : 12);
    final Color borderColor =
    isNested ? const Color(0xFFEDEFF2) : const Color(0xFFE5E7EB);
    final Color bgColor =
    isNested ? const Color(0xFFFAFAFB) : Colors.white;

    final double titleSize = isNested ? 13 : 14;
    final double subtitleSize = isNested ? 11 : 12;
    final double badgeFontSize = isNested ? 9 : 10;
    final EdgeInsets badgePad = isNested
        ? const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5)
        : const EdgeInsets.symmetric(horizontal: 6, vertical: 2);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: radius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isNested) const SizedBox(width: 2),
          Transform.scale(
            scale: isNested ? 0.9 : 1.0,
            child: Checkbox(
              value: isAgreed,
              onChanged: onChanged,
              activeColor: const Color(0xFFFF4E6B),
              visualDensity: isNested
                  ? const VisualDensity(horizontal: -3, vertical: -3)
                  : VisualDensity.standard,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: badgePad,
                      decoration: BoxDecoration(
                        color: isRequired
                            ? const Color(0xFFFF4E6B)
                            : Colors.grey,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: badgeFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  SizedBox(height: isNested ? 4 : 6),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: subtitleSize,
                      color: Colors.black54,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isNested && showView && onView != null)
            TextButton(
              onPressed: onView,
              child: const Text(
                '보기',
                style: TextStyle(
                    color: Color(0xFFFF4E6B), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
