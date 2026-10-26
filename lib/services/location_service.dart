import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Centralized service for real, live GPS location tracking
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;

  bool _isLocating = false;
  bool get isLocating => _isLocating;

  String? _lastLocationName;
  String? get lastLocationName => _lastLocationName;

  /// Get current live GPS position using device / browser geolocation
  Future<Position?> getCurrentLivePosition() async {
    _isLocating = true;
    try {
      // 1. Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('⚠️ Location services are disabled on device.');
      }

      // 2. Check and request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('⚠️ Location permissions are denied by user.');
          _isLocating = false;
          return _currentPosition;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ Location permissions are permanently denied.');
        _isLocating = false;
        return _currentPosition;
      }

      // 3. Query real live position from device hardware / browser GPS
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _currentPosition = position;
      _lastLocationName = '${position.latitude.toStringAsFixed(4)}°, ${position.longitude.toStringAsFixed(4)}°';
      debugPrint('📍 [LocationService] Real Live GPS: ($position.latitude, $position.longitude)');
      _isLocating = false;
      return position;
    } catch (e) {
      debugPrint('ℹ️ [LocationService] Live GPS fetch note: $e');
      _isLocating = false;
      // Fallback to last known position if available
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          _currentPosition = lastKnown;
          return lastKnown;
        }
      } catch (_) {}
      return _currentPosition;
    }
  }

  /// Convert position to LatLng for FlutterMap
  LatLng? get currentLatLng {
    if (_currentPosition == null) return null;
    return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
  }

  /// Check if live position has been acquired
  bool get hasPosition => _currentPosition != null;

  /// Effective LatLng with fallback
  LatLng get effectiveLatLng => currentLatLng ?? const LatLng(37.7749, -122.4194);

  /// Formatted live GPS label
  String get formattedGPS {
    if (_currentPosition == null) return 'Detecting live GPS...';
    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;
    final latDir = lat >= 0 ? 'N' : 'S';
    final lngDir = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(4)}° $latDir, ${lng.abs().toStringAsFixed(4)}° $lngDir';
  }
}

