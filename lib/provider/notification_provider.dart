import 'package:flutter/material.dart';

class AppNotification {
  final String id;
  final int? taskId;
  final String title;
  final String body;
  final DateTime createdAt;
  bool read;

  AppNotification({
    required this.id,
    this.taskId,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
  });

  factory AppNotification.fromTaskAssigned(Map<String, dynamic> data) {
    return AppNotification(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      taskId: data['taskId'] is int
          ? data['taskId']
          : int.tryParse('${data['taskId'] ?? ''}'),
      title: 'New Task Assigned',
      body: data['taskTitle'] != null
          ? 'You have been assigned: ${data['taskTitle']}'
          : 'A new task has been assigned to you.',
      createdAt: DateTime.now(),
    );
  }

  factory AppNotification.fromChatMessage(Map<String, dynamic> data) {
    final last = data['lastMessage'] as Map<String, dynamic>?;
    final sender = last?['senderUsername'] ?? 'Someone';
    final content = last?['type'] == 'image'
        ? '📷 Image'
        : (last?['content'] ?? 'New message');
    final taskId = data['taskId'] is int
        ? data['taskId'] as int
        : int.tryParse('${data['taskId'] ?? ''}');
    return AppNotification(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      taskId: taskId,
      title: 'New Message',
      body: '$sender: $content',
      createdAt: DateTime.now(),
    );
  }
}

class NotificationProvider extends ChangeNotifier {
  final List<AppNotification> _notifications = [];

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.read).length;

  void addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    if (_notifications.length > 50) {
      _notifications.removeRange(50, _notifications.length);
    }
    notifyListeners();
  }

  void markAllRead() {
    for (final n in _notifications) {
      n.read = true;
    }
    notifyListeners();
  }

  void markRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx].read = true;
      notifyListeners();
    }
  }

  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }
}
