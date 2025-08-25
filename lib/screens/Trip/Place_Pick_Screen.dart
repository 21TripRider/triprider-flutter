// lib/screens/trip/place_pick_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:triprider/screens/RiderGram/Api_client.dart';
import 'package:triprider/screens/Trip/Custom_Course_Detail_Screen.dart';
import 'package:triprider/screens/trip/models.dart';

class PlacePickScreen extends StatefulWidget {
  final List<CategoryOption> options;
  const PlacePickScreen({super.key, required this.options});

  @override
  State<PlacePickScreen> createState() => _PlacePickScreenState();
}

class _PlacePickScreenState extends State<PlacePickScreen>
    with SingleTickerProviderStateMixin {
  static const _jeju = LatLng(33.3846, 126.5535);
  late final TabController _tab;
  String? _selectionId;
  bool _loading = true;
  bool _optimize = true;

  final _results = <int, List<NearbyPlace>>{};
  final _picked = <NearbyPlace>[];

  GoogleMapController? _map;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: widget.options.length, vsync: this);
    _initSessionAndLoad();
  }

  @override
  void dispose() {
    _tab.dispose();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _initSessionAndLoad() async {
    try {
      final res = await ApiClient.post('/api/custom/selection/sessions');
      final sid = (jsonDecode(res.body) as Map<String, dynamic>)['selectionId'] as String;
      _selectionId = sid;

      await _loadTab(_tab.index);
      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('세션 생성 실패: $e')));
    }
  }

  Future<void> _loadTab(int i) async {
    if (_results.containsKey(i)) return;
    final opt = widget.options[i];

    try {
      List items;

      if ((opt.presetKey ?? '').isNotEmpty) {
        // Preset 호출
        final res = await ApiClient.get('/api/custom/places/preset', query: {
          'key': opt.presetKey!,
          'page': 1,
          'limit': 20,
        });
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        items = (data['items'] ?? []);
      } else {
        // 일반 카테고리 호출
        final res = await ApiClient.get('/api/custom/places', query: {
          'type': opt.type,
          'lat': _jeju.latitude,
          'lng': _jeju.longitude,
          'radius': 3000,
          'scope': 'jeju',
          if (opt.cat1 != null) 'cat1': opt.cat1!,
          if (opt.cat2 != null) 'cat2': opt.cat2!,
          if (opt.cat3 != null) 'cat3': opt.cat3!,
          'page': 1,
          'limit': 20,
        });
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        items = (data['items'] ?? []);
      }

      _results[i] = items.map((e) => NearbyPlace.fromJson(e)).toList().cast<NearbyPlace>();
      setState(() {});
    } catch (e) {
      _results[i] = [];
      setState(() {});
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('장소 로드 실패: $e')));
    }
  }

  Future<void> _add(NearbyPlace p) async {
    if (_selectionId == null) return;
    final opt = widget.options[_tab.index]; // 현재 탭의 유형 사용
    try {
      await ApiClient.post('/api/custom/selection/${_selectionId!}/picks', body: {
        'contentId': p.contentId ?? p.title,
        'type': opt.type, // ← 탭의 type 그대로 전달 (tour/food/leports/culture/event/shop)
        'title': p.title,
        'lat': p.lat,
        'lng': p.lng,
        'cat1': p.cat1,
        'cat2': p.cat2,
        'cat3': p.cat3,
        'contentTypeId': p.contentTypeId,
        'addr': p.addr,
        'image': p.image,
      });
      setState(() => _picked.add(p));
      _fitMap();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('추가 실패: $e')));
    }
  }

  Future<void> _remove(NearbyPlace p) async {
    if (_selectionId == null) return;
    try {
      await ApiClient.delete('/api/custom/selection/${_selectionId!}/picks/${p.contentId ?? p.title}');
      setState(() => _picked.removeWhere((e) => (e.contentId ?? e.title) == (p.contentId ?? p.title)));
      _fitMap();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('제거 실패: $e')));
    }
  }

  void _fitMap() async {
    if (_map == null || _picked.isEmpty) return;
    double? minLat, maxLat, minLng, maxLng;
    for (final p in _picked) {
      minLat = (minLat == null) ? p.lat : (p.lat < minLat ? p.lat : minLat);
      maxLat = (maxLat == null) ? p.lat : (p.lat > maxLat ? p.lat : maxLat);
      minLng = (minLng == null) ? p.lng : (p.lng < minLng ? p.lng : minLng);
      maxLng = (maxLng == null) ? p.lng : (p.lng > maxLng ? p.lng : maxLng);
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat!, minLng!), northeast: LatLng(maxLat!, maxLng!),
    );
    await _map!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  Future<void> _preview() async {
    if (_selectionId == null || _picked.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('두 곳 이상 선택해 주세요.')));
      return;
    }
    try {
      final res = await ApiClient.post('/api/custom/courses/auto', body: {
        'selectionId': _selectionId!,
        'optimize': _optimize,
      });
      final preview = CoursePreview.fromJson(jsonDecode(res.body));
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CourseDetailScreen.preview(preview: preview)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('코스 생성 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.options.map((o) => Tab(text: o.label)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('장소 선택'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: tabs,
          onTap: (i) => _loadTab(i),
        ),
        actions: [
          Row(children: [
            const Text('최단거리', style: TextStyle(fontSize: 13)),
            Switch(value: _optimize, onChanged: (v) => setState(() => _optimize = v)),
          ]),
          TextButton(
            onPressed: _preview,
            child: const Text('완료', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
        SizedBox(
          height: 220,
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(target: _jeju, zoom: 10.8),
            onMapCreated: (c) => _map = c,
            markers: {
              ..._picked.asMap().entries.map((e) {
                final idx = e.key + 1;
                final p = e.value;
                return Marker(
                  markerId: MarkerId('p$idx'),
                  position: LatLng(p.lat, p.lng),
                  infoWindow: InfoWindow(title: '$idx. ${p.title}', snippet: p.addr),
                );
              }),
            },
            polylines: _buildPolyline(),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: List.generate(widget.options.length, (i) {
              final list = _results[i] ?? [];
              if (list.isEmpty) {
                return const Center(child: Text('검색 결과가 없습니다.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (_, idx) {
                  final p = list[idx];
                  final isPicked = _picked.any((e) => (e.contentId ?? e.title) == (p.contentId ?? p.title));
                  return _PlaceTile(
                    place: p,
                    picked: isPicked,
                    onAdd: () => _add(p),
                    onRemove: () => _remove(p),
                  );
                },
              );
            }),
          ),
        ),
      ]),
    );
  }

  Set<Polyline> _buildPolyline() {
    if (_picked.length < 2) return {};
    final pts = _picked.map((e) => LatLng(e.lat, e.lng)).toList();
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: pts,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(8)],
        color: Colors.red,
      ),
    };
  }
}

class _PlaceTile extends StatelessWidget {
  final NearbyPlace place;
  final bool picked;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  const _PlaceTile({
    required this.place,
    required this.picked,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: (place.image ?? '').isNotEmpty
            ? Image.network(place.image!, width: 84, height: 84, fit: BoxFit.cover)
            : Container(width: 84, height: 84, color: const Color(0x11000000),
            alignment: Alignment.center, child: const Icon(Icons.image_not_supported)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(place.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(place.addr, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54)),
          if (place.distMeters != null)
            Text('${place.distMeters} m', style: const TextStyle(fontSize: 12, color: Colors.black45)),
        ]),
      ),
      TextButton.icon(
        onPressed: picked ? onRemove : onAdd,
        icon: Icon(picked ? Icons.remove : Icons.add, size: 16),
        label: Text(picked ? '제거' : '추가'),
      ),
    ]);
  }
}
