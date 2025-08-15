import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Course_Detailmap.dart';

class Coast1_Map extends StatelessWidget {
  const Coast1_Map({super.key});

  @override
  Widget build(BuildContext context) {
    return CourseDetailmap(
      start: const LatLng(33.515610, 126.510473),
      end:   const LatLng(33.503412, 126.454479),
      startTitle: '출발',
      endTitle: '도착',

      orsJsonAssetPath:
      'assets/routes/Coast1/ors-route_1755153540754.json',
    );
  }
}
