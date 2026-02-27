import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:map_creted/controller/map_tap_info_controller.dart';

import '../constant/ColorsConstant.dart';
import '../controller/Suggestion_controller.dart';
import '../controller/current_location.dart';
import '../controller/map_controller.dart';
import '../controller/mapdataselector.dart';
import '../controller/start_end_calculate_controller.dart'; // TwoMapRouteController
import '../controller/vehicle_tracking_controller.dart';
import '../controller/vehicalselecor_controller.dart';
import '../model/route_step_model.dart';
import '../project_specific/contine_the_map_data.dart';
import '../project_specific/direction_step_seet.dart';
import '../project_specific/image_selected_screen.dart';
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
  final MapTapInfoController mapinfoController = Get.put(MapTapInfoController());
  final ExpansionTileController _expansionController = ExpansionTileController();
   final CurrentLocationController locationController =
   Get.put(CurrentLocationController());
   
  // Vehicle tracking controllers
  final ImageSelectionController imageSelectionController = Get.put(ImageSelectionController());
  final VehicleTrackingController vehicleTrackingController = Get.put(VehicleTrackingController());
   
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

     _initializeData();
   }

   Future<void> _initializeData() async {
     if (widget.passeddirection != null &&
         widget.passeddirection!.isNotEmpty) {

       _searchFirstPlace.text = "Your Location";
       _searchSecondPlace.text = widget.passeddirection!;

       print("passeddirection: ${widget.passeddirection}");

       await mapDataController.setPoint(_searchFirstPlace.text, true);
       await mapDataController.setPoint(_searchSecondPlace.text, false);
     }
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
                  () {
                    // Combine all markers: existing markers + vehicle marker
                    Set<Marker> allMarkers = Set<Marker>.from(mapDataController.markers.value);
                    
                    // Add vehicle marker if tracking is active
                    if (vehicleTrackingController.vehicleMarker.value != null) {
                      allMarkers.add(vehicleTrackingController.vehicleMarker.value!);
                    }
                    
                    // Combine all polylines: existing polylines + route polyline
                    Set<Polyline> allPolylines = Set<Polyline>.from(mapDataController.polylines.value);
                    
                    // Add vehicle route polyline if available
                    if (vehicleTrackingController.routePolyline.value != null) {
                      allPolylines.add(vehicleTrackingController.routePolyline.value!);
                    }
                    
                    return GoogleMap(
                      key: _mapKey,
                      initialCameraPosition: initialPosition,
                      mapType: mapDataChange.selectedMapType.value,
                      myLocationEnabled: true,
                      zoomControlsEnabled: false,
                      markers: allMarkers,
                      polylines: allPolylines,
                      onMapCreated: (GoogleMapController controller) {
                        mapDataController.setMapController(controller);
                        vehicleTrackingController.setMapController(controller);
                      },
                      onCameraMove: (CameraPosition position) {
                        // Update zoom level for dynamic vehicle sizing
                        vehicleTrackingController.currentZoom.value = position.zoom;
                      },
                      onCameraIdle: () {
                        // Recalculate vehicle size when camera stops
                        vehicleTrackingController.triggerZoomUpdate();
                      },
                    );
                  }
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
            Positioned(
              top: 210,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  // Show vehicle tracking bottom sheet
                  _showVehicleTrackingBottomSheet();
                },
                child: Container(
                  height: 50,
                  width: 60,
                  decoration: BoxDecoration(
                    color: AppColor.black.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.directions_car, color: AppColor.orange, size: 28),
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
            if(mapDataController.routeInfoData.value!=null)
            Positioned(
              right: 16,
              bottom: 20,   // ← adjust this value higher if still blocking
              child: SizedBox(
                width: 300,
                child: FloatingActionButton(
                  onPressed: mapDataController.showStepsBottomSheet,
                  backgroundColor: AppColor.black,
                  child:  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Icon(Icons.route_rounded, color: AppColor.orange),
                      Text("Find Steps",style: TextStyle(color: AppColor.orange,fontSize: 22),),
                    ],
                  ),
                ),
              ),
            ),

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

  // Vehicle Tracking Bottom Sheet
  void _showVehicleTrackingBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        snap: true,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: AppColor.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: AppColor.orange.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColor.orange,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.directions_car, color: AppColor.orange),
                      SizedBox(width: 12),
                      Text(
                        "Vehicle Tracking",
                        style: TextStyle(
                          color: AppColor.orange,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.more_vert, color: AppColor.white),
                        onPressed: () async {
                          Get.to(() => ImageSelectedScreen());
                        },
                      ),
                      GestureDetector(
                        onTap: () => Get.back(),
                        child: Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                
                Divider(color: AppColor.orange.withOpacity(0.3)),
                
                // Vehicle Selection and Start Tracking
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Vehicle Selection Status
                          Obx(() {
                            if (!imageSelectionController.hasSelection) {
                              return Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning_amber, color: Colors.orange[700]),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "No Vehicle Selected",
                                            style: TextStyle(
                                              color: Colors.orange[700],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            "Please select a vehicle image first to enable tracking",
                                            style: TextStyle(
                                              color: Colors.orange[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              return Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green[700]),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Vehicle Ready",
                                            style: TextStyle(
                                              color: Colors.green[700],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            "Selected vehicle is ready for tracking",
                                            style: TextStyle(
                                              color: Colors.green[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          }),
                          
                          SizedBox(height: 20),
                          
                          // Start/Stop Tracking Button
                          Obx(() {
                            final isTracking = vehicleTrackingController.isTracking.value;
                            
                            return SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: imageSelectionController.hasSelection
                                    ? () {
                                        if (isTracking) {
                                          vehicleTrackingController.stopTrip();
                                          Get.back();
                                        } else {
                                          _startVehicleTracking();
                                        }
                                      }
                                    : null,
                                icon: Icon(
                                  isTracking ? Icons.stop : Icons.play_arrow,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  isTracking ? "Stop Tracking" : "Start Tracking",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isTracking ? Colors.red : AppColor.Secondry,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            );
                          }),
                          
                          SizedBox(height: 20),
                          
                          // Instructions
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "How to use:",
                                  style: TextStyle(
                                    color: AppColor.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                ...[
                                  "1. Select a vehicle image from vehicle selection",
                                  "2. Set your destination in the directions panel",
                                  "3. Click 'Start Tracking' to begin GPS tracking",
                                  "4. Vehicle will follow the route automatically",
                                  "5. Map will follow your vehicle in 3D view"
                                ].map((instruction) => Padding(
                                  padding: EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("• ", style: TextStyle(color: AppColor.orange)),
                                      Expanded(
                                        child: Text(
                                          instruction,
                                          style: TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Start vehicle tracking with current route
  void _startVehicleTracking() async {
    try {
      // Get current position as starting point
      Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // Get destination from the search field
      String destinationText = _searchSecondPlace.text.trim();
      if (destinationText.isEmpty) {
        Get.snackbar(
          "Error",
          "Please set a destination first",
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      
      // For simplicity, we'll use a fixed destination or you can geocode the text
      // Here we'll use the current route destination if available
      LatLng? destination;
      if (mapDataController.markers.value.length >= 2) {
        final markers = mapDataController.markers.value.toList();
        destination = markers[1].position; // Assuming second marker is destination
      }
      
      if (destination == null) {
        Get.snackbar(
          "Error",
          "No destination found. Please search for a destination first.",
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      
      // Start tracking
      await vehicleTrackingController.startTrip(
        startPosition: LatLng(currentPosition.latitude, currentPosition.longitude),
      );
      
      // Fetch route to destination
      await vehicleTrackingController.fetchRoute(
        LatLng(currentPosition.latitude, currentPosition.longitude),
        destination,
      );
      
      Get.back(); // Close bottom sheet
      
      Get.snackbar(
        "Tracking Started",
        "Vehicle tracking is now active",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to start tracking: $e",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}