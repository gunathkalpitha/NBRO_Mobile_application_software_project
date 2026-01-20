import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/inspection.dart';

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

  DefectType? _selectedDefectType;
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
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
        debugPrint('[DefectCaptureCard] Image selected: ${pickedFile.path}');
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
    if (_selectedDefectType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a defect type')),
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
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        inspectionId: '', // Will be set by parent
        notation: DefectNotation.c, // Default to wall crack
        category: DefectCategory.buildingFloor,
        floorLevel: 'Ground',
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
        _selectedDefectType = null;
        _lengthController.clear();
        _widthController.clear();
        _remarksController.clear();
        _selectedImage = null;
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

              // Defect Type Dropdown
              Text(
                'Defect Type *',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<DefectType>(
                initialValue: _selectedDefectType,
                decoration: InputDecoration(
                  hintText: 'Select defect type',
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
                items: DefectType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedDefectType = value);
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
