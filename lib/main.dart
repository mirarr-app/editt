import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/viewer_screen.dart';

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

class MainApp extends StatelessWidget {
  final String? initialImagePath;

  const MainApp({super.key, this.initialImagePath});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Editt',
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
        fontFamily: 'JetbrainsMono',
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
        fontFamily: 'JetbrainsMono',
      ),
      themeMode: ThemeMode.system,
      home: ViewerScreen(initialImagePath: initialImagePath),
    );
  }
}
