import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/image_service.dart';

class CutoutDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final String originalPath;
  final Function(Uint8List processedBytes, String newPath) onSave;

  const CutoutDialog({
    super.key,
    required this.imageBytes,
    required this.originalPath,
    required this.onSave,
  });

  @override
  State<CutoutDialog> createState() => _CutoutDialogState();
}

class _CutoutDialogState extends State<CutoutDialog> {
  bool _isVertical = true;
  double _startPosition = 0.2;
  double _endPosition = 0.8;
  bool _isProcessing = false;
  Uint8List? _previewImageBytes;
  bool _isGeneratingPreview = false;
  bool _isSelecting = false;
  double? _selectionStart;
  double? _selectionEnd;
  Map<String, int>? _imageDimensions;

  @override
  void initState() {
    super.initState();
    _loadImageDimensions();
    _generatePreview();
  }

  Future<void> _loadImageDimensions() async {
    final dims = await ImageService.getImageDimensions(widget.imageBytes);
    if (mounted) {
      setState(() {
        _imageDimensions = dims;
      });
    }
  }

  Future<void> _generatePreview() async {
    if (_isGeneratingPreview) return;
    
    print('Generating preview: start=$_startPosition, end=$_endPosition, isVertical=$_isVertical');
    
    setState(() {
      _isGeneratingPreview = true;
    });

    try {
      final result = await ImageService.cutoutImage(
        imageBytes: widget.imageBytes,
        startPosition: _startPosition,
        endPosition: _endPosition,
        isVertical: _isVertical,
      );

      print('Preview result: ${result != null ? 'success' : 'failed'}');

      if (mounted) {
        setState(() {
          _previewImageBytes = result;
          _isGeneratingPreview = false;
        });
      }
    } catch (e) {
      print('Preview error: $e');
      if (mounted) {
        setState(() {
          _isGeneratingPreview = false;
        });
      }
    }
  }

  void _onImageTapDown(TapDownDetails details, BoxConstraints constraints) {
    if (_isGeneratingPreview) return;
    
    // Calculate the actual image display size considering BoxFit.contain
    final imageSize = _calculateImageDisplaySize(constraints);
    
    double position;
    if (_isVertical) {
      // Vertical cutout: drag horizontally (use dx)
      position = details.localPosition.dx / imageSize.width;
    } else {
      // Horizontal cutout: drag vertically (use dy)
      position = details.localPosition.dy / imageSize.height;
    }
    
    position = position.clamp(0.0, 1.0);
    
    print('Tap down: localPosition=${details.localPosition}, imageSize=$imageSize, position=$position, isVertical=$_isVertical');
    
    setState(() {
      _isSelecting = true;
      _selectionStart = position;
      _selectionEnd = position;
    });
  }

  void _onImagePanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (!_isSelecting || _selectionStart == null) return;
    
    // Calculate the actual image display size considering BoxFit.contain
    final imageSize = _calculateImageDisplaySize(constraints);
    
    double position;
    if (_isVertical) {
      // Vertical cutout: drag horizontally (use dx)
      position = details.localPosition.dx / imageSize.width;
    } else {
      // Horizontal cutout: drag vertically (use dy)
      position = details.localPosition.dy / imageSize.height;
    }
    
    position = position.clamp(0.0, 1.0);
    
    setState(() {
      _selectionEnd = position;
    });
  }

  void _onImagePanEnd(DragEndDetails details) {
    if (!_isSelecting || _selectionStart == null || _selectionEnd == null) return;
    
    final start = _selectionStart!;
    final end = _selectionEnd!;
    
    print('Selection: start=$start, end=$end, isVertical=$_isVertical');
    print('Selection difference: ${(end - start).abs()}');
    
    setState(() {
      _startPosition = start < end ? start : end;
      _endPosition = start < end ? end : start;
      _isSelecting = false;
      _selectionStart = null;
      _selectionEnd = null;
    });
    
    print('Final positions: start=$_startPosition, end=$_endPosition');
    _generatePreview();
  }

  Size _calculateImageDisplaySize(BoxConstraints constraints) {
    if (_imageDimensions == null) {
      // Fallback to container size if dimensions not available
      return Size(constraints.maxWidth, constraints.maxHeight);
    }
    
    final imageWidth = _imageDimensions!['width']!.toDouble();
    final imageHeight = _imageDimensions!['height']!.toDouble();
    
    // Calculate the actual display size with BoxFit.contain
    final containerAspectRatio = constraints.maxWidth / constraints.maxHeight;
    final imageAspectRatio = imageWidth / imageHeight;
    
    double displayWidth, displayHeight;
    
    if (imageAspectRatio > containerAspectRatio) {
      // Image is wider than container - fit to width
      displayWidth = constraints.maxWidth;
      displayHeight = constraints.maxWidth / imageAspectRatio;
    } else {
      // Image is taller than container - fit to height
      displayHeight = constraints.maxHeight;
      displayWidth = constraints.maxHeight * imageAspectRatio;
    }
    
    return Size(displayWidth, displayHeight);
  }

  Future<void> _applyCutout() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await ImageService.cutoutImage(
        imageBytes: widget.imageBytes,
        startPosition: _startPosition,
        endPosition: _endPosition,
        isVertical: _isVertical,
      );

      if (result == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to apply cutout. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Generate new filename
      final newPath = _generateNewFilename();
      
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSave(result, newPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error applying cutout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  String _generateNewFilename() {
    final pathParts = widget.originalPath.split('/');
    final filename = pathParts.last;
    final nameWithoutExt = filename.split('.').first;
    final extension = filename.split('.').last;
    
    return widget.originalPath.replaceFirst(
      filename,
      '${nameWithoutExt}_cutout.$extension',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cutout Tool'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Direction selection
            const Text(
              'Cutout Direction',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Vertical'),
                  icon: Icon(Icons.swap_horiz),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Horizontal'),
                  icon: Icon(Icons.swap_vert),
                ),
              ],
              selected: {_isVertical},
              onSelectionChanged: (Set<bool> newSelection) {
                setState(() {
                  _isVertical = newSelection.first;
                  // Reset positions when changing direction
                  _startPosition = 0.2;
                  _endPosition = 0.8;
                  _isSelecting = false;
                  _selectionStart = null;
                  _selectionEnd = null;
                });
                _generatePreview();
              },
            ),
            const SizedBox(height: 24),

            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isVertical
                          ? 'Click and drag horizontally on the image below to select the area to remove'
                          : 'Click and drag vertically on the image below to select the area to remove',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Interactive image selection
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Select Area to Remove:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (_isGeneratingPreview)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Interactive image
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onTapDown: (details) => _onImageTapDown(details, constraints),
                        onPanUpdate: (details) => _onImagePanUpdate(details, constraints),
                        onPanEnd: _onImagePanEnd,
                        child: Container(
                          constraints: const BoxConstraints(
                            maxHeight: 300,
                            maxWidth: double.infinity,
                          ),
                          child: Stack(
                            children: [
                              // Original image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.memory(
                                  widget.imageBytes,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 100,
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: Text('Image unavailable'),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              
                              // Selection overlay
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: SelectionPainter(
                                    startPosition: _isSelecting && _selectionStart != null ? _selectionStart! : _startPosition,
                                    endPosition: _isSelecting && _selectionEnd != null ? _selectionEnd! : _endPosition,
                                    isVertical: _isVertical,
                                    imageSize: Size(
                                      constraints.maxWidth,
                                      constraints.maxHeight,
                                    ),
                                    isSelecting: _isSelecting,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Info text
                  Text(
                    _isVertical
                        ? 'Will remove ${((_endPosition - _startPosition) * 100).toStringAsFixed(0)}% of the image width'
                        : 'Will remove ${((_endPosition - _startPosition) * 100).toStringAsFixed(0)}% of the image height',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    _isVertical
                        ? 'New width: ${((1 - (_endPosition - _startPosition)) * 100).toStringAsFixed(0)}% of original'
                        : 'New height: ${((1 - (_endPosition - _startPosition)) * 100).toStringAsFixed(0)}% of original',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Result preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Result Preview:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  // Result image preview
                  if (_previewImageBytes != null)
                    Container(
                      constraints: const BoxConstraints(
                        maxHeight: 200,
                        maxWidth: double.infinity,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.memory(
                          _previewImageBytes!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 100,
                              color: Colors.grey[300],
                              child: const Center(
                                child: Text('Preview unavailable'),
                              ),
                            );
                          },
                        ),
                      ),
                    )
                  else if (!_isGeneratingPreview)
                    Container(
                      height: 100,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Text('No preview available'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _applyCutout,
          child: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Apply Cutout'),
        ),
      ],
    );
  }
}

class SelectionPainter extends CustomPainter {
  final double startPosition;
  final double endPosition;
  final bool isVertical;
  final Size imageSize;
  final bool isSelecting;

  SelectionPainter({
    required this.startPosition,
    required this.endPosition,
    required this.isVertical,
    required this.imageSize,
    this.isSelecting = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    if (isVertical) {
      // Vertical cutout - draw horizontal selection
      final startX = startPosition * size.width;
      final endX = endPosition * size.width;
      
      // Draw selection rectangle
      canvas.drawRect(
        Rect.fromLTRB(startX, 0, endX, size.height),
        paint,
      );
      
      // Draw border
      canvas.drawRect(
        Rect.fromLTRB(startX, 0, endX, size.height),
        borderPaint,
      );
    } else {
      // Horizontal cutout - draw vertical selection
      final startY = startPosition * size.height;
      final endY = endPosition * size.height;
      
      // Draw selection rectangle
      canvas.drawRect(
        Rect.fromLTRB(0, startY, size.width, endY),
        paint,
      );
      
      // Draw border
      canvas.drawRect(
        Rect.fromLTRB(0, startY, size.width, endY),
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(SelectionPainter oldDelegate) {
    return oldDelegate.startPosition != startPosition ||
        oldDelegate.endPosition != endPosition ||
        oldDelegate.isVertical != isVertical ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.isSelecting != isSelecting;
  }
}