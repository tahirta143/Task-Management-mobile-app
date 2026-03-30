import 'dart:io';
import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../services/api_client.dart';

class ChatProvider extends ChangeNotifier {
  List<Message> _messages = [];
  bool _isLoading = false;
  String? _error;

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final ApiClient _api = ApiClient();

  Future<void> fetchMessages(int taskId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.get('/api/tasks/$taskId/messages');
      final List<dynamic> items = response['items'] ?? [];
      _messages = items.map((m) => Message.fromJson(m)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendTextMessage(int taskId, String content) async {
    try {
      final res = await _api.post('/api/tasks/$taskId/messages/text', body: {
        'content': content,
      });
      final newMessage = Message.fromJson(res['item']);
      _messages.add(newMessage);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendImageMessage(int taskId, File file) async {
    try {
      final res = await _api.multipartPost('/api/tasks/$taskId/messages/image', file: file);
      final newMessage = Message.fromJson(res['item']);
      _messages.add(newMessage);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // Socket helpers can be added here once a Socket service is implemented
  void addMessageLocally(Message message) {
    if (!_messages.any((m) => m.id == message.id)) {
      _messages.add(message);
      notifyListeners();
    }
  }
}
