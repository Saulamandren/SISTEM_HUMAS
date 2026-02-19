import 'package:intl/intl.dart';

class Category {
  final int id;
  final String name;
  final String? slug;
  final String? description;
  final String icon;
  final String color;
  final bool isActive;
  final int? createdBy;
  final DateTime? createdAt;

  Category({
    required this.id,
    required this.name,
    this.slug,
    this.description,
    this.icon = 'article',
    this.color = '#1976D2',
    this.isActive = true,
    this.createdBy,
    this.createdAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'],
      description: json['description'],
      icon: json['icon'] ?? 'article',
      color: json['color'] ?? '#1976D2',
      isActive: _parseBool(json['is_active'], defaultValue: true),
      createdBy: json['created_by'],
      createdAt: _parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'icon': icon,
      'color': color,
      'is_active': isActive,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  static bool _parseBool(dynamic value, {bool defaultValue = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return defaultValue;
  }

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
