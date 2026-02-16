import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';

class AdminInspectionsManagementScreen extends StatefulWidget {
  const AdminInspectionsManagementScreen({super.key});

  @override
  State<AdminInspectionsManagementScreen> createState() =>
      _AdminInspectionsManagementScreenState();
}

class _AdminInspectionsManagementScreenState
    extends State<AdminInspectionsManagementScreen> {
  List<Map<String, dynamic>> _inspections = [];
  Map<String, List<Map<String, dynamic>>> _inspectionsByOfficer = {};
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, pending, synced

  @override
  void initState() {
    super.initState();
    _loadInspections();
  }

  Future<void> _loadInspections() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // Fetch all inspections with officer details via user_id
      final response = await supabase
          .from('inspections')
          .select('''
            id,
            user_id,
            building_reference_no,
            site_name,
            site_location,
            inspection_date,
            total_defects,
            defects_with_photos,
            sync_status,
            created_at
          ''')
          .order('created_at', ascending: false);

      // Fetch officer information for each inspection
      final List<Map<String, dynamic>> inspectionsWithProfiles = [];
      final Set<String> fetchedUserIds = {};
      final Map<String, Map<String, dynamic>> profileCache = {};

      for (final inspection in response) {
        final userId = inspection['user_id'];
        
        // Get or fetch profile
        if (!profileCache.containsKey(userId)) {
          if (!fetchedUserIds.contains(userId)) {
            try {
              final profileResponse = await supabase
                  .from('profiles')
                  .select('id, email, full_name, role')
                  .eq('id', userId)
                  .single();
              profileCache[userId] = profileResponse;
              fetchedUserIds.add(userId);
            } catch (e) {
              debugPrint('Error fetching profile for user $userId: $e');
              profileCache[userId] = {
                'id': userId,
                'email': 'Unknown',
                'full_name': 'Unknown Officer',
                'role': 'officer'
              };
            }
          }
        }

        final profileData = profileCache[userId] ?? {};
        inspectionsWithProfiles.add({
          ...inspection,
          'officer_profile': profileData,
        });
      }

      setState(() {
        _inspections = inspectionsWithProfiles;
        _groupInspectionsByOfficer();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading inspections: $e');
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
          ),
        );
      }
    }
  }

  void _groupInspectionsByOfficer() {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final inspection in _inspections) {
      final profile = inspection['officer_profile'] as Map<String, dynamic>?;
      if (profile != null) {
        final officerName = profile['full_name'] ?? profile['email'] ?? 'Unknown';
        final officerId = profile['id'] ?? 'unknown';
        final key = '$officerId:$officerName';

        if (!grouped.containsKey(key)) {
          grouped[key] = [];
        }
        grouped[key]!.add(inspection);
      }
    }

    _inspectionsByOfficer = grouped;
  }

  List<String> _getFilteredOfficers() {
    if (_selectedFilter == 'all') {
      return _inspectionsByOfficer.keys.toList();
    }

    return _inspectionsByOfficer.keys.where((officer) {
      final inspections = _inspectionsByOfficer[officer] ?? [];
      if (_selectedFilter == 'pending') {
        return inspections.any((i) => i['sync_status'] == 'pending');
      } else if (_selectedFilter == 'synced') {
        return inspections.any((i) => i['sync_status'] == 'synced');
      }
      return true;
    }).toList();
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
                icon: const Icon(Icons.arrow_back, color: NBROColors.white),
                onPressed: () => Navigator.pop(context),
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
                    'All officers\' inspections',
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
                      // Filter Chips
                      SliverAppBar(
                        pinned: true,
                        elevation: 0,
                        backgroundColor: NBROColors.light,
                        toolbarHeight: 60,
                        flexibleSpace: FlexibleSpaceBar(
                          background: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        _buildFilterChip('all', 'All'),
                                        const SizedBox(width: 8),
                                        _buildFilterChip(
                                          'pending',
                                          'Pending',
                                        ),
                                        const SizedBox(width: 8),
                                        _buildFilterChip(
                                          'synced',
                                          'Synced',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Officer Groups
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final officers = _getFilteredOfficers();
                            if (officers.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(32),
                                child: Center(
                                  child: Text(
                                    'No inspections match the selected filter',
                                    style: TextStyle(
                                      color: NBROColors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              );
                            }

                            final officer = officers[index];
                            final inspections =
                                _inspectionsByOfficer[officer] ?? [];
                            final officerParts = officer.split(':');
                            final officerName = officerParts.length > 1
                                ? officerParts[1]
                                : 'Unknown Officer';

                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Officer Header
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          NBROColors.primary
                                              .withValues(alpha: 0.1),
                                          NBROColors.primaryLight
                                              .withValues(alpha: 0.1),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: NBROColors.primary
                                            .withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: NBROColors.primary
                                                .withValues(alpha: 0.2),
                                            borderRadius:
                                                BorderRadius.circular(10),
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                officerName,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: NBROColors.black,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${inspections.length} inspections',
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
                                  ),
                                  const SizedBox(height: 12),
                                  // Inspections List for Officer
                                  ...inspections.map(
                                    (inspection) => _buildInspectionCard(
                                      inspection,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          childCount: _getFilteredOfficers().length,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      backgroundColor: isSelected ? NBROColors.primary : NBROColors.light,
      labelStyle: TextStyle(
        color: isSelected ? NBROColors.white : NBROColors.grey,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? NBROColors.primary : NBROColors.grey,
      ),
    );
  }

  Widget _buildInspectionCard(Map<String, dynamic> inspection) {
    final syncStatus = inspection['sync_status'] ?? 'unknown';
    final inspectionDate = inspection['inspection_date'] != null
        ? DateFormat('MMM dd, yyyy').format(
            DateTime.parse(inspection['inspection_date']),
          )
        : 'N/A';
    final createdAt = inspection['created_at'] != null
        ? DateFormat('hh:mm a').format(
            DateTime.parse(inspection['created_at']),
          )
        : 'N/A';

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
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
                    color:
                        _getStatusColor(syncStatus).withValues(alpha: 0.1),
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
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 14, color: NBROColors.grey),
                      const SizedBox(width: 6),
                      Text(
                        inspectionDate,
                        style: TextStyle(
                          fontSize: 12,
                          color: NBROColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 14, color: NBROColors.grey),
                      const SizedBox(width: 6),
                      Text(
                        createdAt,
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
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.assignment_outlined,
                    size: 14, color: NBROColors.info),
                const SizedBox(width: 6),
                Text(
                  '${inspection['total_defects'] ?? 0} defects',
                  style: TextStyle(
                    fontSize: 12,
                    color: NBROColors.info,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.image_outlined,
                    size: 14, color: NBROColors.success),
                const SizedBox(width: 6),
                Text(
                  '${inspection['defects_with_photos'] ?? 0} photos',
                  style: TextStyle(
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
    );
  }
}
