import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/map_tap_info_controller.dart';


class PlaceDetailBottomSheet extends StatelessWidget {
  const PlaceDetailBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MapTapInfoController>();

    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.9,
      snap: true,
      builder: (context, scrollController) {
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            // જો શીટ 0.0 એટલે કે સાવ નીચે પહોંચી જાય, તો કંટ્રોલરમાં સ્ટેટ ફોલ્સ કરો
            if (notification.extent <= 0.0) {
              controller.isBottomSheetOpen.value = false;
              controller.closeBottomSheet(); // આ માર્કર અને ડેટા ક્લિયર કરશે
            }
            return true;
          },
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
            ),
          child: Obx(() {
            if (controller.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }

            final place = controller.selectedPlace.value;
            if (place == null) return const SizedBox.shrink();

            return ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                // 1. Top Image
                if (place.photoUrl != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                    child: Image.network(place.photoUrl!, height: 200, width: double.infinity, fit: BoxFit.cover),
                  ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. Name & Rating
                      Text(place.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          Text(" ${place.rating ?? 0} (${place.totalRatings ?? 0} reviews)"),
                          const Spacer(),
                          _buildStatusBadge(place.isOpen),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(place.address, style: TextStyle(color: Colors.grey[600])),
                      const Divider(height: 30),

                      // 3. Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionBtn(Icons.directions, "Directions", Colors.blue, controller.drawRouteToPlace),
                          _buildActionBtn(Icons.call, "Call", Colors.green, () {}),
                          _buildActionBtn(Icons.public, "Website", Colors.orange, () {}),
                        ],
                      ),
                      const Divider(height: 30),

                      // 4. Reviews List
                      const Text("Reviews", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ...place.reviews.map((review) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(review.authorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(review.text),
                        trailing: Text("${review.rating} ★"),
                      )),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
        );
      },
    );
  }

  Widget _buildStatusBadge(bool? isOpen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen == true ? Colors.green[100] : Colors.red[100],
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(isOpen == true ? "OPEN" : "CLOSED",
          style: TextStyle(color: isOpen == true ? Colors.green[800] : Colors.red[800], fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
