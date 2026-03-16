import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../domain/models/inspection.dart';
import '../../data/repositories/inspection_repository.dart';
import '../../core/theme/app_theme.dart';

class EditInspectionScreen extends StatefulWidget {
  final Inspection inspection;
  final Function(Inspection) onInspectionUpdated;

  const EditInspectionScreen({
    super.key,
    required this.inspection,
    required this.onInspectionUpdated,
  });

  @override
  State<EditInspectionScreen> createState() => _EditInspectionScreenState();
}

class _EditInspectionScreenState extends State<EditInspectionScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final InspectionRepository _repository = InspectionRepository();
  late TabController _tabController;
  
  // Site Data Sheet controllers
  late TextEditingController _ownerNameController;
  late TextEditingController _siteAddressController;
  late TextEditingController _contactNoController;
  late TextEditingController _remarksController;
  late TextEditingController _distanceFromRowController;
  
  // General Observations controllers
  late TextEditingController _ageOfStructureController;
  String? _typeOfStructure;
  String? _presentCondition;
  
  // External Services
  bool? _hasPipeBorneWater;
  String? _waterSource;
  bool? _hasElectricity;
  String? _electricitySource;
  bool? _hasSewageWaste;
  String? _sewageType;
  
  // Building Profile
  late TextEditingController _numberOfFloorsController;
  Map<String, bool> _wallMaterials = {};
  Map<String, bool> _doorMaterials = {};
  Map<String, bool> _floorMaterials = {};
  Map<String, bool> _roofMaterials = {};
  String? _roofCovering;
  
  // Defects
  List<Defect> _defects = [];
  
  // Building Photo
  String? _buildingPhotoUrl;
  String? _newBuildingPhotoPath; // local path of a newly picked photo (not yet uploaded)
  
  bool _isLoading = false;
  bool _hasChanges = false;

  final List<String> _structureTypes = [
    'House',
    'Office',
    'Shop',
    'Warehouse',
    'Factory',
    'Mixed Use',
    'Other'
  ];

  final List<String> _conditionTypes = [
    'Permanent',
    'Semi-permanent',
    'Temporary'
  ];

  final List<String> _waterSources = [
    'From Well',
    'From Main Supply',
    'Borehole',
    'None'
  ];

  final List<String> _electricitySources = [
    'From Private Solar',
    'From Main Supply',
    'Generator',
    'None'
  ];

  final List<String> _sewageTypes = [
    'Private Septic tank',
    'Connected to Sewer',
    'Pit Latrine',
    'None'
  ];

  final List<String> _roofCoverings = [
    'Clay Tiles',
    'Asbestos',
    'Metal',
    'Zinc/Al',
    'Concrete',
    'Thatch'
  ];

  final Map<String, String> _wallMaterialOptions = {
    'Brick': 'Brick',
    'Concrete': 'Concrete',
    'Timber': 'Timber',
    'Stone': 'Stone',
    'Block': 'Block',
  };

  final Map<String, String> _doorMaterialOptions = {
    'Solid Timber': 'Solid Timber',
    'Glazed Aluminium': 'Glazed Aluminium',
    'Metal': 'Metal',
    'PVC': 'PVC',
  };

  final Map<String, String> _floorMaterialOptions = {
    'Cement Rendered': 'Cement Rendered',
    'Floor Tiles': 'Floor Tiles',
    'Marble': 'Marble',
    'Timber': 'Timber',
    'Earth': 'Earth',
  };

  final Map<String, String> _roofMaterialOptions = {
    'Single Pitched': 'Single Pitched',
    'Gable': 'Gable',
    'Hip': 'Hip',
    'Flat': 'Flat',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeControllers();
    _loadDefects();
  }

  void _initializeControllers() {
    _ownerNameController = TextEditingController(text: widget.inspection.ownerName);
    _siteAddressController = TextEditingController(text: widget.inspection.siteAddress);
    _contactNoController = TextEditingController(text: widget.inspection.contactNo ?? '');
    _remarksController = TextEditingController(text: widget.inspection.remarks ?? '');
    _distanceFromRowController = TextEditingController(
      text: widget.inspection.distanceFromRow?.toString() ?? '',
    );
    
    // General Observations
    _ageOfStructureController = TextEditingController(
      text: widget.inspection.ageOfStructure?.toString() ?? '',
    );
    _typeOfStructure = widget.inspection.typeOfStructure;
    _presentCondition = widget.inspection.presentCondition;
    
    // External Services
    _hasPipeBorneWater = widget.inspection.hasPipeBorneWater;
    _waterSource = widget.inspection.waterSource;
    _hasElectricity = widget.inspection.hasElectricity;
    _electricitySource = widget.inspection.electricitySource;
    _hasSewageWaste = widget.inspection.hasSewageWaste;
    _sewageType = widget.inspection.sewageType;
    
    // Building Profile
    _numberOfFloorsController = TextEditingController(
      text: widget.inspection.numberOfFloors ?? '',
    );
    _wallMaterials = Map.from(widget.inspection.wallMaterials ?? {});
    _doorMaterials = Map.from(widget.inspection.doorMaterials ?? {});
    _floorMaterials = Map.from(widget.inspection.floorMaterials ?? {});
    _roofMaterials = Map.from(widget.inspection.roofMaterials ?? {});
    _roofCovering = widget.inspection.roofCovering;
    _buildingPhotoUrl = widget.inspection.buildingPhotoUrl;
  }

  void _loadDefects() {
    _defects = List.from(widget.inspection.defects);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ownerNameController.dispose();
    _siteAddressController.dispose();
    _contactNoController.dispose();
    _remarksController.dispose();
    _distanceFromRowController.dispose();
    _ageOfStructureController.dispose();
    _numberOfFloorsController.dispose();
    super.dispose();
  }

  void _markAsChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  Future<void> _pickBuildingPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        setState(() {
          _newBuildingPhotoPath = picked.path;
          _hasChanges = true;
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

  Future<void> _saveInspection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedInspection = widget.inspection.copyWith(
        ownerName: _ownerNameController.text.trim(),
        siteAddress: _siteAddressController.text.trim(),
        contactNo: _contactNoController.text.trim().isEmpty 
            ? null 
            : _contactNoController.text.trim(),
        remarks: _remarksController.text.trim().isEmpty 
            ? null 
            : _remarksController.text.trim(),
        distanceFromRow: _distanceFromRowController.text.trim().isEmpty 
            ? null 
            : double.tryParse(_distanceFromRowController.text.trim()),
        ageOfStructure: _ageOfStructureController.text.trim().isEmpty
            ? null
            : int.tryParse(_ageOfStructureController.text.trim()),
        typeOfStructure: _typeOfStructure,
        presentCondition: _presentCondition,
        hasPipeBorneWater: _hasPipeBorneWater,
        waterSource: _waterSource,
        hasElectricity: _hasElectricity,
        electricitySource: _electricitySource,
        hasSewageWaste: _hasSewageWaste,
        sewageType: _sewageType,
        numberOfFloors: _numberOfFloorsController.text.trim().isEmpty
            ? null
            : _numberOfFloorsController.text.trim(),
        wallMaterials: _wallMaterials.isEmpty ? null : _wallMaterials,
        doorMaterials: _doorMaterials.isEmpty ? null : _doorMaterials,
        floorMaterials: _floorMaterials.isEmpty ? null : _floorMaterials,
        roofMaterials: _roofMaterials.isEmpty ? null : _roofMaterials,
        roofCovering: _roofCovering,
        defects: _defects,
        buildingPhotoUrl: _buildingPhotoUrl,
        updatedAt: DateTime.now(),
      );

      await _repository.updateInspection(
        updatedInspection,
        newBuildingPhotoPath: _newBuildingPhotoPath,
      );

      if (mounted) {
        widget.onInspectionUpdated(updatedInspection);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Inspection updated successfully in database'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, updatedInspection);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating inspection: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Do you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final dateTimeFormat = DateFormat('MMM dd, yyyy hh:mm a');

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _hasChanges) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Inspection'),
          actions: [
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: _saveInspection,
                tooltip: 'Save Changes',
              ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: const [
              Tab(icon: Icon(Icons.description), text: 'Site Data'),
              Tab(icon: Icon(Icons.info), text: 'Observations'),
              Tab(icon: Icon(Icons.home), text: 'Building'),
              Tab(icon: Icon(Icons.warning), text: 'Defects'),
            ],
          ),
        ),
        body: Form(
          key: _formKey,
          onChanged: _markAsChanged,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSiteDataTab(dateTimeFormat),
              _buildObservationsTab(),
              _buildBuildingProfileTab(),
              _buildDefectsTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSiteDataTab(DateFormat dateTimeFormat) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date Information Card
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Record Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text(
                        'Created: ',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        dateTimeFormat.format(widget.inspection.createdAt),
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                  if (widget.inspection.updatedAt != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.update, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text(
                          'Last Modified: ',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          dateTimeFormat.format(widget.inspection.updatedAt!),
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Building Reference No (Read-only)
          TextFormField(
            initialValue: widget.inspection.id,
            decoration: const InputDecoration(
              labelText: 'Building Reference No (Cannot be changed)',
              prefixIcon: Icon(Icons.tag),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Color(0xFFF5F5F5),
            ),
            enabled: false,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _ownerNameController,
            decoration: const InputDecoration(
              labelText: 'Owner Name *',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter owner name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _siteAddressController,
            decoration: const InputDecoration(
              labelText: 'Site Address *',
              prefixIcon: Icon(Icons.location_on),
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter site address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _contactNoController,
            decoration: const InputDecoration(
              labelText: 'Contact Number',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _distanceFromRowController,
            decoration: const InputDecoration(
              labelText: 'Distance from Row (meters)',
              prefixIcon: Icon(Icons.straighten),
              border: OutlineInputBorder(),
              suffixText: 'm',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),

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

          // Building Photo Section
          Text(
            'Building Photo',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_newBuildingPhotoPath != null || _buildingPhotoUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _newBuildingPhotoPath != null
                  ? (kIsWeb
                      ? Image.network(_newBuildingPhotoPath!, height: 200, width: double.infinity, fit: BoxFit.cover)
                      : Image.file(File(_newBuildingPhotoPath!), height: 200, width: double.infinity, fit: BoxFit.cover))
                  : Image.network(
                      _buildingPhotoUrl!,
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
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Failed to load image'),
                              ],
                            ),
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
                    Text('No building photo'),
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
                  onPressed: () => _pickBuildingPhoto(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Photo'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickBuildingPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('From Gallery'),
                ),
              ),
            ],
          ),
          if (_buildingPhotoUrl != null || _newBuildingPhotoPath != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _buildingPhotoUrl = null;
                  _newBuildingPhotoPath = null;
                  _hasChanges = true;
                });
              },
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildObservationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'General Observations',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _ageOfStructureController,
            decoration: const InputDecoration(
              labelText: 'Age of Structure',
              prefixIcon: Icon(Icons.access_time),
              border: OutlineInputBorder(),
              suffixText: 'years',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),

          // ignore: deprecated_member_use
          DropdownButtonFormField<String>(
            value: _typeOfStructure, // Using value for controlled component with dynamic items
            decoration: const InputDecoration(
              labelText: 'Type of Structure',
              prefixIcon: Icon(Icons.business),
              border: OutlineInputBorder(),
            ),
            items: [
              ..._structureTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))),
              // Add current value if it's not in the predefined list
              if (_typeOfStructure != null && !_structureTypes.contains(_typeOfStructure))
                DropdownMenuItem(value: _typeOfStructure, child: Text(_typeOfStructure!)),
            ],
            onChanged: (value) {
              setState(() {
                _typeOfStructure = value;
                _markAsChanged();
              });
            },
          ),
          const SizedBox(height: 16),

          // ignore: deprecated_member_use
          DropdownButtonFormField<String>(
            value: _presentCondition, // Using value for controlled component with dynamic items
            decoration: const InputDecoration(
              labelText: 'Present Condition',
              prefixIcon: Icon(Icons.grade),
              border: OutlineInputBorder(),
            ),
            items: [
              ..._conditionTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))),
              // Add current value if it's not in the predefined list
              if (_presentCondition != null && !_conditionTypes.contains(_presentCondition))
                DropdownMenuItem(value: _presentCondition, child: Text(_presentCondition!)),
            ],
            onChanged: (value) {
              setState(() {
                _presentCondition = value;
                _markAsChanged();
              });
            },
          ),
          const SizedBox(height: 24),

          Text(
            'External Services',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          SwitchListTile(
            title: const Text('Has Pipe Borne Water'),
            value: _hasPipeBorneWater ?? false,
            onChanged: (value) {
              setState(() {
                _hasPipeBorneWater = value;
                _markAsChanged();
              });
            },
          ),
          if (_hasPipeBorneWater == true) ...[
            const SizedBox(height: 8),
            // ignore: deprecated_member_use
            DropdownButtonFormField<String>(
              value: _waterSource, // Using value for controlled component with dynamic items
              decoration: const InputDecoration(
                labelText: 'Water Source',
                prefixIcon: Icon(Icons.water_drop),
                border: OutlineInputBorder(),
              ),
              items: [
                ..._waterSources.map((source) => DropdownMenuItem(value: source, child: Text(source))),
                // Add current value if it's not in the predefined list
                if (_waterSource != null && !_waterSources.contains(_waterSource))
                  DropdownMenuItem(value: _waterSource, child: Text(_waterSource!)),
              ],
              onChanged: (value) {
                setState(() {
                  _waterSource = value;
                  _markAsChanged();
                });
              },
            ),
          ],
          const SizedBox(height: 16),

          SwitchListTile(
            title: const Text('Has Electricity'),
            value: _hasElectricity ?? false,
            onChanged: (value) {
              setState(() {
                _hasElectricity = value;
                _markAsChanged();
              });
            },
          ),
          if (_hasElectricity == true) ...[
            const SizedBox(height: 8),
            // ignore: deprecated_member_use
            DropdownButtonFormField<String>(
              value: _electricitySource, // Using value for controlled component with dynamic items
              decoration: const InputDecoration(
                labelText: 'Electricity Source',
                prefixIcon: Icon(Icons.electrical_services),
                border: OutlineInputBorder(),
              ),
              items: [
                ..._electricitySources.map((source) => DropdownMenuItem(value: source, child: Text(source))),
                // Add current value if it's not in the predefined list
                if (_electricitySource != null && !_electricitySources.contains(_electricitySource))
                  DropdownMenuItem(value: _electricitySource, child: Text(_electricitySource!)),
              ],
              onChanged: (value) {
                setState(() {
                  _electricitySource = value;
                  _markAsChanged();
                });
              },
            ),
          ],
          const SizedBox(height: 16),

          SwitchListTile(
            title: const Text('Has Sewage/Waste System'),
            value: _hasSewageWaste ?? false,
            onChanged: (value) {
              setState(() {
                _hasSewageWaste = value;
                _markAsChanged();
              });
            },
          ),
          if (_hasSewageWaste == true) ...[
            const SizedBox(height: 8),
            // ignore: deprecated_member_use
            DropdownButtonFormField<String>(
              value: _sewageType, // Using value for controlled component with dynamic items
              decoration: const InputDecoration(
                labelText: 'Sewage Type',
                prefixIcon: Icon(Icons.water_damage),
                border: OutlineInputBorder(),
              ),
              items: [
                ..._sewageTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))),
                // Add current value if it's not in the predefined list
                if (_sewageType != null && !_sewageTypes.contains(_sewageType))
                  DropdownMenuItem(value: _sewageType, child: Text(_sewageType!)),
              ],
              onChanged: (value) {
                setState(() {
                  _sewageType = value;
                  _markAsChanged();
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBuildingProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Building Profile',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _numberOfFloorsController,
            decoration: const InputDecoration(
              labelText: 'Number of Floors (e.g., G+2)',
              prefixIcon: Icon(Icons.layers),
              border: OutlineInputBorder(),
              hintText: 'G+2',
            ),
          ),
          const SizedBox(height: 24),

          _buildMaterialSection(
            'Wall Materials',
            _wallMaterialOptions,
            _wallMaterials,
          ),
          const SizedBox(height: 24),

          _buildMaterialSection(
            'Door Materials',
            _doorMaterialOptions,
            _doorMaterials,
          ),
          const SizedBox(height: 24),

          _buildMaterialSection(
            'Floor Materials',
            _floorMaterialOptions,
            _floorMaterials,
          ),
          const SizedBox(height: 24),

          _buildMaterialSection(
            'Roof Materials',
            _roofMaterialOptions,
            _roofMaterials,
          ),
          const SizedBox(height: 16),

          // ignore: deprecated_member_use
          DropdownButtonFormField<String>(
            value: _roofCovering, // Using value for controlled component with dynamic items
            decoration: const InputDecoration(
              labelText: 'Roof Covering',
              prefixIcon: Icon(Icons.roofing),
              border: OutlineInputBorder(),
            ),
            items: [
              ..._roofCoverings.map((covering) => DropdownMenuItem(value: covering, child: Text(covering))),
              // Add current value if it's not in the predefined list
              if (_roofCovering != null && !_roofCoverings.contains(_roofCovering))
                DropdownMenuItem(value: _roofCovering, child: Text(_roofCovering!)),
            ],
            onChanged: (value) {
              setState(() {
                _roofCovering = value;
                _markAsChanged();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialSection(
    String title,
    Map<String, String> options,
    Map<String, bool> selectedMaterials,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: options.entries.map((entry) {
                return CheckboxListTile(
                  title: Text(entry.value),
                  value: selectedMaterials[entry.key] ?? false,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        selectedMaterials[entry.key] = true;
                      } else {
                        selectedMaterials.remove(entry.key);
                      }
                      _markAsChanged();
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDefectsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Defects (${_defects.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                 
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Add defect functionality coming soon'),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Defect'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _defects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No defects recorded',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _defects.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final defect = _defects[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: NBROColors.primary,
                          child: Text(
                            defect.notation.code,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(defect.category.displayName),
                        subtitle: Text(
                          'Length: ${defect.lengthMm}mm${defect.widthMm != null ? ' | Width: ${defect.widthMm}mm' : ''}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            _deleteDefect(index);
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _deleteDefect(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Defect?'),
        content: const Text('Are you sure you want to delete this defect?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _defects.removeAt(index);
                _markAsChanged();
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
