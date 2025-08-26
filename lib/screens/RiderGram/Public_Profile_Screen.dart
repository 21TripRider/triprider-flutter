// lib/screens/RiderGram/Public_Profile_Screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:triprider/screens/RiderGram/Api_client.dart';

class PublicProfileScreen extends StatefulWidget {
  final int? userId;
  final String? nickname;
  const PublicProfileScreen({super.key, this.userId, this.nickname});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  bool _loading = true;
  String _error = '';
  late String _nickname;
  String? _intro;
  String? _profileImage;
  num? _totalDistance;

  @override
  void initState() {
    super.initState();
    _nickname = widget.nickname ?? '라이더';
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final candidates = <String>[
        if (widget.userId != null) '/api/users/${widget.userId}/profile',
        if (widget.userId != null) '/api/users/${widget.userId}',
        if (widget.nickname != null)
          '/api/public/profile?nickname=${Uri.encodeQueryComponent(widget.nickname!)}',
      ];

      Map<String, dynamic>? dataNullable;
      for (final path in candidates) {
        try {
          final res = await ApiClient.get(path);
          dataNullable = jsonDecode(res.body) as Map<String, dynamic>;
          break;
        } catch (_) {}
      }

      // ✅ 여기서 non-null 로컬 변수로 확정
      final Map<String, dynamic> data = dataNullable ?? const {};

      setState(() {
        _nickname = (data['nickname'] ?? widget.nickname ?? '라이더') as String;
        _intro = data['intro'] as String?;
        _profileImage = (data['profileImage'] ?? data['imageUrl']) as String?;
        _totalDistance = data['totalDistance'] as num?;
        _loading = false;
      });
    } catch (e) {
      setState(() { _loading = false; _error = '불러오기 실패: $e'; });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_loading ? '...' : _nickname, style: const TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error.isNotEmpty)
          ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
          : SingleChildScrollView(
        child: Column(
          children: [
            _TopCard(nickname: _nickname, intro: _intro, profileImage: _profileImage, totalDistance: _totalDistance),
            const SizedBox(height: 16),
            // 필요 시 해당 유저의 게시물/뱃지 등 섹션 추가 가능
          ],
        ),
      ),
    );
  }
}

class _TopCard extends StatelessWidget {
  final String nickname;
  final String? intro;
  final String? profileImage;
  final num? totalDistance;
  const _TopCard({required this.nickname, this.intro, this.profileImage, this.totalDistance});

  @override
  Widget build(BuildContext context) {
    final ImageProvider avatar = (profileImage != null && profileImage!.isNotEmpty)
        ? NetworkImage(profileImage!)
        : const AssetImage('assets/image/logo.png');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16, right: 16, bottom: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF5E7E), Color(0xFFFF7E9E)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(radius: 40, backgroundImage: avatar),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nickname, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                if (totalDistance != null)
                  Text('누적거리 ${totalDistance!.toStringAsFixed(0)} km', style: const TextStyle(color: Colors.white70)),
              ],
            )),
          ]),
          const SizedBox(height: 16),
          Text(intro?.trim().isNotEmpty == true ? intro!.trim() : '소개가 없습니다.',
              style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
