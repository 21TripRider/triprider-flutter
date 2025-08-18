// lib/screens/Trip/Course_Detail_With_Nearby.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:triprider/screens/Trip/API/Nearby_Api.dart';

import 'package:triprider/screens/Trip/Course_Detailmap.dart';


class CourseDetailWithNearby extends StatefulWidget {
  const CourseDetailWithNearby({
    super.key,
    // 지도 표시에 필요한 정보
    required this.points,
    required this.start,
    required this.end,
    this.startTitle = '출발',
    this.endTitle = '도착',
    // 백엔드 조회용 코스 식별자 (카테고리/ID)
    required this.courseCategory,
    required this.courseId,
  });

  final List<LatLng> points;
  final LatLng start;
  final LatLng end;
  final String startTitle;
  final String endTitle;

  final String courseCategory;
  final int courseId;

  @override
  State<CourseDetailWithNearby> createState() => _CourseDetailWithNearbyState();
}

class _CourseDetailWithNearbyState extends State<CourseDetailWithNearby> {
  GoogleMapController? _map;
  late final Polyline _route;
  late final Set<Marker> _markers;
  late final LatLngBounds _bounds;

  NearbyCategory _selected = NearbyCategory.tourist;
  late Future<List<NearbyItem>> _future;

  @override
  void initState() {
    super.initState();
    _route = Polyline(
      polylineId: const PolylineId('route'),
      points: widget.points,
      color: Colors.blue,
      width: 6,
    );
    _markers = {
      Marker(
        markerId: const MarkerId('start'),
        position: widget.start,
        infoWindow: InfoWindow(title: widget.startTitle),
      ),
      Marker(
        markerId: const MarkerId('end'),
        position: widget.end,
        infoWindow: InfoWindow(title: widget.endTitle),
      ),
    };
    _bounds = _computeBounds(widget.points);

    // ✅ 백엔드에서 섹터별 장소 조회
    _future = NearbyApi.fetchByCourse(
      _selected,
      courseCategory: widget.courseCategory,
      courseId: widget.courseId,
      radius: 3000,
      size: 8,
      mode: 'sme',
      count: 5,
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          padding: const EdgeInsets.only(left: 8),
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios),
        ),
        title: const Text('코스 상세'),
      ),
      body: Column(
        children: [
          // 상단 1/3 지도
          SizedBox(
            height: h / 3,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: widget.start, zoom: 12),
                  onMapCreated: (c) {
                    _map = c;
                    WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
                  },
                  polylines: {_route},
                  markers: _markers,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CourseDetailmap(
                            start: widget.start,
                            end: widget.end,
                            startTitle: widget.startTitle,
                            endTitle: widget.endTitle,
                            points: widget.points,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.fullscreen),
                    label: const Text('전체 보기'),
                  ),
                ),
              ],
            ),
          ),

          // 섹터 칩 (백엔드 7개 고정)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: NearbyCategory.values.map((cat) {
                final selected = _selected == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat.title),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _selected = cat;
                        _future = NearbyApi.fetchByCourse(
                          _selected,
                          courseCategory: widget.courseCategory,
                          courseId: widget.courseId,
                        );
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // 리스트
          Expanded(
            child: FutureBuilder<List<NearbyItem>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('로드 실패: ${snap.error}'));
                }
                final items = snap.data ?? const [];
                if (items.isEmpty) return const Center(child: Text('표시할 장소가 없습니다.'));

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final p = items[i];
                    return _PoiTile(
                      item: p,
                      onTap: () => _focusTo(LatLng(p.lat, p.lng)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fitBounds() async {
    if (_map == null) return;
    await Future.delayed(const Duration(milliseconds: 80));
    try {
      await _map!.animateCamera(CameraUpdate.newLatLngBounds(_bounds, 32));
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 160));
      await _map!.animateCamera(CameraUpdate.newLatLngBounds(_bounds, 32));
    }
  }

  Future<void> _focusTo(LatLng p) async {
    if (_map == null) return;
    await _map!.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: p, zoom: 14),
    ));
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'poi');
      _markers.add(Marker(markerId: const MarkerId('poi'), position: p));
    });
  }

  LatLngBounds _computeBounds(List<LatLng> pts) {
    double? minLat, maxLat, minLng, maxLng;
    for (final p in pts) {
      minLat = (minLat == null) ? p.latitude : (p.latitude < minLat ? p.latitude : minLat);
      maxLat = (maxLat == null) ? p.latitude : (p.latitude > maxLat ? p.latitude : maxLat);
      minLng = (minLng == null) ? p.longitude : (p.longitude < minLng ? p.longitude : minLng);
      maxLng = (maxLng == null) ? p.longitude : (p.longitude > maxLng ? p.longitude : maxLng);
    }
    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }
}

class _PoiTile extends StatelessWidget {
  const _PoiTile({required this.item, required this.onTap});
  final NearbyItem item;
  final VoidCallback onTap;

  bool get _hasThumb => (item.thumbUrl?.startsWith('http') ?? false);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 92,
          child: Row(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: _hasThumb
                    ? Image.network(
                  item.thumbUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(),
                )
                    : _placeholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        item.addr ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      if (item.distanceM != null) ...[
                        const Spacer(),
                        Text(
                          '${(item.distanceM! / 1000).toStringAsFixed(1)} km',
                          style: const TextStyle(color: Colors.black45),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => const ColoredBox(
    color: Color(0x11000000),
    child: Center(child: Icon(Icons.photo, color: Colors.black38)),
  );
}
