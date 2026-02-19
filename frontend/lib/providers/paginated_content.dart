import '../models/content_model.dart';

class PaginatedContent {
  final List<Content> contents;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPreviousPage;

  PaginatedContent({
    required this.contents,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  factory PaginatedContent.fromJson(Map<String, dynamic> json) {
    var contentList = json['contents'] as List<dynamic>? ?? [];
    List<Content> contentsList = contentList
        .map((i) => Content.fromJson(i as Map<String, dynamic>))
        .toList();

    final pagination = json['pagination'] as Map<String, dynamic>? ?? const {};

    return PaginatedContent(
      contents: contentsList,
      page: json['page'] ?? pagination['page'] ?? 1,
      perPage: json['per_page'] ?? pagination['per_page'] ?? 10,
      total: json['total'] ?? pagination['total'] ?? 0,
      totalPages: json['total_pages'] ?? pagination['total_pages'] ?? 0,
      hasNextPage:
          (json['page'] ?? pagination['page'] ?? 1) <
          (json['total_pages'] ?? pagination['total_pages'] ?? 0),
      hasPreviousPage: (json['page'] ?? pagination['page'] ?? 1) > 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contents': contents.map((c) => c.toJson()).toList(),
      'page': page,
      'per_page': perPage,
      'total': total,
      'total_pages': totalPages,
    };
  }
}
