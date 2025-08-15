import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Course_Detailmap.dart';

class Coast10_Map extends StatelessWidget {
  const Coast10_Map({super.key});

  @override
  Widget build(BuildContext context) {
    return CourseDetailmap(
      start: const LatLng(33.5130249007841, 126.89818382263185),
      end:   const LatLng(33.526119796464705, 126.86528921127321),
      startTitle: '출발',
      endTitle: '도착',

      orsJsonAssetPath:
      'assets/routes/Coast10/ors-route_1755157841034.json',
    );
  }
}