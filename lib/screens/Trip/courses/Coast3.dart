import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Course_Detailmap.dart';

class Coast3_Map extends StatelessWidget {
  const Coast3_Map({super.key});

  @override
  Widget build(BuildContext context) {
    return CourseDetailmap(
      start: const LatLng(33.445452, 126.294736),
      end:   const LatLng(33.426676, 126.264198),
      startTitle: '출발',
      endTitle: '도착',

      orsJsonAssetPath:
      'assets/routes/Coast3/ors-route_1755154596691.json',
    );
  }
}
