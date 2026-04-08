import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:nbro_mobile_application/core/theme/app_theme.dart';
import 'package:nbro_mobile_application/domain/models/inspection.dart';


class DefectCaptureCard extends StatefulWidget {
  final Function(Defect) onDefectCapture;

  const DefectCaptureCard({
    super.key,
    required this.onDefectCapture,
  });

  @override
  State<DefectCaptureCard> createState() => _DefectCaptureCardState();
}

class _DefectCaptureCardState extends State<DefectCaptureCard> {
  final _imagePicker = ImagePicker();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _remarksController = TextEditingController();

  DefectNotation? _selectedDefectNotation;
  DefectCategory? _selectedDefectCategory;
  String? _selectedFloorLevel;
  File? _selectedImage;
  bool _skipImage = false;
  bool _isSubmitting = false;

  Future<void> _pickImage() async {
    if (kIsWeb) {
      setState(() {
        _skipImage = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image capture is not supported on Web. Skipping image.')),
      );
      return;
    }
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        if (!mounted) {
          return;
        }

        final imageFile = File(pickedFile.path);
        final annotatedImage = await Navigator.of(context).push<File>(
          MaterialPageRoute(
            builder: (_) => DefectPhotoAnnotatorScreen(imageFile: imageFile),
          ),
        );

        if (annotatedImage != null && mounted) {
          setState(() {
            _selectedImage = annotatedImage;
          });
          debugPrint('[DefectCaptureCard] Annotated image selected: ${annotatedImage.path}');
        } else if (mounted) {
          setState(() {
            _selectedImage = imageFile;
          });
          debugPrint('[DefectCaptureCard] Original image selected: ${pickedFile.path}');
        }
      }
    } catch (e) {
      debugPrint('[DefectCaptureCard] Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  Future<void> _submitDefect() async {
    // Validation
    if (_selectedDefectNotation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a defect notation')),
      );
      return;
    }

    if (_selectedDefectCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a defect category')),
      );
      return;
    }

    if (_lengthController.text.isEmpty || _widthController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter length and width')),
      );
      return;
    }

    if (_selectedImage == null && !_skipImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture a photo of the defect or skip on web.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final length = double.parse(_lengthController.text);
      final width = double.parse(_widthController.text);

      final defect = Defect(
        id: const Uuid().v4(),
        inspectionId: '', // Will be set by parent
        notation: _selectedDefectNotation!,
        category: _selectedDefectCategory!,
        floorLevel: _selectedFloorLevel ?? 'Ground',
        lengthMm: length,
        widthMm: width,
        photoPath: _skipImage ? null : _selectedImage?.path,
        remarks: _remarksController.text.isNotEmpty
            ? _remarksController.text
            : null,
        createdAt: DateTime.now(),
      );

      widget.onDefectCapture(defect);

      // Reset form
      setState(() {
        _selectedDefectNotation = null;
        _selectedDefectCategory = null;
        _selectedFloorLevel = null;
        _lengthController.clear();
        _widthController.clear();
        _remarksController.clear();
        _selectedImage = null;
        _skipImage = false;
      });

      debugPrint('[DefectCaptureCard] Defect captured: ${defect.id}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Defect captured successfully')),
        );
      }
    } catch (e) {
      debugPrint('[DefectCaptureCard] Error submitting defect: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _lengthController.dispose();
    _widthController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Capture Structural Defect',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),

              // Photo Capture Section
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: NBROColors.light,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _selectedImage == null && !_skipImage
                    ? Column(
                        children: [
                          InkWell(
                            onTap: _pickImage,
                            child: SizedBox(
                              height: 200,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.camera_alt_outlined,
                                    size: 48,
                                    color: NBROColors.primary,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Tap to capture defect photo',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (kIsWeb)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() => _skipImage = true);
                                },
                                child: const Text('Skip Image (Web)'),
                              ),
                            ),
                        ],
                      )
                    : _skipImage
                        ? Container(
                            height: 200,
                            alignment: Alignment.center,
                            child: const Text('Image skipped (Web)', style: TextStyle(color: Colors.grey)),
                          )
                        : Stack(
                            children: [
                              if (!kIsWeb && _selectedImage != null)
                                Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 200,
                                ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: FloatingActionButton.small(
                                  backgroundColor: NBROColors.error,
                                  onPressed: () {
                                    setState(() {
                                      _selectedImage = null;
                                      _skipImage = false;
                                    });
                                  },
                                  child: const Icon(Icons.close),
                                ),
                              ),
                            ],
                          ),
              ),
              const SizedBox(height: 24),

              // Defect Notation Dropdown
              Text(
                'Defect Notation *',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<DefectNotation>(
                initialValue: _selectedDefectNotation,
                decoration: const InputDecoration(
                  hintText: 'Select defect notation',
                  prefixIcon: Icon(Icons.error_outline),
                ),
                items: DefectNotation.values
                    .map(
                      (notation) => DropdownMenuItem(
                        value: notation,
                        child: Text(notation.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedDefectNotation = value);
                },
              ),
              const SizedBox(height: 20),

              // Defect Category Dropdown
              Text(
                'Defect Category *',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<DefectCategory>(
                initialValue: _selectedDefectCategory,
                decoration: const InputDecoration(
                  hintText: 'Select category',
                  prefixIcon: Icon(Icons.category),
                ),
                items: DefectCategory.values
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedDefectCategory = value);
                },
              ),
              const SizedBox(height: 20),

              // Floor Level Dropdown
              Text(
                'Floor Level *',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedFloorLevel,
                decoration: const InputDecoration(
                  hintText: 'Select floor level',
                  prefixIcon: Icon(Icons.layers),
                ),
                items: const [
                  DropdownMenuItem(value: 'Ground', child: Text('Ground Floor')),
                  DropdownMenuItem(value: '1st', child: Text('1st Floor')),
                  DropdownMenuItem(value: '2nd', child: Text('2nd Floor')),
                  DropdownMenuItem(value: '3rd', child: Text('3rd Floor')),
                  DropdownMenuItem(value: 'Roof', child: Text('Roof')),
                ],
                onChanged: (value) {
                  setState(() => _selectedFloorLevel = value);
                },
              ),
              const SizedBox(height: 20),

              // Dimensions Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Length (mm) *',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _lengthController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'e.g., 150',
                            prefixIcon: Icon(Icons.straighten),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Width (mm) *',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _widthController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'e.g., 50',
                            prefixIcon: Icon(Icons.straighten),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Remarks Field
              Text(
                'Remarks (Optional)',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _remarksController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Additional notes about this defect...',
                  prefixIcon: Icon(Icons.note_outlined),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitDefect,
                  icon: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              NBROColors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(_isSubmitting ? 'Saving...' : 'Save Defect'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AnnotationTool {
  freehand,
  rectangle,
  circle,
}

class _AnnotationStroke {
  final List<Offset> points;
  final _AnnotationTool tool;

  const _AnnotationStroke({
    required this.points,
    required this.tool,
  });
}

class DefectPhotoAnnotatorScreen extends StatefulWidget {
  final File imageFile;

  const DefectPhotoAnnotatorScreen({
    super.key,
    required this.imageFile,
  });

  @override
  State<DefectPhotoAnnotatorScreen> createState() => _DefectPhotoAnnotatorScreenState();
}

class _DefectPhotoAnnotatorScreenState extends State<DefectPhotoAnnotatorScreen> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final List<_AnnotationStroke> _strokes = [];
  List<Offset> _currentPoints = [];
  _AnnotationTool _selectedTool = _AnnotationTool.freehand;
  bool _isSaving = false;

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _currentPoints = [details.localPosition];
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      if (_selectedTool == _AnnotationTool.freehand) {
        _currentPoints.add(details.localPosition);
      } else {
        if (_currentPoints.isEmpty) {
          _currentPoints = [details.localPosition];
        } else {
          _currentPoints = [_currentPoints.first, details.localPosition];
        }
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentPoints.length < 2) {
      setState(() {
        _currentPoints = [];
      });
      return;
    }

    setState(() {
      _strokes.add(_AnnotationStroke(points: List<Offset>.from(_currentPoints), tool: _selectedTool));
      _currentPoints = [];
    });
  }

  Future<void> _saveAnnotatedPhoto() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not prepare image for saving.')),
          );
        }
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not encode annotated image.')),
          );
        }
        return;
      }

      final Uint8List bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final outputFile = File(
        '${tempDir.path}/defect_annotated_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await outputFile.writeAsBytes(bytes, flush: true);

      if (mounted) {
        Navigator.of(context).pop(outputFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save annotated image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Defects'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: Colors.black,
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Center(
                      child: RepaintBoundary(
                        key: _repaintBoundaryKey,
                        child: GestureDetector(
                          onPanStart: _onPanStart,
                          onPanUpdate: _onPanUpdate,
                          onPanEnd: _onPanEnd,
                          child: SizedBox(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  widget.imageFile,
                                  fit: BoxFit.contain,
                                ),
                                CustomPaint(
                                  painter: _DefectAnnotationPainter(
                                    strokes: _strokes,
                                    currentPoints: _currentPoints,
                                    activeTool: _selectedTool,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedTool = _AnnotationTool.freehand;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _selectedTool == _AnnotationTool.freehand
                                ? NBROColors.primary.withOpacity(0.12)
                                : null,
                            foregroundColor: _selectedTool == _AnnotationTool.freehand
                                ? NBROColors.primary
                                : Theme.of(context).colorScheme.onSurface,
                            minimumSize: const Size.fromHeight(54),
                          ),
                          child: Tooltip(
                            message: 'Freehand',
                            child: const Icon(Icons.gesture),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedTool = _AnnotationTool.rectangle;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _selectedTool == _AnnotationTool.rectangle
                                ? NBROColors.primary.withOpacity(0.12)
                                : null,
                            foregroundColor: _selectedTool == _AnnotationTool.rectangle
                                ? NBROColors.primary
                                : Theme.of(context).colorScheme.onSurface,
                            minimumSize: const Size.fromHeight(54),
                          ),
                          child: Tooltip(
                            message: 'Rectangle',
                            child: const Icon(Icons.crop_square),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedTool = _AnnotationTool.circle;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _selectedTool == _AnnotationTool.circle
                                ? NBROColors.primary.withOpacity(0.12)
                                : null,
                            foregroundColor: _selectedTool == _AnnotationTool.circle
                                ? NBROColors.primary
                                : Theme.of(context).colorScheme.onSurface,
                            minimumSize: const Size.fromHeight(54),
                          ),
                          child: Tooltip(
                            message: 'Circle',
                            child: const Icon(Icons.circle_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _strokes.isEmpty
                              ? null
                              : () {
                                  setState(() {
                                    _strokes.removeLast();
                                  });
                                },
                          icon: const Icon(Icons.undo),
                          label: const Text('Undo'),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _strokes.isEmpty
                              ? null
                              : () {
                                  setState(() {
                                    _strokes.clear();
                                    _currentPoints = [];
                                  });
                                },
                          icon: const Icon(Icons.delete_sweep),
                          label: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final useIconOnly = constraints.maxWidth < 170;
                            return ElevatedButton(
                              onPressed: _isSaving ? null : _saveAnnotatedPhoto,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : useIconOnly
                                      ? const Icon(Icons.check)
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.check),
                                            SizedBox(width: 8),
                                            Text('Use Photo'),
                                          ],
                                        ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DefectAnnotationPainter extends CustomPainter {
  final List<_AnnotationStroke> strokes;
  final List<Offset> currentPoints;
  final _AnnotationTool activeTool;

  const _DefectAnnotationPainter({
    required this.strokes,
    required this.currentPoints,
    required this.activeTool,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _paintStroke(canvas, stroke);
    }

    if (currentPoints.length >= 2) {
      _paintStroke(
        canvas,
        _AnnotationStroke(points: currentPoints, tool: activeTool),
      );
    }
  }

  void _paintStroke(Canvas canvas, _AnnotationStroke stroke) {
    const dashLength = 10.0;
    const dashGap = 7.0;
    const strokeWidth = 3.0;
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    if (stroke.tool == _AnnotationTool.rectangle) {
      final rect = Rect.fromPoints(stroke.points.first, stroke.points.last);
      _drawDashedLine(canvas, rect.topLeft, rect.topRight, paint, dashLength, dashGap);
      _drawDashedLine(canvas, rect.topRight, rect.bottomRight, paint, dashLength, dashGap);
      _drawDashedLine(canvas, rect.bottomRight, rect.bottomLeft, paint, dashLength, dashGap);
      _drawDashedLine(canvas, rect.bottomLeft, rect.topLeft, paint, dashLength, dashGap);
      return;
    }

    if (stroke.tool == _AnnotationTool.circle) {
      final rect = Rect.fromPoints(stroke.points.first, stroke.points.last);
      _drawDashedOval(canvas, rect, paint, dashLength, dashGap);
      return;
    }

    final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (int i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
    }

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double next = math.min(distance + dashLength, metric.length);
        final segment = metric.extractPath(distance, next);
        canvas.drawPath(segment, paint);
        distance += dashLength + dashGap;
      }
    }
  }

  void _drawDashedOval(
    Canvas canvas,
    Rect rect,
    Paint paint,
    double dashLength,
    double dashGap,
  ) {
    if (rect.width <= 0 || rect.height <= 0) {
      return;
    }

    final path = Path()..addOval(rect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double next = math.min(distance + dashLength, metric.length);
        final segment = metric.extractPath(distance, next);
        canvas.drawPath(segment, paint);
        distance += dashLength + dashGap;
      }
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double dashLength,
    double dashGap,
  ) {
    final totalDistance = (end - start).distance;
    if (totalDistance == 0) {
      return;
    }

    final direction = (end - start) / totalDistance;
    double distance = 0;
    while (distance < totalDistance) {
      final dashStart = start + direction * distance;
      final dashEnd = start + direction * math.min(distance + dashLength, totalDistance);
      canvas.drawLine(dashStart, dashEnd, paint);
      distance += dashLength + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DefectAnnotationPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.currentPoints != currentPoints ||
        oldDelegate.activeTool != activeTool;
  }
}
