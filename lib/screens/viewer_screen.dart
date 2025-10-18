import 'dart:io';
import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editt - Photo Viewer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _pickImage,
            tooltip: 'Open Image',
          ),
        ],
      ),
      body: _buildBody(),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image_outlined, size: 128, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'No image loaded',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'Open an image to get started',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
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
        ),
      );
    }

    return ImageViewer(
      imageFile: _currentImage!,
      onEditPressed: _openEditor,
    );
  }
}

