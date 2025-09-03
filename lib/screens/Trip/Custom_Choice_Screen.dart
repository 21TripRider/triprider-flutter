// lib/screens/trip/custom_choice_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:triprider/core/network/Api_client.dart';
import 'package:triprider/screens/trip/place_pick_screen.dart';
import 'package:triprider/screens/trip/models.dart';

class CustomChoiceScreen extends StatefulWidget {
  const CustomChoiceScreen({super.key});
  @override
  State<CustomChoiceScreen> createState() => _CustomChoiceScreenState();
}

class _CustomChoiceScreenState extends State<CustomChoiceScreen> {
  // ===== Theme tokens (UI만 변경) =====
  static const _bg = Color(0xFFF7F7FB);
  static const _primary = Color(0xFFFF4E6B);
  static const _headerPink = Color(0xFFFFA6B5);
  static const _chipBg = Color(0xFFF0F1F5);
  static const _chipSelectedBg = Color(0xFFFFF1F4);
  static const _chipBorder = Color(0xFFE5E6EC);
  static const _titleColor = Color(0xFF1C1C1E);
  static const _textSub = Color(0xFF6B6B73);

  final _selected = <CategoryOption>[];

  CategoryTreeDto? _tourTree;    // 12
  CategoryTreeDto? _foodTree;    // 39
  CategoryTreeDto? _leportsTree; // 28
  CategoryTreeDto? _cultureTree; // 14
  CategoryTreeDto? _eventTree;   // 15
  CategoryTreeDto? _shopTree;    // 38

  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadTrees();
  }

  Future<void> _loadTrees() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final resTour    = await ApiClient.get('/api/custom/categories', query: {'type': 'tour'});
      final resFood    = await ApiClient.get('/api/custom/categories', query: {'type': 'food'});
      final resLeports = await ApiClient.get('/api/custom/categories', query: {'type': 'leports'});
      final resCulture = await ApiClient.get('/api/custom/categories', query: {'type': 'culture'});
      final resEvent   = await ApiClient.get('/api/custom/categories', query: {'type': 'event'});
      final resShop    = await ApiClient.get('/api/custom/categories', query: {'type': 'shop'});

      _tourTree    = CategoryTreeDto.fromJson(jsonDecode(resTour.body));
      _foodTree    = CategoryTreeDto.fromJson(jsonDecode(resFood.body));
      _leportsTree = CategoryTreeDto.fromJson(jsonDecode(resLeports.body));
      _cultureTree = CategoryTreeDto.fromJson(jsonDecode(resCulture.body));
      _eventTree   = CategoryTreeDto.fromJson(jsonDecode(resEvent.body));
      _shopTree    = CategoryTreeDto.fromJson(jsonDecode(resShop.body));

      setState(() { _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = '카테고리 로드 실패: $e'; });
    }
  }

  // ---------------- 공통 UI 유틸 ----------------
  void _toggle(CategoryOption c) {
    setState(() {
      final i = _selected.indexWhere((x) =>
      x.type == c.type && x.cat1 == c.cat1 && x.cat2 == c.cat2 && x.cat3 == c.cat3 && x.presetKey == c.presetKey);
      if (i >= 0) _selected.removeAt(i); else _selected.add(c);
    });
  }

  int? _order(CategoryOption c) {
    final idx = _selected.indexWhere((x) =>
    x.type == c.type && x.cat1 == c.cat1 && x.cat2 == c.cat2 && x.cat3 == c.cat3 && x.presetKey == c.presetKey);
    return idx >= 0 ? idx + 1 : null;
  }

  // 그림자·사각 배경 제거, 플랫 칩
  Widget _chip(CategoryOption c) {
    final selected = _selected.any((x) =>
    x.type == c.type && x.cat1 == c.cat1 && x.cat2 == c.cat2 && x.cat3 == c.cat3 && x.presetKey == c.presetKey);
    final order = _order(c);

    return InkWell(
      onTap: () => _toggle(c),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _chipSelectedBg : _chipBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? _primary.withOpacity(0.45) : _chipBorder, width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            c.label,
            style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: selected ? _primary : _titleColor,
            ),
          ),
          if (order != null) ...[
            const SizedBox(width: 6),
            Container(
              width: 20, height: 20, alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? _primary.withOpacity(0.18) : _chipBorder,
              ),
              child: Text(
                '$order',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: selected ? _primary : _textSub,
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _section(String title, List<CategoryOption> options) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 타이틀
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: _titleColor,
                height: 1.15,
              ),
            ),
          ),
          // 칩 그룹 (배경 통일)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10, runSpacing: 10,
              children: options.map(_chip).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 옵션(백엔드 프리셋과 1:1) ----------------

  // 1) 관광지: 자연 / 역사
  List<CategoryOption> _optsTour() => [
    CategoryOption(type: 'tour', label: '자연', presetKey: 'tour.nature'),
    CategoryOption(type: 'tour', label: '역사', presetKey: 'tour.history'),
  ];

  // 2) 음식점: 맛집(통합)
  List<CategoryOption> _optsFood() => [
    CategoryOption(type: 'food', label: '맛집', cat1: 'A05'),
  ];

  // 3) 레포츠: 육상 / 수상
  List<CategoryOption> _optsLeports() => [
    CategoryOption(type: 'leports', label: '육상', presetKey: 'leports.land'),
    CategoryOption(type: 'leports', label: '수상', presetKey: 'leports.water'),
  ];

  // 4) 문화시설(14): 박물관 / 기념관 / 미술관
  List<CategoryOption> _optsCulture() => [
    CategoryOption(type: 'culture', label: '박물관', presetKey: 'culture.museum'),
    CategoryOption(type: 'culture', label: '기념관', presetKey: 'culture.memorial'),
    CategoryOption(type: 'culture', label: '미술관', presetKey: 'culture.art'), // ← 여기! (수정 완료)
  ];


// 5) 축제/행사(15): 공연 / 축제
  List<CategoryOption> _optsEvent() => [
    CategoryOption(type: 'event', label: '공연', presetKey: 'event.performance'),
    CategoryOption(type: 'event', label: '축제', presetKey: 'event.exhibition'),      // ← 여기!(수정 완료)
  ];



  // 6) 쇼핑: 전통시장 / 면세점
  List<CategoryOption> _optsShop() => [
    CategoryOption(type: 'shop', label: '전통시장', presetKey: 'shop.traditional'),
    CategoryOption(type: 'shop', label: '면세점',   presetKey: 'shop.dutyfree'),
  ];

  // ---------------- BUILD ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,

      body: Stack(
        children: [
          // 상단 전체를 덮는 배경 (SafeArea 위까지)
          Container(
            height: 200, // 충분히 크게 (노치 포함)
            width: double.infinity,
            color: _headerPink,
          ),

          SafeArea(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error.isNotEmpty
                  ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
                  : // BUILD 내부의 CustomScrollView 부분만 교체
              CustomScrollView(
                slivers: [
                  // 1) 핑크 헤더(상단 전체 배경 포함)
                  SliverToBoxAdapter(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(0, 18, 20, 22),
                      color: _headerPink,
                      child: Row(


                        children: [

                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios_new),
                          ),

                          const Text(
                            '원하는 카테고리를 선택하여\n맞춤형 여행 코스를 생성해보세요',
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2) 본문 시작: 흰색 패널 (둥근 모서리 + 살짝 그림자)
                  SliverToBoxAdapter(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x14000000), // 아주 은은한 그림자
                            blurRadius: 12,
                            offset: Offset(0, -2),
                          ),
                        ],
                      ),
                      // 패널 안쪽 컨텐츠
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),          // 패널 상단 여백
                          _section('관광지', _optsTour()),
                          _section('음식점', _optsFood()),
                          _section('레포츠', _optsLeports()),
                          _section('문화시설', _optsCulture()),
                          _section('축제/행사', _optsEvent()),
                          _section('쇼핑', _optsShop()),
                          const SizedBox(height: 100),         // 하단 버튼과 간격
                        ],
                      ),
                    ),
                  ),
                ],
              )
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PlacePickScreen(options: _selected)),
              ),
              child: const Text('다음', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }
}