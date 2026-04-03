import '../models/user_model.dart';

class SessionTracking {
  final int id;
  final String sessionTokenId;
  final DateTime loginAt;
  final DateTime lastSeenAt;
  final DateTime? disconnectedAt;
  final DateTime? revokedAt;
  final String? revokedBy;
  final String? revokeReason;
  final bool isActive;
  final DateTime? lastSocketConnectedAt;
  final int socketConnectionCount;
  final String? ipAddress;
  final String? userAgent;
  final User user;

  SessionTracking({
    required this.id,
    required this.sessionTokenId,
    required this.loginAt,
    required this.lastSeenAt,
    this.disconnectedAt,
    this.revokedAt,
    this.revokedBy,
    this.revokeReason,
    required this.isActive,
    this.lastSocketConnectedAt,
    required this.socketConnectionCount,
    this.ipAddress,
    this.userAgent,
    required this.user,
  });

  factory SessionTracking.fromJson(Map<String, dynamic> json) {
    return SessionTracking(
      id: json['id'],
      sessionTokenId: json['sessionTokenId'],
      loginAt: DateTime.parse(json['loginAt']),
      lastSeenAt: DateTime.parse(json['lastSeenAt']),
      disconnectedAt: json['disconnectedAt'] != null ? DateTime.parse(json['disconnectedAt']) : null,
      revokedAt: json['revokedAt'] != null ? DateTime.parse(json['revokedAt']) : null,
      revokedBy: json['revokedBy'],
      revokeReason: json['revokeReason'],
      isActive: json['isActive'] ?? false,
      lastSocketConnectedAt: json['lastSocketConnectedAt'] != null ? DateTime.parse(json['lastSocketConnectedAt']) : null,
      socketConnectionCount: json['socketConnectionCount'] ?? 0,
      ipAddress: json['ipAddress'],
      userAgent: json['userAgent'],
      user: User.fromJson(json['user']),
    );
  }
}
