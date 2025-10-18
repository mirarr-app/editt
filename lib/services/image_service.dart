import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

enum ImageFormat { jpg, png, webp }

class ImageService {
  /// Load an image from file
  static Future<File?> loadImage(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      print('Error loading image: $e');
      return null;
    }
  }

  /// Convert image format
  static Future<Uint8List?> convertFormat({
    required Uint8List imageBytes,
    required ImageFormat targetFormat,
    int quality = 95,
  }) async {
    try {
      // Decode the image
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Encode to target format
      switch (targetFormat) {
        case ImageFormat.jpg:
          return Uint8List.fromList(img.encodeJpg(image, quality: quality));
        case ImageFormat.png:
          return Uint8List.fromList(img.encodePng(image));
        case ImageFormat.webp:
          return Uint8List.fromList(img.encodeJpg(image, quality: quality));
      }
    } catch (e) {
      print('Error converting format: $e');
      return null;
    }
  }

  /// Reduce image resolution by scaling dimensions
  static Future<Uint8List?> reduceResolution({
    required Uint8List imageBytes,
    required int maxWidth,
    required int maxHeight,
  }) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Calculate new dimensions maintaining aspect ratio
      int newWidth = image.width;
      int newHeight = image.height;

      if (newWidth > maxWidth || newHeight > maxHeight) {
        final widthRatio = maxWidth / newWidth;
        final heightRatio = maxHeight / newHeight;
        final ratio = widthRatio < heightRatio ? widthRatio : heightRatio;

        newWidth = (newWidth * ratio).round();
        newHeight = (newHeight * ratio).round();
      }

      // Resize the image
      final resized = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );

      // Encode back to original format (or JPEG for smaller size)
      return Uint8List.fromList(img.encodeJpg(resized, quality: 90));
    } catch (e) {
      print('Error reducing resolution: $e');
      return null;
    }
  }

  /// Reduce image file size by lowering quality
  static Future<Uint8List?> reduceFileSize({
    required Uint8List imageBytes,
    required int quality,
  }) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Re-encode with lower quality
      return Uint8List.fromList(img.encodeJpg(image, quality: quality));
    } catch (e) {
      print('Error reducing file size: $e');
      return null;
    }
  }

  /// Save image bytes to a file
  static Future<bool> saveImage({
    required Uint8List imageBytes,
    required String filePath,
  }) async {
    try {
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);
      return true;
    } catch (e) {
      print('Error saving image: $e');
      return false;
    }
  }

  /// Get image dimensions
  static Future<Map<String, int>?> getImageDimensions(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      return {
        'width': image.width,
        'height': image.height,
      };
    } catch (e) {
      print('Error getting image dimensions: $e');
      return null;
    }
  }

  /// Get file size in bytes
  static Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      return await file.length();
    } catch (e) {
      print('Error getting file size: $e');
      return 0;
    }
  }

  /// Format file size for display
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

