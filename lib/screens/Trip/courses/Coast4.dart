import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Course_Detailmap.dart';

class Coast4_Map extends StatelessWidget {
  const Coast4_Map({super.key});

  @override
  Widget build(BuildContext context) {
    return CourseDetailmap(
      start: const LatLng(33.28565586156556, 126.1634945869446),
      end:   const LatLng(33.241729504147415, 126.22449874877931),
      startTitle: '출발',
      endTitle: '도착',

      orsJsonAssetPath:
      'assets/routes/Coast4/ors-route_1755154991078.json',
    );
  }
}
