import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  Widget _buildSection(String title, String content) {
    return Container(
      width: double.infinity, // ✅ 좌우 꽉 차게
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
      backgroundColor: Colors.grey[100], // ✅ 배경 통일
      appBar: AppBar(
        title: const Text("이용약관"),
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
              _buildSection("제1조 (목적)",
                  "이 약관은 TripRider(이하 '서비스')의 이용조건 및 절차, "
                      "회원과 서비스 제공자의 권리·의무 및 책임사항을 규정함을 목적으로 합니다."),
              _buildSection("제2조 (정의)",
                  "1. '회원'이란 본 약관에 동의하고 서비스를 이용하는 자를 말합니다.\n"
                      "2. '게시물'이란 회원이 서비스 내에 업로드하거나 공유하는 텍스트, 사진, 동영상 등의 콘텐츠를 의미합니다.\n"
                      "3. '코스'란 회원이 직접 생성하거나 추천받은 여행 경로 및 장소 데이터를 의미합니다."),
              _buildSection("제3조 (약관의 효력 및 변경)",
                  "1. 본 약관은 서비스 화면에 게시하거나 기타의 방법으로 회원에게 공지함으로써 효력이 발생합니다.\n"
                      "2. 서비스 운영자는 합리적인 사유가 있는 경우 관련 법령을 위배하지 않는 범위 내에서 약관을 변경할 수 있습니다."),
              _buildSection("제4조 (회원의 의무)",
                  "1. 회원은 서비스 이용 시 다음 행위를 하여서는 안 됩니다.\n"
                      "   - 허위 정보 등록 또는 타인의 정보 도용\n"
                      "   - 서비스 운영을 방해하는 행위\n"
                      "   - 타인의 권리(저작권, 초상권 등)를 침해하는 행위\n"
                      "   - 법령 및 공공질서에 위반되는 행위\n"
                      "2. 회원은 본 약관 및 서비스 운영자가 정한 규정을 성실히 준수해야 합니다."),
              _buildSection("제5조 (서비스의 제공 및 제한)",
                  "1. 서비스는 회원의 여행 코스 추천, 주행 기록 관리, 커뮤니티 기능을 제공합니다.\n"
                      "2. 운영자는 서비스 개선을 위해 사전 고지 후 서비스의 일부 또는 전부를 변경, 중단할 수 있습니다."),
              _buildSection("제6조 (게시물의 관리)",
                  "1. 회원이 등록한 게시물에 대한 권리와 책임은 회원 본인에게 있습니다.\n"
                      "2. 운영자는 게시물이 다음에 해당하는 경우 사전 통지 없이 삭제하거나 등록을 제한할 수 있습니다.\n"
                      "   - 타인의 권리를 침해하거나 명예를 훼손하는 경우\n"
                      "   - 외설적이거나 폭력적인 내용을 포함하는 경우\n"
                      "   - 상업적 광고나 불법적 목적의 경우"),
              _buildSection("제7조 (개인정보 보호)",
                  "회원의 개인정보는 개인정보처리방침에 따라 관리되며, "
                      "서비스 제공 목적 이외의 용도로 사용되지 않습니다."),
              _buildSection("제8조 (계약 해지 및 이용 제한)",
                  "회원은 언제든지 서비스 탈퇴를 요청할 수 있으며, "
                      "운영자는 회원이 본 약관을 위반할 경우 서비스 이용을 제한할 수 있습니다."),
              _buildSection("제9조 (면책 조항)",
                  "1. 운영자는 회원 간 또는 회원과 제3자 간의 분쟁에 개입하지 않습니다.\n"
                      "2. 천재지변, 기술적 장애 등 불가항력으로 인한 서비스 중단에 대해서는 책임을 지지 않습니다."),
              _buildSection("제10조 (준거법 및 관할)",
                  "본 약관은 대한민국 법률에 따르며, "
                      "분쟁 발생 시 운영자 소재지 관할 법원을 전속 관할 법원으로 합니다."),
              _buildSection("부칙",
                  "본 약관은 2025년 1월 1일부터 시행합니다."),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
