/// Local Storage Service for Web Browser (Zero `dart:io` dependencies)
class ImageStorageService {
  static ImageStorageService? _instance;

  ImageStorageService._();

  static ImageStorageService get instance {
    _instance ??= ImageStorageService._();
    return _instance!;
  }

  Future<String?> saveImageLocally({
    required String sourcePath,
    required String inspectionLocalId,
    String? customFileName,
  }) async {
    return sourcePath;
  }

  Future<bool> fileExists(String? path) async {
    return path != null && path.isNotEmpty;
  }

  Future<void> deleteInspectionDirectory(String inspectionLocalId) async {}

  Future<void> cleanupOldSyncedPhotos(List<Map<String, String>> oldSyncedItems) async {}
}
