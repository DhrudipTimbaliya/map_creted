class RouteStep {
  final String instruction;
  final String distance;
  final String duration;
  final String maneuver;

  RouteStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.maneuver,
  });
}

class RouteInfo {
  final String totalDistance;
  final String totalDuration;
  final List<RouteStep> steps;

  RouteInfo({
    required this.totalDistance,
    required this.totalDuration,
    required this.steps,
  });
}