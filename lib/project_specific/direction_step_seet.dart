import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';

import '../constant/ColorsConstant.dart';
import '../model/route_step_model.dart';
import '../controller/start_end_calculate_controller.dart';

// Example GetX Controller


enum TravelModeData { car, walk, train }

class DirectionStepsBottomSheet extends StatefulWidget {
  final RouteInfo data;
  final TravelModeData? travelModedata;
  const DirectionStepsBottomSheet({super.key, required this.travelModedata,required this.data});

  @override
  State<DirectionStepsBottomSheet> createState() => _DirectionStepsBottomSheetState();
}

class _DirectionStepsBottomSheetState extends State<DirectionStepsBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final routeController = Get.find<TwoMapRouteController>();

    return DraggableScrollableSheet(
      snap: false,
      initialChildSize: 0.5,
      maxChildSize: 0.85,
      minChildSize: 0.15,
      builder: (_, scrollController) {
        return Obx(() {
          final route = routeController.routeInfoData.value ?? widget.data;
          final mode = routeController.selectedMode.value;

          return Container(
            decoration: BoxDecoration(
              color: AppColor.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle & Header
                _buildHandle(),
                _buildHeader(route.totalDistance, route.totalDuration),
                travelModeSelectorUI(
                  selectedMode: mode,
                  onTap: (m) {
                    routeController.changeTravelMode(m);
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  "Select your travel mode here",
                  style: TextStyle(
                    color: AppColor.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                //
                const SizedBox(height: 12),
                // Steps List
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: route.steps.length,
                    itemBuilder: (context, index) {
                      final step = route.steps[index];
                      return _buildStepTile(step, index == route.steps.length - 1);
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildStepTile(RouteStep step, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        children: [
          const SizedBox(width: 20),
          Column(
            children: [
              Icon(_getIcon(step.maneuver), color: Colors.blue),
              if (!isLast) Expanded(child: VerticalDivider(color: Colors.grey[300])),
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.instruction, style:  TextStyle(fontWeight: FontWeight.w600,color: AppColor.white)),
                  Text("${step.distance} • ${step.duration}", style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String maneuver) {
    if (maneuver.contains("left")) return Icons.turn_left;
    if (maneuver.contains("right")) return Icons.turn_right;
    return Icons.straight;
  }

// Add _buildHandle and _buildHeader UI methods here...
  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        width: 40, height: 4,
        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildHeader(String dist, String dur) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Route Steps", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30, color: AppColor.orange)),
              Text("$dist • $dur", style: TextStyle(color: Colors.grey[400])),
            ],
          ),
          const Spacer(),
          IconButton(
            icon:  Icon(Icons.close,color: AppColor.white,),
            onPressed: () => Get.back(), // or Navigator.pop(context)
          ),

        ],
      ),
    );
  }

  // 3. Travel Modes Selection (Car, Bike, Walk)
  Widget _buildTravelModes() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildModeChip(Icons.directions_car, "24m", isActive: true),
          _buildModeChip(Icons.directions_bike, "1h 12m"),
          _buildModeChip(Icons.directions_walk, "3h 45m"),
          _buildModeChip(Icons.directions_transit, "42m"),
        ],
      ),
    );
  }

  // Helper for Circular Header Buttons
  Widget _buildCircleIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.grey[800], size: 20),
    );
  }

  // Helper for Vehicle Mode Chips
  Widget _buildModeChip(IconData icon, String time, {bool isActive = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? Colors.black : Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: isActive ? Colors.white : Colors.grey[600], size: 18),
          const SizedBox(width: 8),
          Text(
            time,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey[700],
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStepIcon(String maneuver) {
    switch (maneuver) {
      case 'turn-left':
      case 'turn-slight-left':
      case 'turn-sharp-left':
        return Icons.turn_left;
      case 'turn-right':
      case 'turn-slight-right':
      case 'turn-sharp-right':
        return Icons.turn_right;
      case 'u-turn-left':
      case 'u-turn-right':
        return Icons.u_turn_left;
      case 'merge':
        return Icons.merge;
      case 'ramp-left':
      case 'ramp-right':
        return Icons.navigation;
      default:
        return Icons.straight; // Default for "head north" or "continue"
    }
  }

// Pure widget function: pass selectedMode, no controller
  Widget travelModeSelectorUI({required TravelModeData selectedMode, Function(TravelModeData)? onTap}) {
    final modes = {
      TravelModeData.car: {'icon': Icons.directions_car, 'label': 'Car'},
      TravelModeData.walk: {'icon': Icons.directions_walk, 'label': 'Walk'},
      TravelModeData.train: {'icon': Icons.train, 'label': 'Train'},
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: modes.entries.map((entry) {
          final isActive = selectedMode == entry.key;

          return GestureDetector(
            onTap: () {
              if (onTap != null) onTap(entry.key);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColor.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isActive ? AppColor.orange : AppColor.Secondry),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    entry.value['icon'] as IconData,
                    color: isActive ? AppColor.orange : AppColor.Secondry,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.value['label'] as String,
                    style: TextStyle(
                      color: isActive ? AppColor.orange : AppColor.Secondry,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
