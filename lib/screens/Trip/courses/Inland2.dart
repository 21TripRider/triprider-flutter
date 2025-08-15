      import 'package:flutter/material.dart';
      import 'package:google_maps_flutter/google_maps_flutter.dart';
      import '../Course_Detailmap.dart';

      class Inland2_Map extends StatelessWidget {
        const Inland2_Map({super.key});

        @override
        Widget build(BuildContext context) {
          return CourseDetailmap(
            start: const LatLng(33.434754, 126.724793),
            end: const LatLng(33.361270, 126.766476),
            startTitle: '출발',
            endTitle: '도착',

            orsJsonAssetPath:
            'assets/routes/Inland2/ors-route_1755149841325.json',
          );
        }

      }