import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constant/ColorsConstant.dart';
import '../controller/Suggestion_controller.dart';
import '../controller/current_location.dart';
import '../controller/map_controller.dart';
import '../controller/mapdataselector.dart';
import '../controller/start_end_calculate_controller.dart'; // TwoMapRouteController
import '../project_specific/contine_the_map_data.dart';
import '../project_specific/serch_location.dart';

class DirectionPage extends StatefulWidget {
  final passeddirection;
  const DirectionPage({super.key,this.passeddirection});

  @override
  State<DirectionPage> createState() => _DirectionPageState();
}

class _DirectionPageState extends State<DirectionPage> {
   TextEditingController _searchFirstPlace = TextEditingController();
  final TextEditingController _searchSecondPlace = TextEditingController();
  final TwoMapRouteController mapDataController = Get.put(TwoMapRouteController());
  final ExpansionTileController _expansionController = ExpansionTileController();
   final CurrentLocationController locationController =
   Get.put(CurrentLocationController());
  static const CameraPosition initialPosition = CameraPosition(
    target: LatLng(22.3039, 70.8022),
    zoom: 14,
  );

  bool isExpanded = false;
  final mapDataChange =Get.put(MapDataSelectedController());
  // GlobalKey to control ExpansionTile state
  final GlobalKey _expansionTileKey = GlobalKey();
   final Key _mapKey = UniqueKey();
  @override
  void initState() {
    super.initState();
    Get.put(SuggestionController(), tag: 'start');
    Get.put(SuggestionController(), tag: 'end');
    Get.put(MapController());
    if (widget.passeddirection != null && widget.passeddirection!.isNotEmpty) {
      // Set starting location text
      _searchFirstPlace.text = "Your Location";

      // Set destination location text
      _searchSecondPlace.text = widget.passeddirection!;

      // Update map points in controller
      // true = starting point, false = destination
      mapDataController.setPoint(_searchFirstPlace.text, true);
      mapDataController.setPoint(_searchSecondPlace.text, false);
    }
    // Optional: auto-get current location as start
    // mapDataController.getCurrentLocation();
  }

  void _collapsePanel() {
    if (_expansionController.isExpanded) {
      _expansionController.collapse();
      setState(() => isExpanded = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // Prevent auto-resize on keyboard → avoids fight
      backgroundColor: AppColor.black,
      body: SafeArea(
        child: Stack(
          children: [
            /// MAP - full screen
            Obx(
                  () => GoogleMap(
                    key: _mapKey,
                initialCameraPosition: initialPosition,
                mapType: mapDataChange.selectedMapType.value,
                myLocationEnabled: true,
                zoomControlsEnabled: false,
                markers: mapDataController.markers.value,
                polylines: mapDataController.polylines.value,
                onMapCreated: (controller) {
                  mapDataController.mapController = controller;
                  locationController.setMapController(controller);

                },
              ),
            ),
            Positioned(
              top: 90,
              right: 16,
              child: MapTypeButtonContainer(),
            ),

            Positioned(
              top: 150,
              right: 16,
              child: GestureDetector(
                onTap: () async {
                  // Direct call approach
                  try {
                    Position position = await Geolocator.getCurrentPosition();
                    mapDataController.mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(
                        LatLng(position.latitude, position.longitude),
                        15,
                      ),
                    );
                  } catch (e) {
                    print(e);
                  }
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







            /// TOP PANEL - Search / Direction Panel
            Positioned(
              top: 10,
              left: 15,
              right: 15,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(15),
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColor.black.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: AppColor.orange.withOpacity(0.3), width: 1),
                  ),
                  child: ExpansionTile(
                      controller: _expansionController,   // ← add this
                      key: _expansionTileKey,             // you can keep the key if needed elsewhere
                      initiallyExpanded: false,
                      onExpansionChanged: (expanded) {
                        setState(() => isExpanded = expanded);
                      },

                    collapsedIconColor: AppColor.white,
                    iconColor: AppColor.orange,
                    title: Text(
                      "Directions",
                      style: TextStyle(
                        color: AppColor.primery,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    children: [
                      _buildSearchSection(
                        tag: 'start',
                        controller: _searchFirstPlace,
                        hintText: "Add start location",
                        icon: Icons.location_history,
                        iconColor: AppColor.orange,
                        prefixIcon: Icons.add_location,
                        prefixIconColor: AppColor.Secondry,
                        surffixonTap: () {
                          setState(() {
                            _searchFirstPlace.text = "Your Location";
                          });
                        }
                      ),

                      _buildSearchSection(
                        tag: 'end',
                        controller: _searchSecondPlace,
                        hintText: "Add destination",
                        prefixIcon: Icons.location_on,
                        prefixIconColor: AppColor.green,


                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final startText = _searchFirstPlace.text.trim();
                              final endText = _searchSecondPlace.text.trim();

                              if (startText.isEmpty || endText.isEmpty) {
                                Get.rawSnackbar(  // more stable than snackbar
                                  message: "Please enter both locations",
                                  backgroundColor: Colors.redAccent.withOpacity(0.9),
                                  snackPosition: SnackPosition.BOTTOM,
                                  margin: const EdgeInsets.all(12),
                                  borderRadius: 12,
                                  duration: const Duration(seconds: 3),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                );
                                return;
                              }

                              await mapDataController.setPoint(startText, true);
                              await mapDataController.setPoint(endText, false);

                              _collapsePanel(); // auto collapse after search
                            },
                            icon: const Icon(Icons.directions_car, color: Colors.white),
                            label: const Text(
                              "Find Route",
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColor.Secondry,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            /// Back Button
            Positioned(
              bottom: 20,
              left: 20,
              child: GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: AppColor.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded, color: AppColor.orange, size: 28),
                ),
              ),
            ),

            /// Distance & Duration Box
            Obx(() {
              if (mapDataController.distance.value.isEmpty ||
                  mapDataController.duration.value.isEmpty) {
                return const SizedBox.shrink();
              }

              return Positioned(
                right: 16,
                bottom: 20, // ↑ moved up a bit so it doesn't overlap back button on small screens
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColor.black.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColor.orange.withOpacity(0.4)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Distance: ${mapDataController.distance.value}",
                        style: TextStyle(color: AppColor.orange, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Time: ${mapDataController.duration.value}",
                        style: TextStyle(color: AppColor.orange, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection({
    required String tag,
    required TextEditingController controller,
    required String hintText,
     VoidCallback? surffixonTap,
    IconData?prefixIcon,
    Color? prefixIconColor,
    IconData? icon,
    Color? iconColor,

  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SerchLocation(
            surffixIcon:icon,
            surffixIconColor: iconColor,
            surffixIcononTap: surffixonTap,
            controller: controller,
            hintcolor: AppColor.orange,
            textcolor: AppColor.orange,
            iconcolor: prefixIconColor,
            icon: prefixIcon,
            hinttext: hintText,
            onChanged: (value) {
              Get.find<SuggestionController>(tag: tag).searchPlace(value);
            },
          ),
          const SizedBox(height: 4),
          Obx(() {
            final suggestions = Get.find<SuggestionController>(tag: tag).suggestions;
            if (suggestions.isEmpty) return const SizedBox.shrink();

            return Container(
              constraints: const BoxConstraints(maxHeight: 180), // safe limit
              decoration: BoxDecoration(
                color: AppColor.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColor.orange.withOpacity(0.3)),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final place = suggestions[index];
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    title: Text(place, style: TextStyle(color: AppColor.orange, fontSize: 15)),
                    onTap: () {
                      controller.text = place;
                      suggestions.clear();
                      // Optional: trigger search immediately
                      // mapDataController.setPoint(place, tag == 'start');
                    },
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}