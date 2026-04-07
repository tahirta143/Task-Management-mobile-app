import 'user_model.dart';

class Message {
  final String id;
  final int taskId;
  final int? senderId;
  final User? sender;
  final String type; // 'text' or 'image'
  final String? content;
  final String? imageUrl;
  final Map<String, dynamic>? replyInfo;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool isDeleted;
  final bool canEdit;

  Message({
    required this.id,
    required this.taskId,
    this.senderId,
    this.sender,
    required this.type,
    this.content,
    this.imageUrl,
    this.replyInfo,
    required this.createdAt,
    this.editedAt,
    this.isDeleted = false,
    this.canEdit = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'].toString(),
      taskId: json['taskId'],
      senderId: json['senderId'],
      sender: json['sender'] != null ? User.fromJson(json['sender']) : null,
      type: json['type'] ?? 'text',
      content: json['content'],
      imageUrl: json['imageUrl'],
      replyInfo: json['replyInfo'],
      createdAt: DateTime.parse((json['createdAt'] ?? DateTime.now().toIso8601String()) as String),
      editedAt: json['editedAt'] != null ? DateTime.parse(json['editedAt'] as String) : null,
      isDeleted: json['isDeleted'] ?? false,
      canEdit: json['canEdit'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'senderId': senderId,
      'sender': sender?.toJson(),
      'type': type,
      'content': content,
      'imageUrl': imageUrl,
      'replyInfo': replyInfo,
      'createdAt': createdAt.toIso8601String(),
      'editedAt': editedAt?.toIso8601String(),
      'isDeleted': isDeleted,
      'canEdit': canEdit,
    };
  }
}
