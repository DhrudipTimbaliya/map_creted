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
  final controller = Get.put(MapTapInfoController());
  final MapController mapController = Get.find<MapController>();
  final CurrentLocationController locationController =
  Get.put(CurrentLocationController());
  static const CameraPosition initialPosition = CameraPosition(
    target: LatLng(22.3039, 70.8022),
    zoom: 14,
  );

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
              onTap: (LatLng position) {
                // This triggers the bottom sheet
                controller.onMapTapped(position);
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

            // ──────────────────────────────────────────────
            // BOTTOM SHEET - shown when user taps anywhere on map
            // ──────────────────────────────────────────────
            Obx(() {
              if (!controller.showBottomSheet.value) {
                return const SizedBox.shrink();
              }

              return DraggableScrollableSheet(
                initialChildSize: 0.38,
                minChildSize: 0.25,
                maxChildSize: 0.65,
                snap: true,
                snapSizes: const [0.38, 0.65],
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: AppColor.black,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 16,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Drag handle
                            Center(
                              child: Container(
                                width: 45,
                                height: 5,
                                margin: const EdgeInsets.only(bottom: 18),
                                decoration: BoxDecoration(
                                  color: AppColor.orange.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),

                            // Place name / title
                            Text(
                              controller.placeName.value.isNotEmpty
                                  ? controller.placeName.value
                                  : "Selected Location",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColor.orange,
                              ),
                            ),
                            const SizedBox(height:8),

                            // Address
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.location_on, color: AppColor.orange, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    controller.address.value,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white70,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Coordinates
                            Row(
                              children: [
                                Icon(Icons.pin_drop_outlined, color: Colors.white70, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  "Lat: ${controller.tappedPosition.value?.latitude.toStringAsFixed(6) ?? '—'}",
                                  style: TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                                const SizedBox(width: 20),
                                Text(
                                  "Lng: ${controller.tappedPosition.value?.longitude.toStringAsFixed(6) ?? '—'}",
                                  style: TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),

                            // Action buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildActionButton(
                                  icon: Icons.directions,
                                  label: "Directions",
                                  onTap: () {
                                    // You can navigate to DirectionPage with tapped location
                                    Get.to(() => DirectionPage());
                                  },
                                ),
                                _buildActionButton(
                                  icon: Icons.close,
                                  label: "Close",
                                  onTap: controller.closeBottomSheet,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColor.orange.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColor.orange, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: AppColor.orange, fontSize: 13),
          ),
        ],
      ),
    );
  }
}