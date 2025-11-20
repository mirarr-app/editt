import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/image_service.dart';

class CutoutDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final String originalPath;
  final Function(Uint8List processedBytes) onApply;

  const CutoutDialog({
    super.key,
    required this.imageBytes,
    required this.originalPath,
    required this.onApply,
  });

  @override
  State<CutoutDialog> createState() => _CutoutDialogState();
}

class _CutoutDialogState extends State<CutoutDialog> {
  static const double _kImageHeight = 350.0;

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

      if (mounted) {
        setState(() {
          _previewImageBytes = result;
          _isGeneratingPreview = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeneratingPreview = false;
        });
      }
    }
  }

  void _onImageTapDown(TapDownDetails details, BoxConstraints constraints) {
    if (_isGeneratingPreview) return;
    
    final rect = _calculateImageRect(constraints);
    
    // Map local position to image relative position (0.0 to 1.0)
    final localPos = details.localPosition;
    
    // Check if tap is within the image rect
    if (!rect.contains(localPos)) return;
    
    double position;
    if (_isVertical) {
      // Vertical cutout: drag horizontally (use dx)
      // Relative to the image rect, not the container
      position = (localPos.dx - rect.left) / rect.width;
    } else {
      // Horizontal cutout: drag vertically (use dy)
      position = (localPos.dy - rect.top) / rect.height;
    }
    
    position = position.clamp(0.0, 1.0);
    
    setState(() {
      _isSelecting = true;
      _selectionStart = position;
      _selectionEnd = position;
    });
  }

  void _onImagePanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (!_isSelecting || _selectionStart == null) return;
    
    final rect = _calculateImageRect(constraints);
    final localPos = details.localPosition;
    
    double position;
    if (_isVertical) {
      position = (localPos.dx - rect.left) / rect.width;
    } else {
      position = (localPos.dy - rect.top) / rect.height;
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
    
    setState(() {
      _startPosition = start < end ? start : end;
      _endPosition = start < end ? end : start;
      _isSelecting = false;
      _selectionStart = null;
      _selectionEnd = null;
    });
    
    _generatePreview();
  }

  Rect _calculateImageRect(BoxConstraints constraints) {
    final double containerWidth = constraints.maxWidth;
    final double containerHeight = constraints.maxHeight;

    if (_imageDimensions == null) {
      return Rect.fromLTWH(0, 0, containerWidth, containerHeight);
    }
    
    final double imageWidth = _imageDimensions!['width']!.toDouble();
    final double imageHeight = _imageDimensions!['height']!.toDouble();
    
    final double imageRatio = imageWidth / imageHeight;
    final double containerRatio = containerWidth / containerHeight;
    
    double displayWidth, displayHeight;
    
    if (imageRatio > containerRatio) {
      // Image is wider than container - fit to width
      displayWidth = containerWidth;
      displayHeight = containerWidth / imageRatio;
    } else {
      // Image is taller than container - fit to height
      displayHeight = containerHeight;
      displayWidth = containerHeight * imageRatio;
    }
    
    final double dx = (containerWidth - displayWidth) / 2;
    final double dy = (containerHeight - displayHeight) / 2;
    
    return Rect.fromLTWH(dx, dy, displayWidth, displayHeight);
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

      if (mounted) {
        Navigator.of(context).pop();
        widget.onApply(result);
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cutout Tool'),
      surfaceTintColor: Colors.transparent,
      content: SizedBox(
        width: 700,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Controls and Instructions
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select area to REMOVE',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                
                      ],
                    ),
                  ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('Vertical Cut'),
                        icon: Icon(Icons.swap_horiz),
                      ),
                      ButtonSegment(
                        value: false,
                        label: Text('Horizontal Cut'),
                        icon: Icon(Icons.swap_vert),
                      ),
                    ],
                    selected: {_isVertical},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        _isVertical = newSelection.first;
                        _startPosition = 0.2;
                        _endPosition = 0.8;
                        _isSelecting = false;
                        _selectionStart = null;
                        _selectionEnd = null;
                      });
                      _generatePreview();
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Editor Area
              LayoutBuilder(
                builder: (context, constraints) {
                  // Enforce fixed height for the editor container
                  return SizedBox(
                    height: _kImageHeight,
                    width: double.infinity,
                    child: LayoutBuilder(
                      builder: (context, innerConstraints) {
                        return GestureDetector(
                          onTapDown: (details) => _onImageTapDown(details, innerConstraints),
                          onPanUpdate: (details) => _onImagePanUpdate(details, innerConstraints),
                          onPanEnd: _onImagePanEnd,
                          child: Container(
                            color: Colors.grey.withValues(alpha: 0.1), // Background for empty space
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Image
                                Positioned.fill(
                                  child: Image.memory(
                                    widget.imageBytes,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Center(
                                        child: Text('Image unavailable'),
                                      );
                                    },
                                  ),
                                ),
                                
                                // Selection Overlay
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: SelectionPainter(
                                      startPosition: _isSelecting && _selectionStart != null ? _selectionStart! : _startPosition,
                                      endPosition: _isSelecting && _selectionEnd != null ? _selectionEnd! : _endPosition,
                                      isVertical: _isVertical,
                                      imageRect: _calculateImageRect(innerConstraints),
                                      isSelecting: _isSelecting,
                                    ),
                                  ),
                                ),
                                
                                // Loading indicator
                                if (_isGeneratingPreview)
                                  const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 24),
              
              // Preview Area
              const Text(
                'Result Preview',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.withValues(alpha: 0.05),
                ),
                child: _previewImageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.memory(
                          _previewImageBytes!,
                          fit: BoxFit.contain,
                        ),
                      )
                    : const Center(child: Text('No preview')),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isProcessing ? null : _applyCutout,
          child: const Text('Apply Cutout'),
        ),
      ],
    );
  }
}

class SelectionPainter extends CustomPainter {
  final double startPosition;
  final double endPosition;
  final bool isVertical;
  final Rect imageRect;
  final bool isSelecting;

  SelectionPainter({
    required this.startPosition,
    required this.endPosition,
    required this.isVertical,
    required this.imageRect,
    this.isSelecting = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Clip to the image area so we don't draw on the background
    canvas.save();
    canvas.clipRect(imageRect);

    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
      
    // Draw the "removed" area dark
    if (isVertical) {
      final startX = imageRect.left + (startPosition * imageRect.width);
      final endX = imageRect.left + (endPosition * imageRect.width);
      
      final rect = Rect.fromLTRB(startX, imageRect.top, endX, imageRect.bottom);
      canvas.drawRect(rect, overlayPaint);
      canvas.drawRect(rect, borderPaint);
      
      _drawDeletePattern(canvas, rect);
      
    } else {
      final startY = imageRect.top + (startPosition * imageRect.height);
      final endY = imageRect.top + (endPosition * imageRect.height);
      
      final rect = Rect.fromLTRB(imageRect.left, startY, imageRect.right, endY);
      canvas.drawRect(rect, overlayPaint);
      canvas.drawRect(rect, borderPaint);
      
      _drawDeletePattern(canvas, rect);
    }

    canvas.restore();
  }
  
  void _drawDeletePattern(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = Colors.red.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
      
    // Simple cross
    canvas.drawLine(rect.topLeft, rect.bottomRight, paint);
    canvas.drawLine(rect.topRight, rect.bottomLeft, paint);
  }

  @override
  bool shouldRepaint(SelectionPainter oldDelegate) {
    return oldDelegate.startPosition != startPosition ||
        oldDelegate.endPosition != endPosition ||
        oldDelegate.isVertical != isVertical ||
        oldDelegate.imageRect != imageRect ||
        oldDelegate.isSelecting != isSelecting;
  }
}

