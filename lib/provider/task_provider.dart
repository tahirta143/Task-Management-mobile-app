import 'dart:io';
import 'package:flutter/cupertino.dart';

import '../models/task_model.dart';
import '../models/user_model.dart';
import '../models/company_model.dart';
import '../models/message_model.dart';
import '../services/api_client.dart';

class TaskProvider extends ChangeNotifier {
  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _error;

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final ApiClient _api = ApiClient();

  Future<void> fetchTasks({String orderBy = 'updated_at'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.get('/api/tasks?orderBy=$orderBy');
      final List<dynamic> items = response['items'] ?? [];
      _tasks = items.map((item) => Task.fromJson(item)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Task> fetchTask(int id) async {
    try {
      final response = await _api.get('/api/tasks/$id');
      return Task.fromJson(response['item']);
    } catch (e) {
      rethrow;
    }
  }

  Future<Task> createTask(Map<String, dynamic> payload) async {
    try {
      final response = await _api.post('/api/tasks', body: payload);
      final newTask = Task.fromJson(response['item']);
      _tasks.insert(0, newTask);
      notifyListeners();
      return newTask;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateTask(int taskId, Map<String, dynamic> patch) async {
    try {
      final response = await _api.patch('/api/tasks/$taskId', body: patch);
      final updatedTask = Task.fromJson(response['item']);
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _tasks[index] = updatedTask;
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> replaceTaskAssignees(int taskId, List<int> assigneeIds) async {
    try {
      final response = await _api.put('/api/tasks/$taskId/assignees', body: {'assigneeIds': assigneeIds});
      final updatedTask = Task.fromJson(response['item']);
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _tasks[index] = updatedTask;
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> togglePoint(int taskId, int pointId, bool isDone) async {
    try {
      await _api.patch('/api/tasks/$taskId/points/$pointId', body: {'isDone': isDone});
      // We could update local state here to avoid full reload
      final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
      if (taskIndex != -1) {
        final task = _tasks[taskIndex];
        final pointIndex = task.points.indexWhere((p) => p.id == pointId);
        if (pointIndex != -1) {
          final updatedPoints = List<TaskPoint>.from(task.points);
          updatedPoints[pointIndex] = TaskPoint(
            id: pointId,
            label: updatedPoints[pointIndex].label,
            isDone: isDone,
          );
          _tasks[taskIndex] = Task(
            id: task.id,
            title: task.title,
            description: task.description,
            status: task.status,
            priority: task.priority,
            startDate: task.startDate,
            dueDate: task.dueDate,
            companyId: task.companyId,
            creatorId: task.creatorId,
            assignees: task.assignees,
            points: updatedPoints,
            updatedAt: DateTime.now(),
          );
          notifyListeners();
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteTask(int taskId) async {
    try {
      await _api.delete('/api/tasks/$taskId');
      _tasks.removeWhere((t) => t.id == taskId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // Chat/Messages
  Future<List<Message>> fetchTaskMessages(int taskId) async {
    try {
      final response = await _api.get('/api/tasks/$taskId/messages');
      final List<dynamic> items = response['items'] ?? [];
      return items.map((m) => Message.fromJson(m)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<Message> uploadTaskImage(int taskId, File image) async {
    try {
      final response = await _api.multipartPost('/api/tasks/$taskId/messages/image', file: image);
      return Message.fromJson(response['item']);
    } catch (e) {
      rethrow;
    }
  }

  // Helpers often used in task creation/editing
  Future<List<User>> fetchUsers() async {
    try {
      final response = await _api.get('/api/users');
      final List<dynamic> items = response['items'] ?? [];
      return items.map((item) => User.fromJson(item)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Company>> fetchCompanies() async {
    try {
      final response = await _api.get('/api/companies');
      final List<dynamic> items = response['items'] ?? [];
      return items.map((item) => Company.fromJson(item)).toList();
    } catch (e) {
      rethrow;
    }
  }

  void markTaskAsRead(int taskId) {}
}
