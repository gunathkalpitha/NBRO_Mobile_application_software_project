import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Local Storage Service for Inspection Photos & Attachments (Native)
class ImageStorageService {
  static ImageStorageService? _instance;

  ImageStorageService._();

  static ImageStorageService get instance {
    _instance ??= ImageStorageService._();
    return _instance!;
  }

  Future<Directory> getInspectionDirectory(String inspectionLocalId) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final inspectionDir = Directory(p.join(docsDir.path, 'inspections', inspectionLocalId));
    if (!await inspectionDir.exists()) {
      await inspectionDir.create(recursive: true);
    }
    return inspectionDir;
  }

  Future<String?> saveImageLocally({
    required String sourcePath,
    required String inspectionLocalId,
    String? customFileName,
  }) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        debugPrint('[ImageStorageServiceNative] ⚠️ Source file does not exist: $sourcePath');
        return null;
      }

      final dir = await getInspectionDirectory(inspectionLocalId);
      final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
      final fileName = customFileName ?? 'img_${const Uuid().v4()}$ext';
      final targetPath = p.join(dir.path, fileName);

      final savedFile = await sourceFile.copy(targetPath);
      debugPrint('[ImageStorageServiceNative] ✓ Saved image locally at: ${savedFile.path}');
      return savedFile.path;
    } catch (e) {
      debugPrint('[ImageStorageServiceNative] ❌ Failed to save image locally: $e');
      return null;
    }
  }

  Future<bool> fileExists(String? path) async {
    if (path == null || path.isEmpty) return false;
    return await File(path).exists();
  }

  Future<void> deleteInspectionDirectory(String inspectionLocalId) async {
    try {
      final dir = await getInspectionDirectory(inspectionLocalId);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('[ImageStorageServiceNative] ❌ Failed to delete inspection directory: $e');
    }
  }

  Future<void> cleanupOldSyncedPhotos(List<Map<String, String>> oldSyncedItems) async {
    try {
      int deletedCount = 0;
      for (final item in oldSyncedItems) {
        final localPath = item['local_path'];
        final remoteUrl = item['remote_url'];
        
        if (remoteUrl != null && remoteUrl.startsWith('http') && localPath != null) {
          final file = File(localPath);
          if (await file.exists()) {
            await file.delete();
            deletedCount++;
          }
        }
      }
      if (deletedCount > 0) {
        debugPrint('[ImageStorageServiceNative] 🧹 Cleaned up $deletedCount synced local photo files older than 30 days.');
      }
    } catch (e) {
      debugPrint('[ImageStorageServiceNative] ❌ Failed to cleanup old synced photos: $e');
    }
  }
}
