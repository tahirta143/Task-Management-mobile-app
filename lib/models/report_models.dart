class CompletionTrendItem {
  final String day;
  final int completed;

  CompletionTrendItem({required this.day, required this.completed});

  factory CompletionTrendItem.fromJson(Map<String, dynamic> json) {
    return CompletionTrendItem(
      day: json['day'] ?? '',
      completed: json['completed'] is int ? json['completed'] : (int.tryParse(json['completed'].toString()) ?? 0),
    );
  }
}

class ReportOverview {
  final Map<String, int> counts;
  final List<CompletionTrendItem> completionTrend;

  ReportOverview({required this.counts, required this.completionTrend});

  int get totalTasks => counts['total'] ?? 0;
  int get totalCompleted => counts['completed'] ?? 0;
  int get totalInProgress => counts['inProgress'] ?? 0;
  int get overdueTasks => counts['overdue'] ?? 0;
  int get totalUsers => counts['users'] ?? 0;
  int get totalCompanies => counts['companies'] ?? 0;

  factory ReportOverview.fromJson(Map<String, dynamic> json) {
    // Backend returns { item: { counts: { total, ... }, activeUsers: X, ... } }
    final rawCounts = Map<String, dynamic>.from(json['counts'] ?? {});
    
    // Inject activeUsers into the counts map for convenience in our model getters
    if (json['activeUsers'] != null) {
      rawCounts['users'] = json['activeUsers'];
    }
    
    final countsMap = rawCounts.map(
      (key, value) => MapEntry(key, value is int ? value : (int.tryParse(value.toString()) ?? 0)),
    );

    final List<dynamic> rawTrend = json['completionTrend'] ?? [];
    final trendList = rawTrend.map((i) => CompletionTrendItem.fromJson(i)).toList();
    
    return ReportOverview(counts: countsMap, completionTrend: trendList);
  }
}

class UserPerformance {
  final int userId;
  final String username;
  final String email;
  final int assigned;
  final int pending;
  final int inProgress;
  final int completed;
  final int completionRate;
  final int evaluationCount;
  final double? avgScore;

  UserPerformance({
    required this.userId,
    required this.username,
    required this.email,
    required this.assigned,
    required this.pending,
    required this.inProgress,
    required this.completed,
    required this.completionRate,
    required this.evaluationCount,
    this.avgScore,
  });

  factory UserPerformance.fromJson(Map<String, dynamic> json) {
    final assigned = json['assigned'] ?? 0;
    final completed = json['completed'] ?? 0;
    
    // Calculate rate if not provided by backend
    int rate = json['completionRate'] ?? 0;
    if (rate == 0 && assigned > 0) {
      rate = ((completed / assigned) * 100).toInt();
    }

    return UserPerformance(
      userId: json['userId'],
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      assigned: assigned,
      pending: json['pending'] ?? 0,
      inProgress: json['inProgress'] ?? 0,
      completed: completed,
      completionRate: rate,
      evaluationCount: json['evaluationCount'] ?? 0,
      avgScore: json['avgScore'] != null ? (json['avgScore'] as num).toDouble() : null,
    );
  }
}

class CompanySummary {
  final int companyId;
  final String companyName;
  final int users;
  final int tasks;
  final int completed;

  CompanySummary({
    required this.companyId,
    required this.companyName,
    required this.users,
    required this.tasks,
    required this.completed,
  });

  factory CompanySummary.fromJson(Map<String, dynamic> json) {
    return CompanySummary(
      companyId: json['companyId'],
      companyName: json['companyName'] ?? '',
      users: json['users'] ?? 0,
      tasks: json['tasks'] ?? 0,
      completed: json['completed'] ?? 0,
    );
  }
}
