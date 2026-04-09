class Notice {
  final String id;
  final String title;
  final String message;
  final DateTime publishedAt;
  final String publishedBy;
  final String? publishedByAvatarUrl;
  final NoticePriority priority;
  final bool isRead;

  Notice({
    required this.id,
    required this.title,
    required this.message,
    required this.publishedAt,
    required this.publishedBy,
    this.publishedByAvatarUrl,
    this.priority = NoticePriority.normal,
    this.isRead = false,
  });

  Notice copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? publishedAt,
    String? publishedBy,
    String? publishedByAvatarUrl,
    NoticePriority? priority,
    bool? isRead,
  }) {
    return Notice(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      publishedAt: publishedAt ?? this.publishedAt,
      publishedBy: publishedBy ?? this.publishedBy,
      publishedByAvatarUrl: publishedByAvatarUrl ?? this.publishedByAvatarUrl,
      priority: priority ?? this.priority,
      isRead: isRead ?? this.isRead,
    );
  }

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      publishedAt: DateTime.parse(json['published_at'] as String),
      publishedBy: json['published_by'] as String,
      publishedByAvatarUrl: json['published_by_avatar_url'] as String?,
      priority: NoticePriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => NoticePriority.normal,
      ),
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'published_at': publishedAt.toIso8601String(),
      'published_by': publishedBy,
      'published_by_avatar_url': publishedByAvatarUrl,
      'priority': priority.name,
      'is_read': isRead,
    };
  }
}

enum NoticePriority {
  urgent,
  high,
  normal,
  low;

  String get displayName {
    switch (this) {
      case NoticePriority.urgent:
        return 'Urgent';
      case NoticePriority.high:
        return 'High';
      case NoticePriority.normal:
        return 'Normal';
      case NoticePriority.low:
        return 'Low';
    }
  }
}
