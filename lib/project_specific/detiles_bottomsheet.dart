import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:map_creted/constant/ColorsConstant.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Pages/direction_page.dart';
import '../controller/map_tap_info_controller.dart';
import 'gallary_images.dart';

class PlaceDetailBottomSheet extends StatelessWidget {
  const PlaceDetailBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MapTapInfoController>();

    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.0, // ફેરફાર: આને 0.0 રાખવું જેથી શીટ બંધ થઈ શકે
      maxChildSize: 0.9,
      snap: true,
      builder: (context, scrollController) {
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            if (notification.extent <= 0.0) {
              controller.isBottomSheetOpen.value = false;
              controller.closeBottomSheet();
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
              // જો લોડિંગ થતું હોય તો માત્ર લોડર બતાવો, જૂની શીટનો ડેટા નહીં
              if (controller.isLoading.value) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final place = controller.selectedPlace.value;
              // જો પ્લેસ નલ હોય તો કશું જ ન બતાવો
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

                  if (place.photoUrls.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        height: 180, // હાઇટ થોડી વધારી જેથી મોટા ફોટા વ્યવસ્થિત દેખાય
                        child: Row(
                          children: [
                            // ૧. પ્રથમ મોટો ફોટો (Expandable)
                            Expanded(
                              flex: 2,
                              child: _buildImageTile(place.photoUrls[0], index: 0, allPhotos: place.photoUrls),
                            ),
                            const SizedBox(width: 8),

                            // ૨. બીજો મધ્યમ ફોટો
                            if (place.photoUrls.length > 1)
                              Expanded(
                                flex: 1,
                                child: _buildImageTile(place.photoUrls[1], index: 1, allPhotos: place.photoUrls),
                              ),
                            const SizedBox(width: 8),

                            // ૩. છેલ્લા નાના ફોટાઓની કોલમ (ગ્રીડ જેવું લુક)
                            if (place.photoUrls.length > 2)
                              Expanded(
                                flex: 1,
                                child: Column(
                                  children: [
                                    // ત્રીજો ફોટો
                                    Expanded(child: _buildImageTile(place.photoUrls[2], index: 2, allPhotos: place.photoUrls)),
                                    const SizedBox(height: 4),
                                    // ચોથો ફોટો
                                    if (place.photoUrls.length > 3)
                                      Expanded(child: _buildImageTile(place.photoUrls[3], index: 3, allPhotos: place.photoUrls)),
                                    const SizedBox(height: 4),
                                    // પાંચમો ફોટો અથવા 'More' ઓપ્શન
                                    if (place.photoUrls.length > 4)
                                      Expanded(
                                        child: _buildMoreTile(
                                          place.photoUrls[4],
                                          count: place.photoUrls.length - 4,
                                          allPhotos: place.photoUrls,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildActionBtn(Icons.directions,
                                "Directions",
                                Colors.blue,
                                (){
                                   Get.to(()=>DirectionPage(passeddirection: place.name));
                                }),
                            _buildActionBtn(Icons.call, "Call", Colors.green, () {}),
                            _buildActionBtn(
                              Icons.public,
                              "Website",
                              Colors.orange,
                                  () {
                                if (place.website != null && place.website!.isNotEmpty) {
                                  _launchWebsite(place.website!);
                                } else {
                                  Get.snackbar(
                                    "Info",
                                    "Website not available",
                                    backgroundColor: Colors.grey.shade800,
                                    colorText: Colors.white,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        const Divider(height: 30),

                        const Text(
                          "Reviews",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),

                        if (place.reviews.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              "No reviews available.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),

                        ...place.reviews.map(
                              (review) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Avatar
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColor.black,
                                  child: Text(
                                    review.authorName.isNotEmpty
                                        ? review.authorName[0].toUpperCase()
                                        : "?",
                                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // Review content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Author Name & Rating
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            review.authorName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              const Icon(Icons.star, color: Colors.amber, size: 16),
                                              const SizedBox(width: 2),
                                              Text(
                                                review.rating.toStringAsFixed(1),
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 4),

                                      // Review Text
                                      Text(
                                        review.text,
                                        style: const TextStyle(fontSize: 13),
                                      ),

                                      const SizedBox(height: 2),

                                      // Relative Time
                                      Text(
                                        review.relativeTime,
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
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

  // _buildStatusBadge અને _buildActionBtn પદ્ધતિઓ તમારા જૂના કોડ મુજબ જ રહેશે...
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



  Future<void> _launchWebsite(String url) async {
    try {
      final Uri uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');

      if (!await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      )) {
        Get.snackbar("Error", "Cannot open the website",
            backgroundColor: Colors.red, colorText: Colors.white);
      }
    } catch (e) {
      Get.snackbar("Error", "Website launch failed: $e",
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

// સામાન્ય ઈમેજ ટાઈલ માટે
Widget _buildImageTile(String url, {required int index, required List<String> allPhotos}) {
  return GestureDetector(
    onTap: () => Get.to(() => FullGalleryPage(photoUrls: allPhotos, initialIndex: index)),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(url, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
    ),
  );
}

// 'More' વાળી ઈમેજ ટાઈલ માટે
Widget _buildMoreTile(String url, {required int count, required List<String> allPhotos}) {
  return GestureDetector(
    onTap: () => Get.to(() => FullGalleryPage(photoUrls: allPhotos)),
    child: Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(url, fit: BoxFit.cover),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              "+$count",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ],
    ),
  );
}
}