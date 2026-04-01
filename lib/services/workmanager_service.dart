import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_client.dart';
import 'local_notification_service.dart';

/// Top-level function for Workmanager background execution.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // 1. Initialize essential configurations
      try {
        await dotenv.load(fileName: ".env");
      } catch (_) {
        // Fallback or ignore if .env is missing in isolate
      }
      
      final prefs = await SharedPreferences.getInstance();
      
      // 2. Check if user is authenticated
      final token = prefs.getString('tm_token');
      if (token == null || token.isEmpty) {
        return true; // No token, nothing to sync
      }

      // 3. Fetch latest tasks
      // We use a fresh instance of ApiClient which reads token from SharedPreferences
      final apiClient = ApiClient();
      final response = await apiClient.get('/api/tasks?orderBy=updated_at');
      
      if (response == null || response['items'] == null) {
        return true;
      }

      final List<dynamic> items = response['items'];
      
      if (items.isNotEmpty) {
        final notificationService = LocalNotificationService();
        bool notified = false;

        // --- 1. Handle New Tasks ---
        final latestTask = items.first;
        final int latestId = latestTask['id'];
        final String latestTitle = latestTask['title'] ?? 'New Task';

        // Compare with last notified ID stored in SharedPreferences
        final int lastNotifiedId = prefs.getInt('last_notified_task_id') ?? 0;
        
        if (latestId > lastNotifiedId) {
          await notificationService.initialize();
          await notificationService.showTaskAssigned(
            taskId: latestId,
            taskTitle: latestTitle,
          );
          
          // Update last notified ID to prevent duplicate notifications
          await prefs.setInt('last_notified_task_id', latestId);
          notified = true;
        }

        // --- 2. Handle New Messages ---
        // Sum the unreadCount from all tasks returned by the API
        int totalUnread = 0;
        for (var item in items) {
          totalUnread += (item['unreadCount'] as int? ?? 0);
        }

        final int previousUnread = prefs.getInt('last_notified_unread_count') ?? 0;
        
        if (totalUnread > previousUnread) {
          // If we haven't already shown a "new task" notification, show "new messages"
          // Or we can show both. Let's show both since they are distinct events.
          if (!notificationService.isInitialized) await notificationService.initialize();
          
          await notificationService.show(
            id: 999999, // Use a high constant ID for unread summary
            title: 'New Messages',
            body: 'You have $totalUnread unread messages across your tasks.',
          );
          notified = true;
        }

        // Update the last known unread count regardless of whether we notified, 
        // to stay in sync with the server's current state.
        await prefs.setInt('last_notified_unread_count', totalUnread);
      }
      
      return true;
    } catch (e) {
      // Log error to console (visible in logcat/xcode)
      print('Workmanager Background Task Error: $e');
      return false; 
    }
  });
}

class WorkmanagerService {
  static const String syncTaskName = "com.taskmanager.task_sync";

  /// Initialize Workmanager with the callback dispatcher.
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  }

  /// Registers a periodic task that runs every 15 minutes (Android minimum).
  static Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      "task-sync-periodic", // Unique ID
      syncTaskName,         // Task Name
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep, // Fixed: ExistingPeriodicWorkPolicy instead of ExistingWorkPolicy
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  /// Helper to run a test sync immediately.
  static Future<void> testSync() async {
    await Workmanager().registerOneOffTask(
      "test-sync-${DateTime.now().millisecondsSinceEpoch}",
      syncTaskName,
    );
  }

  /// Cancel sync tasks (e.g. on logout).
  static Future<void> cancelSync() async {
    await Workmanager().cancelByUniqueName("task-sync-periodic");
  }
}
