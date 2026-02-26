import '../project_specific/direction_step_seet.dart';

class VehicleOption {
  final TravelModeData mode;
  final String name;
  final String assetPath; // image path from assets/images/

  const VehicleOption({
    required this.mode,
    required this.name,
    required this.assetPath,
  });
}

class VehicleService {
  VehicleService._();

  static final VehicleService instance = VehicleService._();

  List<VehicleOption>? _cachedVehicles;

  Future<List<VehicleOption>> fetchVehicleList() async {
    if (_cachedVehicles != null) return _cachedVehicles!;

    // Simulate network latency
    await Future.delayed(const Duration(milliseconds: 600));

    _cachedVehicles = const [
      VehicleOption(
        mode: TravelModeData.walk,
        name: 'Walk',
        assetPath: 'assets/images/walk.png', // update to your actual asset
      ),
      VehicleOption(
        mode: TravelModeData.car,
        name: 'Car',
        assetPath: 'assets/images/car.png',
      ),
      VehicleOption(
        mode: TravelModeData.train,
        name: 'Train',
        assetPath: 'assets/images/train.png',
      ),
    ];

    return _cachedVehicles!;
  }
}

