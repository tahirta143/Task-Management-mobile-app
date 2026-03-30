import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/company_model.dart';
import '../models/report_models.dart';
import '../services/api_client.dart';

class AdminProvider extends ChangeNotifier {
  List<User> _users = [];
  List<Company> _companies = [];
  
  ReportOverview? _overview;
  List<UserPerformance> _userPerformance = [];
  List<CompanySummary> _companySummary = [];

  bool _isLoading = false;
  String? _error;

  List<User> get users => _users;
  List<Company> get companies => _companies;
  ReportOverview? get overview => _overview;
  List<UserPerformance> get userPerformance => _userPerformance;
  List<CompanySummary> get companySummary => _companySummary;
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
}
