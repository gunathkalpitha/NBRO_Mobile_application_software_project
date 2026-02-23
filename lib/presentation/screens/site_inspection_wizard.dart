import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/theme/app_theme.dart';
import '../../domain/models/inspection.dart';
import '../state/inspection_bloc.dart';
import '../widgets/defect_capture_card.dart';
import '../../data/services/draft_storage_service.dart';
import 'package:uuid/uuid.dart';

/// Site Inspection Wizard matching NBRO Physical Forms
/// Flow: Site Data Sheet → Building Profile → Defect Capture → Review
class SiteInspectionWizard extends StatefulWidget {
  final String? draftId; // For restoring a draft
  final Map<String, dynamic>? draftData;
  
  const SiteInspectionWizard({super.key, this.draftId, this.draftData});

  @override
  State<SiteInspectionWizard> createState() => _SiteInspectionWizardState();
}

class _SiteInspectionWizardState extends State<SiteInspectionWizard> {
  int _currentStep = 0;
  final ScrollController _scrollController = ScrollController();
  
  // Building Reference and Owner Information (Step 1)
  final _buildingRefController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  String? _buildingPhotoPath;
  
  // GPS Location
  double? _latitude;
  double? _longitude;
  final _distanceController = TextEditingController();
  bool _isGettingLocation = false;
  
  // General Observations (Step 2)
  final _ageController = TextEditingController();
  String? _typeOfStructure;
  final List<String> _structureTypes = ['House', 'Office/Shop', 'Office Building', 'Others (Please specify)', 'Permanent', 'Semi-permanent', 'Temporary'];
  String? _presentCondition;
  
  // External Services
  bool _hasPipeBorneWater = false;
  String? _waterSource;
  bool _hasElectricity = false;
  String? _electricitySource;
  bool _hasSewageWaste = false;
  String? _sewageType;
  
  // Ancillary Buildings/Structures (Step 2)
  final Map<String, Map<String, bool>> _ancillaryStructures = {
    'Boundary walls': {'Brick': false, 'Block wall': false, 'Parapet': false, 'Not Painted': false},
    'Others': {'Wall cracks': false, 'External Toilets': false, 'Water Tanks': false},
  };
  
  // Building Profile (Step 3)
  final _numberOfFloorsController = TextEditingController(); // G+2
  
  final Map<String, Map<String, bool>> _buildingElements = {
    'Walls': {
      'Brick (9" thick wall)': false,
      'Brick (4.5" thick wall)': false,
      'Cement Block work': false,
      'Other': false,
    },
    'Doors': {
      'Solid Timber': false,
      'Other Timber': false,
      'Glazed Aluminium': false,
      'RCC Concrete': false,
    },
    'Floors': {
      'Brick Paved': false,
      'Timber': false,
      'Cement Rendered Floor': false,
      'Floor Tiles': false,
      'Smooth Plastered': false,
      'Rough Plastered': false,
    },
    'Finishes': {
      'Internal Walls - Smooth Plastered': false,
      'Internal Walls - Rough Plastered': false,
      'Internal Walls - Painted': false,
      'External walls - Smooth Plastered': false,
      'External walls - Rough Plastered': false,
      'External walls - Painted': false,
    },
    'Roof': {
      'Single Pitched': false,
      'Gable': false,
      'Hipped': false,
      'Other': false,
    },
  };
  
  String? _roofCovering; // Clay Tiles, Asbestos, Covering Metal, Zinc/Al
  
  // Defects (Step 4)
  final List<Defect> _capturedDefects = [];
  
  // Inspection ID
  late String _inspectionId;
  final DraftStorageService _draftService = DraftStorageService();
  String? _currentDraftId;

  @override
  void initState() {
    super.initState();
    if (widget.draftId != null && widget.draftData != null) {
      // Restoring from draft
      _currentDraftId = widget.draftId;
      _restoreFromDraft(widget.draftData!);
    } else {
      // New inspection
      _inspectionId = 'H-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      _buildingRefController.text = _inspectionId;
      _currentDraftId = const Uuid().v4();
    }
  }

  Future<void> _takeBuildingPhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    
    if (photo != null) {
      setState(() {
        _buildingPhotoPath = photo.path;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Building photo captured')),
        );
      }
    }
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location obtained successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  void _removeDefect(int index) {
    setState(() {
      _capturedDefects.removeAt(index);
    });
  }

  Future<void> _completeInspection() async {
    if (_ownerNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter owner name')),
      );
      setState(() => _currentStep = 0);
      return;
    }

    if (_addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter site address')),
      );
      setState(() => _currentStep = 0);
      return;
    }

    // Update all defects with the inspection ID
    final inspectionId = _buildingRefController.text;
    final defectsWithInspectionId = _capturedDefects.map((defect) {
      return Defect(
        id: defect.id,
        inspectionId: inspectionId,
        notation: defect.notation,
        category: defect.category,
        floorLevel: defect.floorLevel,
        lengthMm: defect.lengthMm,
        widthMm: defect.widthMm,
        photoPath: defect.photoPath,
        remarks: defect.remarks,
        createdAt: defect.createdAt,
      );
    }).toList();

    final inspection = Inspection(
      id: inspectionId,
      ownerName: _ownerNameController.text,
      siteAddress: _addressController.text,
      contactNo: _contactController.text.isEmpty ? null : _contactController.text,
      latitude: _latitude,
      longitude: _longitude,
      distanceFromRow: _distanceController.text.isEmpty ? null : double.tryParse(_distanceController.text),
      ageOfStructure: _ageController.text.isEmpty ? null : int.tryParse(_ageController.text),
      typeOfStructure: _typeOfStructure,
      presentCondition: _presentCondition,
      hasPipeBorneWater: _hasPipeBorneWater,
      waterSource: _waterSource,
      hasElectricity: _hasElectricity,
      electricitySource: _electricitySource,
      hasSewageWaste: _hasSewageWaste,
      sewageType: _sewageType,
      numberOfFloors: _numberOfFloorsController.text.isEmpty ? null : _numberOfFloorsController.text,
      wallMaterials: _buildingElements['Walls'],
      doorMaterials: _buildingElements['Doors'],
      floorMaterials: _buildingElements['Floors'],
      roofMaterials: _buildingElements['Roof'],
      roofCovering: _roofCovering,
      defects: defectsWithInspectionId,
      syncStatus: SyncStatus.synced,
      createdAt: DateTime.now(),
    );

    context.read<InspectionBloc>().add(CreateInspectionEvent(
          inspection: inspection,
          buildingPhotoPath: _buildingPhotoPath,
        ));

    // Delete the draft after completing inspection
    if (_currentDraftId != null) {
      await _draftService.deleteDraft(_currentDraftId!);
    }

    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Inspection saved successfully')),
    );

    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _buildingRefController.dispose();
    _ownerNameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _distanceController.dispose();
    _ageController.dispose();
    _numberOfFloorsController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentStep() {
    // Use a small delay to ensure the step content is rendered before scrolling
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _saveDraft() async {
    final draftData = {
      'building_ref': _buildingRefController.text,
      'owner_name': _ownerNameController.text,
      'address': _addressController.text,
      'contact': _contactController.text,
      'building_photo_path': _buildingPhotoPath,
      'latitude': _latitude,
      'longitude': _longitude,
      'distance': _distanceController.text,
      'age': _ageController.text,
      'type_of_structure': _typeOfStructure,
      'present_condition': _presentCondition,
      'has_pipe_borne_water': _hasPipeBorneWater,
      'water_source': _waterSource,
      'has_electricity': _hasElectricity,
      'electricity_source': _electricitySource,
      'has_sewage_waste': _hasSewageWaste,
      'sewage_type': _sewageType,
      'ancillary_structures': _ancillaryStructures,
      'number_of_floors': _numberOfFloorsController.text,
      'building_elements': _buildingElements,
      'roof_covering': _roofCovering,
      'defects': _capturedDefects.map((d) => d.toJson()).toList(),
      'current_step': _currentStep,
      'inspection_id': _inspectionId,
    };
    
    await _draftService.saveDraft(draftId: _currentDraftId!, draftData: draftData);
  }

  void _restoreFromDraft(Map<String, dynamic> data) {
    _inspectionId = data['inspection_id'] ?? 'H-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    _buildingRefController.text = data['building_ref'] ?? _inspectionId;
    _ownerNameController.text = data['owner_name'] ?? '';
    _addressController.text = data['address'] ?? '';
    _contactController.text = data['contact'] ?? '';
    _buildingPhotoPath = data['building_photo_path'];
    _latitude = data['latitude'];
    _longitude = data['longitude'];
    _distanceController.text = data['distance'] ?? '';
    _ageController.text = data['age'] ?? '';
    _typeOfStructure = data['type_of_structure'];
    _presentCondition = data['present_condition'];
    _hasPipeBorneWater = data['has_pipe_borne_water'] ?? false;
    _waterSource = data['water_source'];
    _hasElectricity = data['has_electricity'] ?? false;
    _electricitySource = data['electricity_source'];
    _hasSewageWaste = data['has_sewage_waste'] ?? false;
    _sewageType = data['sewage_type'];
    
    if (data['ancillary_structures'] != null) {
      final saved = Map<String, dynamic>.from(data['ancillary_structures']);
      saved.forEach((key, value) {
        if (_ancillaryStructures.containsKey(key)) {
          _ancillaryStructures[key] = Map<String, bool>.from(value);
        }
      });
    }
    
    _numberOfFloorsController.text = data['number_of_floors'] ?? '';
    
    if (data['building_elements'] != null) {
      final saved = Map<String, dynamic>.from(data['building_elements']);
      saved.forEach((key, value) {
        if (_buildingElements.containsKey(key)) {
          _buildingElements[key] = Map<String, bool>.from(value);
        }
      });
    }
    
    _roofCovering = data['roof_covering'];
    
    if (data['defects'] != null) {
      _capturedDefects.clear();
      for (final defectJson in (data['defects'] as List)) {
        _capturedDefects.add(Defect.fromJson(defectJson));
      }
    }
    
    _currentStep = data['current_step'] ?? 0;
  }

  Future<bool> _handleBackPress() async {
    // Check if there's any data entered
    final hasData = _buildingRefController.text.isNotEmpty ||
                    _ownerNameController.text.isNotEmpty ||
                    _addressController.text.isNotEmpty ||
                    _capturedDefects.isNotEmpty;
    
    if (!hasData) {
      return true; // Allow navigation without dialog
    }
    
    // Show save draft dialog
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.save_outlined, color: NBROColors.primary),
            const SizedBox(width: 12),
            const Text('Save as Draft?'),
          ],
        ),
        content: const Text(
          'Do you want to save this inspection as a draft? You can continue editing it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text(
              'Discard',
              style: TextStyle(color: NBROColors.error),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, 'save'),
            icon: const Icon(Icons.save),
            label: const Text('Save Draft'),
            style: ElevatedButton.styleFrom(
              backgroundColor: NBROColors.primary,
            ),
          ),
        ],
      ),
    );
    
    if (result == 'save') {
      await _saveDraft();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: NBROColors.white),
                SizedBox(width: 12),
                Text('Draft saved successfully'),
              ],
            ),
            backgroundColor: NBROColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    } else if (result == 'discard') {
      // Delete draft if exists
      if (_currentDraftId != null) {
        await _draftService.deleteDraft(_currentDraftId!);
      }
      return true;
    }
    
    return false; // Cancel navigation
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBackPress,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pre-Crack Survey Report'),
          elevation: 0,
        ),
        body: SingleChildScrollView(
          controller: _scrollController,
          child: Stepper(
        physics: const NeverScrollableScrollPhysics(),
        currentStep: _currentStep,
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  child: Text(_currentStep == 4 ? 'Complete' : 'Continue'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: details.onStepCancel,
                  child: Text(_currentStep == 0 ? 'Cancel' : 'Back'),
                ),
              ],
            ),
          );
        },
        onStepTapped: (step) {
          setState(() {
            _currentStep = step;
          });
          _scrollToCurrentStep();
        },
        onStepContinue: () {
          if (_currentStep < 4) {
            setState(() => _currentStep += 1);
            _scrollToCurrentStep();
          } else {
            _completeInspection();
          }
        },
        onStepCancel: () async {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          } else {
            final navigator = Navigator.of(context);
            final shouldPop = await _handleBackPress();
            if (shouldPop && mounted) {
              navigator.pop();
            }
          }
        },
        steps: [
          _buildSiteDataStep(),
          _buildGeneralObservationsStep(),
          _buildBuildingProfileStep(),
          _buildDefectCaptureStep(),
          _buildReviewStep(),
        ],
        ),
        ),
      ),
    );
  }

  // Step 1: Site Data Sheet
  Step _buildSiteDataStep() {
    return Step(
      title: const Text('Site Data Sheet'),
      subtitle: const Text('Building & Owner Info'),
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Building Reference Photo
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Front View of the Building',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_buildingPhotoPath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_buildingPhotoPath!),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.add_a_photo, size: 48, color: Colors.grey),
                      ),
                    ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _takeBuildingPhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(_buildingPhotoPath == null ? 'Take Photo' : 'Retake Photo'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Building Reference No
          TextField(
            controller: _buildingRefController,
            decoration: const InputDecoration(
              labelText: 'Building Ref. No *',
              hintText: 'e.g., H-01',
              prefixIcon: Icon(Icons.tag),
            ),
          ),
          const SizedBox(height: 16),
          
          // Name of Owner
          TextField(
            controller: _ownerNameController,
            decoration: const InputDecoration(
              labelText: 'Name of the Owner *',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
          
          // Address of Premises
          TextField(
            controller: _addressController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Address of Premises *',
              prefixIcon: Icon(Icons.location_on),
            ),
          ),
          const SizedBox(height: 16),
          
          // Contact No
          TextField(
            controller: _contactController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Contact No.',
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 24),
          
          // GPS Location
          Text(
            'Location of Premises',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_latitude != null && _longitude != null)
            Card(
              color: NBROColors.success.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: NBROColors.success),
                        const SizedBox(width: 8),
                        Text(
                          'GPS Coordinates',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: NBROColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Latitude: ${_latitude!.toStringAsFixed(6)}°'),
                    Text('Longitude: ${_longitude!.toStringAsFixed(6)}°'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _getCurrentLocation,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Update Location'),
                    ),
                  ],
                ),
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
                  : const Icon(Icons.my_location),
              label: const Text('Get GPS Coordinates'),
            ),
          const SizedBox(height: 16),
          
          // Distance from Row
          TextField(
            controller: _distanceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Distance from Row (meters)',
              prefixIcon: Icon(Icons.straighten),
            ),
          ),
        ],
      ),
    );
  }

  // Step 2: General Observations & Services
  Step _buildGeneralObservationsStep() {
    return Step(
      title: const Text('General Observations'),
      subtitle: const Text('Structure Info & Services'),
      isActive: _currentStep >= 1,
      state: _currentStep > 1 ? StepState.complete : (_currentStep == 1 ? StepState.editing : StepState.indexed),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. General Observations',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Age of Structure
          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Approx. Age of existing structures (years)',
              prefixIcon: Icon(Icons.calendar_today),
              hintText: '15-20 years',
            ),
          ),
          const SizedBox(height: 16),
          
          // Type of Structure
          DropdownButtonFormField<String>(
            initialValue: _typeOfStructure,
            decoration: const InputDecoration(
              labelText: 'Type of existing structures',
              prefixIcon: Icon(Icons.home_work),
            ),
            items: _structureTypes.map((type) {
              return DropdownMenuItem(value: type, child: Text(type));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _typeOfStructure = value;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Present Condition
          Text(
            'Present condition of structures',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          RadioGroup<String?>(
            groupValue: _presentCondition,
            onChanged: (value) {
              setState(() {
                _presentCondition = value;
              });
            },
            child: Column(
              children: [
                RadioListTile<String?>(
                  title: const Text('Permanent'),
                  value: 'Permanent',
                ),
                RadioListTile<String?>(
                  title: const Text('Semi-permanent / Temporary'),
                  value: 'Semi-permanent / Temporary',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // External Services
          Text(
            '2. External Services',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Pipe-borne water supply
          SwitchListTile(
            title: const Text('Pipe-borne water supply'),
            value: _hasPipeBorneWater,
            onChanged: (value) {
              setState(() {
                _hasPipeBorneWater = value;
              });
            },
          ),
          if (_hasPipeBorneWater) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: RadioGroup<String?>(
                groupValue: _waterSource,
                onChanged: (value) {
                  setState(() {
                    _waterSource = value;
                  });
                },
                child: Column(
                  children: [
                    RadioListTile<String?>(
                      title: const Text('From Well'),
                      value: 'From Well',
                    ),
                    RadioListTile<String?>(
                      title: const Text('From main supply'),
                      value: 'From main supply',
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          // Electricity
          SwitchListTile(
            title: const Text('Electricity Main Supply'),
            value: _hasElectricity,
            onChanged: (value) {
              setState(() {
                _hasElectricity = value;
              });
            },
          ),
          if (_hasElectricity) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: RadioGroup<String?>(
                groupValue: _electricitySource,
                onChanged: (value) {
                  setState(() {
                    _electricitySource = value;
                  });
                },
                child: Column(
                  children: [
                    RadioListTile<String?>(
                      title: const Text('From Private Solar supply'),
                      value: 'From Private Solar supply',
                    ),
                    RadioListTile<String?>(
                      title: const Text('From Main supply'),
                      value: 'From Main supply',
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          // Sewage & Waste Water Disposal
          SwitchListTile(
            title: const Text('Sewage & Waste Water Disposal'),
            value: _hasSewageWaste,
            onChanged: (value) {
              setState(() {
                _hasSewageWaste = value;
              });
            },
          ),
          if (_hasSewageWaste) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: RadioGroup<String?>(
                groupValue: _sewageType,
                onChanged: (value) {
                  setState(() {
                    _sewageType = value;
                  });
                },
                child: Column(
                  children: [
                    RadioListTile<String?>(
                      title: const Text('Private Septic tank & Soakage pits'),
                      value: 'Private Septic tank & Soakage pits',
                    ),
                    RadioListTile<String?>(
                      title: const Text('Connected to Sewer Main'),
                      value: 'Connected to Sewer Main',
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          
          // Ancillary Buildings/Structures
          Text(
            '3. Details of Ancillary Buildings/Structures',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ..._ancillaryStructures.entries.map((category) {
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.key,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...category.value.entries.map((item) {
                      return CheckboxListTile(
                        title: Text(item.key),
                        value: item.value,
                        onChanged: (value) {
                          setState(() {
                            _ancillaryStructures[category.key]![item.key] = value ?? false;
                          });
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // Step 3: Building Profile (Details of Main Building Elements)
  Step _buildBuildingProfileStep() {
    return Step(
      title: const Text('Building Profile'),
      subtitle: const Text('Main Building Elements'),
      isActive: _currentStep >= 2,
      state: _currentStep > 2 ? StepState.complete : (_currentStep == 2 ? StepState.editing : StepState.indexed),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '4. Details of Main Building Elements',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Number of Floors
          TextField(
            controller: _numberOfFloorsController,
            decoration: const InputDecoration(
              labelText: 'No. of Floors (e.g., G+2)',
              hintText: 'G+2',
              prefixIcon: Icon(Icons.layers),
              helperText: 'G = Ground Floor, +2 = Two additional floors',
            ),
          ),
          const SizedBox(height: 24),
          
          // Building Elements
          ..._buildingElements.entries.map((category) {
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getIconForCategory(category.key),
                          color: NBROColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          category.key,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: NBROColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    ...category.value.entries.map((item) {
                      return CheckboxListTile(
                        title: Text(item.key),
                        value: item.value,
                        onChanged: (value) {
                          setState(() {
                            _buildingElements[category.key]![item.key] = value ?? false;
                          });
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
          
          // Roof Covering
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.roofing, color: NBROColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Roof Covering',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: NBROColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  DropdownButtonFormField<String>(
                    initialValue: _roofCovering,
                    decoration: const InputDecoration(
                      labelText: 'Select Covering Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Clay Tiles', child: Text('Clay Tiles')),
                      DropdownMenuItem(value: 'Asbestos', child: Text('Asbestos')),
                      DropdownMenuItem(value: 'Covering Metal', child: Text('Covering Metal')),
                      DropdownMenuItem(value: 'Zinc/Al', child: Text('Zinc/Al')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _roofCovering = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Step 4: Defect Capture
  Step _buildDefectCaptureStep() {
    return Step(
      title: const Text('Defect Capture'),
      subtitle: Text('${_capturedDefects.length} defects captured'),
      isActive: _currentStep >= 3,
      state: _currentStep > 3 ? StepState.complete : (_currentStep == 3 ? StepState.editing : StepState.indexed),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '5. Details/Photographs of Defects',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Capture defects using standardized NBRO notation system',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          
          // Defect Capture Card
          DefectCaptureCard(
            onDefectCapture: (defect) {
              setState(() {
                _capturedDefects.add(defect);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Defect captured successfully!')),
              );
            },
          ),
          const SizedBox(height: 24),
          
          // Captured Defects List
          if (_capturedDefects.isNotEmpty) ...[
            Text(
              'Captured Defects (${_capturedDefects.length})',
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
                final defect = _capturedDefects[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: NBROColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: defect.photoPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(defect.photoPath!),
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Icon(Icons.image, color: NBROColors.primary),
                    ),
                    title: Text(
                      defect.notation.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${defect.lengthMm}mm × ${defect.widthMm ?? '-'}mm'),
                        if (defect.floorLevel != null)
                          Text('Floor: ${defect.floorLevel}'),
                        if (defect.remarks != null)
                          Text(
                            defect.remarks!,
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: NBROColors.error),
                      onPressed: () => _removeDefect(index),
                    ),
                  ),
                );
              },
            ),
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No defects captured yet',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Step 5: Review & Complete
  Step _buildReviewStep() {
    return Step(
      title: const Text('Review & Complete'),
      subtitle: const Text('Verify all information'),
      isActive: _currentStep >= 4,
      state: _currentStep == 4 ? StepState.editing : StepState.indexed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReviewSection('Site Information', [
            _buildReviewItem('Building Ref.', _buildingRefController.text),
            _buildReviewItem('Owner Name', _ownerNameController.text),
            _buildReviewItem('Address', _addressController.text),
            if (_contactController.text.isNotEmpty)
              _buildReviewItem('Contact', _contactController.text),
            if (_latitude != null && _longitude != null)
              _buildReviewItem('GPS', '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}'),
          ]),
          
          _buildReviewSection('General Observations', [
            if (_ageController.text.isNotEmpty)
              _buildReviewItem('Age', '${_ageController.text} years'),
            if (_typeOfStructure != null)
              _buildReviewItem('Type', _typeOfStructure!),
            if (_presentCondition != null)
              _buildReviewItem('Condition', _presentCondition!),
          ]),
          
          _buildReviewSection('Building Profile', [
            if (_numberOfFloorsController.text.isNotEmpty)
              _buildReviewItem('Floors', _numberOfFloorsController.text),
            ..._buildingElements.entries.map((category) {
              final selected = category.value.entries
                  .where((e) => e.value)
                  .map((e) => e.key)
                  .toList();
              if (selected.isNotEmpty) {
                return _buildReviewItem(category.key, selected.join(', '));
              }
              return const SizedBox.shrink();
            }),
          ]),
          
          _buildReviewSection('Defects', [
            _buildReviewItem('Total Defects', '${_capturedDefects.length}'),
          ]),
          
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NBROColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: NBROColors.warning),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: NBROColors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Please review all information carefully before completing the survey.',
                    style: TextStyle(color: Colors.grey[800]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection(String title, List<Widget> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: NBROColors.primary,
              ),
            ),
            const Divider(),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Walls':
        return Icons.view_column;
      case 'Doors':
        return Icons.door_front_door;
      case 'Floors':
        return Icons.layers;
      case 'Finishes':
        return Icons.format_paint;
      case 'Roof':
        return Icons.roofing;
      default:
        return Icons.home;
    }
  }
}
