import 'package:geolocator/geolocator.dart';

class LocationService {
  // Lahore bounds (approximate 40km radius from city center)
  static const double _lahoreLat = 31.5204;
  static const double _lahoreLng = 74.3587;
  static const double _radiusKm = 40.0;

  /// Returns true if user is within Lahore radius.
  /// Returns null if permission denied or location unavailable.
  static Future<bool?> isUserInLahore() async {
    try {
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Check and request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null; // Can't access location
      }

      // Get current position - Fixed for older + newer geolocator versions
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );

      // Calculate distance from Lahore center
      final double distanceMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        _lahoreLat,
        _lahoreLng,
      );

      // Return true if within 40km radius
      return distanceMeters <= (_radiusKm * 1000);
    } catch (e) {
      print('LocationService Error: $e');
      return null; // Fail open - allow access if we can't determine
    }
  }

  /// Optional: Force update location settings (for newer versions)
  static Future<Position> getCurrentPosition() async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
      timeLimit: const Duration(seconds: 15),
    );
  }
}