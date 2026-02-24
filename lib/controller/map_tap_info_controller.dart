import 'dart:ui';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dio/dio.dart' as dio_pkg;

import '../api/place_serviece.dart';
import '../model/place_model.dart';
import 'map_controller.dart';

class MapTapInfoController extends GetxController {
  final PlacesService _placesService = PlacesService();
  final MapController findPLaceController = Get.find<MapController>();
  final dio_pkg.Dio _dio = dio_pkg.Dio();

  RxSet<Polyline> polylines = <Polyline>{}.obs;
  RxBool isLoading = false.obs;
  RxBool isBottomSheetOpen = false.obs;
  Rx<PlaceModel?> selectedPlace = Rx<PlaceModel?>(null);
  Rx<LatLng?> selectedLatLng = Rx<LatLng?>(null);

  @override
  void onInit() {
    requestLocationPermission();
    super.onInit();
  }

  Future<void> requestLocationPermission() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      getCurrentLocation();
    } else {
      Get.snackbar("Permission Denied", "Please enable location to use the map.");
    }
  }

  Future<Position?> getCurrentLocation() async {
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  // --- આ મેથડ સર્ચ અને ટેપ બંને માટે કોમન લોજિક વાપરે છે ---
  void handleMapTap(LatLng latLng) async {
    // ૧. જૂનો ડેટા અને શીટ તરત જ બંધ કરો જેથી ડબલ શીટ ન દેખાય
    isBottomSheetOpen.value = false;
    _clearMarkers();
    polylines.clear();
    selectedPlace.value = null;
    selectedLatLng.value = latLng;

    isLoading.value = true;

    try {
      // ૨. Reverse Geocoding થી Place ID મેળવો
      final response = await _dio.get(
        "https://maps.googleapis.com/maps/api/geocode/json",
        queryParameters: {
          'latlng': "${latLng.latitude},${latLng.longitude}",
          'key': _placesService.apiKey,
        },
      );

      if (response.data['status'] == 'OK' && response.data['results'].isNotEmpty) {
        String placeId = response.data['results'][0]['place_id'];
        String placeName = response.data['results'][0]['formatted_address'].split(',')[0];

        // ૩. માર્કર એડ કરો
        _addMarker(latLng, placeName);

        // ૪. વિગતો ફેચ કરો
        await fetchPlaceDetails(placeId);

        // ૫. ડેટા આવી ગયા પછી જ શીટ ઓપન કરો
        openBottomSheet();
      } else {
        Get.snackbar("Notice", "No place details found.");
      }
    } catch (e) {
      print("Error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchPlaceDetails(String placeId) async {
    try {
      selectedPlace.value = await _placesService.getPlaceDetails(placeId);
    } catch (e) {
      selectedPlace.value = null;
      Get.snackbar("Error", "વિગત મેળવવામાં ભૂલ થઈ.");
    }
  }

  void _addMarker(LatLng position, String title) {
    findPLaceController.markers.add(Marker(
      markerId: MarkerId("poi_${position.latitude}_${position.longitude}"),
      position: position,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(title: title),
    ));
    findPLaceController.markers.refresh();
  }

  void _clearMarkers() {
    findPLaceController.markers.clear();
    findPLaceController.markers.refresh();
  }

  void openBottomSheet() {
    if (selectedPlace.value != null) {
      isBottomSheetOpen.value = true;
    }
  }

  void closeBottomSheet() {
    isBottomSheetOpen.value = false;
    _clearMarkers();
    polylines.clear();
    selectedPlace.value = null;
    selectedLatLng.value = null;
  }

  Future<void> drawRouteToPlace() async {
    if (selectedLatLng.value == null) return;

    Position? currentPos = await getCurrentLocation();
    if (currentPos == null) return;

    PolylinePoints polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: _placesService.apiKey,
      request: PolylineRequest(
        origin: PointLatLng(currentPos.latitude, currentPos.longitude),
        destination: PointLatLng(selectedLatLng.value!.latitude, selectedLatLng.value!.longitude),
        mode: TravelMode.driving,
      ),
    );

    if (result.points.isNotEmpty) {
      List<LatLng> polylineCoordinates = result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();
      polylines.clear(); // જૂનો રસ્તો સાફ કરો
      polylines.add(Polyline(
        polylineId: const PolylineId("route"),
        color: const Color(0xFF2196F3),
        points: polylineCoordinates,
        width: 5,
      ));
    }
  }
}