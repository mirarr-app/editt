import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/viewer_screen.dart';
import 'services/theme_service.dart';

void main(List<String> args) async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure window manager
  await windowManager.ensureInitialized();
  
  const windowOptions = WindowOptions(
    titleBarStyle: TitleBarStyle.hidden,
    minimumSize: Size(800, 600),
    center: true,
  );
  
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Parse command-line arguments for image path
  String? initialImagePath;
  if (args.isNotEmpty) {
    initialImagePath = args[0];
  }

  runApp(MainApp(initialImagePath: initialImagePath));
}

class MainApp extends StatefulWidget {
  final String? initialImagePath;

  const MainApp({super.key, this.initialImagePath});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  Color _seedColor = Colors.blue;
  Timer? _themeTimer;

  @override
  void initState() {
    super.initState();
    // Initial theme color fetch
    _updateThemeColor();
    
    // Start periodic timer to check theme every 3 seconds
    _themeTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _updateThemeColor(),
    );
  }

  @override
  void dispose() {
    _themeTimer?.cancel();
    super.dispose();
  }

  Future<void> _updateThemeColor() async {
    final newColor = await ThemeService.getOmarchyThemeColor();
    if (mounted && newColor != _seedColor) {
      setState(() {
        _seedColor = newColor;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Editt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        fontFamily: 'JetbrainsMono',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        fontFamily: 'JetbrainsMono',
      ),
      themeMode: ThemeMode.system,
      home: ViewerScreen(initialImagePath: widget.initialImagePath),
    );
  }
}
