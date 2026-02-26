// file: controllers/image_selection_controller.dart
import 'package:get/get.dart';

class ImageSelectionController extends GetxController {
  // Reactive variable to store the selected asset path
  final RxString selectedImagePath = ''.obs;

  // Default / fallback image (change to your own placeholder)
  static const String defaultImage = 'assets/images/default_profile.png';

  // Method to update selected image
  void selectImage(String path) {
    selectedImagePath.value = path;
    // Optional: you can add print for debug or save to local storage here
    // print("Image selected: $path");
  }

  // Optional: clear the selection
  void clearSelection() {
    selectedImagePath.value = '';
  }

  // Helper getter: returns current path or default if none selected
  String get currentImage =>
      selectedImagePath.value.isNotEmpty
          ? selectedImagePath.value
          : defaultImage;

  // Optional: check if any image is selected
  bool get hasSelection => selectedImagePath.value.isNotEmpty;
}