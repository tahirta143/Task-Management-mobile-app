import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;

  IO.Socket get socket => _socket!;
  String get baseUrl =>
      dotenv.env['VITE_API_BASE_URL'] ?? 'https://api.task.afaqhims.com';

  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final base = dotenv.env['VITE_SOCKET_URL'] ??
        dotenv.env['VITE_API_BASE_URL'] ??
        'https://api.task.afaqhims.com';
    final url =
        base.endsWith('/') ? '${base}task-chat' : '$base/task-chat';

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('tm_token');

    _socket = IO.io(
        url,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .disableAutoConnect()
            .setAuth({'token': token})
            .build());

    _socket!.connect();

    _socket!.onConnect((_) {
      print('Socket Connected to $url');
    });

    _socket!.onDisconnect((_) {
      print('Socket Disconnected');
    });

    _socket!.onConnectError((err) {
      print('Socket Connect Error: $err');
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  // ─── User Room ────────────────────────────────────────────────────────────

  /// Join the personal user room so the server can push notifications
  /// (task:assigned, task:new_message) directly to this user.
  /// Must be called right after connect() and authentication.
  void joinUserRoom() {
    _socket?.emit('user:join', {});
  }

  void leaveUserRoom() {
    _socket?.emit('user:leave', {});
  }

  // ─── Task Rooms ───────────────────────────────────────────────────────────

  void joinTask(int taskId) {
    _socket?.emit('task:join', {'taskId': taskId});
  }

  void leaveTask(int taskId) {
    _socket?.emit('task:leave', {'taskId': taskId});
  }

  void sendMessage(int taskId, String content,
      {int? replyToId, Function? onAck}) {
    _socket?.emitWithAck(
        'message:send',
        {
          'taskId': taskId,
          'content': content,
          'replyToId': replyToId,
        }, ack: (data) {
      if (onAck != null) onAck(data);
    });
  }

  void sendImage(int taskId, String imageUrl,
      {int? replyToId, Function? onAck}) {
    _socket?.emitWithAck(
        'message:image',
        {
          'taskId': taskId,
          'imageUrl': imageUrl,
          'replyToId': replyToId,
        }, ack: (data) {
      if (onAck != null) onAck(data);
    });
  }

  void startTyping(int taskId) {
    _socket?.emit('typing:start', {'taskId': taskId});
  }

  void stopTyping(int taskId) {
    _socket?.emit('typing:stop', {'taskId': taskId});
  }

  // ─── Notification listeners ───────────────────────────────────────────────

  /// Listen for task assignment notifications.
  /// [onAssigned] receives: { taskId, taskTitle, assigneeId }
  void listenForTaskAssigned(
      void Function(Map<String, dynamic> payload) onAssigned) {
    _socket?.on('task:assigned', (data) {
      if (data is Map<String, dynamic>) {
        onAssigned(data);
      } else if (data is Map) {
        onAssigned(Map<String, dynamic>.from(data));
      }
    });
  }

  void stopListeningForTaskAssigned() {
    _socket?.off('task:assigned');
  }

  /// Listen for new chat messages on tasks the user belongs to
  /// (fires when a message is sent in a task the user is NOT currently viewing).
  /// [onMessage] receives: { taskId, message, lastMessage }
  void listenForNewChatMessage(
      void Function(Map<String, dynamic> payload) onMessage) {
    _socket?.on('task:new_message', (data) {
      if (data is Map<String, dynamic>) {
        onMessage(data);
      } else if (data is Map) {
        onMessage(Map<String, dynamic>.from(data));
      }
    });
  }

  void stopListeningForNewChatMessage() {
    _socket?.off('task:new_message');
  }

  /// Listen for session termination (admin kill).
  void listenForSessionTerminated(void Function(Map<String, dynamic> payload) onTerminated) {
    _socket?.on('session:terminated', (data) {
      if (data is Map<String, dynamic>) {
        onTerminated(data);
      } else if (data is Map) {
        onTerminated(Map<String, dynamic>.from(data));
      }
    });
  }

  void stopListeningForSessionTerminated() {
    _socket?.off('session:terminated');
  }
}

