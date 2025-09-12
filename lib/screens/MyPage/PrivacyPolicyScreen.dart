import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  Widget _buildSection(String title, String content) {
    return Container(
      width: double.infinity, // ✅ 양옆 꽉 차게
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF4E6B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // 배경 살짝 회색
      appBar: AppBar(

        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),

        title: const Text("개인정보처리방침"),
        centerTitle: true,
        backgroundColor: const Color(0xFFFF4E6B),
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildSection("1. 수집하는 개인정보 항목",
                  "- (필수) 구글/카카오 로그인 시 이름, 이메일 주소, 프로필 사진, 고유 식별자(ID)\n"
                      "- (필수) 위치 정보(GPS 좌표)\n"
                      "- (필수) 기기 정보(모델명, OS 버전, 광고 식별자, 접속 로그 등)\n"
                      "- (선택) 프로필 정보(닉네임, 사진), 게시글, 댓글, 업로드한 사진"),
              _buildSection("2. 개인정보 수집 방법",
                  "- 회원가입 및 로그인 과정에서 입력 또는 구글/카카오 로그인 연동 시 수집\n"
                      "- 서비스 이용 과정에서 자동 수집(위치정보, 접속 로그, 쿠키 등)\n"
                      "- 고객센터 문의 시 이용자가 직접 제공"),
              _buildSection("3. 개인정보 이용 목적",
                  "- 회원 식별 및 로그인 유지\n"
                      "- 맞춤형 여행 코스 추천 및 주변 관광지 안내\n"
                      "- 커뮤니티 기능 제공(게시물, 댓글, 좋아요 등)\n"
                      "- 서비스 품질 개선 및 통계 분석\n"
                      "- 고객 상담 및 민원 처리\n"
                      "- 법령 준수 및 부정 이용 방지"),
              _buildSection("4. 개인정보 보유 및 이용 기간",
                  "- 회원 탈퇴 시 즉시 파기\n"
                      "- 단, 관련 법령에 따라 일정 기간 보관\n"
                      "  · 계약/결제 기록: 5년\n"
                      "  · 소비자 불만 및 분쟁 처리: 3년\n"
                      "  · 접속 로그 기록: 3개월"),
              _buildSection("5. 개인정보 제3자 제공",
                  "- 원칙적으로 외부에 제공하지 않음\n"
                      "- 단, 이용자 동의 또는 법령에 의한 경우 예외"),
              _buildSection("6. 개인정보 처리 위탁",
                  "- 서버 및 데이터 보관: AWS, Google Cloud\n"
                      "- 소셜 로그인 인증: Google, Kakao"),
              _buildSection("7. 이용자의 권리",
                  "- 개인정보 열람, 수정, 삭제, 처리정지 요구 가능\n"
                      "- 동의 철회 및 회원 탈퇴 가능"),
              _buildSection("8. 위치정보 처리에 관한 사항",
                  "- 위치 정보는 여행 코스 추천 및 주변 관광지 안내에만 사용\n"
                      "- 위치 정보 제공 거부 가능 (단, 일부 기능 제한 발생)"),
              _buildSection("9. 개인정보 보호 조치",
                  "- 기술적 조치: 데이터 암호화, 접근 권한 제한, 보안 프로그램 운영\n"
                      "- 관리적 조치: 개인정보 취급 직원 최소화 및 보안 교육"),
              _buildSection("10. 개인정보 보호책임자",
                  "- 성명: [구자혁]\n"
                      "- 직책: [개인정보 보호책임자]\n"
                      "- 이메일: [jhku2433@gmail.com]\n"
                      "- 연락처: [010-3957-7902]"),
              _buildSection("11. 개인정보처리방침 변경",
                  "- 법령, 정책, 보안 기술 변경 시 개정 가능\n"
                      "- 변경 시 앱 내 공지 또는 이메일로 안내"),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}