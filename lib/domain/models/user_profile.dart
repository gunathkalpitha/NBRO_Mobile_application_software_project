class UserProfile {
  final String id;
  final String fullName;
  final String role;
  final bool isActive;
  final String? phoneNumber;
  final String? positionTitle;
  final String? employeeId;
  final String? workRole;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.phoneNumber,
    this.positionTitle,
    this.employeeId,
    this.workRole,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: (map['id'] as String?) ?? '',
      fullName: (map['full_name'] as String?) ?? '',
      role: (map['role'] as String?) ?? 'officer',
      isActive: (map['is_active'] as bool?) ?? true,
      phoneNumber: map['phone_number'] as String?,
      positionTitle: map['position_title'] as String?,
      employeeId: map['employee_id'] as String?,
      workRole: map['work_role'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  UserProfile copyWith({
    String? fullName,
    String? role,
    bool? isActive,
    String? phoneNumber,
    String? positionTitle,
    String? employeeId,
    String? workRole,
    String? avatarUrl,
  }) {
    return UserProfile(
      id: id,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      positionTitle: positionTitle ?? this.positionTitle,
      employeeId: employeeId ?? this.employeeId,
      workRole: workRole ?? this.workRole,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'full_name': fullName,
      'phone_number': _normalized(phoneNumber),
      'position_title': _normalized(positionTitle),
      'employee_id': _normalized(employeeId),
      'work_role': _normalized(workRole),
      'avatar_url': _normalized(avatarUrl),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  static int completionPercentageFromMap(
    Map<String, dynamic> map, {
    required String email,
  }) {
    final checks = <bool>[
      _hasValue(map['full_name']) || email.trim().isNotEmpty,
      _hasValue(map['phone_number']),
      _hasValue(map['position_title']),
      _hasValue(map['employee_id']),
      _hasValue(map['work_role']),
      _hasValue(map['avatar_url']),
    ];

    final filled = checks.where((c) => c).length;
    return ((filled / checks.length) * 100).round();
  }

  int completionPercentage({required String email}) {
    return completionPercentageFromMap(
      {
        'full_name': fullName,
        'phone_number': phoneNumber,
        'position_title': positionTitle,
        'employee_id': employeeId,
        'work_role': workRole,
        'avatar_url': avatarUrl,
      },
      email: email,
    );
  }

  bool isProfileComplete({required String email}) {
    return completionPercentage(email: email) >= 100;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String? _normalized(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool _hasValue(dynamic value) {
    return value is String ? value.trim().isNotEmpty : value != null;
  }
}