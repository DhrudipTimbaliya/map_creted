import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:map_creted/constant/ColorsConstant.dart';

import '../controller/center_marker_controller.dart';
import '../project_specific/center_marker_bootomsheet.dart';

class PinSetPage extends StatefulWidget {
  const PinSetPage({super.key});

  @override
  State<PinSetPage> createState() => _PinSetPageState();
}

class _PinSetPageState extends State<PinSetPage> {
  @override
  Widget build(BuildContext context) {
    // Put controller once
    final controller = Get.put(CenterMarkerController());

    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          Obx(() => GoogleMap(
            initialCameraPosition: CameraPosition(
              target: controller.centerPosition.value,
              zoom: 15,
            ),
            onMapCreated: controller.onMapCreated,
            onCameraMove: controller.onCameraMove,
            // Very important: no default markers
            markers: const {},
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // we use custom one
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
          )),

          // Fixed center marker (always in screen center)
          const Center(
            child: Icon(
              Icons.location_pin,
              size: 56,
              color: Colors.redAccent,
            ),
          ),
          Positioned(
            bottom: 80,
            left: 16,
            child:  Container(
              decoration: BoxDecoration(
                color: AppColor.black,
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(onPressed: (){
              Get.back();
                        }, icon:Icon(Icons.arrow_back,color: AppColor.orange),),
            ),),
          // Bottom sheet trigger area / floating button
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: FloatingActionButton.extended(
              backgroundColor: AppColor.black,
              label:  Text("Show Address",style: TextStyle(color: AppColor.orange),),
              icon:  Icon(Icons.keyboard_arrow_up,size: 24,color: AppColor.orange),
              onPressed: () {
                Get.bottomSheet(
                  const CenterMarkerBottomSheet(),
                  isScrollControlled: true,
                  backgroundColor: AppColor.black,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  elevation: 0,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}