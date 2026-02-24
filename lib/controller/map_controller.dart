import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

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

        markers.clear();

        markers.add(
          Marker(
            markerId: MarkerId(place),
            position: latLng,
            infoWindow: InfoWindow(title: place),
          ),
        );

        mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, 14),
        );
      }
    } catch (e) {
      print("errror are $e");
     Get.snackbar("Error", "access your location");
    }
  }
}