import 'package:flutter/material.dart';
import 'screens/viewer_screen.dart';

void main(List<String> args) {
  // Parse command-line arguments for image path
  String? initialImagePath;
  if (args.isNotEmpty) {
    initialImagePath = args[0];
  }

  runApp(MainApp(initialImagePath: initialImagePath));
}

class MainApp extends StatelessWidget {
  final String? initialImagePath;

  const MainApp({super.key, this.initialImagePath});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Editt - Photo Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: ViewerScreen(initialImagePath: initialImagePath),
    );
  }
}
