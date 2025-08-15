import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Course_Detailmap.dart';

class Inland4_Map extends StatelessWidget {
  const Inland4_Map({super.key});

  @override
  Widget build(BuildContext context) {
    return CourseDetailmap(
      start: const LatLng(33.446222, 126.557502),
      end: const LatLng(33.318030, 126.598598),
      startTitle: '출발',
      endTitle: '도착',

      orsJsonAssetPath:
      'assets/routes/Inland4/ors-route_1755151207874.json',
    );
  }

}