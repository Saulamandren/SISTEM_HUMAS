import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ContentApproval {
  final int id;
  final int contentId;
  final int approverId;
  final String approverName;
  final String approverRole;
  final String action;
  final String? notes;
  final DateTime createdAt;

  ContentApproval({
    required this.id,
    required this.contentId,
    required this.approverId,
    required this.approverName,
    required this.approverRole,
    required this.action,
    this.notes,
    required this.createdAt,
  });

  factory ContentApproval.fromJson(Map<String, dynamic> json) {
    return ContentApproval(
      id: json['id'] ?? 0,
      contentId: json['content_id'] ?? 0,
      approverId: json['approver_id'] ?? 0,
      approverName: json['approver_name'] ?? '',
      approverRole: json['approver_role'] ?? '',
      action: json['action'] ?? '',
      notes: json['notes'],
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content_id': contentId,
      'approver_id': approverId,
      'approver_name': approverName,
      'approver_role': approverRole,
      'action': action,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get actionIcon {
    switch (action.toLowerCase()) {
      case 'submit':
        return 'send';
      case 'approve':
        return 'thumb_up';
      case 'reject':
        return 'thumb_down';
      case 'publish':
        return 'public';
      default:
        return 'help';
    }
  }

  Color get actionColor {
    switch (action.toLowerCase()) {
      case 'submit':
      case 'approve':
      case 'publish':
        return Colors.green;
      case 'reject':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get actionText {
    switch (action.toLowerCase()) {
      case 'submit':
        return 'SUBMIT';
      case 'approve':
        return 'ACCEPT';
      case 'reject':
        return 'REJECT';
      case 'publish':
        return 'PUBLISH';
      default:
        return action.toUpperCase();
    }
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
