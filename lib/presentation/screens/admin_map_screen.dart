import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/inspection.dart';

class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({super.key});

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  GoogleMapController? _mapController;
  Map<String, List<Inspection>> _inspectionsByOfficer = {};
  bool _isLoading = true;
  Set<Marker> _markers = {};
  
  // Default location (Sri Lanka center)
  final LatLng _defaultLocation = const LatLng(7.8731, 80.7718);

  @override
  void initState() {
    super.initState();
    _loadInspectionsData();
  }

  Future<void> _loadInspectionsData() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      
      // Get all officers
      final officersResponse = await supabase
          .from('profiles')
          .select('id, full_name, email')
          .eq('role', 'officer');
      
      final officers = List<Map<String, dynamic>>.from(officersResponse as List);
      
      // Get all inspections
      final inspectionsResponse = await supabase
          .from('inspections')
          .select('*');
      
      final inspections = (inspectionsResponse as List)
          .map((data) => Inspection.fromJson(data))
          .toList();

      // Group inspections by officer
      Map<String, List<Inspection>> grouped = {};
      for (var officer in officers) {
        grouped[officer['id']] = inspections
            .where((i) => i.createdBy == officer['id'])
            .toList();
      }

      setState(() {
        _inspectionsByOfficer = grouped;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading inspections: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: NBROColors.error,
          ),
        );
      }
    }
  }

  void _showOfficerInspections(String officerId) {
    final inspections = _inspectionsByOfficer[officerId] ?? [];
    
    if (inspections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This officer has no inspections yet'),
          backgroundColor: NBROColors.info,
        ),
      );
      return;
    }

    // Create markers for this officer's inspections
    Set<Marker> newMarkers = {};
    LatLngBounds? bounds;
    
    for (var inspection in inspections) {
      if (inspection.latitude != null && inspection.longitude != null) {
        final position = LatLng(inspection.latitude!, inspection.longitude!);
        
        newMarkers.add(
          Marker(
            markerId: MarkerId(inspection.id),
            position: position,
            infoWindow: InfoWindow(
              title: inspection.siteAddress,
              snippet: 'Owner: ${inspection.ownerName}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
          ),
        );

        // Calculate bounds
        if (bounds == null) {
          bounds = LatLngBounds(
            southwest: position,
            northeast: position,
          );
        } else {
          bounds = LatLngBounds(
            southwest: LatLng(
              bounds.southwest.latitude < position.latitude
                  ? bounds.southwest.latitude
                  : position.latitude,
              bounds.southwest.longitude < position.longitude
                  ? bounds.southwest.longitude
                  : position.longitude,
            ),
            northeast: LatLng(
              bounds.northeast.latitude > position.latitude
                  ? bounds.northeast.latitude
                  : position.latitude,
              bounds.northeast.longitude > position.longitude
                  ? bounds.northeast.longitude
                  : position.longitude,
            ),
          );
        }
      }
    }

    setState(() {
      _markers = newMarkers;
    });

    // Animate camera to show all markers
    if (bounds != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NBROColors.light,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [NBROColors.primary, NBROColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: NBROColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AppBar(
              toolbarHeight: 70,
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: NBROColors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inspections Map',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: NBROColors.white,
                    ),
                  ),
                  Text(
                    'View inspections by officer',
                    style: TextStyle(
                      fontSize: 12,
                      color: NBROColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(NBROColors.primary),
              ),
            )
          : Stack(
              children: [
                // Google Map
                GoogleMap(
                  onMapCreated: (controller) => _mapController = controller,
                  initialCameraPosition: CameraPosition(
                    target: _defaultLocation,
                    zoom: 8,
                  ),
                  markers: _markers,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                ),

                // Officers List (Bottom Sheet)
                DraggableScrollableSheet(
                  initialChildSize: 0.3,
                  minChildSize: 0.15,
                  maxChildSize: 0.7,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: const BoxDecoration(
                        color: NBROColors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Drag handle
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 12),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: NBROColors.grey.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.people,
                                  color: NBROColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Select Officer',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: NBROColors.black,
                                      ),
                                ),
                                const Spacer(),
                                Text(
                                  '${_inspectionsByOfficer.length} officers',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: NBROColors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _inspectionsByOfficer.keys.length,
                              itemBuilder: (context, index) {
                                final officerId = _inspectionsByOfficer.keys.elementAt(index);
                                final inspections = _inspectionsByOfficer[officerId] ?? [];
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: NBROColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.person,
                                        color: NBROColors.primary,
                                      ),
                                    ),
                                    title: Text(
                                      'Officer ${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${inspections.length} inspection${inspections.length != 1 ? 's' : ''}',
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: NBROColors.accent.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${inspections.length}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: NBROColors.accent,
                                        ),
                                      ),
                                    ),
                                    onTap: () => _showOfficerInspections(officerId),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
