import 'dart:io';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:window_manager/window_manager.dart';
import '../services/file_service.dart';
import '../widgets/image_viewer.dart';
import 'editor_screen.dart';

class ViewerScreen extends StatefulWidget {
  final String? initialImagePath;

  const ViewerScreen({super.key, this.initialImagePath});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  File? _currentImage;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePath != null) {
      _loadImageFromPath(widget.initialImagePath!);
    }
  }

  Future<void> _loadImageFromPath(String path) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (FileService.validateImagePath(path)) {
      setState(() {
        _currentImage = File(path);
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = 'Invalid image path or file not found: $path';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final file = await FileService.pickImageFile();

    setState(() {
      if (file != null) {
        _currentImage = file;
      }
      _isLoading = false;
    });
  }

  Future<void> _openEditor() async {
    if (_currentImage == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditorScreen(imageFile: _currentImage!),
      ),
    );

    // If an edited image was returned, update the current image
    if (result != null && result is File) {
      setState(() {
        _currentImage = result;
      });
    }
  }

  Future<void> _handleDroppedFiles(List<String> paths) async {
    if (paths.isEmpty) return;
    
    final filePath = paths.first;
    
    // Validate it's an image file
    if (FileService.validateImagePath(filePath)) {
      await _loadImageFromPath(filePath);
    } else {
      setState(() {
        _errorMessage = 'Invalid file type. Please drop an image file.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: GestureDetector(
          onPanStart: (details) {
            windowManager.startDragging();
          },
          child: AppBar(
            title: const Text('Editt'),
            actions: [
              IconButton(
                icon: const Icon(Icons.folder_open, size: 12),
                onPressed: _pickImage,
                tooltip: 'Open Image',
              ),
              IconButton(
                icon: const Icon(Icons.remove, size: 12),
                onPressed: () => windowManager.minimize(),
                tooltip: 'Minimize',
              ),
              IconButton(
                icon: const Icon(Icons.crop_square, size: 12),
                onPressed: () async {
                  if (await windowManager.isMaximized()) {
                    windowManager.unmaximize();
                  } else {
                    windowManager.maximize();
                  }
                },
                tooltip: 'Maximize/Restore',
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 12),
                onPressed: () => windowManager.close(),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
      ),
      body: DropTarget(
        onDragEntered: (details) {
          setState(() {
            _isDragging = true;
          });
        },
        onDragExited: (details) {
          setState(() {
            _isDragging = false;
          });
        },
        onDragDone: (details) async {
          setState(() {
            _isDragging = false;
          });
          
          final paths = details.files.map((file) => file.path).toList();
          await _handleDroppedFiles(paths);
        },
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.folder_open),
              label: const Text('Open Image'),
            ),
          ],
        ),
      );
    }

    if (_currentImage == null) {
      return Container(
        decoration: _isDragging
            ? BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
              )
            : null,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isDragging ? Icons.file_download : Icons.image_outlined,
                size: 128,
                color: _isDragging
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
              const SizedBox(height: 24),
              Text(
                _isDragging ? 'Drop image here' : 'No image loaded',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: _isDragging
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isDragging
                    ? 'Release to open'
                    : 'Open an image or drag & drop',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              if (!_isDragging) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Open Image'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ImageViewer(
      imageFile: _currentImage!,
      onEditPressed: _openEditor,
      onFileDeleted: () {
        // Handle file deletion
        setState(() {
          _currentImage = null;
          _errorMessage = 'The image file was deleted';
        });
      },
    );
  }
}

