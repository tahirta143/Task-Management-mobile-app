import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  
  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  String get baseUrl => dotenv.env['VITE_API_BASE_URL'] ?? 'https://api.task.afaqhims.com';

  Future<Map<String, String>> _getHeaders({bool excludeAuth = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tm_token');
    
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (!excludeAuth && token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<dynamic> _processResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return json.decode(response.body);
    } else {
      String errMsg = 'Request failed';
      try {
        final body = json.decode(response.body);
        if (body['error'] != null && body['error']['message'] != null) {
          errMsg = body['error']['message'];
        } else if (body['message'] != null) {
          errMsg = body['message'];
        }
      } catch (_) {}
      
      throw ApiException(errMsg, response.statusCode);
    }
  }

  Future<dynamic> get(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 20));
    return _processResponse(response);
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    
    // Auto-exclude auth for auth endpoints
    final bool isAuthEndpoint = endpoint.contains('/api/auth/login') || endpoint.contains('/api/auth/register');
    final headers = await _getHeaders(excludeAuth: isAuthEndpoint);
    
    final response = await http.post(
      url,
      headers: headers,
      body: body != null ? json.encode(body) : null,
    ).timeout(const Duration(seconds: 20));
    return _processResponse(response);
  }
  
  Future<dynamic> multipartPost(String endpoint, {Map<String, String>? fields, required File file, String fieldName = 'image'}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    // Multipart has its own content-type, let the request handle it
    headers.remove('Content-Type');

    final request = http.MultipartRequest('POST', url);
    request.headers.addAll(headers);
    if (fields != null) {
      request.fields.addAll(fields);
    }

    final multipartFile = await http.MultipartFile.fromPath(
      fieldName,
      file.path,
      filename: path.basename(file.path),
    );
    request.files.add(multipartFile);

    final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);
    return _processResponse(response);
  }

  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    final response = await http.put(
      url,
      headers: headers,
      body: body != null ? json.encode(body) : null,
    ).timeout(const Duration(seconds: 20));
    return _processResponse(response);
  }

  Future<dynamic> patch(String endpoint, {Map<String, dynamic>? body}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    
    final request = http.Request('PATCH', url);
    request.headers.addAll(headers);
    if (body != null) {
      request.body = json.encode(body);
    }
    
    final streamedResponse = await request.send().timeout(const Duration(seconds: 20));
    final response = await http.Response.fromStream(streamedResponse);
    return _processResponse(response);
  }

  Future<dynamic> delete(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    final response = await http.delete(url, headers: headers).timeout(const Duration(seconds: 20));
    return _processResponse(response);
  }
}
