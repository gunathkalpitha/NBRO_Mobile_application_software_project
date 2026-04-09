import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nbro_mobile_application/domain/models/inspection.dart';
import 'package:nbro_mobile_application/presentation/widgets/defect_capture_card.dart';

class EditDefectModal extends StatefulWidget {
  final Defect? defect;
  final Function(Defect) onSave;

  const EditDefectModal({
    super.key,
    this.defect,
    required this.onSave,
  });

  @override
  State<EditDefectModal> createState() => _EditDefectModalState();
}

class _EditDefectModalState extends State<EditDefectModal> {
  late TextEditingController _lengthController;
  late TextEditingController _widthController;
  late TextEditingController _remarksController;
  String? _selectedNotation;
  String? _selectedCategory;
  String? _selectedFloorLevel;
  String? _photoPath;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final defect = widget.defect;
    _lengthController = TextEditingController(text: defect?.lengthMm.toString() ?? '');
    _widthController = TextEditingController(text: defect?.widthMm?.toString() ?? '');
    _remarksController = TextEditingController(text: defect?.remarks ?? '');
    _selectedNotation = defect?.notation.code;
    _selectedCategory = defect?.category.name;
    _selectedFloorLevel = defect?.floorLevel;
    _photoUrl = defect?.photoUrl ?? defect?.photoPath;
  }

  @override
  void dispose() {
    _lengthController.dispose();
    _widthController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _pickDefectPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        setState(() {
          _photoPath = picked.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _annotateCurrentImage() async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Red dotted-line annotation is not supported on web.'),
          ),
        );
      }
      return;
    }

    String? imagePathForAnnotation = _photoPath;

    if (imagePathForAnnotation == null && _photoUrl != null) {
      if (_photoUrl!.startsWith('http://') || _photoUrl!.startsWith('https://')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please pick this image again from gallery to add red dotted markings.'),
            ),
          );
        }
        return;
      }
      imagePathForAnnotation = _photoUrl;
    }

    if (imagePathForAnnotation == null || imagePathForAnnotation.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a photo first to mark defects.')),
        );
      }
      return;
    }

    final file = File(imagePathForAnnotation);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Local image not found. Please pick again from gallery/camera.'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    final annotatedImage = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => DefectPhotoAnnotatorScreen(imageFile: file),
      ),
    );

    if (annotatedImage != null && mounted) {
      setState(() {
        _photoPath = annotatedImage.path;
        _photoUrl = null;
      });
    }
  }

  void _saveDefect() {
    if (_selectedNotation == null ||
        _selectedCategory == null ||
        _lengthController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in notation, category, and length'),
        ),
      );
      return;
    }

    final defect = Defect(
      id: widget.defect?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      inspectionId: widget.defect?.inspectionId ?? '',
      notation: DefectNotation.values.firstWhere(
        (e) => e.code == _selectedNotation,
      ),
      category: DefectCategory.values.firstWhere(
        (e) => e.name == _selectedCategory,
      ),
      floorLevel: _selectedFloorLevel,
      lengthMm: double.parse(_lengthController.text),
      widthMm: _widthController.text.isEmpty ? null : double.parse(_widthController.text),
      photoPath: _photoPath ?? _photoUrl ?? '',
      remarks: _remarksController.text.isEmpty ? null : _remarksController.text,
      createdAt: widget.defect?.createdAt ?? DateTime.now(),
    );

    widget.onSave(defect);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.defect == null ? 'Add Defect' : 'Edit Defect'),
          automaticallyImplyLeading: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Defect Photo
              Text(
                'Defect Photo (with red marking)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (_photoPath != null || _photoUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _photoPath != null
                      ? (kIsWeb
                          ? Image.network(_photoPath!, height: 200, width: double.infinity, fit: BoxFit.cover)
                          : Image.file(File(_photoPath!), height: 200, width: double.infinity, fit: BoxFit.cover))
                      : Image.network(
                          _photoUrl!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Icon(Icons.error_outline, size: 48, color: Colors.grey),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_camera, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No defect photo'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDefectPhoto(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDefectPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('From Gallery'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: (_photoPath != null || _photoUrl != null)
                      ? _annotateCurrentImage
                      : null,
                  icon: const Icon(Icons.edit),
                  label: const Text('Mark Red Dotted Line'),
                ),
              ),
              if (_photoPath != null || _photoUrl != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _photoPath = null;
                      _photoUrl = null;
                    });
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                ),
              ],
              const SizedBox(height: 24),

              // Defect Notation
              DropdownButtonFormField<String>(
                value: _selectedNotation,
                decoration: const InputDecoration(
                  labelText: 'Defect Notation *',
                  prefixIcon: Icon(Icons.code),
                  border: OutlineInputBorder(),
                ),
                items: DefectNotation.values
                    .map((n) => DropdownMenuItem(
                      value: n.code,
                      child: Text(n.code),
                    ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedNotation = value);
                },
              ),
              const SizedBox(height: 16),

              // Defect Category
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                items: DefectCategory.values
                    .map((c) => DropdownMenuItem(
                      value: c.name,
                      child: Text(c.displayName),
                    ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedCategory = value);
                },
              ),
              const SizedBox(height: 16),

              // Floor Level
              TextFormField(
                initialValue: _selectedFloorLevel,
                decoration: const InputDecoration(
                  labelText: 'Floor Level',
                  prefixIcon: Icon(Icons.layers),
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Ground, First, etc.',
                ),
                onChanged: (value) => _selectedFloorLevel = value.isEmpty ? null : value,
              ),
              const SizedBox(height: 16),

              // Length
              TextFormField(
                controller: _lengthController,
                decoration: const InputDecoration(
                  labelText: 'Length (mm) *',
                  prefixIcon: Icon(Icons.straighten),
                  border: OutlineInputBorder(),
                  suffixText: 'mm',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Width
              TextFormField(
                controller: _widthController,
                decoration: const InputDecoration(
                  labelText: 'Width (mm)',
                  prefixIcon: Icon(Icons.straighten),
                  border: OutlineInputBorder(),
                  suffixText: 'mm',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Remarks
              TextFormField(
                controller: _remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks',
                  prefixIcon: Icon(Icons.note),
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saveDefect,
                  icon: const Icon(Icons.check_circle),
                  label: Text(widget.defect == null ? 'Add Defect' : 'Update Defect'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
