import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import '../config/app_config.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📩 Background FCM: ${message.notification?.title}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final ApiService _api = ApiService();
  
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Initialize FCM and request permissions
  Future<void> initialize() async {
    try {
      // Request permission (iOS will show dialog, Android auto-grants)
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ FCM Permission granted');
        
        // Get FCM token
        _fcmToken = await _fcm.getToken();
        debugPrint('🔑 FCM Token: $_fcmToken');

        // Send token to backend
        if (_fcmToken != null) {
          await _sendTokenToBackend(_fcmToken!);
        }

        // Listen for token refresh
        _fcm.onTokenRefresh.listen(_sendTokenToBackend);

        // Set background message handler
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        // Listen for foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle notification tap when app is in background
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        // Check if app was opened from a notification
        final initialMessage = await _fcm.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }

      } else {
        debugPrint('❌ FCM Permission denied');
      }
    } catch (e) {
      debugPrint('❌ FCM Init error: $e');
    }
  }

  /// Send token to Laravel backend
  Future<void> _sendTokenToBackend(String token) async {
    try {
      await _api.post(
        '/customer/device-token',
        data: {'device_token': token},
      );
      debugPrint('✅ Sent FCM token to backend');
    } catch (e) {
      debugPrint('❌ Failed to send token: $e');
    }
  }

  /// Public method to re-send FCM token after login/registration
  Future<void> sendTokenToServer() async {
    _fcmToken ??= await _fcm.getToken();
    if (_fcmToken != null) {
      await _sendTokenToBackend(_fcmToken!);
    }
  }

  /// Handle foreground message (app is open)
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📬 Foreground FCM: ${message.notification?.title}');
    // You can show in-app notification here if needed
    // For now, system handles it automatically
  }

  /// Handle notification tap (opens app from notification)
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('👆 Tapped notification: ${message.data}');
    
    // Navigate based on notification data
    final bookingId = message.data['booking_id'];
    if (bookingId != null) {
      // TODO: Navigate to booking details screen
      // Example: navigatorKey.currentState?.pushNamed('/booking-details', arguments: bookingId);
    }
  }
}
