import 'dart:io';
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

  Future<void> _handleSave(Uint8List editedBytes) async {
    setState(() {
      _editedImageBytes = editedBytes;
    });

    // Show the save dialog
    final result = await showSaveDialog(
      context: context,
      originalFilePath: widget.imageFile.path,
    );

    if (result == null || result['option'] == SaveOption.cancel) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
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

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image saved successfully to ${path.basename(savePath)}'),
              backgroundColor: Colors.green,
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
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAdvancedOptions() {
    if (_editedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please make some edits first'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _AdvancedOptionsDialog(
        imageBytes: _editedImageBytes!,
        originalPath: widget.imageFile.path,
        onSave: (processedBytes, newPath) async {
          final success = await ImageService.saveImage(
            imageBytes: processedBytes,
            filePath: newPath,
          );

          if (mounted) {
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
    if (_isSaving) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          color: Colors.black54,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Saving image...',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        ProImageEditor.file(
          widget.imageFile,
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (bytes) async {
              await _handleSave(bytes);
            },
            onCloseEditor: (editorMode) {
              Navigator.of(context).pop();
            },
          ),
          configs: const ProImageEditorConfigs(),
        ),
        // Advanced options button
        Positioned(
          top: 16,
          right: 16,
          child: SafeArea(
            child: FloatingActionButton.small(
              heroTag: 'advanced_options',
              backgroundColor: Colors.black87,
              onPressed: _showAdvancedOptions,
              tooltip: 'Advanced Options',
              child: const Icon(Icons.settings, color: Colors.white),
            ),
          ),
        ),
      ],
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

  Map<String, int>? _currentDimensions;

  @override
  void initState() {
    super.initState();
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

  Future<void> _loadDimensions() async {
    final dims = await ImageService.getImageDimensions(widget.imageBytes);
    if (mounted) {
      setState(() {
        _currentDimensions = dims;
        if (dims != null) {
          _maxWidth = dims['width']!;
          _maxHeight = dims['height']!;
        }
      });
    }
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

    Navigator.of(context).pop();
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
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Max Width',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        controller: TextEditingController(text: _maxWidth.toString()),
                        onChanged: (value) {
                          _maxWidth = int.tryParse(value) ?? _maxWidth;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Max Height',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        controller: TextEditingController(text: _maxHeight.toString()),
                        onChanged: (value) {
                          _maxHeight = int.tryParse(value) ?? _maxHeight;
                        },
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

