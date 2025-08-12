import 'package:flutter/material.dart';
import 'package:triprider/widgets/Bottom_App_Bar.dart';

class RecordScreen extends StatelessWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, size: 28),
        ),
        centerTitle: true,
        title: Text('주행 기록', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: EdgeInsets.all(25),
        children: [
          // 누적 주행 정보
          Container(
            height: 170,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '누적 주행거리',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w500),
                ),
                Text(
                  '507.3 km',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildStatColumn('제주도', '2.3 바퀴'),
                    SizedBox(width: 30),
                    _buildStatColumn('라이딩', '12 회'),
                    SizedBox(width: 30),
                    _buildStatColumn('시간', '10:12:34'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          //  주행 기록 카드 리스트
          _buildRideCard(
            date: '2025.07.23',
            location: '제주도 제주시 한경면',
            distance: '57',
            avgSpeed: '53',
            maxSpeed: '82',
            time: '01:04:32',
          ),
          _buildRideCard(
            date: '2025.07.22',
            location: '제주도 서귀포시 안덕면',
            distance: '49',
            avgSpeed: '50',
            maxSpeed: '79',
            time: '00:55:10',
          ),

          _buildRideCard(
            date: '2025.07.23',
            location: '제주도 제주시 한경면',
            distance: '57',
            avgSpeed: '53',
            maxSpeed: '82',
            time: '01:04:32',
          ),

          _buildRideCard(
            date: '2025.07.23',
            location: '제주도 제주시 한경면',
            distance: '57',
            avgSpeed: '53',
            maxSpeed: '82',
            time: '01:04:32',
          ),
          // 필요시 더 추가...
        ],
      ),

    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: Colors.grey, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRideCard({
    required String date,
    required String location,
    required String distance,
    required String avgSpeed,
    required String maxSpeed,
    required String time,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날짜 & 거리
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(date, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('$distance km', style: TextStyle(fontSize: 20, color: Colors.black54, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),

          // 위치 태그
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(location, style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)),
          ),

          const SizedBox(height: 12),
          Divider(),
          const SizedBox(height: 12),

          // 속도, 시간 정보
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildRideInfo('평균 속도', '$avgSpeed km'),
              _buildRideInfo('최고 속도', '$maxSpeed km'),
              _buildRideInfo('주행 시간', time),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRideInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
