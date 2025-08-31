import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:triprider/screens/Trip/API/Nearby_Api.dart';
import 'package:triprider/screens/Trip/Course_Detailmap.dart';

class CourseDetailWithNearby extends StatefulWidget {
  const CourseDetailWithNearby({
    super.key,
    required this.points,
    required this.start,
    required this.end,
    this.startTitle = '출발',
    this.endTitle = '도착',
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
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
        ),
        title: const Text(
          '코스 상세',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // 지도
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
                  child: FloatingActionButton.extended(
                    heroTag: "btn1",
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 3,
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

          // 아래 영역 (카드 스타일)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  )
                ],
              ),
              child: Column(
                children: [
                  // 카테고리 버튼
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: NearbyCategory.values.map((cat) {
                        final selected = _selected == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ChoiceChip(
                            label: Row(
                              children: [
                                Icon(_iconFor(cat),
                                    size: 18,
                                    color: selected ? Colors.white : Colors.black54),
                                const SizedBox(width: 4),
                                Text(cat.title),
                              ],
                            ),
                            selected: selected,
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : Colors.black87,
                            ),
                            selectedColor: const Color(0xffFF5F9E), // 핑크
                            backgroundColor: Colors.grey.shade100,
                            side: BorderSide(
                              color: selected
                                  ? Colors.pinkAccent
                                  : Colors.grey.shade400,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
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
                        if (items.isEmpty) {
                          return const Center(child: Text('표시할 장소가 없습니다.'));
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
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
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(NearbyCategory cat) {
    switch (cat) {
      case NearbyCategory.tourist:
        return Icons.park;
      case NearbyCategory.culture:
        return Icons.account_balance;
      case NearbyCategory.event:
        return Icons.celebration;
      case NearbyCategory.leports:
        return Icons.sports_soccer;
      case NearbyCategory.stay:
        return Icons.hotel;
      case NearbyCategory.shop:
        return Icons.shopping_bag;
      case NearbyCategory.food:
        return Icons.restaurant;
    }
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

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 100,
          child: Row(
            children: [
              // 썸네일
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: _buildThumb(),
              ),
              const SizedBox(width: 12),
              // 텍스트
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        item.addr ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      if (item.distanceM != null) ...[
                        const Spacer(),
                        Chip(
                          label: Text('${(item.distanceM! / 1000).toStringAsFixed(1)} km'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.pink.shade50,
                          labelStyle: const TextStyle(color: Colors.pink),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 12.0),
                child: Icon(Icons.arrow_forward_ios, size: 18, color: Colors.black45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumb() {
    if (item.thumbUrl.startsWith('http')) {
      return Image.network(
        item.thumbUrl,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          _resolveDefaultAsset(),
          width: 100,
          height: 100,
          fit: BoxFit.cover,
        ),
      );
    } else {
      return Image.asset(
        item.thumbUrl,
        width: 100,
        height: 100,
        fit: BoxFit.cover,
      );
    }
  }

  String _resolveDefaultAsset() {
    switch (item.contentTypeId) {
      case 12: return 'assets/image/tour.png';
      case 14: return 'assets/image/culture.png';
      case 15: return 'assets/image/event.png';
      case 28: return 'assets/image/leports.png';
      case 32: return 'assets/image/stay.png';
      case 38: return 'assets/image/shop.png';
      case 39: return 'assets/image/food.png';
      default: return 'assets/image/tour.png';
    }
  }
}
