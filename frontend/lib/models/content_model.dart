import 'package:intl/intl.dart';

enum ContentStatus {
  draft('draft', 'Draft'),
  pending('pending', 'Pending Review'),
  approved('approved', 'Approved'),
  published('published', 'Published'),
  rejected('rejected', 'Rejected');

  final String value;
  final String displayName;

  const ContentStatus(this.value, this.displayName);

  static ContentStatus fromString(String value) {
    return ContentStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ContentStatus.draft,
    );
  }
}

class Content {
  final int id;
  final String title;
  final String? slug;
  final String? excerpt;
  final String body;
  final int categoryId;
  final String categoryName;
  final int authorId;
  final String authorName;
  final ContentStatus status;
  final String statusText;
  final int views;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Content({
    required this.id,
    required this.title,
    this.slug,
    this.excerpt,
    required this.body,
    required this.categoryId,
    required this.categoryName,
    required this.authorId,
    required this.authorName,
    required this.status,
    required this.statusText,
    this.views = 0,
    this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Content.fromJson(Map<String, dynamic> json) {
    final status = ContentStatus.fromString(json['status'] ?? 'draft');
    return Content(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      slug: json['slug'],
      excerpt: json['excerpt'],
      body: json['body'] ?? '',
      categoryId: json['category_id'] ?? 0,
      categoryName: json['category_name'] ?? '',
      authorId: json['author_id'] ?? 0,
      authorName: json['author_name'] ?? '',
      status: status,
      statusText: json['status_text'] ?? status.displayName,
      views: json['views'] ?? 0,
      publishedAt: _parseDate(json['published_at']),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
    );
  }

  // 🔥 GETTER METHODS UNTUK FIX ERROR:
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'slug': slug,
      'excerpt': excerpt,
      'body': body,
      'category_id': categoryId,
      'category_name': categoryName,
      'author_id': authorId,
      'author_name': authorName,
      'status': status.value,
      'status_text': statusText,
      'views': views,
      'published_at': publishedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isPublished => status.value == 'published';
  bool get isDraft => status.value == 'draft';
  bool get isPending => status.value == 'pending';
  bool get isApproved => status.value == 'approved';
  bool get isRejected => status.value == 'rejected';
  String? get featuredImage => null; // Placeholder

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is num) {
      final millis =
          value > 10000000000 ? value.toInt() : (value * 1000).toInt();
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    }
    if (value is String) {
      final iso = DateTime.tryParse(value);
      if (iso != null) return iso;
      try {
        return DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'", 'en_US')
            .parseUtc(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
