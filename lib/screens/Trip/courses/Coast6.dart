import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Course_Detailmap.dart';

class Coast6_Map extends StatelessWidget {
  const Coast6_Map({super.key});

  @override
  Widget build(BuildContext context) {
    return CourseDetailmap(
      start: const LatLng(33.54262423249732, 126.66954159736635),
      end:   const LatLng(33.52456353971891, 126.8610191345215),
      startTitle: '출발',
      endTitle: '도착',

      orsJsonAssetPath:
      'assets/routes/Coast6/ors-route_1755156213032.json',
    );
  }
}