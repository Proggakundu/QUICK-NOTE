import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;

class NotificationService {
  static bool _permissionGranted = false;
  static bool _permissionRequested = false;

  /// Initialize and request notification permission
  static Future<bool> initialize() async {
    if (!kIsWeb) {
      // On mobile, use flutter_local_notifications (can add later)
      return false;
    }

    if (_permissionRequested) {
      return _permissionGranted;
    }

    try {
      // Check if notifications are supported
      if (!html.Notification.supported) {
        print('Notifications not supported in this browser');
        return false;
      }

      // Check current permission
      final permission = html.Notification.permission;
      
      if (permission == 'granted') {
        _permissionGranted = true;
        _permissionRequested = true;
        return true;
      }

      if (permission == 'denied') {
        _permissionGranted = false;
        _permissionRequested = true;
        return false;
      }

      // Request permission
      final result = await html.Notification.requestPermission();
      _permissionRequested = true;
      _permissionGranted = result == 'granted';
      
      return _permissionGranted;
    } catch (e) {
      print('Error initializing notifications: $e');
      return false;
    }
  }

  /// Show a notification
  static Future<void> showNotification(String title, String body, {String? icon}) async {
    if (!kIsWeb) return;

    try {
      // Request permission if not already requested
      if (!_permissionRequested) {
        final granted = await initialize();
        if (!granted) return;
      }

      if (!_permissionGranted) {
        print('Notification permission not granted');
        return;
      }

      // Show notification
      html.Notification(
        title,
        body: body,
        icon: icon ?? '/icons/Icon-192.png',
      );
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  /// Show auto-save notification
  static Future<void> notifyAutoSave(String noteTitle) async {
    await showNotification(
      '✓ Auto-Saved',
      '"$noteTitle" has been saved automatically',
    );
  }

  /// Show location captured notification
  static Future<void> notifyLocationCaptured(double lat, double lon) async {
    await showNotification(
      '📍 Location Captured',
      'Location: ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}',
    );
  }

  /// Show sync notification
  static Future<void> notifySynced(int noteCount) async {
    await showNotification(
      '☁️ Synced to Cloud',
      '$noteCount ${noteCount == 1 ? 'note' : 'notes'} synced successfully',
    );
  }

  /// Show reminder notification
  static Future<void> notifyReminder(String noteTitle, String message) async {
    await showNotification(
      '🔔 Reminder: $noteTitle',
      message,
    );
  }

  /// Check if notifications are supported
  static bool isSupported() {
    if (!kIsWeb) return false;
    return html.Notification.supported;
  }

  /// Check if permission is granted
  static bool hasPermission() {
    return _permissionGranted;
  }
}