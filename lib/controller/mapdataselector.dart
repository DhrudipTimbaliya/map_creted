// map_data_selected_controller.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapDataSelectedController extends GetxController {
  final Rx<MapType> selectedMapType = MapType.normal.obs;

  final List<Map<String, dynamic>> mapTypes = [
    {'type': MapType.normal, 'name': 'Normal', 'icon': Icons.map},
    {'type': MapType.satellite, 'name': 'Satellite', 'icon': Icons.satellite},
    {'type': MapType.hybrid, 'name': 'Hybrid', 'icon': Icons.layers},
    {'type': MapType.terrain, 'name': 'Terrain', 'icon': Icons.terrain},
  ];

  void changeMapType(MapType newType) {
    if (selectedMapType.value != newType) {
      selectedMapType.value = newType;
    }
  }

  String get currentName => mapTypes
      .firstWhere((e) => e['type'] == selectedMapType.value, orElse: () => mapTypes[0])['name'];

  IconData get currentIcon => mapTypes
      .firstWhere((e) => e['type'] == selectedMapType.value)['icon'];
}