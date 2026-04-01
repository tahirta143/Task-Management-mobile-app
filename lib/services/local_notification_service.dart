import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Singleton service for showing OS-level system tray notifications.
/// Works even when the app is backgrounded / screen is locked.
class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  // ─── Android channel config ───────────────────────────────────────────────
  static const String _channelId = 'task_manager_notifications';
  static const String _channelName = 'Task Manager';
  static const String _channelDesc =
      'Notifications for chat messages and task assignments';

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    _channelId,
    _channelName,
    channelDescription: _channelDesc,
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    icon: '@mipmap/ic_launcher',
  );

  static const NotificationDetails _notificationDetails = NotificationDetails(
    android: _androidDetails,
  );

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    // Request permission on Android 13+
    // Note: We don't await this if we're in background as it's a UI action
    _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  // ─── Show notification ────────────────────────────────────────────────────

  /// Shows a system tray notification immediately.
  /// [id] should be unique per notification source to avoid collisions.
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    await _plugin.show(id, title, body, _notificationDetails);
  }

  /// Convenience method for new chat messages.
  Future<void> showChatMessage({
    required int taskId,
    required String senderName,
    required String message,
  }) async {
    await show(
      // Use taskId as notification ID so messages in the same task
      // update/replace the previous notification instead of stacking.
      id: taskId,
      title: senderName,
      body: message,
    );
  }

  /// Convenience method for new task assignment.
  Future<void> showTaskAssigned({
    required int taskId,
    required String taskTitle,
  }) async {
    await show(
      id: 1000000 + taskId, // offset to avoid collision with chat IDs
      title: 'New Task Assigned',
      body: 'You have been assigned: $taskTitle',
    );
  }

  /// Cancel a specific notification (e.g. when user opens the chat).
  Future<void> cancel(int id) => _plugin.cancel(id);

  /// Cancel all pending notifications.
  Future<void> cancelAll() => _plugin.cancelAll();
}
