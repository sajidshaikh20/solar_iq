import 'package:flutter/material.dart';

enum NotificationType {
  generation,
  system,
  cleaning,
  alert,
  record;

  IconData get icon {
    switch (this) {
      case NotificationType.generation:
        return Icons.bar_chart_rounded;
      case NotificationType.system:
        return Icons.system_update_rounded;
      case NotificationType.cleaning:
        return Icons.water_drop_rounded;
      case NotificationType.alert:
        return Icons.warning_rounded;
      case NotificationType.record:
        return Icons.bolt_rounded;
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.generation:
        return const Color(0xFF00695C);
      case NotificationType.system:
        return const Color(0xFF1565C0);
      case NotificationType.cleaning:
        return const Color(0xFF0277BD);
      case NotificationType.alert:
        return const Color(0xFFE65100);
      case NotificationType.record:
        return const Color(0xFF2E7D32);
    }
  }
}

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final NotificationType type;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.type,
    this.isRead = false,
  });

  factory NotificationModel.fromMap(String id, Map<dynamic, dynamic> map) {
    return NotificationModel(
      id: id,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      type: NotificationType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'system'),
        orElse: () => NotificationType.system,
      ),
      isRead: map['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'isRead': isRead,
    };
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      title: title,
      body: body,
      timestamp: timestamp,
      type: type,
      isRead: isRead ?? this.isRead,
    );
  }
}
