import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:nbro_mobile_application/domain/models/inspection.dart';
import 'package:nbro_mobile_application/core/theme/app_theme.dart';
import 'inspection_detail_screen.dart';

/// Screen to display inspection sites on a map
/// Can show all sites or a single site location
class InspectionMapScreen extends StatefulWidget {
  final List<Inspection> inspections;
  final Inspection? selectedInspection;
  final void Function(BuildContext, Inspection)? onViewDetails;

  const InspectionMapScreen({
    super.key,
    required this.inspections,
    this.selectedInspection,
    this.onViewDetails,
  });

  @override
  State<InspectionMapScreen> createState() => _InspectionMapScreenState();
}

class _InspectionMapScreenState extends State<InspectionMapScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Inspection? _selectedSite;

  @override
  void initState() {
    super.initState();
    _createMarkers();
    _selectedSite = widget.selectedInspection;
  }

  void _createMarkers() {
    final markers = <Marker>{};
    
    for (final inspection in widget.inspections) {
      if (inspection.latitude != null && inspection.longitude != null) {
        markers.add(
          Marker(
            markerId: MarkerId(inspection.id),
            position: LatLng(inspection.latitude!, inspection.longitude!),
            infoWindow: InfoWindow(
              title: inspection.id,
              snippet: inspection.ownerName,
              onTap: () => _onMarkerTapped(inspection),
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              widget.selectedInspection?.id == inspection.id 
                  ? BitmapDescriptor.hueRed 
                  : BitmapDescriptor.hueBlue,
            ),
            onTap: () => _onMarkerTapped(inspection),
          ),
        );
      }
    }
    
    setState(() {
      _markers = markers;
    });
  }

  void _onMarkerTapped(Inspection inspection) {
    setState(() {
      _selectedSite = inspection;
    });
  }

  void _openInspectionDetails(Inspection inspection) {
    if (widget.onViewDetails != null) {
      widget.onViewDetails!(context, inspection);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InspectionDetailScreen(
          inspection: inspection,
        ),
      ),
    );
  }

  LatLng _getInitialPosition() {
    if (widget.selectedInspection != null &&
        widget.selectedInspection!.latitude != null &&
        widget.selectedInspection!.longitude != null) {
      return LatLng(
        widget.selectedInspection!.latitude!,
        widget.selectedInspection!.longitude!,
      );
    }
    
    // Find average position of all sites with coordinates
    final sitesWithCoords = widget.inspections
        .where((i) => i.latitude != null && i.longitude != null)
        .toList();
    
    if (sitesWithCoords.isEmpty) {
      // Default to Sri Lanka coordinates
      return const LatLng(7.8731, 80.7718);
    }
    
    final avgLat = sitesWithCoords
        .map((i) => i.latitude!)
        .reduce((a, b) => a + b) / sitesWithCoords.length;
    final avgLng = sitesWithCoords
        .map((i) => i.longitude!)
        .reduce((a, b) => a + b) / sitesWithCoords.length;
    
    return LatLng(avgLat, avgLng);
  }

  double _getInitialZoom() {
    if (widget.selectedInspection != null) {
      return 16.0; // Closer zoom for single site
    }
    return 12.0; // Wider zoom for multiple sites
  }

  @override
  Widget build(BuildContext context) {
    final initialPosition = _getInitialPosition();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.selectedInspection != null
              ? 'Site Location'
              : 'All Inspection Sites',
          style: const TextStyle(
            color: NBROColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: NBROColors.primary,
        iconTheme: const IconThemeData(color: NBROColors.white),
        elevation: 0,
        actions: [
          if (widget.selectedInspection == null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: NBROColors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_markers.length} Sites',
                    style: const TextStyle(
                      color: NBROColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialPosition,
              zoom: _getInitialZoom(),
            ),
            markers: _markers,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: false,
            zoomControlsEnabled: true,
          ),
          
          // Site info card at bottom
          if (_selectedSite != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _SiteInfoCard(
                inspection: _selectedSite!,
                onClose: () {
                  setState(() {
                    _selectedSite = null;
                  });
                },
                onViewDetails: () {
                  _openInspectionDetails(_selectedSite!);
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

class _SiteInfoCard extends StatelessWidget {
  final Inspection inspection;
  final VoidCallback onClose;
  final VoidCallback onViewDetails;

  const _SiteInfoCard({
    required this.inspection,
    required this.onClose,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NBROColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: NBROColors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with close button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: NBROColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    inspection.id,
                    style: const TextStyle(
                      color: NBROColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClose,
                  color: NBROColors.grey,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          
          // Site information
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inspection.ownerName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: NBROColors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: NBROColors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        inspection.siteAddress,
                        style: const TextStyle(
                          fontSize: 14,
                          color: NBROColors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.gps_fixed, size: 16, color: NBROColors.grey),
                    const SizedBox(width: 6),
                    Text(
                      '${inspection.latitude!.toStringAsFixed(6)}, ${inspection.longitude!.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: NBROColors.grey,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Stats row
                Row(
                  children: [
                    _StatChip(
                      icon: Icons.warning_amber_rounded,
                      label: '${inspection.defects.length} Defects',
                      color: NBROColors.warning,
                    ),
                    const SizedBox(width: 8),
                    if (inspection.typeOfStructure != null)
                      _StatChip(
                        icon: Icons.home,
                        label: inspection.typeOfStructure!,
                        color: NBROColors.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // View details button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onViewDetails,
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View Full Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NBROColors.primary,
                      foregroundColor: NBROColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
