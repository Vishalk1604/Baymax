import 'package:geolocator/geolocator.dart';

enum LocationProblem { serviceOff, denied, deniedForever, unavailable }

class LocationException implements Exception {
  LocationException(this.problem);
  final LocationProblem problem;

  String get message => switch (problem) {
        LocationProblem.serviceOff => 'Location is turned off. Turn it on to find care near you.',
        LocationProblem.denied => 'Baymax needs your location to find clinics near you.',
        LocationProblem.deniedForever => 'Location access is blocked. Allow it in Settings to find clinics near you.',
        LocationProblem.unavailable => "Couldn't get your location. Try again in a moment.",
      };

  /// Whether opening system settings is the way to fix it.
  bool get needsSettings => problem == LocationProblem.deniedForever || problem == LocationProblem.serviceOff;
}

/// Current position, asking for permission only when called (i.e. when the
/// person actually searches for care).
abstract final class LocationService {
  static Future<Position> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw LocationException(LocationProblem.serviceOff);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) throw LocationException(LocationProblem.denied);
    if (permission == LocationPermission.deniedForever) throw LocationException(LocationProblem.deniedForever);
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15)),
      );
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      throw LocationException(LocationProblem.unavailable);
    }
  }

  /// True when a search can run without asking the person for anything.
  static Future<bool> isReady() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      final p = await Geolocator.checkPermission();
      return p == LocationPermission.always || p == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openSettings(LocationException e) async {
    if (e.problem == LocationProblem.serviceOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}
