import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/inspection.dart';
import '../state/inspection_bloc.dart';
import '../widgets/defect_capture_card.dart';
import '../widgets/defect_review_card.dart';

class SiteInspectionWizard extends StatefulWidget {
  const SiteInspectionWizard({super.key});

  @override
  State<SiteInspectionWizard> createState() => _SiteInspectionWizardState();
}

class _SiteInspectionWizardState extends State<SiteInspectionWizard> {
  int _currentStep = 0;
  
  // Step 1: Site Metadata
  final _addressController = TextEditingController();
  double? _latitude;
  double? _longitude;
  bool _isGettingLocation = false;

  // Step 2: Building Materials
  final Map<String, bool> _buildingMaterials = {
    'Brick': false,
    'Concrete': false,
    'Timber': false,
    'Steel': false,
    'Glass': false,
    'Stone': false,
    'Other': false,
  };
  final _otherMaterialController = TextEditingController();

  // Step 3: Defects
  final List<Defect> _capturedDefects = [];

  // Inspection ID
  late String _inspectionId;

  @override
  void initState() {
    super.initState();
    _inspectionId = DateTime.now().millisecondsSinceEpoch.toString();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      debugPrint(
        '[SiteInspectionWizard] Location obtained: $_latitude, $_longitude',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location obtained successfully')),
        );
      }
    } catch (e) {
      debugPrint('[SiteInspectionWizard] Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  void _addDefect(Defect defect) {
    setState(() {
      _capturedDefects.add(
        Defect(
          id: defect.id,
          inspectionId: _inspectionId,
          type: defect.type,
          lengthMm: defect.lengthMm,
          widthMm: defect.widthMm,
          photoPath: defect.photoPath,
          remarks: defect.remarks,
          createdAt: defect.createdAt,
        ),
      );
    });

    debugPrint(
      '[SiteInspectionWizard] Defect added. Total: ${_capturedDefects.length}',
    );
  }

  void _removeDefect(int index) {
    setState(() {
      _capturedDefects.removeAt(index);
    });
    debugPrint(
      '[SiteInspectionWizard] Defect removed. Total: ${_capturedDefects.length}',
    );
  }

  void _updateDefect(int index, Defect updatedDefect) {
    setState(() {
      _capturedDefects[index] = updatedDefect;
    });
    debugPrint(
      '[SiteInspectionWizard] Defect updated at index $index',
    );
  }

  void _completeInspection() {
    if (_addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter site address')),
      );
      return;
    }

    if (_capturedDefects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture at least one defect')),
      );
      return;
    }

    final inspection = Inspection(
      id: _inspectionId,
      siteAddress: _addressController.text,
      latitude: _latitude,
      longitude: _longitude,
      defects: _capturedDefects,
      createdAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
      remarks: _buildingMaterials.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .join(', '),
    );

    context.read<InspectionBloc>().add(CreateInspectionEvent(
          siteAddress: inspection.siteAddress,
          latitude: inspection.latitude,
          longitude: inspection.longitude,
        ));

    debugPrint('[SiteInspectionWizard] Inspection completed: ${inspection.id}');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Inspection saved successfully')),
    );

    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _otherMaterialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Inspection'),
        elevation: 0,
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 3) {
            setState(() => _currentStep += 1);
          } else {
            _completeInspection();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          } else {
            Navigator.of(context).pop();
          }
        },
        steps: [
          // Step 1: Site Metadata
          Step(
            title: const Text('Site Information'),
            isActive: _currentStep >= 0,
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Site Address *',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _addressController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Enter the site address...',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'GPS Location',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  if (_latitude != null && _longitude != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: NBROColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: NBROColors.success,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Location: $_latitude, $_longitude',
                                  style: const TextStyle(
                                    color: NBROColors.success,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _getCurrentLocation,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Update Location'),
                          ),
                        ],
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _isGettingLocation ? null : _getCurrentLocation,
                      icon: _isGettingLocation
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.location_searching),
                      label: const Text('Get Current Location'),
                    ),
                ],
              ),
            ),
          ),

          // Step 2: Building Materials
          Step(
            title: const Text('Building Materials'),
            isActive: _currentStep >= 1,
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select primary building materials',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ..._buildingMaterials.entries.map((entry) {
                    return CheckboxListTile(
                      title: Text(entry.key),
                      value: entry.value,
                      onChanged: (value) {
                        setState(() {
                          _buildingMaterials[entry.key] = value ?? false;
                        });
                      },
                    );
                  }),
                  if (_buildingMaterials['Other'] == true) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _otherMaterialController,
                      decoration: const InputDecoration(
                        hintText: 'Specify other materials...',
                        prefixIcon: Icon(Icons.edit),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Step 3: Defect Capture
          Step(
            title: const Text('Capture Defects'),
            isActive: _currentStep >= 2,
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DefectCaptureCard(
                    onDefectCapture: _addDefect,
                  ),
                  const SizedBox(height: 24),
                  if (_capturedDefects.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Captured Defects (${_capturedDefects.length})',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _capturedDefects.length,
                          itemBuilder: (context, index) {
                            final defect = _capturedDefects[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.image),
                                title: Text(defect.type.displayName),
                                subtitle: Text(
                                  '${defect.lengthMm}mm × ${defect.widthMm}mm',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => _removeDefect(index),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Step 4: Review & Edit Details
          Step(
            title: const Text('Review & Edit'),
            isActive: _currentStep >= 3,
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Site Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Address', _addressController.text),
                          if (_latitude != null && _longitude != null) ...[
                            const SizedBox(height: 8),
                            _buildDetailRow('Latitude', _latitude!.toStringAsFixed(4)),
                            const SizedBox(height: 8),
                            _buildDetailRow('Longitude', _longitude!.toStringAsFixed(4)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Building Materials',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _buildingMaterials.entries
                        .where((e) => e.value)
                        .map((e) => Chip(label: Text(e.key)))
                        .toList(),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Defects - Tap to Edit',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _capturedDefects.length,
                    itemBuilder: (context, index) {
                      return DefectReviewCard(
                        defect: _capturedDefects[index],
                        onDefectUpdate: (updatedDefect) {
                          _updateDefect(index, updatedDefect);
                        },
                        onDefectDelete: () {
                          _removeDefect(index);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Defect removed')),
                          );
                        },
                      );
                    },
                  ),
                  if (_capturedDefects.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No defects captured yet',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
