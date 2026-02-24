import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:map_creted/constant/ColorsConstant.dart';
import 'package:map_creted/project_specific/serch_location.dart';

import '../controller/Suggestion_controller.dart';
import '../controller/current_location.dart';
import '../controller/map_controller.dart';
import '../controller/map_tap_info_controller.dart';
import '../controller/mapdataselector.dart';
import '../project_specific/contine_the_map_data.dart';
import '../project_specific/detiles_bottomsheet.dart';
import 'direction_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _serchplace = TextEditingController();
  final MapController findPLaceController = Get.put(MapController());
  final mapDataChange = Get.put(MapDataSelectedController());

  final MapTapInfoController mapTapcontroller = Get.put(MapTapInfoController());
  final MapController mapController = Get.find<MapController>();
  final CurrentLocationController locationController =
  Get.put(CurrentLocationController());
  static const CameraPosition initialPosition = CameraPosition(
    target: LatLng(22.3039, 70.8022),
    zoom: 14,
  );

  @override
  void initState() {
  super.initState();

 // ← once here
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Google Map with onTap handler
            Obx(() => GoogleMap(
              initialCameraPosition: initialPosition,
              mapType: mapDataChange.selectedMapType.value,
              myLocationEnabled: true,
              zoomControlsEnabled: false,
              markers: findPLaceController.markers.toSet(),
              onMapCreated: (controller) {
                findPLaceController.setMapController(controller);
                locationController.setMapController(controller);
              },
              onTap: (LatLng latLng) {
                mapTapcontroller.handleMapTap(latLng);
              },
            )),

            // Map Type Selector (your existing button)
            Positioned(
              top: 90,
              right: 16,
              child: MapTypeButtonContainer(),
            ),
            Positioned(
              top: 150,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  locationController.goToCurrentLocation();
                },
                child: Container(
                  height: 50,
                  width: 60,
                  decoration: BoxDecoration(
                    color: AppColor.black.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.my_location, color: AppColor.orange, size: 28),
                ),
              ),
            ),
            // Search bar + suggestions
            Positioned(
              top: 15,
              left: 15,
              right: 15,
              child: Column(
                children: [
                  SerchLocation(
                    icon: Icons.search_outlined,
                    controller: _serchplace,
                    hintcolor: AppColor.orange,
                    textcolor: AppColor.orange,
                    iconcolor: AppColor.orange,
                    onSubmitted: true,
                    onChanged: (value) {
                      Get.find<SuggestionController>().searchPlace(value);
                    },
                  ),

                  Obx(() {
                    final suggestions = Get.find<SuggestionController>().suggestions;
                    if (suggestions.isEmpty) return const SizedBox();

                    return Container(
                      color: AppColor.black,
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: suggestions.length,
                        itemBuilder: (context, index) {
                          final place = suggestions[index];
                          return ListTile(
                            title: Text(place, style: TextStyle(color: AppColor.orange)),
                            onTap: () {
                              _serchplace.text = place;
                              mapController.searchPlace(_serchplace.text);
                              suggestions.clear();
                            },
                          );
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Direction button
            Positioned(
              bottom: 20,
              right: 15,
              child: GestureDetector(
                onTap: () {
                  Get.to(() => DirectionPage());
                },
                child: Container(
                  height: 60,
                  width: 60,
                  decoration: BoxDecoration(
                    color: AppColor.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.directions, color: AppColor.orange),
                ),
              ),
            ),
            // 2. Bottom Sheet Overlay
            Obx(() => mapTapcontroller.isBottomSheetOpen.value
                ? const PlaceDetailBottomSheet()
                : const SizedBox.shrink()),

            // 2. Bottom Sheet Overlay (ફક્ત શીટ જ આવશે, બટન નહીં)
            Obx(() => mapTapcontroller.isBottomSheetOpen.value
                ? const PlaceDetailBottomSheet()
                : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}