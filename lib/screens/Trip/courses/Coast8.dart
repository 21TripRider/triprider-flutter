import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Course_Detailmap.dart';

class Coast8_Map extends StatelessWidget {
  const Coast8_Map({super.key});

  @override
  Widget build(BuildContext context) {
    return CourseDetailmap(
      start: const LatLng(33.30341659295311, 126.80658102035524),
      end:   const LatLng(33.32507342319544, 126.84733986854555),
      startTitle: '출발',
      endTitle: '도착',

      orsJsonAssetPath:
      'assets/routes/Coast8/ors-route_1755157157182.json',
    );
  }
}