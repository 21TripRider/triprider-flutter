import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Course_Detailmap.dart';

class UdoElectricRentcarMap extends StatelessWidget {
  const UdoElectricRentcarMap({super.key});

  @override
  Widget build(BuildContext context) {
    return CourseDetailmap(
      start: const LatLng(33.511056, 126.943441),   // 우도전기렌트카
      end:   const LatLng(33.516624, 126.958287),   // 하고수동 방사탑
      startTitle: '출발',
      endTitle: '도착',

      orsJsonAssetPath:
      'assets/routes/UdoElectricRentcar/ors-route_1755092065670.json',
    );
  }
}
