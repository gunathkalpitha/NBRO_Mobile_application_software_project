/// Inspection model representing a site inspection (Site Metadata)
class Inspection {
  final String id; // Building Reference No (e.g., H-01)
  final String ownerName;
  final String siteAddress;
  final String? contactNo;
  final double? latitude;
  final double? longitude;
  final double? distanceFromRow; // Distance from Row in meters
  
  // General Observations
  final int? ageOfStructure; // in years
  final String? typeOfStructure; // House, Office, Shop, etc.
  final String? presentCondition; // Permanent, Semi-permanent, Temporary
  
  // External Services
  final bool? hasPipeBorneWater;
  final String? waterSource; // From Well, From Main Supply
  final bool? hasElectricity;
  final String? electricitySource; // From Private Solar, From Main Supply
  final bool? hasSewageWaste;
  final String? sewageType; // Private Septic tank, Connected to Sewer, etc.
  
  // Building Profile (Details of Main Building Elements)
  final String? numberOfFloors; // e.g., G+2
  final Map<String, bool>? wallMaterials; // Brick, Concrete, Timber, etc.
  final Map<String, bool>? doorMaterials; // Solid Timber, Glazed Aluminium, etc.
  final Map<String, bool>? floorMaterials; // Cement Rendered, Floor Tiles, etc.
  final Map<String, bool>? roofMaterials; // Single Pitched, Gable, etc.
  final String? roofCovering; // Clay Tiles, Asbestos, Metal, Zinc/Al
  
  final List<Defect> defects;
  final SyncStatus syncStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? remarks;

  Inspection({
    required this.id,
    required this.ownerName,
    required this.siteAddress,
    this.contactNo,
    this.latitude,
    this.longitude,
    this.distanceFromRow,
    this.ageOfStructure,
    this.typeOfStructure,
    this.presentCondition,
    this.hasPipeBorneWater,
    this.waterSource,
    this.hasElectricity,
    this.electricitySource,
    this.hasSewageWaste,
    this.sewageType,
    this.numberOfFloors,
    this.wallMaterials,
    this.doorMaterials,
    this.floorMaterials,
    this.roofMaterials,
    this.roofCovering,
    this.defects = const [],
    this.syncStatus = SyncStatus.pending,
    required this.createdAt,
    this.updatedAt,
    this.remarks,
  });

  Inspection copyWith({
    String? id,
    String? ownerName,
    String? siteAddress,
    String? contactNo,
    double? latitude,
    double? longitude,
    double? distanceFromRow,
    int? ageOfStructure,
    String? typeOfStructure,
    String? presentCondition,
    bool? hasPipeBorneWater,
    String? waterSource,
    bool? hasElectricity,
    String? electricitySource,
    bool? hasSewageWaste,
    String? sewageType,
    String? numberOfFloors,
    Map<String, bool>? wallMaterials,
    Map<String, bool>? doorMaterials,
    Map<String, bool>? floorMaterials,
    Map<String, bool>? roofMaterials,
    String? roofCovering,
    List<Defect>? defects,
    SyncStatus? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? remarks,
  }) {
    return Inspection(
      id: id ?? this.id,
      ownerName: ownerName ?? this.ownerName,
      siteAddress: siteAddress ?? this.siteAddress,
      contactNo: contactNo ?? this.contactNo,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceFromRow: distanceFromRow ?? this.distanceFromRow,
      ageOfStructure: ageOfStructure ?? this.ageOfStructure,
      typeOfStructure: typeOfStructure ?? this.typeOfStructure,
      presentCondition: presentCondition ?? this.presentCondition,
      hasPipeBorneWater: hasPipeBorneWater ?? this.hasPipeBorneWater,
      waterSource: waterSource ?? this.waterSource,
      hasElectricity: hasElectricity ?? this.hasElectricity,
      electricitySource: electricitySource ?? this.electricitySource,
      hasSewageWaste: hasSewageWaste ?? this.hasSewageWaste,
      sewageType: sewageType ?? this.sewageType,
      numberOfFloors: numberOfFloors ?? this.numberOfFloors,
      wallMaterials: wallMaterials ?? this.wallMaterials,
      doorMaterials: doorMaterials ?? this.doorMaterials,
      floorMaterials: floorMaterials ?? this.floorMaterials,
      roofMaterials: roofMaterials ?? this.roofMaterials,
      roofCovering: roofCovering ?? this.roofCovering,
      defects: defects ?? this.defects,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      remarks: remarks ?? this.remarks,
    );
  }
}

/// Defect model representing structural defects (Defect Inventory)
class Defect {
  final String id;
  final String inspectionId;
  final DefectNotation notation; // Standardized notation (C, BC, CC, etc.)
  final DefectCategory category; // Type 01: Building Floor / Type 02: Boundary Wall
  final String? floorLevel; // Basement, Ground, 1st, 2nd, etc.
  final double lengthMm;
  final double? widthMm; // Optional for patches
  final String? photoPath;
  final String? remarks;
  final DateTime createdAt;
  final String? photoUrl; // For synced photos

  Defect({
    required this.id,
    required this.inspectionId,
    required this.notation,
    required this.category,
    this.floorLevel,
    required this.lengthMm,
    this.widthMm,
    this.photoPath,
    this.remarks,
    required this.createdAt,
    this.photoUrl,
  });
}

/// Defect Category (Type of Photo Table)
enum DefectCategory {
  buildingFloor, // Type 01: Considering a building (Basement, Ground Floor, First Floor, Second Floor, Roof/parapet & ceiling)
  boundaryWall; // Type 02: Considering Boundary wall

  String get displayName {
    switch (this) {
      case DefectCategory.buildingFloor:
        return 'Building Floor/Ceiling';
      case DefectCategory.boundaryWall:
        return 'Boundary Wall';
    }
  }
}

/// Defect Notation - Standardized from NBRO Defects Order
enum DefectNotation {
  // Cracks
  c,    // Wall Crack
  bc,   // Beam Crack
  cc,   // Column Crack
  fc,   // Floor Crack
  sc,   // Slab Crack
  tc,   // Tile Crack
  
  // Separations
  sp,   // Separation (Where should be contained in remark column)
  
  // Damages
  d,    // Damaged Area
  wd,   // Wall Damage
  bd,   // Beam Damage
  cd,   // Column Damage
  fd,   // Floor Damage
  dd,   // Door/Windows Frame Damages
  td,   // Tile Damage
  gd,   // Glass Damage
  pd,   // Plaster Damage
  rd,   // Roof Damage
  
  // Patches
  dp,   // Damp Patch
  
  // Boundary Wall (BWC = Boundary Wall Crack, BWD = Boundary Wall Damage, BWDP = Boundary Wall Damp Patch)
  bwc,  // Boundary Wall Crack
  bws,  // Boundary Wall Separation
  bwd,  // Boundary Wall Damage
  bwdp; // Boundary Wall Damp Patch

  String get displayName {
    switch (this) {
      case DefectNotation.c:
        return 'C - Wall Crack';
      case DefectNotation.bc:
        return 'BC - Beam Crack';
      case DefectNotation.cc:
        return 'CC - Column Crack';
      case DefectNotation.fc:
        return 'FC - Floor Crack';
      case DefectNotation.sc:
        return 'SC - Slab Crack';
      case DefectNotation.tc:
        return 'TC - Tile Crack';
      case DefectNotation.sp:
        return 'SP - Separation';
      case DefectNotation.d:
        return 'D - Damaged Area';
      case DefectNotation.wd:
        return 'WD - Wall Damage';
      case DefectNotation.bd:
        return 'BD - Beam Damage';
      case DefectNotation.cd:
        return 'CD - Column Damage';
      case DefectNotation.fd:
        return 'FD - Floor Damage';
      case DefectNotation.dd:
        return 'DD - Door/Windows Frame Damages';
      case DefectNotation.td:
        return 'TD - Tile Damage';
      case DefectNotation.gd:
        return 'GD - Glass Damage';
      case DefectNotation.pd:
        return 'PD - Plaster Damage';
      case DefectNotation.rd:
        return 'RD - Roof Damage';
      case DefectNotation.dp:
        return 'DP - Damp Patch';
      case DefectNotation.bwc:
        return 'BWC - Boundary Wall Crack';
      case DefectNotation.bws:
        return 'BWS - Boundary Wall Separation';
      case DefectNotation.bwd:
        return 'BWD - Boundary Wall Damage';
      case DefectNotation.bwdp:
        return 'BWDP - Boundary Wall Damp Patch';
    }
  }

  String get notation {
    return name.toUpperCase();
  }

  String get description {
    switch (this) {
      case DefectNotation.c:
        return 'Wall Crack';
      case DefectNotation.bc:
        return 'Beam Crack';
      case DefectNotation.cc:
        return 'Column Crack';
      case DefectNotation.fc:
        return 'Floor Crack';
      case DefectNotation.sc:
        return 'Slab Crack';
      case DefectNotation.tc:
        return 'Tile Crack';
      case DefectNotation.sp:
        return 'Separation (Wall-wall, Beam-wall, etc.)';
      case DefectNotation.d:
        return 'Damaged Area';
      case DefectNotation.wd:
        return 'Wall Damage';
      case DefectNotation.bd:
        return 'Beam Damage';
      case DefectNotation.cd:
        return 'Column Damage';
      case DefectNotation.fd:
        return 'Floor Damage';
      case DefectNotation.dd:
        return 'Door/Windows Frame Damages';
      case DefectNotation.td:
        return 'Tile Damage';
      case DefectNotation.gd:
        return 'Glass Damage';
      case DefectNotation.pd:
        return 'Plaster Damage';
      case DefectNotation.rd:
        return 'Roof Damage';
      case DefectNotation.dp:
        return 'Damp Patch (Nature should be specified in remark)';
      case DefectNotation.bwc:
        return 'Boundary Wall Crack';
      case DefectNotation.bws:
        return 'Boundary Wall Separation';
      case DefectNotation.bwd:
        return 'Boundary Wall Damage';
      case DefectNotation.bwdp:
        return 'Boundary Wall Damp Patch';
    }
  }
}

/// Enumeration for defect types (Legacy - for backward compatibility)
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
