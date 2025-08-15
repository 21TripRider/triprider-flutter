import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Course_Detailmap.dart';

class Inland5_Map extends StatelessWidget {
  const Inland5_Map({super.key});

  @override
  Widget build(BuildContext context) {
    return CourseDetailmap(
      start: const LatLng(33.414495, 126.480667),
      end: const LatLng(33.290706, 126.460971),
      startTitle: '출발',
      endTitle: '도착',

      orsJsonAssetPath:
      'assets/routes/Inland5/ors-route_1755151567724.json',
    );
  }

}