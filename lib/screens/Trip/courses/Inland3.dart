import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Course_Detailmap.dart';

class Inland3_Map extends StatelessWidget {
  const Inland3_Map({super.key});

  @override
  Widget build(BuildContext context) {
    return CourseDetailmap(
      start: const LatLng(33.326285, 126.380952),
      end: const LatLng(33.317703, 126.598491),
      startTitle: '출발',
      endTitle: '도착',

      orsJsonAssetPath:
      'assets/routes/Inland3/ors-route_1755150907407.json',
    );
  }

}