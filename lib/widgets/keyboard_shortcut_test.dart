import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/keyboard_shortcut_service.dart';

/// A simple test widget to verify keyboard shortcuts work
class KeyboardShortcutTest extends StatefulWidget {
  const KeyboardShortcutTest({super.key});

  @override
  State<KeyboardShortcutTest> createState() => _KeyboardShortcutTestState();
}

class _KeyboardShortcutTestState extends State<KeyboardShortcutTest> {
  final List<String> _pressedKeys = [];

  @override
  void initState() {
    super.initState();
    _setupTestShortcuts();
  }

  @override
  void dispose() {
    KeyboardShortcutService.clearShortcuts();
    super.dispose();
  }

  void _setupTestShortcuts() {
    KeyboardShortcutService.registerShortcut(
      'ctrl+t',
      () => _addPressedKey('Ctrl+T - Text Editor'),
      description: 'Test Text Editor',
    );
    KeyboardShortcutService.registerShortcut(
      'ctrl+b',
      () => _addPressedKey('Ctrl+B - Paint Editor'),
      description: 'Test Paint Editor',
    );
    KeyboardShortcutService.registerShortcut(
      'ctrl+c',
      () => _addPressedKey('Ctrl+C - Crop Editor'),
      description: 'Test Crop Editor',
    );
    
    // Debug: Print registered shortcuts
    print('Registered shortcuts: ${KeyboardShortcutService.getAllShortcuts()}');
    print('Shortcuts map: ${KeyboardShortcutService.shortcuts}');
  }

  void _addPressedKey(String key) {
    setState(() {
      _pressedKeys.add('${DateTime.now().toString().substring(11, 19)}: $key');
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardShortcutHandler(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Keyboard Shortcut Test'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Click anywhere in this window to focus, then try the shortcuts below:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Test Keyboard Shortcuts:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Ctrl+T - Text Editor'),
              const Text('• Ctrl+B - Paint Editor'),
              const Text('• Ctrl+C - Crop Editor'),
              const SizedBox(height: 16),
              const Text(
                'Pressed Keys:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _pressedKeys.isEmpty
                      ? const Text('No keys pressed yet... Try Ctrl+T, Ctrl+B, or Ctrl+C')
                      : ListView.builder(
                          itemCount: _pressedKeys.length,
                          itemBuilder: (context, index) {
                            return Text(_pressedKeys[index]);
                          },
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _pressedKeys.clear();
                      });
                    },
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Test manual callback
                      _addPressedKey('Manual Test - Ctrl+T');
                    },
                    child: const Text('Test Manual'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
