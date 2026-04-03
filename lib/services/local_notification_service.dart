import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../main.dart';
import '../screens/chat_screen/chat_detail_screen.dart';
import '../screens/board_screen/task_detail_screen.dart';

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

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          _onNotificationTap(response.payload!);
        }
      },
    );

    // Request permission on Android 13+
    // Note: We don't await this if we're in background as it's a UI action
    _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  // ─── Click Handler ────────────────────────────────────────────────────────

  void _onNotificationTap(String payload) {
    try {
      final Map<String, dynamic> data = jsonDecode(payload);
      final taskId = data['taskId'];
      final type = data['type'];

      if (taskId == null) return;

      final context = navigatorKey.currentContext;
      if (context == null) return;

      if (type == 'chat') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              taskId: taskId is int ? taskId : int.parse(taskId.toString()),
              taskTitle: data['taskTitle'] ?? 'Chat',
            ),
          ),
        );
      } else if (type == 'task') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => TaskDetailScreen(
              taskId: taskId is int ? taskId : int.parse(taskId.toString()),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
    }
  }

  // ─── Show notification ────────────────────────────────────────────────────

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    await _plugin.show(id, title, body, _notificationDetails, payload: payload);
  }

  /// Convenience method for new chat messages.
  Future<void> showChatMessage({
    required int taskId,
    required String senderName,
    required String message,
    String? taskTitle,
  }) async {
    final payload = jsonEncode({
      'type': 'chat',
      'taskId': taskId,
      'taskTitle': taskTitle ?? 'Chat Room',
    });
    
    await show(
      id: taskId,
      title: senderName,
      body: message,
      payload: payload,
    );
  }

  /// Convenience method for new task assignment.
  Future<void> showTaskAssigned({
    required int taskId,
    required String taskTitle,
  }) async {
    final payload = jsonEncode({
      'type': 'task',
      'taskId': taskId,
      'taskTitle': taskTitle,
    });

    await show(
      id: 1000000 + taskId, // offset to avoid collision with chat IDs
      title: 'New Task Assigned',
      body: 'You have been assigned: $taskTitle',
      payload: payload,
    );
  }

  /// Cancel a specific notification (e.g. when user opens the chat).
  Future<void> cancel(int id) => _plugin.cancel(id);

  /// Cancel all pending notifications.
  Future<void> cancelAll() => _plugin.cancelAll();
}
