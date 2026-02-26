import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:map_creted/constant/ColorsConstant.dart';

import '../controller/center_marker_controller.dart';


class CenterMarkerBottomSheet extends StatelessWidget {
  const CenterMarkerBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CenterMarkerController>();

    return Container(
      decoration:  BoxDecoration(
        color: AppColor.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Obx(() => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                 Text(
                  "Selected Location",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColor.Secondry,
                  ),
                ),
                const SizedBox(height: 16),

                // Address
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, color: Colors.redAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.currentAddress.value,
                            style:  TextStyle(fontSize: 16,color: AppColor.orange),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                "PIN: ${controller.currentPincode.value}",
                                style: TextStyle(
                                  color: AppColor.primery,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (controller.isLoadingAddress.value) ...[
                                const SizedBox(width: 12),
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Optional action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.my_location, size: 18),
                      label: const Text("My Location"),
                      onPressed: controller.goToMyLocation,
                    ),
                    ElevatedButton.icon(
                      icon:  Icon(Icons.check, size: 18,color: AppColor.Secondry,),
                      label:  Text("Confirm",style: TextStyle(color: AppColor.Secondry),),
                      onPressed: () {
                        // You can Get.back() or pass value to parent
                        Get.back(result: controller.centerPosition.value);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColor.black,

                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            )),
          ),
        ],
      ),
    );
  }
}