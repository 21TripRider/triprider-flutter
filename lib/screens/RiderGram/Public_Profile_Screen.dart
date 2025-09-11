// lib/screens/RiderGram/Public_Profile_Screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:triprider/core/network/Api_client.dart';
import 'package:triprider/screens/RiderGram/Post_Detail.dart';

/// 상대방 공개 프로필 + 게시물 그리드 (이미지/텍스트 모두 표시)
class PublicProfileScreen extends StatefulWidget {
  final int? userId;
  final String? nickname;
  const PublicProfileScreen({super.key, this.userId, this.nickname});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  // ---- 프로필 상태 ----
  bool _loadingProfile = true;
  String _errorProfile = '';
  late String _nickname;
  String? _intro;
  String? _profileImageUrl; // 절대 URL
  num? _totalDistance;

  // 내부적으로 사용: 대상 유저 id (닉네임으로 찾은 경우 채움)
  int? _userId;

  // “마이페이지 스타일” 확장 필드
  String? _region;                  // 예: 제주도
  double? _wheels;                  // 예: 2.3
  int? _badgeCount;                 // 예: 6
  String? _titleName;               // 예: 제주 토박이
  int? _titleLevel;                 // 예: 2

  // 라운드(바퀴) 1회 거리 (마이페이지와 동일하게 240km로 통일)
  static const double _lapKm = 240.0;

  // ---- 게시물 상태 ----
  final List<_PostThumb> _posts = [];
  bool _loadingPosts = true;
  bool _hasMore = true;
  int _page = 0;
  final int _size = 30;
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _nickname = widget.nickname ?? '라이더';
    _userId = widget.userId; // 초기값 세팅
    _scroll = ScrollController()..addListener(_onScroll);
    _initLoad();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _initLoad() async {
    await _fetchProfile();            // 프로필(닉/소개/이미지 + id 추출)
    await _fetchRideSummaryForUser(); // 누적거리(바퀴 계산)
    await _loadPosts(reset: true);    // 게시물(이미지/텍스트)
  }

  // ---- 공통 유틸 ----
  String? _absOrNull(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty || s.toLowerCase() == 'null' || s.toLowerCase() == 'undefined') return null;
    return ApiClient.absoluteUrl(s);
  }

  String? _cleanString(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final t = v.trim();
      if (t.isEmpty) return null;
      final low = t.toLowerCase();
      if (low == 'null' || low == 'undefined') return null;
      return t;
    }
    return v.toString();
  }

  num? _cleanNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    if (v is String) {
      final t = v.trim().toLowerCase();
      if (t.isEmpty || t == 'null' || t == 'undefined') return null;
      return num.tryParse(t);
    }
    return null;
  }

  T? _firstNonNull<T>(
      Map<String, dynamic> src,
      List<String> keys,
      T? Function(dynamic)? conv,
      ) {
    for (final k in keys) {
      if (!src.containsKey(k)) continue;
      final raw = src[k];
      final T? parsed = conv == null ? raw as T? : conv(raw);
      if (parsed == null) continue;
      if (parsed is String && parsed.trim().isEmpty) continue;
      return parsed;
    }
    return null;
  }

  // ========= 딥 서치 유틸 (nested 응답 대비) =========
  String? _deepGetString(Map<String, dynamic> m, List<String> keys, {int depth = 0}) {
    if (depth > 3) return null;
    for (final k in keys) {
      final v = m[k];
      if (v is String) {
        final t = v.trim();
        if (t.isNotEmpty && t.toLowerCase() != 'null' && t.toLowerCase() != 'undefined') {
          return t;
        }
      }
    }
    for (final v in m.values) {
      if (v is Map) {
        final hit = _deepGetString(v.cast<String, dynamic>(), keys, depth: depth + 1);
        if (hit != null) return hit;
      } else if (v is List) {
        for (final it in v) {
          if (it is Map) {
            final hit = _deepGetString(it.cast<String, dynamic>(), keys, depth: depth + 1);
            if (hit != null) return hit;
          }
        }
      }
    }
    return null;
  }

  num? _deepGetNum(Map<String, dynamic> m, List<String> keys, {int depth = 0}) {
    if (depth > 3) return null;
    for (final k in keys) {
      final v = m[k];
      if (v is num) return v;
      if (v is String) {
        final t = v.trim().toLowerCase();
        if (t.isNotEmpty && t != 'null' && t != 'undefined') {
          final p = num.tryParse(t);
          if (p != null) return p;
        }
      }
    }
    for (final v in m.values) {
      if (v is Map) {
        final hit = _deepGetNum(v.cast<String, dynamic>(), keys, depth: depth + 1);
        if (hit != null) return hit;
      } else if (v is List) {
        for (final it in v) {
          if (it is Map) {
            final hit = _deepGetNum(it.cast<String, dynamic>(), keys, depth: depth + 1);
            if (hit != null) return hit;
          }
        }
      }
    }
    return null;
  }

  /// 인트로 문자열을 “표시 가능한 텍스트”로 정규화
  /// - null/빈문자/'null'/'undefined' → null
  /// - '{"intro":null}' / '{"intro":""}' 같은 이중 인코딩 문자열 → 파싱하여 null 처리
  /// - '{"intro":"text"}' → 'text'
  String? _normalizeIntro(String? s) {
    if (s == null) return null;
    final t = s.trim();
    if (t.isEmpty) return null;
    final low = t.toLowerCase();
    if (low == 'null' || low == 'undefined') return null;

    // JSON처럼 보이면 한 번 더 파싱 시도
    if ((t.startsWith('{') && t.endsWith('}')) || (t.startsWith('[') && t.endsWith(']'))) {
      try {
        final inner = jsonDecode(t);
        if (inner is Map) {
          final v = inner['intro'];
          if (v == null) return null;
          if (v is String && v.trim().isEmpty) return null;
          if (v is String && (v.trim().toLowerCase() == 'null' || v.trim().toLowerCase() == 'undefined')) {
            return null;
          }
          return v.toString();
        }
        // 배열/기타는 표시하지 않음
        return null;
      } catch (_) {
        // 특수 케이스: 파싱 실패하지만 문자열에 intro:null 패턴이 포함됨
        if (t.contains('"intro":null') || t.contains("'intro':null")) return null;
      }
    }
    return t;
  }

  // ---- 프로필 로드 ----
  Future<void> _fetchProfile() async {
    setState(() { _loadingProfile = true; _errorProfile = ''; });

    try {
      // (A) 닉네임만 들어온 화면이면 userId 먼저 확정
      if (_userId == null && (widget.nickname?.isNotEmpty ?? false)) {
        try {
          final uri = ApiClient.publicUri('/api/public/users/by-nickname', {'nickname': widget.nickname!});
          final res = await ApiClient.get(uri.path, query: uri.queryParameters);
          if (res.statusCode >= 200 && res.statusCode < 300) {
            final obj = jsonDecode(res.body);
            if (obj is Map) {
              final m = obj.cast<String, dynamic>();
              final idNum = _cleanNum(m['userId']) ?? _cleanNum(m['id']);
              if (idNum != null) _userId = idNum.toInt();
              final nick = _cleanString(m['nickname']);
              if (nick != null && nick.isNotEmpty) _nickname = nick; // 서버 닉네임으로 갱신
            }
          }
        } catch (_) {}
      }

      // (B) 실제 프로필은 여기서 가져온다 (public 우선)
      final candidates = <Uri>[
        if (_userId != null) ApiClient.publicUri('/api/public/users/${_userId}'),
        if (_userId != null) ApiClient.publicUri('/api/public/profile', {'userId': '$_userId'}),
        if (_userId == null && (widget.nickname?.isNotEmpty ?? false))
          ApiClient.publicUri('/api/public/profile', {'nickname': widget.nickname!}),
        if (_userId == null && (widget.nickname == null || widget.nickname!.isEmpty))
          ApiClient.publicUri('/api/mypage', {}),
      ];

      Map<String, dynamic> data = const {};
      for (final uri in candidates) {
        try {
          final res = await ApiClient.get(uri.path, query: uri.queryParameters);
          if (res.statusCode >= 200 && res.statusCode < 300) {
            final firstDecoded = jsonDecode(res.body);
            if (firstDecoded is Map) {
              data = firstDecoded.cast<String, dynamic>();
              break;
            }
            // 서버가 문자열로 JSON을 한 번 더 감싼 경우 처리
            if (firstDecoded is String) {
              try {
                final secondDecoded = jsonDecode(firstDecoded);
                if (secondDecoded is Map) {
                  data = secondDecoded.cast<String, dynamic>();
                } else {
                  data = {'intro': _cleanString(firstDecoded)};
                }
              } catch (_) {
                data = {'intro': _cleanString(firstDecoded)};
              }
              break;
            }
          }
        } catch (_) {}
      }

      // id 재확정(중복 안전)
      final idNum = _firstNonNull<num>(data, ['id','userId','uid','authorId'], _cleanNum)
          ?? _deepGetNum(data, ['id','userId','uid','authorId']);
      if (idNum != null) _userId = idNum.toInt();

      // --- 기존 파싱 로직 + intro 정규화 ---
      String? imgRaw    = _firstNonNull<String>(data, ['profileImage','profile_image','imageUrl','avatarUrl','photoUrl'], _cleanString)
          ?? _deepGetString(data, ['profileImage','profile_image','imageUrl','avatarUrl','photoUrl']);
      num?    wheelsRaw = _firstNonNull<num>(data, ['wheels','wheel','laps','levelProgress'], _cleanNum)
          ?? _deepGetNum(data,    ['wheels','wheel','laps','levelProgress']);
      num?    badgesRaw = _firstNonNull<num>(data, ['badgeCount','badges','badgesCount','badgeTotal'], _cleanNum)
          ?? _deepGetNum(data,    ['badgeCount','badges','badgesCount','badgeTotal']);
      String? title     = _firstNonNull<String>(data, ['title','titleName','rankName'], _cleanString)
          ?? _deepGetString(data, ['title','titleName','rankName']);
      num?    titleLv   = _firstNonNull<num>(data, ['titleLevel','rankLevel','grade'], _cleanNum)
          ?? _deepGetNum(data,    ['titleLevel','rankLevel','grade']);
      String? region    = _firstNonNull<String>(data, ['region','location','area'], _cleanString)
          ?? _deepGetString(data, ['region','location','area']) ?? '제주도';
      num?    totalDist = _firstNonNull<num>(data, ['totalKm','totalDistance','distance','distKm'], _cleanNum)
          ?? _deepGetNum(data,    ['totalKm','totalDistance','distance','distKm']);

      // intro는 다양한 키를 보고 + 정규화 필터 적용
      String? introRaw  = _firstNonNull<String>(
          data,
          ['intro','introduction','bio','about','oneLineIntro','profileIntro'],
          _cleanString)
          ?? _deepGetString(
              data, ['intro','introduction','bio','about','oneLineIntro','profileIntro']);
      introRaw = _normalizeIntro(introRaw);

      double? wheels = (wheelsRaw != null) ? wheelsRaw.toDouble()
          : (totalDist != null ? totalDist.toDouble() / _lapKm : null);

      setState(() {
        _nickname        = _cleanString(_firstNonNull<String>(data, ['nickname','name','displayName'], _cleanString)) ?? widget.nickname ?? _nickname;
        _intro           = introRaw; // null이면 화면에서 플레이스홀더 처리
        _profileImageUrl = _absOrNull(imgRaw);
        _totalDistance   = totalDist;
        _region          = region;
        _wheels          = wheels;
        _badgeCount      = badgesRaw?.toInt();
        _titleName       = title;
        _titleLevel      = titleLv?.toInt();
        _loadingProfile  = false;
      });
    } catch (e) {
      setState(() { _loadingProfile = false; _errorProfile = '프로필 불러오기 실패: $e'; });
    }
  }

  // ---- 특정 유저의 누적거리(요약) ----
  Future<void> _fetchRideSummaryForUser() async {
    // 닉네임만 들어온 경우, 먼저 userId를 획득 시도
    if (_userId == null && (widget.nickname != null && widget.nickname!.isNotEmpty)) {
      try {
        final uri = ApiClient.publicUri('/api/public/users/by-nickname', {'nickname': widget.nickname!});
        final res = await ApiClient.get(uri.path, query: uri.queryParameters);
        final obj = jsonDecode(res.body);
        if (obj is Map) {
          final m = obj.cast<String, dynamic>();
          final idNum = _firstNonNull<num>(m, ['id','userId','uid'], _cleanNum)
              ?? _deepGetNum(m, ['id','userId','uid']);
          if (idNum != null) _userId = idNum.toInt();
        }
      } catch (_) {}
    }

    // 그래도 없으면 포기
    if (_userId == null) return;

    final List<Uri> candidates = [
      ApiClient.publicUri('/api/users/${_userId}/summary'),
      ApiClient.publicUri('/api/public/users/${_userId}/summary'),
      ApiClient.publicUri('/api/rides/summary', {'userId': '$_userId'}),
      ApiClient.publicUri('/api/public/rides/summary', {'userId': '$_userId'}),
      ApiClient.publicUri('/api/rides/summaryByUser', {'userId': '$_userId'}),
    ];

    for (final uri in candidates) {
      try {
        final res = await ApiClient.get(uri.path, query: uri.queryParameters);
        if (res.statusCode < 200 || res.statusCode >= 300) continue;
        final obj = jsonDecode(res.body);

        Map<String, dynamic> m;
        if (obj is Map) {
          m = obj.cast<String, dynamic>();
        } else if (obj is List && obj.isNotEmpty && obj.first is Map) {
          m = (obj.first as Map).cast<String, dynamic>();
        } else {
          continue;
        }

        final totalKm = _firstNonNull<num>(m, ['totalKm','totalDistance','sumKm','distance','distKm'], _cleanNum)?.toDouble();
        if (totalKm != null) {
          setState(() {
            _totalDistance = totalKm;
            _wheels = totalKm / _lapKm;
          });
          return;
        }
      } catch (_) {}
    }
  }

  // ---- 게시물 로드 (이미지/텍스트 모두) ----
  Future<void> _loadPosts({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loadingPosts = true;
        _page = 0;
        _hasMore = true;
        _posts.clear();
      });
    }
    if (!_hasMore) return;

    try {
      final Map<String, String> q = {'page': '$_page', 'size': '$_size'};
      final List<Uri> paths = [
        if (_userId != null)
          ApiClient.publicUri('/api/public/users/${_userId}/posts', q),
        if (_userId != null)
          ApiClient.publicUri('/api/public/posts', {...q, 'userId': '$_userId'}),
        if (_userId != null)
          ApiClient.publicUri('/api/posts/user/${_userId}', q),
        if (_userId != null)
          ApiClient.publicUri('/api/posts', {...q, 'userId': '$_userId'}),
        if (widget.nickname != null && widget.nickname!.isNotEmpty)
          ApiClient.publicUri('/api/public/posts/by-nickname',
              {'nickname': widget.nickname!, ...q}),
        if (widget.nickname != null && widget.nickname!.isNotEmpty)
          ApiClient.publicUri('/api/posts',
              {'nickname': widget.nickname!, ...q}),
      ];

      List rawItems = const [];
      for (final uri in paths) {
        try {
          final res = await ApiClient.get(uri.path, query: uri.queryParameters);
          final decoded = jsonDecode(res.body);
          if (decoded is List) {
            rawItems = decoded;
            break;
          }
          if (decoded is Map) {
            if (decoded['content'] is List) {
              rawItems = decoded['content'];
              break;
            }
            if (decoded['data'] is List) {
              rawItems = decoded['data'];
              break;
            }
            if (decoded['items'] is List) {
              rawItems = decoded['items'];
              break;
            }
          }
        } catch (_) {}
      }

      // ------------------------------
      // ★ 클라이언트 측 안전 필터링
      // ------------------------------
      final int? targetId = _userId;
      final String? targetNick = (widget.nickname?.isNotEmpty ?? false)
          ? widget.nickname
          : (_nickname.isNotEmpty ? _nickname : null);

      if (rawItems.isNotEmpty && (targetId != null || (targetNick != null && targetNick.isNotEmpty))) {
        rawItems = rawItems.where((e) {
          if (e is! Map) return false;
          final m = e.cast<String, dynamic>();

          final uid = _cleanNum(m['userId']) ??
              _cleanNum(m['authorId']) ??
              _cleanNum(m['writerId']);

          if (targetId != null && uid != null) {
            return uid.toInt() == targetId;
          }

          final wn = _cleanString(m['writer']) ??
              _cleanString(m['nickname']) ??
              _cleanString(m['author']);

          if (targetNick != null && wn != null) {
            return wn == targetNick;
          }

          return false; // 기준 못 찾으면 섞이지 않도록 제외
        }).toList();
      }

      // ----------------------------------------
      // ★ 프로필 이미지 폴백: 소유 게시물일 때만 반영
      // ----------------------------------------
      if (_profileImageUrl == null && rawItems.isNotEmpty) {
        try {
          final first = (rawItems.first as Map).cast<String, dynamic>();

          final uid = _cleanNum(first['userId']) ??
              _cleanNum(first['authorId']) ??
              _cleanNum(first['writerId']);
          final wn = _cleanString(first['writer']) ??
              _cleanString(first['nickname']) ??
              _cleanString(first['author']);

          final isOwner = (targetId != null && uid != null && uid.toInt() == targetId) ||
              (targetNick != null && wn != null && wn == targetNick);

          if (isOwner) {
            final writerImg = _cleanString(
              first['writerProfileImage'] ??
                  first['profileImage'] ??
                  first['writerImage'] ??
                  first['authorImage'],
            );
            final abs = _absOrNull(writerImg);
            if (abs != null && abs.isNotEmpty) {
              setState(() => _profileImageUrl = abs);
            }
          }
        } catch (_) {}
      }

      // 매핑
      final fetched = rawItems.map<_PostThumb>((e) {
        final m = (e as Map).cast<String, dynamic>();
        return _PostThumb.fromJson(m, _absOrNull);
      }).toList();

      setState(() {
        _posts.addAll(fetched);
        _loadingPosts = false;
        _hasMore = fetched.length >= _size && rawItems.isNotEmpty;
        if (_hasMore) _page += 1;
      });
    } catch (e) {
      setState(() {
        _loadingPosts = false;
        _hasMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('게시물 불러오기 실패: $e')),
        );
      }
    }
  }

  void _onScroll() {
    if (!_hasMore || _loadingPosts) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 800) _loadPosts();
  }

  Future<void> _onRefresh() async {
    await _fetchProfile();
    await _fetchRideSummaryForUser();
    await _loadPosts(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            // ====== 상단: 안 잘리는 그라데이션 헤더 ======
            SliverAppBar(
              automaticallyImplyLeading: false,
              pinned: false,
              floating: false,
              snap: false,
              expandedHeight: 300,
              backgroundColor: Colors.transparent,
              leadingWidth: 48,
              leading: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: _HeaderGradientCard(
                  nickname: _nickname,
                  intro: _intro,
                  profileImage: _profileImageUrl,
                  totalDistance: _totalDistance,
                  region: _region,
                  wheels: _wheels,
                  lapKm: _lapKm,
                  badgeCount: _badgeCount,
                  titleName: _titleName,
                  titleLevel: _titleLevel,
                ),
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
            ),

            // ====== 게시물 그리드 ======
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
              sliver: _posts.isEmpty && !_loadingPosts
                  ? const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text('아직 게시물이 없어요.'),
                  ),
                ),
              )
                  : SliverGrid(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    if (index >= _posts.length) return const _TileLoading();
                    return _PostTile(thumb: _posts[index]);
                  },
                  childCount: _posts.length + (_hasMore ? 9 : 0),
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1,
                ),
              ),
            ),

            if (_loadingPosts)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ========= 상단 그라데이션 카드 (FlexibleSpace에서 사용) =========
class _HeaderGradientCard extends StatelessWidget {
  final String nickname;
  final String? intro;
  final String? profileImage;
  final num? totalDistance;

  final String? region;
  final double? wheels;
  final double lapKm;
  final int? badgeCount;
  final String? titleName;
  final int? titleLevel;

  const _HeaderGradientCard({
    required this.nickname,
    this.intro,
    this.profileImage,
    this.totalDistance,
    this.region,
    this.wheels,
    required this.lapKm,
    this.badgeCount,
    this.titleName,
    this.titleLevel,
  });

  @override
  Widget build(BuildContext context) {
    final ImageProvider avatar =
    (profileImage != null && profileImage!.isNotEmpty)
        ? NetworkImage(profileImage!)
        : const AssetImage('assets/image/logo.png');

    final double? wheel = wheels;
    final bool hasWheel = wheel != null;
    final String wheelText = hasWheel ? wheel!.toStringAsFixed(1) : '-';
    final String distText =
    (totalDistance != null) ? '${totalDistance!.toStringAsFixed(0)} km' : '- km';

    double? frac;
    double? remainKm;
    if (hasWheel) {
      frac = wheel - wheel.floorToDouble();
      remainKm = ((1 - frac) * lapKm);
    }

    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF5E7E), Color(0xFFFF7E9E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 닉네임
          Text(
            nickname,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          // 아바타 + 지표
          Row(children: [
            CircleAvatar(radius: 40, backgroundImage: avatar),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(region ?? '제주도',
                      style: const TextStyle(color: Colors.white, fontSize: 16)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        wheelText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (hasWheel) ...[
                        const SizedBox(width: 4),
                        const Text('바퀴',
                            style: TextStyle(color: Colors.white, fontSize: 16)),
                      ],
                      const Spacer(),
                      Text('누적거리 $distText',
                          style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (hasWheel && frac != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: frac!.clamp(0, 1),
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 6,
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (hasWheel && remainKm != null)
                    Text(
                      '${wheel!.floor() + 1}바퀴까지 ${remainKm!.ceil()} km 남음',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // 소개
          Text(
            (intro != null && intro!.trim().isNotEmpty)
                ? intro!.trim()
                : '한줄 소개가 없습니다.',
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// ====== 그리드용 썸네일 모델 (이미지/텍스트 지원) ======
class _PostThumb {
  final int id;
  final String? imageUrl;      // 절대 URL (없을 수 있음)
  final String? text;          // 텍스트 게시물 내용 (없을 수 있음)
  final int likeCount;
  final int commentCount;

  _PostThumb({
    required this.id,
    required this.imageUrl,
    required this.text,
    required this.likeCount,
    required this.commentCount,
  });

  static String? _pickFirstImageUrl(Map<String, dynamic> j, String? Function(String?) abs) {
    const single = [
      'imageUrl','thumbnail','thumbnailUrl','coverUrl','url','photoUrl',
      'firstImageUrl','mainImage','path','fileUrl'
    ];
    for (final k in single) {
      final v = j[k];
      if (v is String && v.trim().isNotEmpty) return abs(v);
    }
    const listKeys = ['images','imageUrls','photos','media','files','attachments'];
    for (final k in listKeys) {
      final v = j[k];
      if (v is List && v.isNotEmpty) {
        final first = v.first;
        if (first is String && first.trim().isNotEmpty) return abs(first);
        if (first is Map) {
          final fm = first.cast<String, dynamic>();
          final u = (fm['url'] as String?) ?? (fm['fileUrl'] as String?) ?? (fm['path'] as String?);
          if (u != null && u.trim().isNotEmpty) return abs(u);
        }
      }
    }
    const obj = ['image','thumbnail','cover','media','photo'];
    for (final k in obj) {
      final v = j[k];
      if (v is Map) {
        final m = v.cast<String, dynamic>();
        final u = (m['url'] as String?) ?? (m['fileUrl'] as String?) ?? (m['path'] as String?);
        if (u != null && u.trim().isNotEmpty) return abs(u);
      }
    }
    return null;
  }

  static String? _pickText(Map<String, dynamic> j) {
    const keys = ['content','text','body','caption','description','message'];
    for (final k in keys) {
      final v = j[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  factory _PostThumb.fromJson(Map<String, dynamic> j, String? Function(String?) abs) {
    int _asInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }
    final img = _pickFirstImageUrl(j, abs);
    final txt = _pickText(j);
    return _PostThumb(
      id: _asInt(j['id'] ?? j['postId'] ?? j['no'] ?? 0),
      imageUrl: img,
      text: txt,
      likeCount: _asInt(j['likeCount'] ?? j['likes'] ?? j['hearts']),
      commentCount: _asInt(j['commentCount'] ?? j['comments'] ?? j['replyCount']),
    );
  }
}

/// ====== 그리드 타일 (이미지/텍스트) ======
class _PostTile extends StatelessWidget {
  final _PostThumb thumb;
  const _PostTile({required this.thumb});

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailScreen(postId: thumb.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 텍스트-only 타일
    if (thumb.imageUrl == null) {
      final text = (thumb.text?.isNotEmpty == true) ? thumb.text! : '(텍스트)';
      return GestureDetector(
        onTap: () => _openDetail(context),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0x11000000)),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    text,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.2),
                  ),
                ),
              ),
              Positioned(
                right: 6,
                top: 6,
                child: _CounterChip(like: thumb.likeCount, comment: thumb.commentCount),
              ),
            ],
          ),
        ),
      );
    }

    // 이미지 타일
    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            thumb.imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0x11000000),
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined),
            ),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(color: const Color(0x11000000));
            },
          ),
          Positioned(
            right: 6,
            top: 6,
            child: _CounterChip(like: thumb.likeCount, comment: thumb.commentCount),
          ),
        ],
      ),
    );
  }
}

class _CounterChip extends StatelessWidget {
  final int like;
  final int comment;
  const _CounterChip({required this.like, required this.comment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black45, borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite, size: 12, color: Colors.white),
          const SizedBox(width: 3),
          Text('$like', style: const TextStyle(color: Colors.white, fontSize: 11)),
          const SizedBox(width: 6),
          const Icon(Icons.mode_comment, size: 12, color: Colors.white),
          const SizedBox(width: 3),
          Text('$comment', style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}

/// 로딩 타일
class _TileLoading extends StatelessWidget {
  const _TileLoading();
  @override
  Widget build(BuildContext context) {
    return Container(color: const Color(0x11000000));
  }
}

/// 마이페이지와 동일 느낌의 뱃지 미니 스트립(가로 스크롤 + 오버플로 방지)
class _BadgeStripMini extends StatelessWidget {
  final int count; // 서버에서 받은 뱃지 개수(없으면 0)
  const _BadgeStripMini({required this.count});

  @override
  Widget build(BuildContext context) {
    final all = <String>[
      'assets/badges/badge1.png',
      'assets/badges/badge2.png',
      'assets/badges/badge3.png',
      'assets/badges/badge4.png',
      'assets/badges/badge5.png',
      'assets/badges/badge6.png',
    ];

    final showCount = count.clamp(0, all.length);
    final show = all.take(showCount).toList();

    return Row(
      children: [
        const Text('뱃지', style: TextStyle(color: Colors.white70, fontSize: 15)),
        const SizedBox(width: 6),
        const Text('|', style: TextStyle(fontSize: 20, color: Colors.white)),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final path in show)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Image.asset(
                        path,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Text('🍊', style: TextStyle(fontSize: 22)),
                      ),
                    ),
                  ),
                if (count > show.length)
                  Text(
                    '+${count - show.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
