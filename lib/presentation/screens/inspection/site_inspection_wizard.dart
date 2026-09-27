import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:nbro_mobile_application/core/theme/app_theme.dart';
import 'package:nbro_mobile_application/domain/models/inspection.dart';
import 'package:nbro_mobile_application/presentation/state/inspection_bloc.dart';
import 'package:nbro_mobile_application/presentation/widgets/defect_capture_card.dart';
import 'package:nbro_mobile_application/data/services/draft_storage_service.dart';
import 'package:nbro_mobile_application/data/repositories/inspection_repository.dart';
import 'package:nbro_mobile_application/core/network/connectivity_service.dart';
import 'package:uuid/uuid.dart';

/// Professional Slide-by-Slide Pre-Crack Survey Wizard (Site Inspection)
class SiteInspectionWizard extends StatefulWidget {
  final String? draftId;
  final Map<String, dynamic>? draftData;
  
  const SiteInspectionWizard({super.key, this.draftId, this.draftData});

  @override
  State<SiteInspectionWizard> createState() => _SiteInspectionWizardState();
}

class _SiteInspectionWizardState extends State<SiteInspectionWizard>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late TabController _tabController;
  int _currentStep = 0;
  
  // Step 1: Site Data
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
  
  // Step 2: Observations & Utilities
  final _ageController = TextEditingController();
  String? _typeOfStructure;
  final List<String> _structureTypes = [
    'House',
    'Office/Shop',
    'Office Building',
    'Others (Please specify)',
    'Permanent',
    'Semi-permanent',
    'Temporary'
  ];
  String? _presentCondition;
  
  // External Services
  bool _hasPipeBorneWater = false;
  String? _waterSource;
  bool _hasElectricity = false;
  String? _electricitySource;
  bool _hasSewageWaste = false;
  String? _sewageType;
  
  // Ancillary Structures
  final Map<String, Map<String, bool>> _ancillaryStructures = {
    'Boundary walls': {'Brick': false, 'Block wall': false, 'Parapet': false, 'Not Painted': false},
    'Others': {'Wall cracks': false, 'External Toilets': false, 'Water Tanks': false},
  };
  
  // Step 3: Building Profile
  final _numberOfFloorsController = TextEditingController();
  
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
  
  String? _roofCovering;
  
  // Step 4: Defects
  final List<Defect> _capturedDefects = [];
  
  // Draft Storage
  late String _inspectionId;
  final DraftStorageService _draftService = DraftStorageService();
  String? _currentDraftId;

  final List<String> _stepTitles = [
    'Site Data',
    'Observations',
    'Building Profile',
    'Defects',
    'Review',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _tabController = TabController(length: 5, vsync: this);

    if (widget.draftId != null && widget.draftData != null) {
      _currentDraftId = widget.draftId;
      _restoreFromDraft(widget.draftData!);
    } else {
      _inspectionId = 'H-';
      _buildingRefController.text = _inspectionId;
      _currentDraftId = const Uuid().v4();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tabController.dispose();
    _buildingRefController.dispose();
    _ownerNameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _distanceController.dispose();
    _ageController.dispose();
    _numberOfFloorsController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    if (step < 0 || step > 4) return;
    setState(() {
      _currentStep = step;
      _tabController.animateTo(step);
    });
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
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
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable GPS location services on your device')),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission permanently denied in settings')),
          );
        }
        return;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 12),
        );
      } catch (e) {
        debugPrint('[Wizard] getCurrentPosition failed ($e), trying last known...');
        position = await Geolocator.getLastKnownPosition();
      }

      if (position != null) {
        final pos = position;
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Location obtained successfully'),
              backgroundColor: NBROColors.success,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to obtain GPS fix')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  void _removeDefect(int index) {
    setState(() {
      _capturedDefects.removeAt(index);
    });
  }

  Future<void> _completeInspection() async {
    final ownerName = _ownerNameController.text.trim();
    final address = _addressController.text.trim();

    if (ownerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter owner name'),
          backgroundColor: NBROColors.warning,
        ),
      );
      _goToStep(0);
      return;
    }

    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter site address'),
          backgroundColor: NBROColors.warning,
        ),
      );
      _goToStep(0);
      return;
    }

    final inspectionId = _buildingRefController.text.trim();
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
      ownerName: ownerName,
      siteAddress: address,
      contactNo: _contactController.text.trim().isEmpty ? null : _contactController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      distanceFromRow: _distanceController.text.trim().isEmpty ? null : double.tryParse(_distanceController.text.trim()),
      ageOfStructure: _ageController.text.trim().isEmpty ? null : int.tryParse(_ageController.text.trim()),
      typeOfStructure: _typeOfStructure,
      presentCondition: _presentCondition,
      hasPipeBorneWater: _hasPipeBorneWater,
      waterSource: _waterSource,
      hasElectricity: _hasElectricity,
      electricitySource: _electricitySource,
      hasSewageWaste: _hasSewageWaste,
      sewageType: _sewageType,
      numberOfFloors: _numberOfFloorsController.text.trim().isEmpty ? null : _numberOfFloorsController.text.trim(),
      wallMaterials: _buildingElements['Walls'],
      doorMaterials: _buildingElements['Doors'],
      floorMaterials: _buildingElements['Floors'],
      roofMaterials: _buildingElements['Roof'],
      roofCovering: _roofCovering,
      defects: defectsWithInspectionId,
      syncStatus: SyncStatus.synced,
      createdAt: DateTime.now(),
    );

    final messenger = ScaffoldMessenger.of(context);
    final bloc = context.read<InspectionBloc>();
    final isOnline = await ConnectivityService.instance.checkActualConnectivity();
    if (!mounted) return;

    // Show professional uploading loading dialog
    BuildContext? loadingCtx;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        loadingCtx = ctx;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(NBROColors.primary),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 20),
                Text(
                  isOnline ? 'Uploading Inspection Data...' : 'Saving Inspection Offline...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: NBROColors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isOnline
                      ? 'Saving site details, photos & specifications to database'
                      : 'Saving report to local storage. Will sync when online.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: NBROColors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final repository = InspectionRepository();
      await repository.createInspection(
        inspection,
        buildingPhotoPath: _buildingPhotoPath,
      );

      // Clean up draft if exists
      if (_currentDraftId != null) {
        await _draftService.deleteDraft(_currentDraftId!);
      }

      // Refresh BLoC state
      bloc.add(const LoadInspectionsEvent());

      // Dismiss loading dialog
      if (loadingCtx != null && loadingCtx!.mounted) {
        Navigator.pop(loadingCtx!);
      }

      if (!mounted) return;

      // Show success modal with green checkmark
      await _showSuccessModal(context, inspectionId, ownerName);
    } catch (e) {
      // Dismiss loading dialog
      if (loadingCtx != null && loadingCtx!.mounted) {
        Navigator.pop(loadingCtx!);
      }

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to complete inspection: $e'),
          backgroundColor: NBROColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _showSuccessModal(
    BuildContext context,
    String refNo,
    String ownerName,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NBROColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: NBROColors.success,
                  size: 56,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Uploaded Successfully!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: NBROColors.black,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'The inspection survey report has been saved to the database.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: NBROColors.grey),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Building Ref:', style: TextStyle(fontSize: 12, color: NBROColors.grey)),
                        Text(refNo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: NBROColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Owner:', style: TextStyle(fontSize: 12, color: NBROColors.grey)),
                        Text(ownerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: NBROColors.black)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop(); // Close modal
                    Navigator.of(context).pop(); // Exit wizard back to Dashboard
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NBROColors.primary,
                    foregroundColor: NBROColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveDraft() async {
    final draftData = {
      'draft_id': _currentDraftId ?? const Uuid().v4(),
      'saved_at': DateTime.now().toIso8601String(),
      'current_step': _currentStep,
      'building_ref': _buildingRefController.text,
      'owner_name': _ownerNameController.text,
      'address': _addressController.text,
      'contact': _contactController.text,
      'latitude': _latitude,
      'longitude': _longitude,
      'distance_from_row': _distanceController.text,
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
      'building_photo_path': _buildingPhotoPath,
    };

    await _draftService.saveDraft(draftId: _currentDraftId!, draftData: draftData);
  }

  void _restoreFromDraft(Map<String, dynamic> data) {
    _buildingRefController.text = data['building_ref'] ?? '';
    _ownerNameController.text = data['owner_name'] ?? '';
    _addressController.text = data['address'] ?? '';
    _contactController.text = data['contact'] ?? '';
    _latitude = data['latitude'];
    _longitude = data['longitude'];
    _distanceController.text = data['distance_from_row'] ?? '';
    _ageController.text = data['age'] ?? '';
    _typeOfStructure = data['type_of_structure'];
    _presentCondition = data['present_condition'];
    _hasPipeBorneWater = data['has_pipe_borne_water'] ?? false;
    _waterSource = data['water_source'];
    _hasElectricity = data['has_electricity'] ?? false;
    _electricitySource = data['electricity_source'];
    _hasSewageWaste = data['has_sewage_waste'] ?? false;
    _sewageType = data['sewage_type'];
    _buildingPhotoPath = data['building_photo_path'];
    
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
    final hasData = _buildingRefController.text.isNotEmpty ||
                    _ownerNameController.text.isNotEmpty ||
                    _addressController.text.isNotEmpty ||
                    _capturedDefects.isNotEmpty;
    
    if (!hasData) return true;
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.save_outlined, color: NBROColors.primary),
            SizedBox(width: 12),
            Text('Save Draft?'),
          ],
        ),
        content: const Text(
          'Do you want to save this inspection as a draft to continue later?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard', style: TextStyle(color: NBROColors.error)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, 'save'),
            icon: const Icon(Icons.save),
            label: const Text('Save Draft'),
            style: ElevatedButton.styleFrom(backgroundColor: NBROColors.primary),
          ),
        ],
      ),
    );
    
    if (result == 'save') {
      await _saveDraft();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft saved successfully'),
            backgroundColor: NBROColors.success,
          ),
        );
      }
      return true;
    } else if (result == 'discard') {
      if (_currentDraftId != null) {
        await _draftService.deleteDraft(_currentDraftId!);
      }
      return true;
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBackPress,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          toolbarHeight: 65,
          backgroundColor: NBROColors.primary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: NBROColors.white),
            onPressed: () async {
              final pop = await _handleBackPress();
              if (pop && context.mounted) Navigator.of(context).pop();
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pre-Crack Survey Report',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: NBROColors.white,
                ),
              ),
              Text(
                'Step ${_currentStep + 1} of 5: ${_stepTitles[_currentStep]}',
                style: TextStyle(
                  fontSize: 12,
                  color: NBROColors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.save_outlined, color: NBROColors.white),
              tooltip: 'Save Draft',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await _saveDraft();
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('✓ Draft saved successfully'),
                    backgroundColor: NBROColors.success,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              color: NBROColors.white,
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: NBROColors.primary,
                indicatorWeight: 3,
                labelColor: NBROColors.primary,
                unselectedLabelColor: NBROColors.grey,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
                onTap: (index) {
                  _goToStep(index);
                },
                tabs: const [
                  Tab(text: '1. Site Data'),
                  Tab(text: '2. Observations'),
                  Tab(text: '3. Profile'),
                  Tab(text: '4. Defects'),
                  Tab(text: '5. Review'),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // Linear Progress Line
            LinearProgressIndicator(
              value: (_currentStep + 1) / 5,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(NBROColors.primary),
              minHeight: 3,
            ),

            // Slide PageView
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentStep = page;
                    _tabController.animateTo(page);
                  });
                },
                children: [
                  _buildPageWrapper(_buildSiteDataPage()),
                  _buildPageWrapper(_buildGeneralObservationsPage()),
                  _buildPageWrapper(_buildBuildingProfilePage()),
                  _buildPageWrapper(_buildDefectCapturePage()),
                  _buildPageWrapper(_buildReviewPage()),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: NBROColors.white,
            boxShadow: [
              BoxShadow(
                color: NBROColors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _goToStep(_currentStep - 1),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final pop = await _handleBackPress();
                        if (pop && context.mounted) Navigator.pop(context);
                      },
                      child: const Text('Cancel', style: TextStyle(color: NBROColors.grey)),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_currentStep < 4) {
                        _goToStep(_currentStep + 1);
                      } else {
                        _completeInspection();
                      }
                    },
                    icon: Icon(_currentStep == 4 ? Icons.check_circle : Icons.arrow_forward),
                    label: Text(_currentStep == 4 ? 'Complete Inspection' : 'Next Step'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NBROColors.primary,
                      foregroundColor: NBROColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageWrapper(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  // ─── STEP 1: SITE DATA SHEET ──────────────────────────────────────────────
  Widget _buildSiteDataPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FormCard(
          title: 'Building Front View Photo',
          icon: Icons.camera_alt_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_buildingPhotoPath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(_buildingPhotoPath!),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, size: 40, color: NBROColors.grey),
                        SizedBox(height: 8),
                        Text('No photo captured', style: TextStyle(color: NBROColors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _takeBuildingPhoto,
                icon: const Icon(Icons.camera_alt),
                label: Text(_buildingPhotoPath == null ? 'Capture Photo' : 'Retake Photo'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _FormCard(
          title: 'General Premises Information',
          icon: Icons.business_outlined,
          child: Column(
            children: [
              TextField(
                controller: _buildingRefController,
                decoration: const InputDecoration(
                  labelText: 'Building Ref. No *',
                  hintText: 'e.g., H-01',
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _ownerNameController,
                decoration: const InputDecoration(
                  labelText: 'Name of the Owner *',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Address of Premises *',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _contactController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Contact Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _FormCard(
          title: 'GPS Coordinates & ROW',
          icon: Icons.my_location,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_latitude != null && _longitude != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: NBROColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: NBROColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: NBROColors.success, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'GPS: ${_latitude!.toStringAsFixed(6)}°, ${_longitude!.toStringAsFixed(6)}°',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: NBROColors.success, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18, color: NBROColors.success),
                        onPressed: _getCurrentLocation,
                      ),
                    ],
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: _isGettingLocation ? null : _getCurrentLocation,
                  icon: _isGettingLocation
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location),
                  label: const Text('Get Live GPS Coordinates'),
                ),
              const SizedBox(height: 14),
              TextField(
                controller: _distanceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Distance from Right-of-Way (m)',
                  prefixIcon: Icon(Icons.straighten),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── STEP 2: GENERAL OBSERVATIONS & SERVICES ─────────────────────────────
  Widget _buildGeneralObservationsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormCard(
          title: 'General Observations',
          icon: Icons.fact_check_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Approx. Age of Structure (years)',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _typeOfStructure,
                decoration: const InputDecoration(
                  labelText: 'Type of Existing Structure',
                  prefixIcon: Icon(Icons.apartment),
                  border: OutlineInputBorder(),
                ),
                items: _structureTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (val) => setState(() => _typeOfStructure = val),
              ),
              const SizedBox(height: 14),
              const Text('Present Condition', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: NBROColors.grey)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _presentCondition,
                decoration: const InputDecoration(
                  labelText: 'Select Condition',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Permanent', child: Text('Permanent')),
                  DropdownMenuItem(value: 'Semi-permanent / Temporary', child: Text('Semi-permanent / Temporary')),
                ],
                onChanged: (val) => setState(() => _presentCondition = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _FormCard(
          title: 'External Utility Services',
          icon: Icons.electrical_services_outlined,
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Pipe-borne water supply', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                value: _hasPipeBorneWater,
                onChanged: (val) => setState(() => _hasPipeBorneWater = val),
              ),
              if (_hasPipeBorneWater)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: DropdownButtonFormField<String>(
                    value: _waterSource,
                    decoration: const InputDecoration(labelText: 'Water Source', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'From Well', child: Text('From Well')),
                      DropdownMenuItem(value: 'From main supply', child: Text('From main supply')),
                    ],
                    onChanged: (val) => setState(() => _waterSource = val),
                  ),
                ),
              const Divider(),
              SwitchListTile(
                title: const Text('Electricity Main Supply', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                value: _hasElectricity,
                onChanged: (val) => setState(() => _hasElectricity = val),
              ),
              if (_hasElectricity)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: DropdownButtonFormField<String>(
                    value: _electricitySource,
                    decoration: const InputDecoration(labelText: 'Electricity Source', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'From Private Solar supply', child: Text('From Private Solar supply')),
                      DropdownMenuItem(value: 'From Main supply', child: Text('From Main supply')),
                    ],
                    onChanged: (val) => setState(() => _electricitySource = val),
                  ),
                ),
              const Divider(),
              SwitchListTile(
                title: const Text('Sewage & Waste Water Disposal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                value: _hasSewageWaste,
                onChanged: (val) => setState(() => _hasSewageWaste = val),
              ),
              if (_hasSewageWaste)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: DropdownButtonFormField<String>(
                    value: _sewageType,
                    decoration: const InputDecoration(labelText: 'Sewage Disposal Type', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'Private Septic tank & Soakage pits', child: Text('Private Septic tank & Soakage pits')),
                      DropdownMenuItem(value: 'Connected to Sewer Main', child: Text('Connected to Sewer Main')),
                    ],
                    onChanged: (val) => setState(() => _sewageType = val),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── STEP 3: BUILDING PROFILE ─────────────────────────────────────────────
  Widget _buildBuildingProfilePage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormCard(
          title: 'Floors & Roof Structure',
          icon: Icons.layers_outlined,
          child: Column(
            children: [
              TextField(
                controller: _numberOfFloorsController,
                decoration: const InputDecoration(
                  labelText: 'No. of Floors (e.g., G+2)',
                  hintText: 'G+2',
                  prefixIcon: Icon(Icons.layers),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _roofCovering,
                decoration: const InputDecoration(
                  labelText: 'Roof Covering Type',
                  prefixIcon: Icon(Icons.roofing),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Clay Tiles', child: Text('Clay Tiles')),
                  DropdownMenuItem(value: 'Asbestos', child: Text('Asbestos')),
                  DropdownMenuItem(value: 'Covering Metal', child: Text('Covering Metal')),
                  DropdownMenuItem(value: 'Zinc/Al', child: Text('Zinc/Al')),
                ],
                onChanged: (val) => setState(() => _roofCovering = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._buildingElements.entries.map((category) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _FormCard(
              title: category.key,
              icon: _getIconForCategory(category.key),
              child: Column(
                children: category.value.entries.map((item) {
                  return CheckboxListTile(
                    title: Text(item.key, style: const TextStyle(fontSize: 13)),
                    value: item.value,
                    onChanged: (val) {
                      setState(() {
                        _buildingElements[category.key]![item.key] = val ?? false;
                      });
                    },
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ─── STEP 4: DEFECT CAPTURE ───────────────────────────────────────────────
  Widget _buildDefectCapturePage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormCard(
          title: 'Capture New Defect',
          icon: Icons.report_problem_outlined,
          child: DefectCaptureCard(
            onDefectCapture: (defect) {
              setState(() {
                _capturedDefects.add(defect);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✓ Defect added')),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (_capturedDefects.isNotEmpty) ...[
          Text(
            'Captured Defects (${_capturedDefects.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: NBROColors.black),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _capturedDefects.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final defect = _capturedDefects[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NBROColors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: defect.photoPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(File(defect.photoPath!), fit: BoxFit.cover),
                            )
                          : const Icon(Icons.image, color: NBROColors.grey),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(defect.notation.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('${defect.lengthMm}mm${defect.widthMm != null ? ' × ${defect.widthMm}mm' : ''}', style: const TextStyle(fontSize: 12, color: NBROColors.grey)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: NBROColors.error),
                      onPressed: () => _removeDefect(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ] else
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  const Text('No defects captured yet', style: TextStyle(color: NBROColors.grey)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ─── STEP 5: REVIEW ───────────────────────────────────────────────────────
  Widget _buildReviewPage() {
    final selectedMaterialsList = <String>[];
    _buildingElements.forEach((cat, items) {
      items.forEach((item, selected) {
        if (selected) selectedMaterialsList.add('$cat: $item');
      });
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormCard(
          title: 'Site & Owner Details',
          icon: Icons.business_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReviewRow('Ref No.', _buildingRefController.text),
              _buildReviewRow('Owner Name', _ownerNameController.text),
              _buildReviewRow('Address', _addressController.text),
              if (_contactController.text.isNotEmpty)
                _buildReviewRow('Contact No.', _contactController.text),
              if (_latitude != null && _longitude != null)
                _buildReviewRow('GPS Coordinates', '${_latitude!.toStringAsFixed(6)}°, ${_longitude!.toStringAsFixed(6)}°'),
              if (_distanceController.text.isNotEmpty)
                _buildReviewRow('Distance from ROW', '${_distanceController.text} m'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _FormCard(
          title: 'Observations & Utility Services',
          icon: Icons.fact_check_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_typeOfStructure != null) _buildReviewRow('Structure Type', _typeOfStructure!),
              if (_presentCondition != null) _buildReviewRow('Present Condition', _presentCondition!),
              if (_ageController.text.isNotEmpty) _buildReviewRow('Approx. Age', '${_ageController.text} years'),
              _buildReviewRow('Water Supply', _hasPipeBorneWater ? (_waterSource ?? 'Available') : 'Not Available'),
              _buildReviewRow('Electricity', _hasElectricity ? (_electricitySource ?? 'Available') : 'Not Available'),
              _buildReviewRow('Sewage & Waste', _hasSewageWaste ? (_sewageType ?? 'Available') : 'Not Available'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _FormCard(
          title: 'Building Profile & Materials',
          icon: Icons.construction_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_numberOfFloorsController.text.isNotEmpty)
                _buildReviewRow('Number of Floors', _numberOfFloorsController.text),
              if (_roofCovering != null)
                _buildReviewRow('Roof Covering', _roofCovering!),
              if (selectedMaterialsList.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Selected Specifications:', style: TextStyle(fontSize: 12, color: NBROColors.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: selectedMaterialsList
                      .map((mat) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: NBROColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(mat, style: const TextStyle(fontSize: 11, color: NBROColors.primary, fontWeight: FontWeight.w600)),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        _FormCard(
          title: 'Captured Defects (${_capturedDefects.length})',
          icon: Icons.report_problem_outlined,
          child: _capturedDefects.isNotEmpty
              ? Column(
                  children: _capturedDefects.map((defect) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: NBROColors.error,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(defect.notation.code, style: const TextStyle(color: NBROColors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(defect.notation.displayName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          Text('${defect.lengthMm}mm', style: const TextStyle(fontSize: 12, color: NBROColors.grey)),
                        ],
                      ),
                    );
                  }).toList(),
                )
              : const Text('No defects captured for this inspection.', style: TextStyle(fontSize: 13, color: NBROColors.grey)),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: NBROColors.info.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: NBROColors.info.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: NBROColors.info),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Please review all survey details above. Tap "Complete Inspection" below to finalize.',
                  style: TextStyle(fontSize: 13, color: NBROColors.darkGrey),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: NBROColors.grey)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: NBROColors.black)),
        ],
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'Walls':
        return Icons.foundation;
      case 'Doors':
        return Icons.door_front_door;
      case 'Floors':
        return Icons.texture;
      case 'Finishes':
        return Icons.brush;
      case 'Roof':
        return Icons.roofing;
      default:
        return Icons.business;
    }
  }
}

class _FormCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _FormCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: NBROColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: NBROColors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: NBROColors.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: NBROColors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
