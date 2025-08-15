import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Course_Detailmap.dart';

class UdoFerryMap extends StatelessWidget {
  const UdoFerryMap({super.key});

  @override
  Widget build(BuildContext context) {
    return CourseDetailmap(
      start: const LatLng(33.496625, 126.968696),  //우도레저선착장
      end:   const LatLng(33.514948, 126.972016),  //비양도등대
      startTitle: '우도레저선착장',
      endTitle: '비양도등대',

      orsJsonAssetPath:
      'assets/routes/UdoFerry/ors-route_1755075508408.json', // 해당 코스 JSON
    );
  }
}
