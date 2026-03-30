class User {
  final int id;
  final String username;
  final String role;
  final String? email;
  final int? companyId;
  final String? profileImageUrl;
  final String? fullName;
  final String? phone;
  final String? designation;

  User({
    required this.id,
    required this.username,
    required this.role,
    this.email,
    this.companyId,
    this.profileImageUrl,
    this.fullName,
    this.phone,
    this.designation,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'] ?? '',
      role: json['role'] ?? 'user',
      email: json['email'],
      companyId: json['companyId'],
      profileImageUrl: json['profileImageUrl'],
      fullName: json['fullName'],
      phone: json['phone'],
      designation: json['designation'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'role': role,
      'email': email,
      'companyId': companyId,
      'profileImageUrl': profileImageUrl,
      'fullName': fullName,
      'phone': phone,
      'designation': designation,
    };
  }
}
