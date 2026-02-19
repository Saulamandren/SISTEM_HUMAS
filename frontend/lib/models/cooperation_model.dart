import 'package:intl/intl.dart';

class Cooperation {
  final int id;
  final String institutionName;
  final String contactName;
  final String email;
  final String phone;
  final String purpose;
  final DateTime eventDate;
  final String documentName;
  final String? documentMime;
  final String status;
  final int createdBy;
  final String? createdByName;
  final DateTime createdAt;
  final DateTime updatedAt;

  Cooperation({
    required this.id,
    required this.institutionName,
    required this.contactName,
    required this.email,
    required this.phone,
    required this.purpose,
    required this.eventDate,
    required this.documentName,
    this.documentMime,
    required this.status,
    required this.createdBy,
    this.createdByName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Cooperation.fromJson(Map<String, dynamic> json) {
    return Cooperation(
      id: json['id'] ?? 0,
      institutionName: json['institution_name'] ?? '',
      contactName: json['contact_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      purpose: json['purpose'] ?? '',
      eventDate: _parseDate(json['event_date']) ?? DateTime.now(),
      documentName: json['document_name'] ?? '',
      documentMime: json['document_mime'],
      status: json['status'] ?? 'pending',
      createdBy: json['created_by'] ?? 0,
      createdByName: json['created_by_name'],
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
    );
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
