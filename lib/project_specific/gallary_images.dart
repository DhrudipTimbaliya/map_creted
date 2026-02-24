import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';

class FullGalleryPage extends StatelessWidget {
  final List<String> photoUrls;
  final int initialIndex;

  const FullGalleryPage({super.key, required this.photoUrls, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Photos", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // એક લાઈનમાં ૩ ફોટા
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: photoUrls.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                // ફોટો ફૂલ સ્ક્રીન જોવા માટે (Optional)
                Get.dialog(
                  Dialog.fullscreen(
                    backgroundColor: Colors.black, // બેકગ્રાઉન્ડ કાળું રાખવાથી ફોટો સારો લાગશે
                    child: Stack(
                      children: [
                        // ૧. ફોટાને સેન્ટર કરવા માટે
                        Center(
                          child: InteractiveViewer(
                            panEnabled: true,      // આંગળીથી ફોટો ખસેડવા માટે
                            minScale: 0.5,
                            maxScale: 4.0,         // ઝૂમ કરવા માટે
                            child: Image.network(
                              photoUrls[index],
                              width: double.infinity,
                              fit: BoxFit.contain, // આ પ્રોપર્ટી ફોટાને સેન્ટરમાં એડજસ્ટ કરશે
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(child: CircularProgressIndicator(color: Colors.white));
                              },
                            ),
                          ),
                        ),

                        // ૨. ક્લોઝ બટન (ટોપ લેફ્ટ)
                        Positioned(
                          top: 40,
                          left: 20,
                          child: CircleAvatar(
                            backgroundColor: Colors.black.withOpacity(0.5),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 25),
                              onPressed: () => Get.back(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(photoUrls[index], fit: BoxFit.cover),
              ),
            );
          },
        ),
      ),
    );
  }
}