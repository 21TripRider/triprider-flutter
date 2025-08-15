import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Course_Detailmap.dart';

class Coast7_Map extends StatelessWidget {
  const Coast7_Map({super.key});

  @override
  Widget build(BuildContext context) {
    return CourseDetailmap(
      start: const LatLng(33.24220508383717, 126.61668062210084),
      end:   const LatLng(33.258382225225695, 126.62424445152284),
      startTitle: '출발',
      endTitle: '도착',

      orsJsonAssetPath:
      'assets/routes/Coast7/ors-route_1755156948329.json',
    );
  }
}