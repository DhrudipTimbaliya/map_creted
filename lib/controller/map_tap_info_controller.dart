import 'dart:ui';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dio/dio.dart' as dio_pkg; // dio package use

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

  // --- REPLACED: onPoiTap removed, handleMapTap used ---
  // આ મેથડ PointOfInterest પેરામીટર વગર કામ કરે છે
  void handleMapTap(LatLng latLng) async {
    _clearMarkers();
    polylines.clear();
    selectedPlace.value = null;
    selectedLatLng.value = latLng;

    isLoading.value = true;

    try {
      // ૧. LatLng પરથી Place ID મેળવવા Reverse Geocoding API call
      final response = await _dio.get(
        "https://maps.googleapis.com/maps/api/geocode/json",
        queryParameters: {
          'latlng': "${latLng.latitude},${latLng.longitude}",
          'key': _placesService.apiKey, // PlacesService માંથી API Key લેશે
        },
      );

      if (response.data['status'] == 'OK' && response.data['results'].isNotEmpty) {
        // ૨. સૌથી સચોટ Place ID મેળવો
        String placeId = response.data['results'][0]['place_id'];
        String placeName = response.data['results'][0]['formatted_address'].split(',')[0];

        // ૩. માર્કર એડ કરો
        _addMarker(latLng, placeName);

        // ૪. Exact Place Details ફેચ કરો
        await fetchPlaceDetails(placeId);

        // ૫. શીટ ઓપન કરો
        openBottomSheet();
      } else {
        Get.snackbar("Notice", "No place details found at this location.");
      }
    } catch (e) {
      Get.snackbar("Error", "Failed to fetch location info.");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchPlaceDetails(String placeId) async {
    isLoading.value = true;
    try {
      selectedPlace.value = await _placesService.getPlaceDetails(placeId);
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  void _addMarker(LatLng position, String title) {
    findPLaceController.markers.add(Marker(
      markerId: MarkerId("manual_poi_${position.latitude}"),
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

  void openBottomSheet() => isBottomSheetOpen.value = true;

  void closeBottomSheet() {
    isBottomSheetOpen.value = false;
    _clearMarkers();
    polylines.clear();
    selectedPlace.value = null;
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
      polylines.add(Polyline(
        polylineId: const PolylineId("route"),
        color: const Color(0xFF2196F3),
        points: polylineCoordinates,
        width: 5,
      ));
    }
  }
}