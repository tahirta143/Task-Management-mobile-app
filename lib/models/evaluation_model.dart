class Evaluation {
  final int id;
  final int taskId;
  final int userId;
  final double rating;
  final String? remarks;
  final DateTime createdAt;

  Evaluation({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.rating,
    this.remarks,
    required this.createdAt,
  });

  factory Evaluation.fromJson(Map<String, dynamic> json) {
    return Evaluation(
      id: json['id'],
      taskId: json['taskId'],
      userId: json['userId'],
      rating: (json['rating'] ?? 0.0).toDouble(),
      remarks: json['remarks'],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'userId': userId,
      'rating': rating,
      'remarks': remarks,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
