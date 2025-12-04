import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:path/path.dart' as path;
import 'package:super_clipboard/super_clipboard.dart';
import '../services/image_service.dart';
import '../services/file_service.dart';
import '../services/keyboard_shortcut_service.dart';
import '../widgets/save_dialog.dart';
import '../widgets/cutout_dialog.dart';
import '../widgets/keyboard_shortcuts_dialog.dart';

class EditorScreen extends StatefulWidget {
  final File imageFile;

  const EditorScreen({super.key, required this.imageFile});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  bool _isSaving = false;
  Uint8List? _editedImageBytes;
  bool _isProcessing = false;
  Timer? _fileCheckTimer;
  int _editorVersion = 0;
  bool _hasUnappliedChanges = false;
  bool _shortcutsInitialized = false;
  bool _saveToClipboardAction = false;

  @override
  void initState() {
    super.initState();
    _startFileWatcher();
    _registerKeyboardShortcuts();
  }

  @override
  void dispose() {
    _fileCheckTimer?.cancel();
    // Don't clear shortcuts here - let them persist for the editor
    super.dispose();
  }

  void _startFileWatcher() {
    // Check if source file still exists every 3 seconds
    _fileCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final exists = await widget.imageFile.exists();
      if (!exists) {
        timer.cancel();
        
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Source image file has been deleted'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          
          // Return to viewer
          Navigator.of(context).pop();
        }
      }
    });
  }

  void _registerKeyboardShortcuts() {
    // Register shortcuts immediately when the screen is initialized
    // We'll update them with actual editor callbacks when the editor is available
    EditorShortcutHelper.registerEditorShortcuts(
      onTextEditor: () {},
      onPaintEditor: () {},
      onCropEditor: () {},
      onFilterEditor: () {},
      onEmojiEditor: () {},
      onTuneEditor: () {},
      onBlurEditor: () {},
      onCutoutTool: () {},
      onUndo: () {},
      onRedo: () {},
      onSave: () {},
      onSaveToClipboard: () {},
      onClose: () {},
      onDone: () {},
      onShortCutHelper: () => _showKeyboardShortcutsDialog(),
    );
  }

  void _setupEditorShortcuts(ProImageEditorState editor) {
    if (_shortcutsInitialized) {
      return;
    }
    
    EditorShortcutHelper.updateEditorShortcuts(
      onTextEditor: editor.openTextEditor,
      onPaintEditor: editor.openPaintEditor,
      onCropEditor: editor.openCropRotateEditor,
      onFilterEditor: editor.openFilterEditor,
      onEmojiEditor: editor.openEmojiEditor,
      onTuneEditor: editor.openTuneEditor,
      onBlurEditor: editor.openBlurEditor,
      onCutoutTool: _showCutoutDialog,
      onUndo: editor.undoAction,
      onRedo: editor.redoAction,
      onSave: _showAdvancedOptions,
      onSaveToClipboard: () {
        setState(() {
          _saveToClipboardAction = true;
        });
        editor.doneEditing();
      },
      onClose: editor.closeEditor,
      onDone: editor.doneEditing,
      onShortCutHelper: _showKeyboardShortcutsDialog,
    );
    
    _shortcutsInitialized = true;
  }

  Future<void> _onEditingComplete(Uint8List editedBytes) async {
    // Store the bytes immediately
    _editedImageBytes = editedBytes;
    _hasUnappliedChanges = false;
    
    // Small delay to let the loading dialog dismiss
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Check if we need to save to clipboard
    if (_saveToClipboardAction) {
      await _handleClipboardSave(editedBytes);
      return;
    }

    // Show save dialog
    if (mounted && context.mounted && !_isProcessing) {
      _showSaveDialogAndSave(editedBytes).ignore();
    }
  }

  Future<void> _handleClipboardSave(Uint8List imageBytes) async {
    setState(() {
      _saveToClipboardAction = false; // Reset flag
      _isProcessing = true;
      _isSaving = true; // Mark as saving to prevent premature close
    });

    try {
      final pngBytes = await ImageService.convertFormat(
        imageBytes: imageBytes,
        targetFormat: ImageFormat.png,
        quality: 100,
      );

      if (pngBytes == null) {
        throw Exception('Failed to convert image to PNG');
      }

      final clipboard = SystemClipboard.instance;
      if (clipboard == null) {
        throw Exception('Clipboard not available');
      }
      
      final item = DataWriterItem();
      item.add(Formats.png(pngBytes));
      await clipboard.write([item]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image saved to clipboard (PNG)'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Close the editor after successful save to clipboard
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving to clipboard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // Reset _isSaving so we can exit if we want
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _showSaveDialogAndSave(Uint8List editedBytes) async {
    if (!mounted || _isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // Show the save dialog
      if (!mounted || !context.mounted) {
        setState(() {
          _isProcessing = false;
        });
        return;
      }
      
      final result = await showSaveDialog(
        context: context,
        originalFilePath: widget.imageFile.path,
      );

      // User cancelled
      if (!mounted) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
        return;
      }
      
      if (result == null || result['option'] == SaveOption.cancel) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
        return;
      }

      setState(() {
        _isSaving = true;
      });

      String savePath;

      if (result['option'] == SaveOption.overwrite) {
        savePath = widget.imageFile.path;
      } else {
        // Save as new file
        final dir = FileService.getDirectory(widget.imageFile.path);
        final filename = result['filename'] as String;
        savePath = path.join(dir, filename);
      }

      final success = await ImageService.saveImage(
        imageBytes: editedBytes,
        filePath: savePath,
      );

      if (!mounted) return;
      
      setState(() {
        _isSaving = false;
        _isProcessing = false;
      });

      if (!mounted || !context.mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image saved successfully to ${path.basename(savePath)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Return the saved file to the viewer
        Navigator.of(context).pop(File(savePath));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save image'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isSaving = false;
        _isProcessing = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAdvancedOptions() async {
    // Load the original image bytes if no edits have been made yet
    Uint8List imageBytes;
    
    if (_editedImageBytes == null) {
      try {
        imageBytes = await widget.imageFile.readAsBytes();
      } catch (e) {
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading image: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    } else {
      imageBytes = _editedImageBytes!;
    }

    if (!mounted || !context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => _AdvancedOptionsDialog(
        imageBytes: imageBytes,
        originalPath: widget.imageFile.path,
        onSave: (processedBytes, newPath) async {
          final success = await ImageService.saveImage(
            imageBytes: processedBytes,
            filePath: newPath,
          );

          if (mounted && context.mounted) {
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Image saved to ${path.basename(newPath)}'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.of(context).pop(File(newPath));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to save image'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showKeyboardShortcutsDialog() {
    if (!mounted || !context.mounted) return;
    showKeyboardShortcutsDialog(context, mode: ShortcutMode.editor);
  }

  Future<void> _showCutoutDialog() async {
    // Guard: warn if there are unapplied changes in the editor
    if (_hasUnappliedChanges) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(

          title: const Text('Discard current changes?'),
          content: const Text(
            'You have unsaved changes in the editor. If you continue to Cutout without pressing the checkmark, these changes will be discarded.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    // Load the original image bytes if no edits have been made yet
    Uint8List imageBytes;
    
    if (_editedImageBytes == null) {
      try {
        imageBytes = await widget.imageFile.readAsBytes();
      } catch (e) {
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading image: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    } else {
      imageBytes = _editedImageBytes!;
    }

    if (!mounted || !context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => CutoutDialog(
        imageBytes: imageBytes,
        originalPath: widget.imageFile.path,
        onApply: (processedBytes) {
          // Apply the cutout and continue editing
          setState(() {
            _editedImageBytes = processedBytes;
            _editorVersion++;
            _hasUnappliedChanges = false;
            _shortcutsInitialized = false; // Reset shortcuts when editor changes
          });
          
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cutout applied successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }

  AppBar _buildCustomAppBar(ProImageEditorState editor) {
    return AppBar(
      automaticallyImplyLeading: false,
      foregroundColor: Colors.white,
      backgroundColor: Colors.black,
      actions: [
        IconButton(
          tooltip: 'Close',
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: Icon(
            Icons.close,
            color: Colors.white,
          ),
          onPressed: editor.closeEditor,
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Undo',
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: Icon(
            Icons.undo,
            color: editor.canUndo == true
                ? Colors.white
                : Colors.white.withAlpha(80),
          ),
          onPressed: editor.undoAction,
        ),
        IconButton(
          tooltip: 'Redo',
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: Icon(
            Icons.redo,
            color: editor.canRedo == true
                ? Colors.white
                : Colors.white.withAlpha(80),
          ),
          onPressed: editor.redoAction,
        ),
      
        IconButton(
          tooltip: 'Done',
          padding: const EdgeInsets.symmetric(horizontal: 8),
          icon: const Icon(Icons.done),
          iconSize: 28,
          onPressed: editor.doneEditing,
        ),
          IconButton(
          tooltip: 'Save Image',
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          iconSize: 28,
          icon:  const Icon(Icons.save),
          onPressed: _showAdvancedOptions,
        ),
      ],
    );
  }

  Widget _buildCustomBottomBar(ProImageEditorState editor, Key key) {
    return Scrollbar(
      key: key,
      scrollbarOrientation: ScrollbarOrientation.top,
      thickness: 0,
      child: BottomAppBar(
        height: kBottomNavigationBarHeight,
        color: Colors.black,
        padding: EdgeInsets.zero,
        child: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 550,
                maxWidth: 550,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FlatIconTextButton(
                      label:  Text('Paint', style: TextStyle(fontSize: 10.0, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                      icon:  Icon(
                        Icons.edit_rounded,
                        size: 22.0,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      onPressed: editor.openPaintEditor,
                    ),
                    FlatIconTextButton(
                      label: Text('Text', style: TextStyle(fontSize: 10.0, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                      icon:  Icon(
                        Icons.text_fields,
                        size: 22.0,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      onPressed: editor.openTextEditor,
                    ),
                    // Custom button - Cutout Tool
                
                    FlatIconTextButton(
                      label:  Text('Crop/ Rotate', style: TextStyle(fontSize: 10.0, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                      icon:  Icon(
                        Icons.crop_rotate_rounded,
                        size: 22.0,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      onPressed: editor.openCropRotateEditor,
                    ),
                    FlatIconTextButton(
                      label:  Text('Filter', style: TextStyle(fontSize: 10.0, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                      icon:  Icon(
                        Icons.filter,
                        size: 22.0,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      onPressed: editor.openFilterEditor,
                    ),
                    FlatIconTextButton(
                      label:  Text('Emoji', style: TextStyle(fontSize: 10.0, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                      icon:  Icon(
                        Icons.sentiment_satisfied_alt_rounded,
                        size: 22.0,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      onPressed: editor.openEmojiEditor,
                    ),    FlatIconTextButton(
                      label: Text('Tune', style: TextStyle(fontSize: 10.0, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                      icon:  Icon(
                        Icons.tune,
                        size: 22.0,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      onPressed: editor.openTuneEditor,
                    ),
    FlatIconTextButton(
                      label: Text('Blur', style: TextStyle(fontSize: 10.0, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                      icon:  Icon(
                        Icons.blur_on,
                        size: 22.0,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      onPressed: editor.openBlurEditor,
                    ),

                        FlatIconTextButton(
                      label: Text('Cutout', style: TextStyle(fontSize: 10.0, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                      icon:  Icon(
                        Icons.content_cut,
                        size: 22.0,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      onPressed: _showCutoutDialog,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  

  @override
  Widget build(BuildContext context) {
    return KeyboardShortcutHandler(
      child: PopScope(
        canPop: !_isSaving,
        onPopInvokedWithResult: (didPop, result) async {
          // Prevent back navigation during save
          if (_isSaving) {
            return;
          }
        },
        child: Stack(
        children: [
          _editedImageBytes != null
              ? ProImageEditor.memory(
                  _editedImageBytes!,
                  key: ValueKey('editor-memory-$_editorVersion'),
                  callbacks: ProImageEditorCallbacks(
                    onImageEditingComplete: _onEditingComplete,
                    onCloseEditor: (editorMode) {
                      // Don't close if we're in the middle of saving
                      if (!_isSaving && mounted && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    mainEditorCallbacks: MainEditorCallbacks(
                      onImageDecoded: () {
                        // Freshly loaded image has no user changes yet
                        _hasUnappliedChanges = false;
                      },
                      onStateHistoryChange: (stateHistory, editor) {
                        // Mark as dirty when history changes
                        _hasUnappliedChanges = true;
                      },
                    ),
                  ),
                  configs: ProImageEditorConfigs(
                    mainEditor: MainEditorConfigs(
                      widgets: MainEditorWidgets(
                        appBar: (editor, rebuildStream) => ReactiveAppbar(
                          stream: rebuildStream,
                          builder: (_) {
                            // Set up keyboard shortcuts when app bar is built
                            _setupEditorShortcuts(editor);
                            return _buildCustomAppBar(editor);
                          },
                        ),
                        bottomBar: (editor, rebuildStream, key) => ReactiveWidget(
                          stream: rebuildStream,
                          builder: (_) => _buildCustomBottomBar(editor, key),
                        ),
                      ),
                    ),
                  ),
                )
              : ProImageEditor.file(
                  widget.imageFile,
                  key: ValueKey('editor-file-$_editorVersion'),
                  callbacks: ProImageEditorCallbacks(
                    onImageEditingComplete: _onEditingComplete,
                    onCloseEditor: (editorMode) {
                      // Don't close if we're in the middle of saving
                      if (!_isSaving && mounted && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    mainEditorCallbacks: MainEditorCallbacks(
                      onImageDecoded: () {
                        _hasUnappliedChanges = false;
                      },
                      onStateHistoryChange: (stateHistory, editor) {
                        _hasUnappliedChanges = true;
                      },
                    ),
                  ),
                  configs: ProImageEditorConfigs(
                    mainEditor: MainEditorConfigs(
                      widgets: MainEditorWidgets(
                        appBar: (editor, rebuildStream) => ReactiveAppbar(
                          stream: rebuildStream,
                          builder: (_) {
                            // Set up keyboard shortcuts when app bar is built
                            _setupEditorShortcuts(editor);
                            return _buildCustomAppBar(editor);
                          },
                        ),
                        bottomBar: (editor, rebuildStream, key) => ReactiveWidget(
                          stream: rebuildStream,
                          builder: (_) => _buildCustomBottomBar(editor, key),
                        ),
                      ),
                    ),
                  ),
                ),
          // Saving overlay
          if (_isSaving)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const PopScope(
                  canPop: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.white,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Saving image...',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }
}

class _AdvancedOptionsDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final String originalPath;
  final Function(Uint8List, String) onSave;

  const _AdvancedOptionsDialog({
    required this.imageBytes,
    required this.originalPath,
    required this.onSave,
  });

  @override
  State<_AdvancedOptionsDialog> createState() => _AdvancedOptionsDialogState();
}

class _AdvancedOptionsDialogState extends State<_AdvancedOptionsDialog> {
  ImageFormat _selectedFormat = ImageFormat.jpg;
  int _quality = 95;
  int _maxWidth = 4096;
  int _maxHeight = 4096;
  bool _reduceResolution = false;
  bool _isProcessing = false;
  bool _maintainAspectRatio = true;

  Map<String, int>? _currentDimensions;
  double? _aspectRatio;
  
  late TextEditingController _widthController;
  late TextEditingController _heightController;

  @override
  void initState() {
    super.initState();
    _widthController = TextEditingController();
    _heightController = TextEditingController();
    _loadDimensions();
    
    // Set initial format based on original file
    final ext = FileService.getExtension(widget.originalPath);
    if (ext == 'png') {
      _selectedFormat = ImageFormat.png;
    } else if (ext == 'webp') {
      _selectedFormat = ImageFormat.webp;
    } else {
      _selectedFormat = ImageFormat.jpg;
    }
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _loadDimensions() async {
    final dims = await ImageService.getImageDimensions(widget.imageBytes);
    if (mounted) {
      setState(() {
        _currentDimensions = dims;
        if (dims != null) {
          _maxWidth = dims['width']!;
          _maxHeight = dims['height']!;
          _aspectRatio = dims['width']! / dims['height']!;
          _widthController.text = _maxWidth.toString();
          _heightController.text = _maxHeight.toString();
        }
      });
    }
  }

  void _updateWidth(String value) {
    final newWidth = int.tryParse(value);
    if (newWidth == null) return;
    
    setState(() {
      _maxWidth = newWidth;
      if (_maintainAspectRatio && _aspectRatio != null) {
        _maxHeight = (newWidth / _aspectRatio!).round();
        _heightController.text = _maxHeight.toString();
      }
    });
  }

  void _updateHeight(String value) {
    final newHeight = int.tryParse(value);
    if (newHeight == null) return;
    
    setState(() {
      _maxHeight = newHeight;
      if (_maintainAspectRatio && _aspectRatio != null) {
        _maxWidth = (newHeight * _aspectRatio!).round();
        _widthController.text = _maxWidth.toString();
      }
    });
  }

  Future<void> _processAndSave() async {
    setState(() {
      _isProcessing = true;
    });

    Uint8List? processedBytes = widget.imageBytes;

    // Apply resolution reduction if needed
    if (_reduceResolution && _currentDimensions != null) {
      if (_maxWidth < _currentDimensions!['width']! ||
          _maxHeight < _currentDimensions!['height']!) {
        processedBytes = await ImageService.reduceResolution(
          imageBytes: processedBytes,
          maxWidth: _maxWidth,
          maxHeight: _maxHeight,
        );
        if (processedBytes == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to reduce resolution')),
            );
          }
          setState(() {
            _isProcessing = false;
          });
          return;
        }
      }
    }

    // Apply format conversion and quality
    processedBytes = await ImageService.convertFormat(
      imageBytes: processedBytes,
      targetFormat: _selectedFormat,
      quality: _quality,
    );

    if (processedBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to convert format')),
        );
      }
      setState(() {
        _isProcessing = false;
      });
      return;
    }

    // Generate new path with correct extension
    String extension = '.${_selectedFormat.name}';
    final newPath = FileService.generateNewFilename(
      widget.originalPath,
      extension,
    );

    setState(() {
      _isProcessing = false;
    });

    if (mounted && context.mounted) {
      Navigator.of(context).pop();
    }
    widget.onSave(processedBytes, newPath);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save Options'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Format selection
              const Text(
                'Output Format',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SegmentedButton<ImageFormat>(
                segments: const [
                  ButtonSegment(
                    value: ImageFormat.jpg,
                    label: Text('JPG'),
                    icon: Icon(Icons.image),
                  ),
                  ButtonSegment(
                    value: ImageFormat.png,
                    label: Text('PNG'),
                    icon: Icon(Icons.image),
                  ),
                  ButtonSegment(
                    value: ImageFormat.webp,
                    label: Text('WebP'),
                    icon: Icon(Icons.image),
                  ),
                ],
                selected: {_selectedFormat},
                onSelectionChanged: (Set<ImageFormat> newSelection) {
                  setState(() {
                    _selectedFormat = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Quality slider (for JPG/WebP)
              if (_selectedFormat != ImageFormat.png) ...[
                const Text(
                  'Image Quality',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _quality.toDouble(),
                        min: 10,
                        max: 100,
                        divisions: 18,
                        label: '$_quality%',
                        onChanged: (value) {
                          setState(() {
                            _quality = value.toInt();
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text('$_quality%'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Resolution reduction
              const Text(
                'Resolution',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_currentDimensions != null)
                Text(
                  'Current: ${_currentDimensions!['width']} x ${_currentDimensions!['height']} px',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              CheckboxListTile(
                title: const Text('Reduce Resolution'),
                value: _reduceResolution,
                onChanged: (value) {
                  setState(() {
                    _reduceResolution = value ?? false;
                  });
                },
              ),
              if (_reduceResolution) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Max Width',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        controller: _widthController,
                        onChanged: _updateWidth,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: IconButton(
                        icon: Icon(
                          _maintainAspectRatio ? Icons.link : Icons.link_off,
                          color: _maintainAspectRatio 
                            ? Theme.of(context).colorScheme.primary 
                            : Colors.grey,
                        ),
                        tooltip: _maintainAspectRatio 
                          ? 'Maintain aspect ratio' 
                          : 'Independent dimensions',
                        onPressed: () {
                          setState(() {
                            _maintainAspectRatio = !_maintainAspectRatio;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Max Height',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        controller: _heightController,
                        onChanged: _updateHeight,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _processAndSave,
          child: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

