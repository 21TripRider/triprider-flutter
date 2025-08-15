import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Course_Detailmap.dart';

class Coast2_Map extends StatelessWidget {
  const Coast2_Map({super.key});

  @override
  Widget build(BuildContext context) {
    return CourseDetailmap(
      start: const LatLng(33.483618, 126.376985),
      end:   const LatLng(33.467045, 126.337593),
      startTitle: '출발',
      endTitle: '도착',

      orsJsonAssetPath:
      'assets/routes/Coast2/ors-route_1755154145825.json',
    );
  }
}
