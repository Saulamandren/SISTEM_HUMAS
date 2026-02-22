import '../models/user_model.dart';

class PaginatedUsers {
  final List<User> users;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPreviousPage;

  PaginatedUsers({
    required this.users,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  factory PaginatedUsers.fromJson(Map<String, dynamic> json) {
    final userList = json['users'] as List<dynamic>? ?? [];
    final users = userList
        .map((item) => User.fromJson(item as Map<String, dynamic>))
        .toList();

    final pagination = json['pagination'] as Map<String, dynamic>? ?? const {};
    final page = json['page'] ?? pagination['page'] ?? 1;
    final totalPages = json['total_pages'] ?? pagination['total_pages'] ?? 0;

    return PaginatedUsers(
      users: users,
      page: page,
      perPage: json['per_page'] ?? pagination['per_page'] ?? 10,
      total: json['total'] ?? pagination['total'] ?? 0,
      totalPages: totalPages,
      hasNextPage: page < totalPages,
      hasPreviousPage: page > 1,
    );
  }
}
