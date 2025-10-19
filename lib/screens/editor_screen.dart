import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:path/path.dart' as path;
import '../services/image_service.dart';
import '../services/file_service.dart';
import '../widgets/save_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    _startFileWatcher();
  }

  @override
  void dispose() {
    _fileCheckTimer?.cancel();
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

  Future<void> _onEditingComplete(Uint8List editedBytes) async {
    // Store the bytes immediately
    _editedImageBytes = editedBytes;
    
    // Small delay to let the loading dialog dismiss
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Show save dialog
    if (mounted && context.mounted && !_isProcessing) {
      _showSaveDialogAndSave(editedBytes).ignore();
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      onPopInvokedWithResult: (didPop, result) async {
        // Prevent back navigation during save
        if (_isSaving) {
          return;
        }
      },
      child: Stack(
        children: [
          ProImageEditor.file(
            widget.imageFile,
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: _onEditingComplete,
            onCloseEditor: (editorMode) {
              // Don't close if we're in the middle of saving
              if (!_isSaving && mounted && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
            configs: const ProImageEditorConfigs(),
          ),
        // Advanced options button
        if (!_isSaving)
          Positioned(
            bottom: 24,
            right: 24,
            child: SafeArea(
              child: FloatingActionButton(
                heroTag: 'advanced_options',
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                onPressed: _showAdvancedOptions,
                tooltip: 'Advanced Options',
                child: const Icon(Icons.tune),
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
      title: const Text('Advanced Options'),
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

