import 'dart:io';
import 'package:flutter/foundation.dart';
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
      if (kDebugMode) {
        debugPrint('Error loading image: $e');
      }
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
      if (kDebugMode) {
        debugPrint('Error converting format: $e');
      }
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
      if (kDebugMode) {
        debugPrint('Error reducing resolution: $e');
      }
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
      if (kDebugMode) {
        debugPrint('Error reducing file size: $e');
      }
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
      if (kDebugMode) {
        debugPrint('Error saving image: $e');
      }
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
      if (kDebugMode) {
        debugPrint('Error getting image dimensions: $e');
      }
      return null;
    }
  }

  /// Get file size in bytes
  static Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      return await file.length();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting file size: $e');
      }
      return 0;
    }
  }

  /// Format file size for display
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Cutout a vertical or horizontal section from the image
  /// startPosition: Starting position (x for vertical, y for horizontal)
  /// endPosition: Ending position (x for vertical, y for horizontal)
  /// isVertical: true for vertical cutout, false for horizontal cutout
  static Future<Uint8List?> cutoutImage({
    required Uint8List imageBytes,
    required double startPosition,
    required double endPosition,
    required bool isVertical,
  }) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Convert relative positions to absolute pixel positions
      int startPixel, endPixel;
      
      if (isVertical) {
        startPixel = (startPosition * image.width).round();
        endPixel = (endPosition * image.width).round();
        
        // Ensure positions are within bounds
        startPixel = startPixel.clamp(0, image.width);
        endPixel = endPixel.clamp(0, image.width);
        
        // Ensure start is before end
        if (startPixel > endPixel) {
          final temp = startPixel;
          startPixel = endPixel;
          endPixel = temp;
        }
        
        // Don't allow cutting the entire image
        if (startPixel == 0 && endPixel == image.width) {
          return null;
        }
        
        return _cutoutVertical(image, startPixel, endPixel);
      } else {
        startPixel = (startPosition * image.height).round();
        endPixel = (endPosition * image.height).round();
        
        // Ensure positions are within bounds
        startPixel = startPixel.clamp(0, image.height);
        endPixel = endPixel.clamp(0, image.height);
        
        // Ensure start is before end
        if (startPixel > endPixel) {
          final temp = startPixel;
          startPixel = endPixel;
          endPixel = temp;
        }
        
        // Don't allow cutting the entire image
        if (startPixel == 0 && endPixel == image.height) {
          return null;
        }
        
        return _cutoutHorizontal(image, startPixel, endPixel);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error performing cutout: $e');
      }
      return null;
    }
  }

  /// Cutout a vertical section from the image
  static Uint8List? _cutoutVertical(img.Image image, int startX, int endX) {
    try {
      final cutWidth = endX - startX;
      final newWidth = image.width - cutWidth;
      
      if (newWidth <= 0) return null;
      
      // Create new image with reduced width
      final newImage = img.Image(width: newWidth, height: image.height);
      
      // Copy pixels from left side (before cutout)
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < startX; x++) {
          newImage.setPixel(x, y, image.getPixel(x, y));
        }
      }
      
      // Copy pixels from right side (after cutout)
      for (int y = 0; y < image.height; y++) {
        for (int x = endX; x < image.width; x++) {
          final newX = x - cutWidth;
          newImage.setPixel(newX, y, image.getPixel(x, y));
        }
      }
      
      return Uint8List.fromList(img.encodeJpg(newImage, quality: 95));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in vertical cutout: $e');
      }
      return null;
    }
  }

  /// Cutout a horizontal section from the image
  static Uint8List? _cutoutHorizontal(img.Image image, int startY, int endY) {
    try {
      final cutHeight = endY - startY;
      final newHeight = image.height - cutHeight;
      
      if (newHeight <= 0) return null;
      
      // Create new image with reduced height
      final newImage = img.Image(width: image.width, height: newHeight);
      
      // Copy pixels from top side (before cutout)
      for (int y = 0; y < startY; y++) {
        for (int x = 0; x < image.width; x++) {
          newImage.setPixel(x, y, image.getPixel(x, y));
        }
      }
      
      // Copy pixels from bottom side (after cutout)
      for (int y = endY; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final newY = y - cutHeight;
          newImage.setPixel(x, newY, image.getPixel(x, y));
        }
      }
      
      return Uint8List.fromList(img.encodeJpg(newImage, quality: 95));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in horizontal cutout: $e');
      }
      return null;
    }
  }
}

