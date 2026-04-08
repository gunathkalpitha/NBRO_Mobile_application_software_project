import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:nbro_mobile_application/core/theme/app_theme.dart';
import 'package:nbro_mobile_application/presentation/widgets/app_shell.dart';

class AdminInspectionsManagementScreen extends StatefulWidget {
  final bool embedded;
  final String? initialInspectionId;

  const AdminInspectionsManagementScreen({
    super.key,
    this.embedded = false,
    this.initialInspectionId,
  });

  @override
  State<AdminInspectionsManagementScreen> createState() =>
      _AdminInspectionsManagementScreenState();
}

class _AdminInspectionsManagementScreenState
    extends State<AdminInspectionsManagementScreen> {
  List<Map<String, dynamic>> _inspections = [];
  List<Map<String, dynamic>> _filteredInspections = [];
  Map<String, Map<String, dynamic>> _officers = {};
  bool _isLoading = true;
  String _selectedView = 'recent'; // recent, all, officers
  final TextEditingController _searchController = TextEditingController();
  bool _hasOpenedInitialInspection = false;

  @override
  void initState() {
    super.initState();
    _loadInspections();
    _searchController.addListener(_filterInspections);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInspections() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      try {
        final adminCheck = await supabase.rpc('is_admin');
        debugPrint('🔍 DEBUG: is_admin() result: $adminCheck');
      } catch (e) {
        debugPrint('🔍 DEBUG: Could not check is_admin(): $e');
      }

      final response = await supabase
          .from('site')
          .select('''
            site_id,
            user_id,
            building_ref,
            owner_name,
            owner_contact,
            address,
            latitude,
            longitude,
            distance_from_row,
            building_photo_url,
            building_photo_path,
            sync_status,
            created_at,
            updated_at,
            general_observation(type, present_condition, approx_age),
            external_services(pipe_born_water_supply, sewage_waste, electricity_source),
            main_building(no_floors)
          ''')
          .order('created_at', ascending: false);

      final officersResponse = await supabase
          .from('profile')
          .select('id, full_name, role')
          .eq('role', 'officer');

      final Map<String, Map<String, dynamic>> officersMap = {};
      for (final officer in officersResponse) {
        final officerId = officer['id'] as String?;
        if (officerId != null && officerId.isNotEmpty) {
          officersMap[officerId] = officer;
        }
      }

      // Match inspections with officers
      final List<Map<String, dynamic>> inspectionsWithProfiles = [];
      for (final row in response) {
        final userId = row['user_id'] as String?;
        final observations = (row['general_observation'] as List?) ?? const [];
        final services = (row['external_services'] as List?) ?? const [];
        final buildings = (row['main_building'] as List?) ?? const [];

        final observation = observations.isNotEmpty
            ? observations.first as Map<String, dynamic>
            : const <String, dynamic>{};
        final service = services.isNotEmpty
            ? services.first as Map<String, dynamic>
            : const <String, dynamic>{};
        final building = buildings.isNotEmpty
            ? buildings.first as Map<String, dynamic>
            : const <String, dynamic>{};

        final pipeWater = service['pipe_born_water_supply'] as String?;
        final electricity = service['electricity_source'] as String?;
        final sewage = service['sewage_waste'] as String?;

        final siteData = <String, dynamic>{
          'site_id': row['site_id'],
          'building_ref': row['building_ref'],
          'owner_name': row['owner_name'],
          'owner_contact': row['owner_contact'],
          'site_address': row['address'],
          'address': row['address'],
          'latitude': row['latitude'],
          'longitude': row['longitude'],
          'distance_from_row': row['distance_from_row'],
          'building_photo_url': row['building_photo_url'],
          'building_photo_path': row['building_photo_path'],
          'sync_status': row['sync_status'],
          'age_of_structure': observation['approx_age'],
          'type_of_structure': observation['type'],
          'present_condition': observation['present_condition'],
          'number_of_floors': building['no_floors'],
          'water_source': pipeWater,
          'has_pipe_borne_water': (pipeWater ?? '').toLowerCase().contains('available'),
          'electricity_source': electricity,
          'has_electricity': (electricity ?? '').toLowerCase().contains('available'),
          'sewage_type': sewage,
          'has_sewage_waste': (sewage ?? '').toLowerCase().contains('available'),
        };

        final officer = (userId != null && userId.isNotEmpty) 
            ? (officersMap[userId] ?? {
                'id': userId,
                'full_name': 'Unknown Officer',
                'role': 'officer'
              })
            : {
                'id': 'unknown',
                'full_name': 'Unknown Officer',
                'role': 'officer'
              };
        
        inspectionsWithProfiles.add({
          'id': row['site_id'],
          'site_id': row['site_id'],
          'user_id': userId,
          'building_reference_no': row['building_ref'],
          'site_name': row['owner_name'],
          'site_location': row['address'],
          'inspection_date': row['created_at'],
          'sync_status': row['sync_status'],
          'created_at': row['created_at'],
          'updated_at': row['updated_at'],
          'total_defects': 0,
          'defects_with_photos': 0,
          'site_data': siteData,
          'officer_profile': officer,
        });
      }

      debugPrint('📊 Loaded ${inspectionsWithProfiles.length} inspection(s)');

      // Fetch actual photo counts from defect_media table
      await _updatePhotoCountsForInspections(inspectionsWithProfiles);

      setState(() {
        _inspections = inspectionsWithProfiles;
        _filteredInspections = inspectionsWithProfiles;
        _officers = officersMap;
        _isLoading = false;
      });

      _openInitialInspectionIfNeeded();
    } catch (e) {
      debugPrint('❌ Error loading inspections: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: NBROColors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error loading inspections: $e')),
              ],
            ),
            backgroundColor: NBROColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _updatePhotoCountsForInspections(List<Map<String, dynamic>> inspections) async {
    try {
      final supabase = Supabase.instance.client;

      final siteIds = inspections
          .map((insp) => insp['site_id'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .toSet()
          .toList();

      if (siteIds.isEmpty) return;

      final defectsResponse = await supabase
          .from('defects')
          .select('defect_id, site_id')
          .inFilter('site_id', siteIds);

      final defectCounts = <String, int>{};
      final defectToSite = <String, String>{};
      for (final defect in (defectsResponse as List)) {
        final siteId = defect['site_id'] as String?;
        final defectId = defect['defect_id'] as String?;
        if (siteId != null) {
          defectCounts[siteId] = (defectCounts[siteId] ?? 0) + 1;
        }
        if (siteId != null && defectId != null) {
          defectToSite[defectId] = siteId;
        }
      }

      final defectIds = defectToSite.keys.toList();
      final photoCounts = <String, int>{};

      if (defectIds.isNotEmpty) {
        final defectInfoResponse = await supabase
            .from('defect_info')
            .select('info_id, defect_id')
            .inFilter('defect_id', defectIds);

        final infoToDefect = <String, String>{};
        for (final info in (defectInfoResponse as List)) {
          final infoId = info['info_id'] as String?;
          final defectId = info['defect_id'] as String?;
          if (infoId != null && defectId != null) {
            infoToDefect[infoId] = defectId;
          }
        }

        final infoIds = infoToDefect.keys.toList();
        if (infoIds.isNotEmpty) {
          final imagesResponse = await supabase
              .from('defect_image')
              .select('info_id')
              .inFilter('info_id', infoIds);

          for (final image in (imagesResponse as List)) {
            final infoId = image['info_id'] as String?;
            if (infoId == null) continue;
            final defectId = infoToDefect[infoId];
            if (defectId == null) continue;
            final siteId = defectToSite[defectId];
            if (siteId == null) continue;
            photoCounts[siteId] = (photoCounts[siteId] ?? 0) + 1;
          }
        }
      }

      // Update each inspection with actual counts
      for (final inspection in inspections) {
        final siteId = inspection['site_id'] as String?;
        if (siteId != null) {
          inspection['defects_with_photos'] = photoCounts[siteId] ?? 0;
          inspection['total_defects'] = defectCounts[siteId] ?? 0;
        }
      }

      debugPrint('✅ Updated photo counts for ${inspections.length} inspections');
    } catch (e) {
      debugPrint('⚠️ Error updating photo counts: $e');
      // Continue without photo counts rather than failing completely
    }
  }

  void _openInitialInspectionIfNeeded() {
    if (_hasOpenedInitialInspection || widget.initialInspectionId == null) {
      return;
    }

    final targetId = widget.initialInspectionId;
    final match = _inspections.firstWhere(
      (inspection) => inspection['building_reference_no'] == targetId,
      orElse: () => <String, dynamic>{},
    );

    if (match.isEmpty) {
      _hasOpenedInitialInspection = true;
      return;
    }

    _selectedView = 'all';
    _hasOpenedInitialInspection = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showInspectionDetails(match);
    });
  }

  void _filterInspections() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredInspections = _inspections;
      } else {
        _filteredInspections = _inspections.where((inspection) {
          final siteName = (inspection['site_name'] ?? '').toLowerCase();
          final location = (inspection['site_location'] ?? '').toLowerCase();
          final buildingRef = (inspection['building_reference_no'] ?? '').toLowerCase();
          final officerProfile = inspection['officer_profile'] as Map<String, dynamic>?;
          final officerName = (officerProfile?['full_name'] ?? '').toLowerCase();
          final officerEmail = (officerProfile?['email'] ?? '').toLowerCase();
          
          return siteName.contains(query) ||
                 location.contains(query) ||
                 buildingRef.contains(query) ||
                 officerName.contains(query) ||
                 officerEmail.contains(query);
        }).toList();
      }
    });
  }

  Map<String, int> _getOfficerInspectionCounts() {
    final counts = <String, int>{};
    for (final inspection in _inspections) {
      final userId = inspection['user_id'] as String?;
      if (userId != null && userId.isNotEmpty) {
        counts[userId] = (counts[userId] ?? 0) + 1;
      }
    }
    return counts;
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'syncing':
        return 'Syncing...';
      case 'synced':
        return 'Synced';
      case 'error':
        return 'Error';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return NBROColors.darkGrey;
      case 'syncing':
        return NBROColors.info;
      case 'synced':
        return NBROColors.success;
      case 'error':
        return NBROColors.error;
      default:
        return NBROColors.grey;
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
                icon: Icon(
                  widget.embedded ? Icons.menu : Icons.arrow_back,
                  color: NBROColors.white,
                ),
                onPressed: () {
                  if (widget.embedded) {
                    NavRailController.toggleVisibility();
                    return;
                  }
                  Navigator.pop(context);
                },
              ),
              title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inspections Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: NBROColors.white,
                    ),
                  ),
                  Text(
                    'View and monitor all inspections',
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
          : _inspections.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: 80,
                        color: NBROColors.grey.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No inspections yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: NBROColors.darkGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Officers will record inspections here',
                        style: TextStyle(
                          color: NBROColors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadInspections,
                  child: CustomScrollView(
                    slivers: [
                      // Search Bar
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search by site, location, or officer...',
                              prefixIcon: const Icon(Icons.search, color: NBROColors.primary),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: NBROColors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: NBROColors.grey.withValues(alpha: 0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: NBROColors.grey.withValues(alpha: 0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: NBROColors.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // View Selector
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              _buildViewChip('recent', 'Recent (5)', Icons.schedule),
                              const SizedBox(width: 8),
                              _buildViewChip('all', 'All Inspections', Icons.list),
                              const SizedBox(width: 8),
                              _buildViewChip('officers', 'By Officers', Icons.people),
                            ],
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 16)),

                      // Content based on selected view
                      if (_selectedView == 'recent')
                        _buildRecentInspections()
                      else if (_selectedView == 'all')
                        _buildAllInspections()
                      else
                        _buildOfficersList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildViewChip(String value, String label, IconData icon) {
    final isSelected = _selectedView == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedView = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? NBROColors.primary : NBROColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? NBROColors.primary : NBROColors.grey.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? NBROColors.white : NBROColors.grey,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? NBROColors.white : NBROColors.darkGrey,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentInspections() {
    final recentInspections = _filteredInspections.take(5).toList();
    
    if (recentInspections.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Text(
            'No inspections found',
            style: TextStyle(color: NBROColors.grey, fontSize: 14),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return _buildInspectionCard(recentInspections[index]);
          },
          childCount: recentInspections.length,
        ),
      ),
    );
  }

  Widget _buildAllInspections() {
    if (_filteredInspections.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Text(
            'No inspections found',
            style: TextStyle(color: NBROColors.grey, fontSize: 14),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return _buildInspectionCard(_filteredInspections[index]);
          },
          childCount: _filteredInspections.length,
        ),
      ),
    );
  }

  Widget _buildOfficersList() {
    final counts = _getOfficerInspectionCounts();
    final officers = _officers.values.toList();

    if (officers.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Text(
            'No officers found',
            style: TextStyle(color: NBROColors.grey, fontSize: 14),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final officer = officers[index];
            final officerId = officer['id'] as String?;
            final count = (officerId != null) ? (counts[officerId] ?? 0) : 0;
            return _buildOfficerCard(officer, count);
          },
          childCount: officers.length,
        ),
      ),
    );
  }

  Widget _buildOfficerCard(Map<String, dynamic> officer, int count) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: NBROColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.person,
            color: NBROColors.primary,
            size: 24,
          ),
        ),
        title: Text(
          officer['full_name'] ?? officer['email'] ?? 'Unknown Officer',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          officer['email'] ?? '',
          style: TextStyle(
            fontSize: 12,
            color: NBROColors.grey,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: NBROColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: NBROColors.primary,
              fontSize: 14,
            ),
          ),
        ),
        onTap: () {
          _showOfficerInspections(officer);
        },
      ),
    );
  }

  void _showOfficerInspections(Map<String, dynamic> officer) {
    final officerId = officer['id'] as String?;
    if (officerId == null || officerId.isEmpty) return;
    
    final officerInspections = _inspections
        .where((inspection) => inspection['user_id'] == officerId)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: NBROColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: NBROColors.primary.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: NBROColors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: NBROColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: NBROColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  officer['full_name'] ?? officer['email'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${officerInspections.length} inspections',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: NBROColors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: officerInspections.length,
                    itemBuilder: (context, index) {
                      return _buildInspectionCard(officerInspections[index]);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInspectionCard(Map<String, dynamic> inspection) {
    final syncStatus = inspection['sync_status'] ?? 'unknown';
    final createdAt = inspection['created_at'] != null
        ? DateFormat('MMM dd, yyyy • hh:mm a').format(
            DateTime.parse(inspection['created_at']),
          )
        : 'N/A';
    
    final officerProfile = inspection['officer_profile'] as Map<String, dynamic>?;
    final officerName = officerProfile?['full_name'] ?? officerProfile?['email'] ?? 'Unknown Officer';
    
    final siteData = _resolveSiteData(inspection);
    final buildingPhotoUrl = siteData?['building_photo_url'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: NBROColors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showInspectionDetails(inspection),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Building Photo Thumbnail
                  if (buildingPhotoUrl != null && buildingPhotoUrl.isNotEmpty)
                    Container(
                      width: 60,
                      height: 60,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: NBROColors.primary.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          buildingPhotoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: NBROColors.primary.withValues(alpha: 0.1),
                              child: Icon(
                                Icons.image_not_supported,
                                color: NBROColors.grey,
                                size: 24,
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: NBROColors.primary.withValues(alpha: 0.1),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    NBROColors.primary,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 60,
                      height: 60,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: NBROColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: NBROColors.primary.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.apartment,
                        color: NBROColors.primary,
                        size: 28,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inspection['site_name'] ?? inspection['building_reference_no'] ?? 'Unknown Site',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: NBROColors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          inspection['site_location'] ?? 'No location',
                          style: TextStyle(
                            fontSize: 12,
                            color: NBROColors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(syncStatus).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusLabel(syncStatus),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(syncStatus),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: NBROColors.light,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, size: 14, color: NBROColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            officerName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: NBROColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.access_time, size: 14, color: NBROColors.grey),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  createdAt,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: NBROColors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.warning_amber, size: 14, color: NBROColors.accent),
                  const SizedBox(width: 6),
                  Text(
                    '${inspection['total_defects'] ?? 0} defects',
                    style: const TextStyle(
                      fontSize: 12,
                      color: NBROColors.accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.image_outlined, size: 14, color: NBROColors.success),
                  const SizedBox(width: 6),
                  Text(
                    '${inspection['defects_with_photos'] ?? 0} photos',
                    style: const TextStyle(
                      fontSize: 12,
                      color: NBROColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInspectionDetails(Map<String, dynamic> inspection) {
    final officerProfile = inspection['officer_profile'] as Map<String, dynamic>?;
    final officerName = officerProfile?['full_name'] ?? officerProfile?['email'] ?? 'Unknown Officer';
    final siteData = _resolveSiteData(inspection);
    final buildingPhotoUrl = siteData?['building_photo_url'] as String?;
    final buildingRef = inspection['building_reference_no'] as String?;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: NBROColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [NBROColors.primary, NBROColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: NBROColors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.visibility, color: NBROColors.white, size: 24),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Inspection Details',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: NBROColors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: NBROColors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Building Photo Section
                      if (buildingPhotoUrl != null && buildingPhotoUrl.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: NBROColors.grey.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: NBROColors.primary.withValues(alpha: 0.1),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.image,
                                      size: 20,
                                      color: NBROColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Building Photo',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: NBROColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(12),
                                ),
                                child: Image.network(
                                  buildingPhotoUrl,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 200,
                                      color: NBROColors.light,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.broken_image,
                                            size: 48,
                                            color: NBROColors.grey,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Failed to load image',
                                            style: TextStyle(
                                              color: NBROColors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      height: 200,
                                      color: NBROColors.light,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            NBROColors.primary,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (buildingRef != null && buildingRef.isNotEmpty)
                        _buildDefectsSection(buildingRef),
                      _buildDetailSection('Site Information', [
                        _buildDetailRow('Site Name', inspection['site_name'] ?? 'N/A'),
                        _buildDetailRow('Building Ref', inspection['building_reference_no'] ?? 'N/A'),
                        _buildDetailRow('Location', inspection['site_location'] ?? 'N/A'),
                        _buildDetailRow(
                          'Site Address',
                          _getSiteValue(siteData, 'site_address'),
                        ),
                        _buildDetailRow(
                          'Latitude',
                          _getSiteValue(siteData, 'latitude'),
                        ),
                        _buildDetailRow(
                          'Longitude',
                          _getSiteValue(siteData, 'longitude'),
                        ),
                        _buildDetailRow(
                          'Distance from ROW',
                          _getSiteValue(siteData, 'distance_from_row'),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _buildDetailSection('Owner Information', [
                        _buildDetailRow('Owner Name', _getSiteValue(siteData, 'owner_name')),
                        _buildDetailRow('Contact', _getSiteValue(siteData, 'owner_contact')),
                      ]),
                      const SizedBox(height: 16),
                      _buildDetailSection('General Observations', [
                        _buildDetailRow(
                          'Age of Structure',
                          _getSiteValue(siteData, 'age_of_structure'),
                        ),
                        _buildDetailRow(
                          'Type of Structure',
                          _getSiteValue(siteData, 'type_of_structure'),
                        ),
                        _buildDetailRow(
                          'Present Condition',
                          _getSiteValue(siteData, 'present_condition'),
                        ),
                        _buildDetailRow(
                          'Number of Floors',
                          _getSiteValue(siteData, 'number_of_floors'),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _buildDetailSection('External Services', [
                        _buildDetailRow(
                          'Pipe-borne Water',
                          _formatYesNo(_getSiteBool(siteData, 'has_pipe_borne_water')),
                        ),
                        _buildDetailRow(
                          'Water Source',
                          _getSiteValue(siteData, 'water_source'),
                        ),
                        _buildDetailRow(
                          'Electricity',
                          _formatYesNo(_getSiteBool(siteData, 'has_electricity')),
                        ),
                        _buildDetailRow(
                          'Electricity Source',
                          _getSiteValue(siteData, 'electricity_source'),
                        ),
                        _buildDetailRow(
                          'Sewage Waste',
                          _formatYesNo(_getSiteBool(siteData, 'has_sewage_waste')),
                        ),
                        _buildDetailRow(
                          'Sewage Type',
                          _getSiteValue(siteData, 'sewage_type'),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _buildDetailSection('Building Materials', [
                        _buildDetailRow(
                          'Wall Materials',
                          _formatMaterialMap(_getSiteField(siteData, 'wall_materials')),
                        ),
                        _buildDetailRow(
                          'Door Materials',
                          _formatMaterialMap(_getSiteField(siteData, 'door_materials')),
                        ),
                        _buildDetailRow(
                          'Floor Materials',
                          _formatMaterialMap(_getSiteField(siteData, 'floor_materials')),
                        ),
                        _buildDetailRow(
                          'Roof Materials',
                          _formatMaterialMap(_getSiteField(siteData, 'roof_materials')),
                        ),
                        _buildDetailRow(
                          'Roof Covering',
                          _getSiteValue(siteData, 'roof_covering'),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _buildDetailSection('Additional Details', [
                        _buildDetailRow(
                          'Ancillary Structures',
                          _formatJsonList(_getSiteField(siteData, 'ancillary_structures')),
                        ),
                        _buildDetailRow(
                          'Finishes',
                          _formatJsonList(_getSiteField(siteData, 'finishes')),
                        ),
                        _buildDetailRow(
                          'Remarks',
                          _getSiteValue(siteData, 'remarks'),
                        ),
                        _buildDetailRow(
                          'Site Sync Status',
                          _getSiteValue(siteData, 'sync_status'),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _buildDetailSection('Inspection Details', [
                        _buildDetailRow('Inspector', officerName),
                        _buildDetailRow('Inspection Date', 
                          inspection['inspection_date'] != null
                            ? DateFormat('MMM dd, yyyy').format(DateTime.parse(inspection['inspection_date']))
                            : 'N/A'),
                        _buildDetailRow('Created At',
                          inspection['created_at'] != null
                            ? DateFormat('MMM dd, yyyy • hh:mm a').format(DateTime.parse(inspection['created_at']))
                            : 'N/A'),
                        _buildDetailRow('Last Updated',
                          inspection['updated_at'] != null
                            ? DateFormat('MMM dd, yyyy • hh:mm a').format(DateTime.parse(inspection['updated_at']))
                            : 'N/A'),
                      ]),
                      const SizedBox(height: 16),
                      _buildDetailSection('Statistics', [
                        _buildDetailRow('Total Defects', '${inspection['total_defects'] ?? 0}'),
                        _buildDetailRow('Photos Captured', '${inspection['defects_with_photos'] ?? 0}'),
                        _buildDetailRow('Sync Status', _getStatusLabel(inspection['sync_status'] ?? 'unknown')),
                      ]),
                      const SizedBox(height: 16),
                      _buildDetailSection('Officer', [
                        _buildDetailRow('Name', officerName),
                        _buildDetailRow('Email', officerProfile?['email'] ?? 'N/A'),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchDefectDetails(String buildingRef) async {
    final supabase = Supabase.instance.client;
    final site = await supabase
        .from('site')
        .select('site_id')
        .eq('building_ref', buildingRef)
        .maybeSingle();

    if (site == null) {
      return [];
    }

    final siteId = site['site_id'] as String;

    final defectsResponse = await supabase
        .from('defects')
        .select(
            'defect_id, created_at, defect_info(info_id, remarks, length, width, defect_image(image_url, image_path))')
        .eq('site_id', siteId)
        .order('created_at', ascending: false);

    return (defectsResponse as List).map((defect) {
      final defectRow = defect as Map<String, dynamic>;
      final infoList = (defectRow['defect_info'] as List?) ?? const [];
      final info = infoList.isNotEmpty
          ? infoList.first as Map<String, dynamic>
          : const <String, dynamic>{};

      final imageList = (info['defect_image'] as List?) ?? const [];
      final image = imageList.isNotEmpty
          ? imageList.first as Map<String, dynamic>
          : const <String, dynamic>{};

      final parsed = _parseDefectMeta(info['remarks'] as String?);

      final defectId = defect['defect_id'] as String?;
      return {
        'defect_id': defectId,
        'notation': parsed['notation'],
        'defect_category': parsed['category'],
        'floor_level': parsed['floor'],
        'length_mm': info['length'],
        'width_mm': info['width'],
        'location_description': null,
        'remarks': parsed['remarks'],
        'photo_url': image['image_url'],
      };
    }).toList();
  }

  Map<String, String> _parseDefectMeta(String? rawRemarks) {
    if (rawRemarks == null || !rawRemarks.startsWith('NBRO_META:')) {
      return {
        'notation': 'C',
        'category': 'buildingFloor',
        'floor': '',
        'remarks': rawRemarks ?? '',
      };
    }

    final splitIndex = rawRemarks.indexOf('|');
    if (splitIndex == -1) {
      return {
        'notation': 'C',
        'category': 'buildingFloor',
        'floor': '',
        'remarks': rawRemarks,
      };
    }

    final meta = rawRemarks.substring('NBRO_META:'.length, splitIndex);
    final plainRemarks = rawRemarks.substring(splitIndex + 1);
    final result = <String, String>{
      'notation': 'C',
      'category': 'buildingFloor',
      'floor': '',
      'remarks': plainRemarks,
    };

    for (final pair in meta.split(';')) {
      final index = pair.indexOf('=');
      if (index <= 0) continue;
      result[pair.substring(0, index)] = pair.substring(index + 1);
    }

    return result;
  }

  Widget _buildDefectsSection(String buildingRef) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchDefectDetails(buildingRef),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NBROColors.light,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: NBROColors.grey.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Loading defect photos...',
                  style: TextStyle(
                    fontSize: 12,
                    color: NBROColors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NBROColors.light,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: NBROColors.grey.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              'Failed to load defect photos',
              style: TextStyle(
                fontSize: 12,
                color: NBROColors.grey,
              ),
            ),
          );
        }

        final defects = snapshot.data ?? [];
        if (defects.isEmpty) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NBROColors.light,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: NBROColors.grey.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              'No defects available',
              style: TextStyle(
                fontSize: 12,
                color: NBROColors.grey,
              ),
            ),
          );
        }

        final defectsWithPhotos = defects
            .where((defect) => (defect['photo_url'] as String?)?.isNotEmpty == true)
            .toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: NBROColors.light,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: NBROColors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.photo_library,
                    size: 18,
                    color: NBROColors.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Defect Photos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: NBROColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (defectsWithPhotos.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: defectsWithPhotos.length,
                  itemBuilder: (context, index) {
                    final photo = defectsWithPhotos[index];
                    final photoUrl = photo['photo_url'] as String?;
                    final notation = photo['notation'] as String?;
                    final location = photo['location_description'] as String?;

                  return Container(
                    decoration: BoxDecoration(
                      color: NBROColors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: NBROColors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(10),
                            ),
                            child: photoUrl == null || photoUrl.isEmpty
                                ? Container(
                                    color: NBROColors.white,
                                    child: Icon(
                                      Icons.broken_image,
                                      color: NBROColors.grey,
                                      size: 32,
                                    ),
                                  )
                                : Image.network(
                                    photoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: NBROColors.white,
                                        child: Icon(
                                          Icons.broken_image,
                                          color: NBROColors.grey,
                                          size: 32,
                                        ),
                                      );
                                    },
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                          valueColor: const AlwaysStoppedAnimation<Color>(
                                            NBROColors.primary,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (notation != null && notation.isNotEmpty)
                                Text(
                                  'Type: $notation',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: NBROColors.darkGrey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (location != null && location.isNotEmpty)
                                Text(
                                  location,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: NBROColors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                  },
                )
              else
                Text(
                  'No defect photos available',
                  style: TextStyle(
                    fontSize: 12,
                    color: NBROColors.grey,
                  ),
                ),
              const SizedBox(height: 16),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: defects.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final defect = defects[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: NBROColors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: NBROColors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              size: 16,
                              color: NBROColors.accent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Defect ${defect['defect_id'] ?? ''}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: NBROColors.black,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildInlineDetail('Notation', defect['notation']),
                        _buildInlineDetail('Category', defect['defect_category']),
                        _buildInlineDetail('Floor Level', defect['floor_level']),
                        _buildInlineDetail('Length (mm)', defect['length_mm']),
                        _buildInlineDetail('Width (mm)', defect['width_mm']),
                        _buildInlineDetail('Location', defect['location_description']),
                        _buildInlineDetail('Remarks', defect['remarks']),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _getSiteValue(Map<String, dynamic>? siteData, String key) {
    if (siteData == null) return 'N/A';
    final value = siteData[key];
    if (value == null) return 'N/A';
    return value.toString();
  }

  Map<String, dynamic>? _resolveSiteData(Map<String, dynamic> inspection) {
    final siteData = inspection['site_data'];
    if (siteData is Map<String, dynamic>) {
      return siteData;
    }

    // Check for site data from join
    final sites = inspection['sites'];
    if (sites is Map<String, dynamic>) {
      return sites;
    }
    
    // Fallback to old field names
    final byId = inspection['sites_by_id'];
    if (byId is Map<String, dynamic>) {
      return byId;
    }
    final byRef = inspection['sites_by_ref'];
    if (byRef is Map<String, dynamic>) {
      return byRef;
    }
    return null;
  }

  bool? _getSiteBool(Map<String, dynamic>? siteData, String key) {
    if (siteData == null) return null;
    final value = siteData[key];
    if (value is bool) return value;
    return null;
  }

  dynamic _getSiteField(Map<String, dynamic>? siteData, String key) {
    if (siteData == null) return null;
    return siteData[key];
  }

  String _formatYesNo(bool? value) {
    if (value == null) return 'N/A';
    return value ? 'Yes' : 'No';
  }

  String _formatMaterialMap(dynamic value) {
    if (value == null) return 'N/A';
    if (value is Map) {
      final selected = <String>[];
      value.forEach((key, val) {
        if (val == true) {
          selected.add(key.toString());
        }
      });
      if (selected.isEmpty) return 'N/A';
      return selected.join(', ');
    }
    return value.toString();
  }

  String _formatJsonList(dynamic value) {
    if (value == null) return 'N/A';
    if (value is List) {
      if (value.isEmpty) return 'N/A';
      return value.map((item) => item.toString()).join(', ');
    }
    if (value is Map) {
      if (value.isEmpty) return 'N/A';
      return value.keys.map((key) => key.toString()).join(', ');
    }
    return value.toString();
  }

  Widget _buildInlineDetail(String label, dynamic value) {
    final displayValue = (value == null || value.toString().isEmpty) ? 'N/A' : value.toString();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: NBROColors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(
                fontSize: 11,
                color: NBROColors.darkGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NBROColors.light,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: NBROColors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: NBROColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == 'N/A') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: NBROColors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: NBROColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }}