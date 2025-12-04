import 'package:flutter/material.dart';

enum ShortcutMode { viewer, editor }

class KeyboardShortcutsDialog extends StatelessWidget {
  final ShortcutMode mode;
  
  const KeyboardShortcutsDialog({
    super.key, 
    this.mode = ShortcutMode.editor,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> editorShortcuts = [
      {'key': 'Ctrl+T', 'description': 'Open Text Editor'},
      {'key': 'Ctrl+B', 'description': 'Open Paint Editor'},
      {'key': 'Ctrl+C', 'description': 'Open Crop/Rotate Editor'},
      {'key': 'Ctrl+F', 'description': 'Open Filter Editor'},
      {'key': 'Ctrl+E', 'description': 'Open Emoji Editor'},
      {'key': 'Ctrl+U', 'description': 'Open Tune Editor'},
      {'key': 'Ctrl+L', 'description': 'Open Blur Editor'},
      {'key': 'Ctrl+X', 'description': 'Open Cutout Tool'},
      {'key': 'Ctrl+Z', 'description': 'Undo'},
      {'key': 'Ctrl+Y', 'description': 'Redo'},
      {'key': 'Ctrl+S', 'description': 'Save Image'},
      {'key': 'Ctrl+W', 'description': 'Close Editor'},
      {'key': 'Ctrl+D', 'description': 'Done Editing'},
      {'key': 'Ctrl+K', 'description': 'Show Keyboard Shortcuts'},
    ];

    final List<Map<String, String>> viewerShortcuts = [
      {'key': 'Right / L', 'description': 'Next Image'},
      {'key': 'Left / H', 'description': 'Previous Image'},
      {'key': 'K', 'description': 'Zoom In'},
      {'key': 'J', 'description': 'Zoom Out'},
      {'key': 'DD', 'description': 'Delete Image'},
      {'key': 'Delete', 'description': 'Delete Image (Confirm)'},
      {'key': 'Q', 'description': 'Close Image'},
      {'key': 'Ctrl+K', 'description': 'Show Keyboard Shortcuts'},
    ];

    final shortcuts = mode == ShortcutMode.editor ? editorShortcuts : viewerShortcuts;
    final title = mode == ShortcutMode.editor ? 'Editor Shortcuts' : 'Viewer Shortcuts';

    return Dialog(
      child: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.keyboard,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Keyboard Shortcuts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...shortcuts.map((shortcut) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Keyboard shortcut badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey[700]!
                                      : Colors.grey[400]!,
                                ),
                              ),
                              child: Text(
                                shortcut['key'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Description
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  shortcut['description'] as String,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                   
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Show the keyboard shortcuts dialog
void showKeyboardShortcutsDialog(BuildContext context, {ShortcutMode mode = ShortcutMode.editor}) {
  showDialog(
    context: context,
    builder: (context) => KeyboardShortcutsDialog(mode: mode),
    barrierDismissible: true,
  );
}
