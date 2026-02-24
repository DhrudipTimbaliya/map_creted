// map_type_button_container.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constant/ColorsConstant.dart';
import '../controller/mapdataselector.dart';


class MapTypeButtonContainer extends StatelessWidget {
  const MapTypeButtonContainer({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MapDataSelectedController>();

    return Obx(() {
      return Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(15),
        color: AppColor.black,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () => _openMapTypeSelector(context, controller),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  controller.currentIcon,
                  size: 30,
                  color: AppColor.orange,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _openMapTypeSelector(
      BuildContext context,
      MapDataSelectedController controller,
      ) {
    showModalBottomSheet(
      backgroundColor: AppColor.black,
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                /// Drag Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                /// Title
                 Text(
                  "Select Map Type",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color:AppColor.white,
                  ),
                ),

                const SizedBox(height: 20),

                /// Grid (2 per row)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.mapTypes.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final item = controller.mapTypes[index];
                    final type = item['type'] as MapType;
                    final name = item['name'] as String;
                    final icon = item['icon'] as IconData;
                    final selected =
                        controller.selectedMapType.value == type;

                    return GestureDetector(
                      onTap: () {
                        controller.changeMapType(type);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColor.black
                              : AppColor.black,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? AppColor.orange
                                : AppColor.Secondry,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              size: 50,
                              color: selected
                                  ? AppColor.orange
                                  : AppColor.Secondry,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: selected
                                    ? AppColor.orange
                                    : AppColor.Secondry,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}