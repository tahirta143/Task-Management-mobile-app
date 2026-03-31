import 'dart:io';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/company_model.dart';
import '../models/report_models.dart';
import '../models/task_model.dart';
import '../services/api_client.dart';

class AdminProvider extends ChangeNotifier {
  List<User> _users = [];
  List<Company> _companies = [];
  
  ReportOverview? _overview;
  List<UserPerformance> _userPerformance = [];
  List<CompanySummary> _companySummary = [];
  List<Task> _progressTasks = [];

  // Filter State
  String _datePreset = 'all';
  DateTimeRange? _customRange;
  int? _selectedUserId;

  bool _isLoading = false;
  String? _error;

  List<User> get users => _users;
  List<Company> get companies => _companies;
  ReportOverview? get overview => _overview;
  List<UserPerformance> get userPerformance => _userPerformance;
  List<CompanySummary> get companySummary => _companySummary;
  List<Task> get progressTasks => _progressTasks;
  
  String get datePreset => _datePreset;
  DateTimeRange? get customRange => _customRange;
  int? get selectedUserId => _selectedUserId;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final ApiClient _api = ApiClient();

  // User Management
  Future<void> fetchUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.get('/api/users');
      final List<dynamic> items = response['items'] ?? [];
      _users = items.map((u) => User.fromJson(u)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createUser(Map<String, dynamic> payload) async {
    try {
      final response = await _api.post('/api/users', body: payload);
      final newUser = User.fromJson(response['item']);
      _users.insert(0, newUser);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateUser(int userId, Map<String, dynamic> payload) async {
    try {
      final response = await _api.patch('/api/users/$userId', body: payload);
      final updatedUser = User.fromJson(response['item']);
      final index = _users.indexWhere((u) => u.id == userId);
      if (index != -1) {
        _users[index] = updatedUser;
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteUser(int userId) async {
    try {
      await _api.delete('/api/users/$userId');
      _users.removeWhere((u) => u.id == userId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> setUserCompany(int userId, int? companyId) async {
    try {
      final response = await _api.patch('/api/users/$userId/company', body: {'companyId': companyId});
      final updatedUser = User.fromJson(response['item']);
      final index = _users.indexWhere((u) => u.id == userId);
      if (index != -1) {
        _users[index] = updatedUser;
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String> uploadProfileImage(File file) async {
    try {
      final res = await _api.multipartPost('/api/upload', file: file, fieldName: 'image');
      return res['url'];
    } catch (e) {
      rethrow;
    }
  }

  // Company Management
  Future<void> fetchCompanies() async {
    try {
      final response = await _api.get('/api/companies');
      final List<dynamic> items = response['items'] ?? [];
      _companies = items.map((c) => Company.fromJson(c)).toList();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createCompany(String name) async {
    try {
      final response = await _api.post('/api/companies', body: {'name': name});
      final newCompany = Company.fromJson(response['item']);
      _companies.insert(0, newCompany);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // Reports
  Future<void> fetchDashboardReport() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.get('/api/reports/overview');
      debugPrint('AdminProvider: Raw Overview Data: ${res['item']}');
      _overview = ReportOverview.fromJson(res['item']);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('AdminProvider: Error fetching overview: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUserPerformance() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _api.get('/api/reports/user-performance');
      debugPrint('AdminProvider: Raw Performance Data: ${res['items']}');
      final List<dynamic> items = res['items'] ?? [];
      _userPerformance = items.map((i) => UserPerformance.fromJson(i)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('AdminProvider: Error fetching performance: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCompanySummary() async {
    try {
      final res = await _api.get('/api/reports/company-summary');
      final List<dynamic> items = res['items'] ?? [];
      _companySummary = items.map((i) => CompanySummary.fromJson(i)).toList();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> fetchProgressTasks() async {
    try {
      final res = await _api.get('/api/progress');
      final List<dynamic> items = res['items'] ?? [];
      _progressTasks = items.map((i) => Task.fromJson(i)).toList();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  void setFilters({String? datePreset, DateTimeRange? customRange, int? selectedUserId}) {
    if (datePreset != null) _datePreset = datePreset;
    _customRange = customRange; // Allow null to clear
    _selectedUserId = selectedUserId;
    notifyListeners();
  }

  List<Task> get filteredProgressTasks {
    DateTime? start;
    DateTime? end = DateTime.now().add(const Duration(days: 1)); // Buffer to include current day

    if (_datePreset == 'today') {
      start = DateTime(end.year, end.month, end.day - 1);
    } else if (_datePreset == 'week') {
      final now = DateTime.now();
      start = now.subtract(Duration(days: now.weekday - 1));
      start = DateTime(start.year, start.month, start.day);
    } else if (_datePreset == 'month') {
      final now = DateTime.now();
      start = DateTime(now.year, now.month, 1);
    } else if (_datePreset == '7d') {
      start = DateTime.now().subtract(const Duration(days: 7));
    } else if (_datePreset == '30d') {
      start = DateTime.now().subtract(const Duration(days: 30));
    } else if (_datePreset == '90d') {
      start = DateTime.now().subtract(const Duration(days: 90));
    } else if (_datePreset == 'custom' && _customRange != null) {
      start = _customRange!.start;
      end = _customRange!.end.add(const Duration(days: 1));
    }

    return _progressTasks.where((t) {
      final date = t.dueDate ?? t.updatedAt;
      bool inDateRange = true;
      if (start != null) {
        inDateRange = date.isAfter(start!) && date.isBefore(end!);
      }
      
      bool matchesUser = true;
      if (_selectedUserId != null) {
        matchesUser = t.assignees.any((u) => u.id == _selectedUserId);
      }
      
      return inDateRange && matchesUser;
    }).toList();
  }
}
