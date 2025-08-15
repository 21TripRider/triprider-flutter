import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Course_Detailmap.dart';

class Inland1_Map extends StatelessWidget {
  const Inland1_Map({super.key});

  @override
  Widget build(BuildContext context) {
    return CourseDetailmap(
      start: const LatLng(33.527760, 126.644836),   // 조천리,제주특별자치도 제주시 조천읍
      end:   const LatLng(33.343894, 126.703439),   //
      startTitle: '출발',
      endTitle: '도착',

      orsJsonAssetPath:
      'assets/routes/Inland1/ors-route_1755149124757.json',
    );
  }
}
