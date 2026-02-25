import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/show_direction.dart';


class DirectionStepsSheet extends StatelessWidget {
  const DirectionStepsSheet({super.key});
  String removeHtmlTags(String htmlString) {
    return htmlString.replaceAll(RegExp(r'<[^>]*>|&nbsp;'), ' ');
  }
  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ShowDirectionController());

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false, // આ ખાસ 'false' રાખવું, નહિતર શીટ દેખાશે નહીં
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ટોપ હેડર
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40, height: 5,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
              Obx(() => ListTile(
                title: const Text("Steps", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                subtitle: Text("${controller.totalDistance} • ${controller.totalDuration}"),
                trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => Get.back()),
              )),
              const Divider(),

              // સ્ટેપ્સની લિસ્ટ
              Expanded(
                child: Obx(() {

                  if (controller.isStepLoading.value) return const Center(child: CircularProgressIndicator());
                  return ListView.separated(
                    controller: scrollController,
                    itemCount: controller.steps.length,
                    separatorBuilder: (context, index) => const Divider(indent: 70),
                    itemBuilder: (context, index) {
                      var step = controller.steps[index];
                      return ListTile(
                        leading: _getDirectionIcon(step['maneuver']),
                        title: Text(
                          removeHtmlTags(step['html_instructions']), // HTML ટેગ્સ કાઢીને ટેક્સ્ટ બતાવશે
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            step['distance']['text'],
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  // વળાંક મુજબ આઈકોન નક્કી કરવા
  Widget _getDirectionIcon(String? maneuver) {
    IconData icon;
    switch (maneuver) {
      case 'turn-left': icon = Icons.turn_left; break;
      case 'turn-right': icon = Icons.turn_right; break;
      case 'merge': icon = Icons.merge; break;
      default: icon = Icons.straight;
    }
    return CircleAvatar(backgroundColor: Colors.blue.withOpacity(0.1), child: Icon(icon, color: Colors.blue));
  }
}