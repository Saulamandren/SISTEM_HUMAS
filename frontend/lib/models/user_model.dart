class User {
  final int id;
  final String username;
  final String email;
  final String fullName;
  final String? nip;
  final String role;
  final bool isActive;
  final bool emailVerified;
  final DateTime? lastLogin;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    this.nip,
    required this.role,
    required this.isActive,
    required this.emailVerified,
    this.lastLogin,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value, {int fallback = 0}) {
      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      final text = value?.toString().toLowerCase();
      return text == 'true' || text == '1' || text == 'yes';
    }

    String parseString(dynamic value, {String fallback = ''}) {
      if (value == null) return fallback;
      return value.toString();
    }

    return User(
      id: parseInt(json['id']),
      username: parseString(json['username']),
      email: parseString(json['email']),
      fullName: parseString(
        json['full_name'] ?? json['fullName'] ?? json['name'] ?? json['username'],
      ),
      nip: json['nip']?.toString(),
      role: parseString(json['role'] ?? json['role_name'], fallback: 'User'),
      isActive: parseBool(json['is_active'] ?? json['isActive']),
      emailVerified:
          parseBool(json['email_verified'] ?? json['emailVerified']),
      lastLogin: json['last_login'] != null
          ? DateTime.tryParse(json['last_login'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'full_name': fullName,
      'nip': nip,
      'role': role,
      'is_active': isActive,
      'email_verified': emailVerified,
      'last_login': lastLogin?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isUser => role == 'User';
  bool get isStaff => role == 'Staff Jashumas';
  bool get isKasubbag => role == 'Kasubbag Jashumas';
  bool get isAdmin => isKasubbag;
}
