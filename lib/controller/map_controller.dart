import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'map_tap_info_controller.dart';

class MapController extends GetxController {
  RxSet<Marker> markers = <Marker>{}.obs;
  GoogleMapController? mapController;

  void setMapController(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> searchPlace(String place) async {
    try {
      List<Location> locations = await locationFromAddress(place);

      if (locations.isNotEmpty) {
        final loc = locations.first;
        LatLng latLng = LatLng(loc.latitude, loc.longitude);

        // કેમેરા મુવ કરો
        mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, 15),
        );

        // મહત્વનું: બીજા કંટ્રોલરની મેથડ કોલ કરો જે બધું હેન્ડલ કરશે
        // આનાથી બે-બે વાર ડેટા લોડ નહીં થાય
        final infoController = Get.find<MapTapInfoController>();
        infoController.handleMapTap(latLng);
      }
    } catch (e) {
      Get.snackbar("Error", "Location not found");
    }
  }
}