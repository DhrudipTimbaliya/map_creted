// file: screens/image_selected_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:map_creted/constant/ColorsConstant.dart';

import '../controller/vehicalselecor_controller.dart';

// List of your available images (update with your real asset paths)
const List<String> availableImages = [
  'assets/images/bike.png',
  'assets/images/bus.png',
  'assets/images/car.png',
  'assets/images/train.png',
];

class ImageSelectedScreen extends StatelessWidget {
  const ImageSelectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get controller (make sure it's put somewhere: Get.put(ImageSelectionController()))
    final controller = Get.put(ImageSelectionController());

    return Scaffold(
     backgroundColor: AppColor.black,
      body: SafeArea(

        child: Column(
          children: [
            // Live preview of selected image
            Obx(() => Padding(
              padding: const EdgeInsets.all(32.0),
              child: CircleAvatar(
                radius: 70,
                backgroundColor: Colors.grey[800],
                backgroundImage: AssetImage(controller.currentImage),
                child: controller.selectedImagePath.value.isEmpty
                    ? const Icon(
                  Icons.person,
                  size: 70,
                  color: Colors.white70,
                )
                    : null,
              ),
            )),
        
            const Divider(height: 40, thickness: 1, color: Colors.grey),
        
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemCount: availableImages.length,
                  itemBuilder: (context, index) {
                    final path = availableImages[index];
        
                    return Obx(() {
                      final isSelected = controller.selectedImagePath.value == path;
        
                      return GestureDetector(
                        onTap: () {
                          controller.selectImage(path);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected ? Colors.orange : Colors.transparent,
                              width: isSelected ? 3 : 0,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: isSelected
                                ? [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              )
                            ]
                                : null,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              path,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.broken_image,
                                  color: Colors.red,
                                  size: 40,
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Get.back(),
              child: Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: AppColor.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColor.orange),
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
            Obx(() => controller.hasSelection
                ? FloatingActionButton.extended(
                        onPressed: () {
                // You can show success message or navigate back
                Get.snackbar(
                  "Success",
                  "Vehical  selected!",
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.TOP,
                );

                        },
                        label: const Text("Confirm"),
                        icon: const Icon(Icons.check),
                        backgroundColor: Colors.orange,
                      )
                : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
