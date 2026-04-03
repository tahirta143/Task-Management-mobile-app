import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../services/api_client.dart';
import '../services/socket_service.dart';

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
    _initSessionListener();
  }

  void _initSessionListener() {
    SocketService().listenForSessionTerminated((payload) {
      debugPrint('SESSION TERMINATED: ${payload['message']}');
      logout(); // Perform logout and notify listeners
    });
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
      // If authenticated on load, ensure FCM token is registered
      if (isAuthenticated) {
        _updateFcmToken();
      }
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
      
      // Register FCM Token after successful login
      _updateFcmToken();
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
    
    // Clear socket connection so next login uses new token
    SocketService().disconnect();
    
    notifyListeners();
  }
  
  Future<void> updateProfileImage(File imageFile) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      if (_user == null) throw ApiException('User not authenticated');

      // 1. Upload the image
      final uploadRes = await ApiClient().multipartPost(
        '/api/uploads/image',
        file: imageFile,
        fieldName: 'image'
      );
      
      final url = uploadRes['url'];
      if (url == null) throw ApiException('Failed to get upload URL');

      // 2. Patch the user's profileImageUrl
      final patchRes = await ApiClient().patch(
        '/api/users/${_user!['id']}/profile-image',
        body: {'profileImageUrl': url}
      );
      
      // 3. Update the local user object with returned data or manually
      final updatedUser = Map<String, dynamic>.from(_user!);
      updatedUser['profileImageUrl'] = url;
      _user = updatedUser;
      
      // 4. Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tm_user', json.encode(_user));
      
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Failed to upload profile image';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
  
  Future<void> changePassword(String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      if (_user == null) throw ApiException('User not authenticated');

      await ApiClient().patch(
        '/api/users/me/password',
        body: {'password': newPassword}
      );
      
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Failed to change password';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateProfile({String? username, String? email}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_user == null) throw ApiException('User not authenticated');

      final payload = <String, dynamic>{};
      final currentUsername = _user!['username']?.toString() ?? '';
      final currentEmail = _user!['email']?.toString() ?? '';

      if (username != null && username.trim().isNotEmpty && username.trim() != currentUsername) {
        payload['username'] = username.trim();
      }
      if (email != null && email.trim().isNotEmpty && email.trim() != currentEmail) {
        payload['email'] = email.trim();
      }

      if (payload.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await ApiClient().patch(
        '/api/users/me',
        body: payload,
      );

      // response['item'] contains the updated user
      if (response != null && response['item'] != null) {
        final userData = Map<String, dynamic>.from(response['item']);
        // Normalize role if present
        if (userData['role'] != null) {
          userData['role'] = userData['role'].toString().toLowerCase();
        }
        _user = userData;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('tm_user', json.encode(_user));
      }

      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = 'Failed to update profile';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
  
  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  /// Fetches and registers the FCM token for the current user.
  Future<void> _updateFcmToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      
      // Request permission (redundant if already done in LocalNotificationService but safe)
      await messaging.requestPermission();

      final token = await messaging.getToken();
      if (token != null) {
        debugPrint('FCM Token: $token');
        await ApiClient().patch('/api/auth/me/fcm-token', body: {'fcmToken': token});
        debugPrint('FCM Token Registered Successfully');
      }
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }
}
