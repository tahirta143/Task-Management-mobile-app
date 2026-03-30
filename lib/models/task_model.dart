import 'user_model.dart';

class TaskPoint {
  final int id;
  final String label;
  final bool isDone;

  TaskPoint({
    required this.id,
    required this.label,
    required this.isDone,
  });

  factory TaskPoint.fromJson(Map<String, dynamic> json) {
    return TaskPoint(
      id: json['id'],
      label: json['label'] ?? '',
      isDone: json['isDone'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'isDone': isDone,
    };
  }
}

class Task {
  final int id;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final DateTime? startDate;
  final DateTime? dueDate;
  final int? companyId;
  final int? creatorId;
  final List<User> assignees;
  final List<TaskPoint> points;
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.startDate,
    this.dueDate,
    this.companyId,
    this.creatorId,
    this.assignees = const [],
    this.points = const [],
    required this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'],
      status: json['status'] ?? 'pending',
      priority: json['priority'] ?? 'medium',
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      companyId: json['companyId'],
      creatorId: json['creatorId'],
      assignees: (json['assignees'] as List?)?.map((u) => User.fromJson(u)).toList() ?? [],
      points: (json['points'] as List?)?.map((p) => TaskPoint.fromJson(p)).toList() ?? [],
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'startDate': startDate?.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'companyId': companyId,
      'creatorId': creatorId,
      'assignees': assignees.map((u) => u.toJson()).toList(),
      'points': points.map((p) => p.toJson()).toList(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
