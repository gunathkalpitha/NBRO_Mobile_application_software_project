import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';

class AdminInspectionsScreen extends StatefulWidget {
  final bool embedded;
  
  const AdminInspectionsScreen({super.key, this.embedded = false});

  @override
  State<AdminInspectionsScreen> createState() => _AdminInspectionsScreenState();
}

class _AdminInspectionsScreenState extends State<AdminInspectionsScreen> {
  List<Map<String, dynamic>> _officers = [];
  final Map<String, List<Map<String, dynamic>>> _inspectionsByOfficer = {};
  bool _isLoading = true;
  String? _selectedOfficerId;
  RealtimeChannel? _inspectionsSubscription;

  @override
  void initState() {
    super.initState();
    _loadOfficersAndInspections();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _inspectionsSubscription?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    final supabase = Supabase.instance.client;
    
    _inspectionsSubscription = supabase
        .channel('admin_inspections')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inspections',
          callback: (payload) {
            debugPrint('Inspections changed: ${payload.eventType}');
            _loadOfficersAndInspections();
          },
        )
        .subscribe();
  }

  Future<void> _loadOfficersAndInspections() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final supabase = Supabase.instance.client;
      
      debugPrint('Admin Inspections: Starting to load officers...');
      
      // First, test if admin can see ANY inspections
      try {
        final testAllInspections = await supabase
            .from('inspections')
            .select('id, user_id')
            .limit(10);
        debugPrint('Admin Inspections: TEST - Can see ${(testAllInspections as List).length} total inspections');
      } catch (e) {
        debugPrint('Admin Inspections: TEST FAILED - Cannot query inspections: $e');
      }
      
      // Get all officers
      final officersResponse = await supabase
          .from('profiles')
          .select('id, email, full_name, role, created_at')
          .eq('role', 'officer')
          .order('full_name', ascending: true);

      _officers = List<Map<String, dynamic>>.from(officersResponse as List);
      debugPrint('Admin Inspections: Loaded ${_officers.length} officers');

      // Clear previous inspections
      _inspectionsByOfficer.clear();

      // Get all inspections grouped by officer
      for (var officer in _officers) {
        debugPrint('Admin Inspections: Loading inspections for ${officer['full_name']} (${officer['email']}) - ID: ${officer['id']}');
        
        try {
          final inspectionsResponse = await supabase
              .from('inspections')
              .select('id, site_name, site_location, inspection_date, sync_status, total_defects, created_at, user_id')
              .eq('user_id', officer['id'])
              .order('inspection_date', ascending: false);

          final inspections = List<Map<String, dynamic>>.from(inspectionsResponse as List);
          _inspectionsByOfficer[officer['id']] = inspections;
          
          if (inspections.isNotEmpty) {
            debugPrint('Admin Inspections: ✓ Found ${inspections.length} inspections for ${officer['full_name']}');
            for (var insp in inspections) {
              debugPrint('  - ${insp['site_name']} (${insp['inspection_date']})');
            }
          } else {
            debugPrint('Admin Inspections: ✗ Found 0 inspections for ${officer['full_name']}');
          }
        } catch (e) {
          debugPrint('Admin Inspections: ERROR loading inspections for officer ${officer['id']}: $e');
          _inspectionsByOfficer[officer['id']] = [];
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
      
      // Show summary in debug
      final totalInspections = _inspectionsByOfficer.values.fold<int>(0, (sum, list) => sum + list.length);
      debugPrint('Admin Inspections: Total loaded - ${_officers.length} officers, $totalInspections inspections');
      
    } catch (e) {
      debugPrint('Admin Inspections: Critical error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: NBROColors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: $e')),
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
              automaticallyImplyLeading: true,
              title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Officer Inspections',
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
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: NBROColors.white),
                  onPressed: _loadOfficersAndInspections,
                  tooltip: 'Refresh',
                ),
              ],
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
          : _officers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 80,
                        color: NBROColors.grey.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No officers found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: NBROColors.darkGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add officers to see their inspections',
                        style: TextStyle(
                          color: NBROColors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadOfficersAndInspections,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _officers.length,
                    itemBuilder: (context, index) {
                      final officer = _officers[index];
                      final inspections = _inspectionsByOfficer[officer['id']] ?? [];
                      final isExpanded = _selectedOfficerId == officer['id'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: NBROColors.grey.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Officer Header
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedOfficerId = isExpanded ? null : officer['id'];
                                });
                              },
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: NBROColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.person,
                                        color: NBROColors.primary,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            officer['full_name'] ?? 'Unknown Officer',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: NBROColors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            officer['email'] ?? '',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: NBROColors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: NBROColors.info.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.assignment,
                                                      size: 12,
                                                      color: NBROColors.info,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${inspections.length} Inspections',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: NBROColors.info,
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
                                    Icon(
                                      isExpanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      color: NBROColors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Inspections List
                            if (isExpanded)
                              Container(
                                decoration: BoxDecoration(
                                  color: NBROColors.light,
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(16),
                                  ),
                                ),
                                child: inspections.isEmpty
                                    ? Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          children: [
                                            Icon(
                                              Icons.assignment_outlined,
                                              size: 48,
                                              color: NBROColors.grey.withValues(alpha: 0.5),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'No inspections yet',
                                              style: TextStyle(
                                                color: NBROColors.grey,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Column(
                                        children: [
                                          Divider(
                                            height: 1,
                                            color: NBROColors.grey.withValues(alpha: 0.2),
                                          ),
                                          ListView.separated(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            padding: const EdgeInsets.all(12),
                                            itemCount: inspections.length,
                                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                                            itemBuilder: (context, inspectionIndex) {
                                              final inspection = inspections[inspectionIndex];
                                              return _buildInspectionItem(inspection);
                                            },
                                          ),
                                        ],
                                      ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildInspectionItem(Map<String, dynamic> inspection) {
    final syncStatus = inspection['sync_status'] ?? 'unknown';
    final statusColor = syncStatus == 'synced' ? NBROColors.success : NBROColors.warning;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NBROColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: NBROColors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  inspection['site_name'] ?? 'Unnamed Site',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: NBROColors.black,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  syncStatus.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 14,
                color: NBROColors.grey,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  inspection['site_location'] ?? 'Unknown location',
                  style: TextStyle(
                    fontSize: 12,
                    color: NBROColors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 14,
                color: NBROColors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                inspection['inspection_date'] ?? 'No date',
                style: TextStyle(
                  fontSize: 12,
                  color: NBROColors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
