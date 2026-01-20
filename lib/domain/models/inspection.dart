/// Inspection model representing a site inspection
class Inspection {
  final String id;
  final String siteAddress;
  final double? latitude;
  final double? longitude;
  final List<Defect> defects;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? remarks;

  Inspection({
    required this.id,
    required this.siteAddress,
    this.latitude,
    this.longitude,
    this.defects = const [],
    this.syncStatus = SyncStatus.pending,
    required this.createdAt,
    this.updatedAt,
    this.remarks,
  });

  Inspection copyWith({
    String? id,
    String? siteAddress,
    double? latitude,
    double? longitude,
    List<Defect>? defects,
    SyncStatus? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? remarks,
  }) {
    return Inspection(
      id: id ?? this.id,
      siteAddress: siteAddress ?? this.siteAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      defects: defects ?? this.defects,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      remarks: remarks ?? this.remarks,
    );
  }
}

/// Defect model representing structural defects
class Defect {
  final String id;
  final String inspectionId;
  final DefectType type;
  final double lengthMm;
  final double widthMm;
  final String? photoPath;
  final String? remarks;
  final DateTime createdAt;
  final String? photoUrl; // For synced photos

  Defect({
    required this.id,
    required this.inspectionId,
    required this.type,
    required this.lengthMm,
    required this.widthMm,
    this.photoPath,
    this.remarks,
    required this.createdAt,
    this.photoUrl,
  });
}

/// Enumeration for defect types
enum DefectType {
  crack,
  dampPatch,
  wallSeparation,
  spalling,
  efflorescence,
  other;

  String get displayName {
    switch (this) {
      case DefectType.crack:
        return 'Crack';
      case DefectType.dampPatch:
        return 'Damp Patch';
      case DefectType.wallSeparation:
        return 'Wall Separation';
      case DefectType.spalling:
        return 'Spalling';
      case DefectType.efflorescence:
        return 'Efflorescence';
      case DefectType.other:
        return 'Other';
    }
  }
}

/// Sync status enumeration
enum SyncStatus {
  pending,
  syncing,
  synced,
  error;

  String get displayName {
    switch (this) {
      case SyncStatus.pending:
        return 'Pending';
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.error:
        return 'Sync Error';
    }
  }
}

/// User model
class User {
  final String id;
  final String email;
  final String displayName;
  final bool biometricEnabled;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.displayName,
    this.biometricEnabled = false,
    required this.createdAt,
  });
}
