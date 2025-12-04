import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:window_manager/window_manager.dart';
import '../services/file_service.dart';
import '../widgets/image_viewer.dart';
import '../widgets/keyboard_shortcuts_dialog.dart';
import 'editor_screen.dart';

class ViewerScreen extends StatefulWidget {
  final String? initialImagePath;

  const ViewerScreen({super.key, this.initialImagePath});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  File? _currentImage;
  List<File> _directoryImages = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDragging = false;
  final FocusNode _focusNode = FocusNode();
  final TransformationController _transformationController = TransformationController();
  
  // Shortcuts needed for double key presses like 'dd'
  DateTime? _lastDKeyPress;

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePath != null) {
      _loadImageFromPath(widget.initialImagePath!);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadImageFromPath(String path) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (FileService.validateImagePath(path)) {
      final directoryImages = await FileService.getImagesInDirectory(path);
      
      setState(() {
        _currentImage = File(path);
        _directoryImages = directoryImages;
        _isLoading = false;
      });
      
      // Request focus so keyboard shortcuts work immediately
      _focusNode.requestFocus();
    } else {
      setState(() {
        _errorMessage = 'Invalid image path or file not found: $path';
        _isLoading = false;
      });
    }
  }

  void _navigateImage(int direction) {
    if (_currentImage == null || _directoryImages.isEmpty) return;

    // Try to find current image by path or absolute path
    final currentIndex = _directoryImages.indexWhere((file) => 
      file.path == _currentImage!.path || file.absolute.path == _currentImage!.absolute.path);
      
    if (currentIndex == -1) return;

    int newIndex = currentIndex + direction;
    
    // Loop around
    if (newIndex < 0) {
      newIndex = _directoryImages.length - 1;
    } else if (newIndex >= _directoryImages.length) {
      newIndex = 0;
    }

    setState(() {
      _currentImage = _directoryImages[newIndex];
    });
  }

  void _handleDKey() {
    final now = DateTime.now();
    if (_lastDKeyPress != null && 
        now.difference(_lastDKeyPress!) < const Duration(milliseconds: 500)) {
      // Double press detected - delete without confirmation for the shortcut
      _performDeletion(confirm: false);
      _lastDKeyPress = null;
    } else {
      _lastDKeyPress = now;
    }
  }

  void _handleZoom(bool zoomIn) {
    if (_currentImage == null) return;

    final Matrix4 currentMatrix = _transformationController.value;
    final double currentScale = currentMatrix.getMaxScaleOnAxis();
    final double scaleFactor = zoomIn ? 1.2 : 1/1.2;
    final double newScale = currentScale * scaleFactor;
    
    // If we are zooming out and the new scale is less than 1.0 (or close to it),
    // we should reset to identity (center the image) to avoid panning issues.
    if (!zoomIn && newScale <= 1.05) {
       _transformationController.value = Matrix4.identity();
       return;
    }

    // Clamp scale
    if (newScale < 0.5 || newScale > 4.0) return;
    
    // Apply scale relative to the center of the viewport
    // To zoom around the center, we need to:
    // 1. Translate to center
    // 2. Scale
    // 3. Translate back
    
    // However, since we don't know the exact viewport center easily here without LayoutBuilder context in this method,
    // and InteractiveViewer handles gesture zooming nicely around the focal point.
    // For keyboard zooming, zooming in/out on the center of the VIEWPORT is usually desired.
    
    // A simplified approach that works well for "reset to center on zoom out" is handled above.
    // For general zooming, we can just scale the matrix.
    
    final Matrix4 newMatrix = currentMatrix.clone();
    newMatrix.scale(scaleFactor);
    
    _transformationController.value = newMatrix;
  }

  void _closeImage() {
    setState(() {
      _currentImage = null;
      _directoryImages = [];
    });
  }

  Future<void> _performDeletion({bool confirm = true}) async {
     if (_currentImage == null) return;

    bool shouldDelete = true;

    if (confirm) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Image'),
          content: const Text('Are you sure you want to delete this image?\nThis action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      shouldDelete = confirmed == true;
    }

    if (shouldDelete) {
      try {
        final fileToDelete = _currentImage!;
        
        // Find the index before deleting so we know where to go next
        final currentIndex = _directoryImages.indexWhere((file) => 
          file.path == fileToDelete.path || file.absolute.path == fileToDelete.absolute.path);
          
        // Delete the file
        await fileToDelete.delete();
        
        // Remove from the list
        setState(() {
          _directoryImages.removeAt(currentIndex);
        });

        if (_directoryImages.isEmpty) {
          // No more images
          setState(() {
            _currentImage = null;
            _errorMessage = 'No more images in this directory';
          });
        } else {
          // Go to the next image, or the previous if we were at the end
          int nextIndex = currentIndex;
          if (nextIndex >= _directoryImages.length) {
            nextIndex = _directoryImages.length - 1;
          }
          
          setState(() {
            _currentImage = _directoryImages[nextIndex];
          });
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteCurrentImage() async {
    await _performDeletion(confirm: true);
  }

  Future<void> _pickImage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final file = await FileService.pickImageFile();

    if (file != null) {
      await _loadImageFromPath(file.path);
    } else {
      setState(() {
        _isLoading = false;
      });
    }
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
      // Refresh directory images in case new file was created
      final directoryImages = await FileService.getImagesInDirectory(result.path);
      setState(() {
        _directoryImages = directoryImages;
      });
    }
  }

  void _showKeyboardShortcutsDialog() {
    showKeyboardShortcutsDialog(context, mode: ShortcutMode.viewer);
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
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _navigateImage(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _navigateImage(-1),
        const SingleActivator(LogicalKeyboardKey.keyL): () => _navigateImage(1),
        const SingleActivator(LogicalKeyboardKey.keyH): () => _navigateImage(-1),
        const SingleActivator(LogicalKeyboardKey.keyK): () => _handleZoom(true),
        const SingleActivator(LogicalKeyboardKey.keyJ): () => _handleZoom(false),
        const SingleActivator(LogicalKeyboardKey.keyQ): _closeImage,
        const SingleActivator(LogicalKeyboardKey.keyD): _handleDKey,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): _showKeyboardShortcutsDialog,
        // Also keep Delete key for convenience
        const SingleActivator(LogicalKeyboardKey.delete): _deleteCurrentImage,
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: GestureDetector(
              onPanStart: (details) {
                windowManager.startDragging();
              },
              child: AppBar(
                title: const Text('Editt', style: TextStyle(fontFamily: 'JetbrainsMono')),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.folder_open, size: 12),
                    onPressed: _pickImage,
                    tooltip: 'Open Image',
                  ),
                  if (_currentImage != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 12),
                      onPressed: _deleteCurrentImage,
                      tooltip: 'Delete Image',
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
        ),
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
      transformationController: _transformationController,
    );
  }
}
