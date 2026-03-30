import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
// import '../services/api_client.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  String? _error;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null && _user != null;

  AuthProvider() {
    _loadAuthFromPrefs();
  }

  Future<void> _loadAuthFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('tm_token');
      final userStr = prefs.getString('tm_user');
      
      if (_token != null && userStr != null) {
        _user = json.decode(userStr);
        // Normalize role on load too
        if (_user?['role'] != null) {
          _user!['role'] = _user!['role'].toString().toLowerCase();
        }
      } else {
        _token = null;
        _user = null;
      }
    } catch (_) {
      _token = null;
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiClient().post('/api/auth/login', body: {
        'username': username,
        'password': password,
      });

      // DIAGNOSTIC LOGGING
      debugPrint('Login Response Structure: ${response.keys}');
      debugPrint('User Data: ${response['user']}');

      _token = response['token'];
      final userData = Map<String, dynamic>.from(response['user']);
      
      // Normalize role to lowercase for consistent checking
      if (userData['role'] != null) {
        userData['role'] = userData['role'].toString().toLowerCase();
        debugPrint('Detected Role: ${userData['role']}');
      }
      _user = userData;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tm_token', _token!);
      await prefs.setString('tm_user', json.encode(_user));

      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'An unexpected error occurred';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tm_token');
    await prefs.remove('tm_user');
    
    notifyListeners();
  }
  
  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }
}
