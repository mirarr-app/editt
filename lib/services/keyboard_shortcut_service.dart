import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A reusable keyboard shortcut service that manages keyboard shortcuts for the editor
class KeyboardShortcutService {
  static final Map<String, VoidCallback> _shortcuts = {};
  static final Map<String, String> _shortcutDescriptions = {};
  
  /// Get the shortcuts map (for internal use by KeyboardShortcutHandler)
  static Map<String, VoidCallback> get shortcuts => _shortcuts;
  
  /// Callback to notify when shortcuts are updated
  static VoidCallback? _onShortcutsUpdated;
  
  /// Set callback to be called when shortcuts are updated
  static void setOnShortcutsUpdated(VoidCallback? callback) {
    _onShortcutsUpdated = callback;
  }
  
  /// Notify that shortcuts have been updated
  static void _notifyShortcutsUpdated() {
    _onShortcutsUpdated?.call();
  }

  /// Register a keyboard shortcut
  /// [key] - The key combination (e.g., 'ctrl+t', 'ctrl+c', 'ctrl+b')
  /// [callback] - The function to call when the shortcut is pressed
  /// [description] - Optional description for the shortcut
  static void registerShortcut(String key, VoidCallback callback, {String? description}) {
    _shortcuts[key.toLowerCase()] = callback;
    if (description != null) {
      _shortcutDescriptions[key.toLowerCase()] = description;
    }
    _notifyShortcutsUpdated();
  }

  /// Update an existing keyboard shortcut callback
  /// [key] - The key combination to update
  /// [callback] - The new function to call when the shortcut is pressed
  static void updateShortcut(String key, VoidCallback callback) {
    if (_shortcuts.containsKey(key.toLowerCase())) {
      _shortcuts[key.toLowerCase()] = callback;
      _notifyShortcutsUpdated();
    }
  }

  /// Unregister a keyboard shortcut
  static void unregisterShortcut(String key) {
    _shortcuts.remove(key.toLowerCase());
    _shortcutDescriptions.remove(key.toLowerCase());
  }

  /// Clear all registered shortcuts
  static void clearShortcuts() {
    _shortcuts.clear();
    _shortcutDescriptions.clear();
  }

  /// Get all registered shortcuts and their descriptions
  static Map<String, String> getAllShortcuts() {
    return Map.from(_shortcutDescriptions);
  }

  /// Handle keyboard events
  static bool handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final key = _buildKeyString(event);
    debugPrint('Key pressed: $key'); // Debug logging
    final callback = _shortcuts[key];
    
    if (callback != null) {
      try {
        debugPrint('Executing shortcut: $key'); // Debug logging
        callback();
        return true;
      } catch (e) {
        debugPrint('Error executing keyboard shortcut $key: $e');
        return false;
      }
    }
    
    return false;
  }

  /// Build a key string from a KeyEvent
  static String _buildKeyString(KeyEvent event) {
    final buffer = StringBuffer();
    
    // Add modifiers
    if (event.logicalKey == LogicalKeyboardKey.controlLeft || 
        event.logicalKey == LogicalKeyboardKey.controlRight ||
        HardwareKeyboard.instance.isControlPressed) {
      buffer.write('ctrl+');
    }
    
    if (event.logicalKey == LogicalKeyboardKey.shiftLeft || 
        event.logicalKey == LogicalKeyboardKey.shiftRight ||
        HardwareKeyboard.instance.isShiftPressed) {
      buffer.write('shift+');
    }
    
    if (event.logicalKey == LogicalKeyboardKey.altLeft || 
        event.logicalKey == LogicalKeyboardKey.altRight ||
        HardwareKeyboard.instance.isAltPressed) {
      buffer.write('alt+');
    }
    
    // Add the main key
    final keyLabel = event.logicalKey.keyLabel;
    buffer.write(keyLabel.toLowerCase());
    
    return buffer.toString();
  }

  /// Check if a specific shortcut is registered
  static bool hasShortcut(String key) {
    return _shortcuts.containsKey(key.toLowerCase());
  }

  /// Get the callback for a specific shortcut
  static VoidCallback? getShortcutCallback(String key) {
    return _shortcuts[key.toLowerCase()];
  }
}

/// A widget that handles keyboard shortcuts using Flutter's Shortcuts widget
class KeyboardShortcutHandler extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const KeyboardShortcutHandler({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<KeyboardShortcutHandler> createState() => _KeyboardShortcutHandlerState();
}

class _KeyboardShortcutHandlerState extends State<KeyboardShortcutHandler> {
  late FocusNode _focusNode;
  late Map<ShortcutActivator, Intent> _shortcuts;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _shortcuts = _buildShortcutsMap();
    
    // Request focus when the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    
    // Set up callback to rebuild when shortcuts are updated
    KeyboardShortcutService.setOnShortcutsUpdated(() {
      if (mounted) {
        // Use Future.microtask to defer setState until after build phase
        Future.microtask(() {
          if (mounted) {
            setState(() {
              _shortcuts = _buildShortcutsMap();
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    KeyboardShortcutService.setOnShortcutsUpdated(null);
    super.dispose();
  }

  Map<ShortcutActivator, Intent> _buildShortcutsMap() {
    final shortcuts = <ShortcutActivator, Intent>{};
    
    for (final entry in KeyboardShortcutService.shortcuts.entries) {
      final key = entry.key;
      final callback = entry.value;
      
      // Convert string key to ShortcutActivator
      final activator = _parseKeyString(key);
      if (activator != null) {
        shortcuts[activator] = _ShortcutIntent(callback);
      }
    }
    
    return shortcuts;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ShortcutIntent: _ShortcutAction(),
        },
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          child: widget.child,
        ),
      ),
    );
  }

  /// Parse a key string like "ctrl+t" into a ShortcutActivator
  ShortcutActivator? _parseKeyString(String keyString) {
    final parts = keyString.toLowerCase().split('+');
    bool control = false;
    bool shift = false;
    bool alt = false;
    LogicalKeyboardKey? mainKey;

    for (final part in parts) {
      switch (part.trim()) {
        case 'ctrl':
          control = true;
          break;
        case 'shift':
          shift = true;
          break;
        case 'alt':
          alt = true;
          break;
        case 't':
          mainKey = LogicalKeyboardKey.keyT;
          break;
        case 'b':
          mainKey = LogicalKeyboardKey.keyB;
          break;
        case 'c':
          mainKey = LogicalKeyboardKey.keyC;
          break;
        case 'f':
          mainKey = LogicalKeyboardKey.keyF;
          break;
        case 'e':
          mainKey = LogicalKeyboardKey.keyE;
          break;
        case 'u':
          mainKey = LogicalKeyboardKey.keyU;
          break;
        case 'l':
          mainKey = LogicalKeyboardKey.keyL;
          break;
        case 'k':
          mainKey = LogicalKeyboardKey.keyK;
          break;
        case 'z':
          mainKey = LogicalKeyboardKey.keyZ;
          break;
        case 'y':
          mainKey = LogicalKeyboardKey.keyY;
          break;
        case 's':
          mainKey = LogicalKeyboardKey.keyS;
          break;
        case 'w':
          mainKey = LogicalKeyboardKey.keyW;
          break;
        case 'd':
          mainKey = LogicalKeyboardKey.keyD;
          break;
        default:
          return null;
      }
    }

    if (mainKey == null) return null;

    return SingleActivator(
      mainKey,
      control: control,
      shift: shift,
      alt: alt,
    );
  }
}

/// Intent class for shortcuts
class _ShortcutIntent extends Intent {
  final VoidCallback callback;
  
  const _ShortcutIntent(this.callback);
}

/// Action class for shortcuts
class _ShortcutAction extends Action<_ShortcutIntent> {
  @override
  Object? invoke(_ShortcutIntent intent) {
    try {
      intent.callback();
    } catch (e) {
      debugPrint('Error executing keyboard shortcut: $e');
    }
    return null;
  }
}

/// Predefined shortcut keys for common editor actions
class EditorShortcuts {
  static const String textEditor = 'ctrl+t';
  static const String paintEditor = 'ctrl+b';
  static const String cropEditor = 'ctrl+c';
  static const String filterEditor = 'ctrl+f';
  static const String emojiEditor = 'ctrl+e';
  static const String tuneEditor = 'ctrl+u';
  static const String blurEditor = 'ctrl+l';
  static const String cutoutTool = 'ctrl+x';
  static const String undo = 'ctrl+z';
  static const String redo = 'ctrl+y';
  static const String save = 'ctrl+s';
  static const String close = 'ctrl+w';
  static const String done = 'ctrl+d';
  static const String shortCutHelper = 'ctrl+k';
}

/// Helper class to make registering editor shortcuts easier
class EditorShortcutHelper {
  /// Register common editor shortcuts
  static void registerEditorShortcuts({
    required VoidCallback onTextEditor,
    required VoidCallback onPaintEditor,
    required VoidCallback onCropEditor,
    required VoidCallback onFilterEditor,
    required VoidCallback onEmojiEditor,
    required VoidCallback onTuneEditor,
    required VoidCallback onBlurEditor,
    required VoidCallback onCutoutTool,
    required VoidCallback onUndo,
    required VoidCallback onRedo,
    required VoidCallback onSave,
    required VoidCallback onClose,
    required VoidCallback onDone,
    required VoidCallback onShortCutHelper,
  }) {
    KeyboardShortcutService.registerShortcut(EditorShortcuts.textEditor, onTextEditor, description: 'Open Text Editor');
    KeyboardShortcutService.registerShortcut(EditorShortcuts.paintEditor, onPaintEditor, description: 'Open Paint Editor');
    KeyboardShortcutService.registerShortcut(EditorShortcuts.cropEditor, onCropEditor, description: 'Open Crop/Rotate Editor');
    KeyboardShortcutService.registerShortcut(EditorShortcuts.filterEditor, onFilterEditor, description: 'Open Filter Editor');
    KeyboardShortcutService.registerShortcut(EditorShortcuts.emojiEditor, onEmojiEditor, description: 'Open Emoji Editor');
    KeyboardShortcutService.registerShortcut(EditorShortcuts.tuneEditor, onTuneEditor, description: 'Open Tune Editor');
    KeyboardShortcutService.registerShortcut(EditorShortcuts.blurEditor, onBlurEditor, description: 'Open Blur Editor');
    KeyboardShortcutService.registerShortcut(EditorShortcuts.cutoutTool, onCutoutTool, description: 'Open Cutout Tool');
    KeyboardShortcutService.registerShortcut(EditorShortcuts.undo, onUndo, description: 'Undo');
    KeyboardShortcutService.registerShortcut(EditorShortcuts.redo, onRedo, description: 'Redo');
    KeyboardShortcutService.registerShortcut(EditorShortcuts.save, onSave, description: 'Save Image');
    KeyboardShortcutService.registerShortcut(EditorShortcuts.close, onClose, description: 'Close Editor');
    KeyboardShortcutService.registerShortcut(EditorShortcuts.done, onDone, description: 'Done Editing');
    KeyboardShortcutService.registerShortcut(EditorShortcuts.shortCutHelper, onShortCutHelper, description: 'Short Cut Helper');
  }

  /// Update existing editor shortcuts with new callbacks
  static void updateEditorShortcuts({
    required VoidCallback onTextEditor,
    required VoidCallback onPaintEditor,
    required VoidCallback onCropEditor,
    required VoidCallback onFilterEditor,
    required VoidCallback onEmojiEditor,
    required VoidCallback onTuneEditor,
    required VoidCallback onBlurEditor,
    required VoidCallback onCutoutTool,
    required VoidCallback onUndo,
    required VoidCallback onRedo,
    required VoidCallback onSave,
    required VoidCallback onClose,
    required VoidCallback onDone,
    required VoidCallback onShortCutHelper,
  }) {
    // Batch update all shortcuts without triggering notifications
    KeyboardShortcutService._shortcuts[EditorShortcuts.textEditor] = onTextEditor;
    KeyboardShortcutService._shortcuts[EditorShortcuts.paintEditor] = onPaintEditor;
    KeyboardShortcutService._shortcuts[EditorShortcuts.cropEditor] = onCropEditor;
    KeyboardShortcutService._shortcuts[EditorShortcuts.filterEditor] = onFilterEditor;
    KeyboardShortcutService._shortcuts[EditorShortcuts.emojiEditor] = onEmojiEditor;
    KeyboardShortcutService._shortcuts[EditorShortcuts.tuneEditor] = onTuneEditor;
    KeyboardShortcutService._shortcuts[EditorShortcuts.blurEditor] = onBlurEditor;
    KeyboardShortcutService._shortcuts[EditorShortcuts.cutoutTool] = onCutoutTool;
    KeyboardShortcutService._shortcuts[EditorShortcuts.undo] = onUndo;
    KeyboardShortcutService._shortcuts[EditorShortcuts.redo] = onRedo;
    KeyboardShortcutService._shortcuts[EditorShortcuts.save] = onSave;
    KeyboardShortcutService._shortcuts[EditorShortcuts.close] = onClose;
    KeyboardShortcutService._shortcuts[EditorShortcuts.done] = onDone;
    KeyboardShortcutService._shortcuts[EditorShortcuts.shortCutHelper] = onShortCutHelper;
    // Trigger notification only once after all updates
    KeyboardShortcutService._notifyShortcutsUpdated();
  }
}
