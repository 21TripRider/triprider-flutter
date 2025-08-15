import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Course_Detailmap.dart';

class Coast9_Map extends StatelessWidget {
  const Coast9_Map({super.key});

  @override
  Widget build(BuildContext context) {
    return CourseDetailmap(
      start: const LatLng(33.38259410131823, 126.88022375106813),
      end:   const LatLng(33.405185106871755, 126.90419197082521),
      startTitle: '출발',
      endTitle: '도착',

      orsJsonAssetPath:
      'assets/routes/Coast9/ors-route_1755157606508.json',
    );
  }
}