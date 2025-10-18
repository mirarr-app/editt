import 'dart:io';
import 'package:flutter/material.dart';

class ThemeService {
  // Map of Yaru color names to Flutter Colors
  static final Map<String, Color> _colorMap = {
    'blue': Colors.blue,
    'red': Colors.red,
    'green': Colors.green,
    'yellow': Colors.yellow,
    'purple': Colors.purple,
    'orange': Colors.orange,
    'pink': Colors.pink,
    'teal': Colors.teal,
    'cyan': Colors.cyan,
    'indigo': Colors.indigo,
    'lime': Colors.lime,
    'amber': Colors.amber,
    'brown': Colors.brown,
    'grey': Colors.grey,
    'gray': Colors.grey,
    'magenta': Colors.deepPurple,
    'sage': Colors.green,
    'olive': Colors.green,
  };

  /// Get the current Omarchy theme color
  /// Returns Colors.blue as fallback for any errors
  static Future<Color> getOmarchyThemeColor() async {
    try {
      // Execute omarchy-theme-current command
      final result = await Process.run('omarchy-theme-current', []);
      
      // Check if command was successful
      if (result.exitCode != 0) {
        return Colors.blue;
      }
      // Get theme name, lowercase it, and replace spaces with hyphens
      final themeName = result.stdout.toString().trim().toLowerCase().replaceAll(' ', '-');
      if (themeName.isEmpty) {
        return Colors.blue;
      }

      // Read the icons.theme file
      final homeDir = Platform.environment['HOME'];
      if (homeDir == null) {
        return Colors.blue;
      }

      final themeFilePath = '$homeDir/.config/omarchy/themes/$themeName/icons.theme';
      final themeFile = File(themeFilePath);

      if (!await themeFile.exists()) {
        return Colors.blue;
      }

      final content = await themeFile.readAsString();
      
      // Parse the content to find Yaru color variant
      // Looking for patterns like "Yaru-blue", "Yaru-red", etc.
      final yaruRegex = RegExp(r'Yaru-(\w+)', caseSensitive: false);
      final match = yaruRegex.firstMatch(content);

      if (match == null) {
        return Colors.blue;
      }

      // Extract the color part (e.g., "blue" from "Yaru-blue")
      final colorName = match.group(1)?.toLowerCase();
      
      if (colorName == null) {
        return Colors.blue;
      }

      // Map the color name to Flutter Color
      return _colorMap[colorName] ?? Colors.blue;

    } catch (e) {
      // Any error (command not found, file errors, etc.) returns blue
      return Colors.blue;
    }
  }
}

