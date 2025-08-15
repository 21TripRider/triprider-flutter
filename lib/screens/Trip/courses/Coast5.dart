import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Course_Detailmap.dart';

class Coast5_Map extends StatelessWidget {
  const Coast5_Map({super.key});

  @override
  Widget build(BuildContext context) {
    return CourseDetailmap(
      start: const LatLng(33.233852900131055, 126.37819737195971),
      end:   const LatLng(33.24106996954097, 126.3964766263962),
      startTitle: '출발',
      endTitle: '도착',

      orsJsonAssetPath:
      'assets/routes/Coast5/ors-route_1755155632325.json',
    );
  }
}
