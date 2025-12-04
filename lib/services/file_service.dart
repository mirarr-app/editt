import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

class FileService {
  /// Pick an image file using the file picker dialog
  static Future<File?> pickImageFile() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Images',
        extensions: ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'],
      );
      
      final XFile? file = await openFile(
        acceptedTypeGroups: [typeGroup],
      );

      if (file != null) {
        return File(file.path);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error picking file: $e');
      }
      return null;
    }
  }

  /// Validate if a file path exists and is an image
  static bool validateImagePath(String? filePath) {
    if (filePath == null || filePath.isEmpty) return false;

    final file = File(filePath);
    if (!file.existsSync()) return false;

    final extension = path.extension(filePath).toLowerCase();
    final validExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'];
    return validExtensions.contains(extension);
  }

  /// Generate a new filename for saving edited images
  static String generateNewFilename(String originalPath, String? newExtension) {
    final dir = path.dirname(originalPath);
    final basename = path.basenameWithoutExtension(originalPath);
    final ext = newExtension ?? path.extension(originalPath);

    // Add timestamp to make it unique
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return path.join(dir, '${basename}_edited_$timestamp$ext');
  }

  /// Get the file extension without the dot
  static String getExtension(String filePath) {
    return path.extension(filePath).replaceFirst('.', '').toLowerCase();
  }

  /// Get the directory of a file
  static String getDirectory(String filePath) {
    return path.dirname(filePath);
  }

  /// Get the filename with extension
  static String getFilename(String filePath) {
    return path.basename(filePath);
  }

  /// Create a file path with a new extension
  static String changeExtension(String filePath, String newExtension) {
    final dir = path.dirname(filePath);
    final basename = path.basenameWithoutExtension(filePath);
    final ext = newExtension.startsWith('.') ? newExtension : '.$newExtension';
    return path.join(dir, '$basename$ext');
  }

  /// Get all image files in the same directory as the reference file
  static Future<List<File>> getImagesInDirectory(String referenceFilePath) async {
    try {
      final dir = Directory(path.dirname(referenceFilePath));
      if (!await dir.exists()) return [];

      final List<File> images = [];
      await for (final entity in dir.list()) {
        if (entity is File && validateImagePath(entity.path)) {
          images.add(entity);
        }
      }
      
      // Sort files by name to ensure consistent order
      images.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
      
      return images;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error listing images: $e');
      }
      return [];
    }
  }
}
