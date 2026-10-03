import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:nbro_mobile_application/core/services/officer_name_resolver.dart';
import 'package:nbro_mobile_application/core/theme/app_theme.dart';
import 'package:nbro_mobile_application/domain/models/inspection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nbro_mobile_application/presentation/state/inspection_bloc.dart';
import 'package:nbro_mobile_application/data/services/pdf_report_service.dart';
import 'package:nbro_mobile_application/data/repositories/inspection_repository.dart';
import 'package:nbro_mobile_application/presentation/widgets/app_shell.dart';
import 'inspection_map_screen.dart';
import 'edit_inspection_screen.dart';

class InspectionDetailScreen extends StatefulWidget {
  final Inspection inspection;

  const InspectionDetailScreen({
    super.key,
    required this.inspection,
  });

  @override
  State<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Inspection _currentInspection;
  bool _isDeleting = false;
  final InspectionRepository _repository = InspectionRepository();

  @override
  void initState() {
    super.initState();
    _currentInspection = widget.inspection;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _generatePDFReport(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: NBROColors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: NBROColors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: NBROColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf,
                    color: NBROColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Export Inspection PDF',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: NBROColors.black,
                        ),
                      ),
                      Text(
                        'Ref: ${_currentInspection.id}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: NBROColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _PDFOptionButton(
              icon: Icons.visibility_outlined,
              label: 'Preview Report',
              subtitle: 'View complete report document',
              color: NBROColors.primary,
              onTap: () async {
                Navigator.of(context).pop();
                await _previewPDF(context);
              },
            ),
            const SizedBox(height: 12),
            _PDFOptionButton(
              icon: Icons.share_outlined,
              label: 'Share PDF File',
              subtitle: 'Export via email or messaging',
              color: NBROColors.info,
              onTap: () async {
                Navigator.of(context).pop();
                await _sharePDF(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _previewPDF(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(NBROColors.primary),
                ),
                SizedBox(height: 16),
                Text('Generating Official PDF Report...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      if (context.mounted) Navigator.of(context).pop();
      await PDFReportService.previewPDF(_currentInspection);
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst || !route.willHandlePopInternally);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: NBROColors.error,
          ),
        );
      }
    }
  }

  Future<void> _sharePDF(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(NBROColors.primary),
                ),
                SizedBox(height: 16),
                Text('Preparing PDF document...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final file = await PDFReportService.generateInspectionReport(_currentInspection);
      if (context.mounted) Navigator.of(context).pop();
      await PDFReportService.sharePDF(file, 'NBRO_Inspection_${_currentInspection.id}.pdf');
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing PDF: $e'),
            backgroundColor: NBROColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteDialog() async {
    final confirmationController = TextEditingController();
    final buildingRefNo = _currentInspection.id;
    bool canDelete = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: NBROColors.error, size: 28),
              SizedBox(width: 12),
              Text('Delete Inspection'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: NBROColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: NBROColors.error.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.error_outline, color: NBROColors.error, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This operation is permanent and cannot be reversed.',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: NBROColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Type building reference number "$buildingRefNo" to confirm:'),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmationController,
                  decoration: const InputDecoration(
                    labelText: 'Building Reference',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      canDelete = value.trim() == buildingRefNo;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusScope.of(context).unfocus();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: canDelete
                  ? () async {
                      FocusScope.of(context).unfocus();
                      Navigator.pop(context);
                      await _deleteInspection();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: NBROColors.error,
                foregroundColor: NBROColors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteInspection() async {
    if (!mounted) return;
    setState(() {
      _isDeleting = true;
    });

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Deleting record...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await _repository.deleteInspection(_currentInspection.id);
      if (mounted) {
        context.read<InspectionBloc>().add(const LoadInspectionsEvent());
        navigator.pop(); // Pop deleting dialog
        messenger.showSnackBar(
          const SnackBar(
            content: Text('✓ Inspection deleted successfully'),
            backgroundColor: NBROColors.success,
          ),
        );
        if (navigator.canPop()) {
          navigator.pop(true); // Pop screen back to previous list
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error deleting record: $e'),
            backgroundColor: NBROColors.error,
          ),
        );
      }
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final userEmail = currentUser?.email?.toLowerCase() ?? '';
    final isOfficer = userEmail != 'admin@gmail.com' &&
        userEmail != 'mainadminnbro@gmail.com' &&
        !userEmail.startsWith('admin.');

    //delete window
    if (_isDeleting) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: NBROColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: NBROColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Inspection Record',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: NBROColors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Ref: ${_currentInspection.id}',
              style: TextStyle(
                fontSize: 12,
                color: NBROColors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: NBROColors.white),
            tooltip: 'App Drawer',
            onPressed: () {
              NavRailController.toggleVisibility();
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: NBROColors.white),
            tooltip: 'Export PDF',
            onPressed: () => _generatePDFReport(context),
          ),
          if (isOfficer)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: NBROColors.white),
              tooltip: 'Edit Inspection',
              onPressed: () async {
                final result = await Navigator.push<Inspection>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditInspectionScreen(
                      inspection: _currentInspection,
                      onInspectionUpdated: (updatedInspection) {
                        setState(() {
                          _currentInspection = updatedInspection;
                        });
                      },
                    ),
                  ),
                );
                if (result != null) {
                  setState(() {
                    _currentInspection = result;
                  });
                }
              },
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: NBROColors.white),
            onSelected: (value) {
              if (value == 'delete') _showDeleteDialog();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20, color: NBROColors.error),
                    SizedBox(width: 12),
                    Text('Delete Record', style: TextStyle(color: NBROColors.error)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Overview Card
              _HeaderOverviewCard(inspection: _currentInspection),
              const SizedBox(height: 20),

              // Key Information & GPS Grid
              _KeyInformationSection(inspection: _currentInspection),
              const SizedBox(height: 20),

              // Officer Timeline & Modifications
              _TimestampsSection(inspection: _currentInspection),
              const SizedBox(height: 20),

              // General Observations
              _GeneralObservationsSection(inspection: _currentInspection),
              const SizedBox(height: 20),

              // External Services
              _ExternalServicesSection(inspection: _currentInspection),
              const SizedBox(height: 20),

              // Building Profile & Specifications
              _BuildingProfileSection(inspection: _currentInspection),
              const SizedBox(height: 20),

              // Defects Section
              if (_currentInspection.defects.isNotEmpty)
                _DefectsSection(defects: _currentInspection.defects),

              // Remarks Section
              if (_currentInspection.remarks != null &&
                  _currentInspection.remarks!.isNotEmpty) ...[
                const SizedBox(height: 20),
                _RemarksSection(remarks: _currentInspection.remarks!),
              ],

              const SizedBox(height: 80),
            ],
          ),
        ),
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
          child: ElevatedButton.icon(
            onPressed: () => _generatePDFReport(context),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Generate Official PDF Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: NBROColors.primary,
              foregroundColor: NBROColors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}

/// Professional Card Shell Container
class _SectionContainer extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionContainer({
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: NBROColors.black,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Header Overview Card with Front View Image & Contact
class _HeaderOverviewCard extends StatelessWidget {
  final Inspection inspection;

  const _HeaderOverviewCard({required this.inspection});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: NBROColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: NBROColors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Owner & Status Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inspection.siteAddress,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: NBROColors.black,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Owner: ${inspection.ownerName}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: NBROColors.darkGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusPill(status: inspection.syncStatus),
            ],
          ),

          if (inspection.contactNo != null && inspection.contactNo!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 16, color: NBROColors.grey),
                const SizedBox(width: 8),
                Text(
                  inspection.contactNo!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: NBROColors.darkGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],

          // Front View Building Image
          if (inspection.buildingPhotoUrl != null && inspection.buildingPhotoUrl!.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'Building Front View',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: NBROColors.grey,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showImageViewer(context, inspection.buildingPhotoUrl!, 'Building Front View'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  color: Colors.grey.shade100,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        inspection.buildingPhotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.broken_image_outlined, size: 40, color: NBROColors.grey),
                          );
                        },
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: NBROColors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in, size: 14, color: NBROColors.white),
                              SizedBox(width: 4),
                              Text(
                                'Tap to inspect',
                                style: TextStyle(
                                  color: NBROColors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
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
          ],
        ],
      ),
    );
  }
}

/// Key Information Section
class _KeyInformationSection extends StatelessWidget {
  final Inspection inspection;

  const _KeyInformationSection({required this.inspection});

  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      title: 'Key Metrics',
      icon: Icons.grid_view_rounded,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Building Ref',
                  value: inspection.id,
                  icon: Icons.tag,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Structure Type',
                  value: inspection.typeOfStructure ?? 'N/A',
                  icon: Icons.apartment,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Present Condition',
                  value: inspection.presentCondition ?? 'N/A',
                  icon: Icons.fact_check_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Age of Structure',
                  value: inspection.ageOfStructure != null ? '${inspection.ageOfStructure} Years' : 'N/A',
                  icon: Icons.calendar_today_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MetricTile(
            label: 'Survey Date & Time',
            value: DateFormat('dd MMM yyyy • hh:mm a').format(inspection.createdAt),
            icon: Icons.event_note_rounded,
          ),
          if (inspection.latitude != null && inspection.longitude != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InspectionMapScreen(
                      inspections: [inspection],
                      selectedInspection: inspection,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: NBROColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: NBROColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 18, color: NBROColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GPS Location',
                            style: TextStyle(fontSize: 11, color: NBROColors.grey, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${inspection.latitude!.toStringAsFixed(6)}, ${inspection.longitude!.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 13, color: NBROColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: NBROColors.primary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Timeline & Officer Audit Section
class _TimestampsSection extends StatelessWidget {
  final Inspection inspection;

  const _TimestampsSection({required this.inspection});

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MMM dd, yyyy • hh:mm a');

    return _SectionContainer(
      title: 'Timeline & Officer Audit',
      icon: Icons.history_rounded,
      child: Column(
        children: [
          _AuditItem(
            icon: Icons.add_circle_outline,
            label: 'Created On',
            date: dateFormatter.format(inspection.createdAt),
            officer: OfficerNameResolver.resolve(inspection.createdBy),
          ),
          if (inspection.updatedAt != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF0F0F0)),
            ),
            _AuditItem(
              icon: Icons.edit_calendar_outlined,
              label: 'Last Modified On',
              date: dateFormatter.format(inspection.updatedAt!),
              officer: OfficerNameResolver.resolve(inspection.updatedBy ?? inspection.createdBy),
            ),
          ],
        ],
      ),
    );
  }
}

/// General Observations Section
class _GeneralObservationsSection extends StatelessWidget {
  final Inspection inspection;

  const _GeneralObservationsSection({required this.inspection});

  @override
  Widget build(BuildContext context) {
    if (inspection.numberOfFloors == null && inspection.distanceFromRow == null) {
      return const SizedBox.shrink();
    }

    return _SectionContainer(
      title: 'Site Observations',
      icon: Icons.assignment_outlined,
      child: Column(
        children: [
          if (inspection.numberOfFloors != null)
            _DataRow(
              label: 'Number of Floors',
              value: inspection.numberOfFloors!,
            ),
          if (inspection.distanceFromRow != null)
            _DataRow(
              label: 'Distance from Right-of-Way (ROW)',
              value: '${inspection.distanceFromRow} meters',
            ),
        ],
      ),
    );
  }
}

/// External Services Section
class _ExternalServicesSection extends StatelessWidget {
  final Inspection inspection;

  const _ExternalServicesSection({required this.inspection});

  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      title: 'External Utility Services',
      icon: Icons.electrical_services_outlined,
      child: Row(
        children: [
          Expanded(
            child: _ServiceTile(
              icon: Icons.water_drop_outlined,
              label: 'Water Supply',
              hasService: inspection.hasPipeBorneWater ?? false,
              source: inspection.waterSource,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ServiceTile(
              icon: Icons.bolt_outlined,
              label: 'Electricity',
              hasService: inspection.hasElectricity ?? false,
              source: inspection.electricitySource,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ServiceTile(
              icon: Icons.sanitizer_outlined,
              label: 'Sewage',
              hasService: inspection.hasSewageWaste ?? false,
              source: inspection.sewageType,
            ),
          ),
        ],
      ),
    );
  }
}

/// Building Profile Section
class _BuildingProfileSection extends StatelessWidget {
  final Inspection inspection;

  const _BuildingProfileSection({required this.inspection});

  @override
  Widget build(BuildContext context) {
    final wallMap = (inspection.wallMaterials != null && inspection.wallMaterials!.isNotEmpty)
        ? inspection.wallMaterials!
        : {'Brickwork / Plastered': true};
    final doorMap = (inspection.doorMaterials != null && inspection.doorMaterials!.isNotEmpty)
        ? inspection.doorMaterials!
        : {'Timber Frames & Glass': true};
    final floorMap = (inspection.floorMaterials != null && inspection.floorMaterials!.isNotEmpty)
        ? inspection.floorMaterials!
        : {'Cement Rendered / Tiles': true};
    final roofMap = (inspection.roofMaterials != null && inspection.roofMaterials!.isNotEmpty)
        ? inspection.roofMaterials!
        : {'Timber Frame': true};

    return _SectionContainer(
      title: 'Building Material Specifications',
      icon: Icons.construction_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MaterialChipGroup(label: 'Wall Materials', materials: wallMap),
          const SizedBox(height: 12),
          _MaterialChipGroup(label: 'Door & Window Materials', materials: doorMap),
          const SizedBox(height: 12),
          _MaterialChipGroup(label: 'Floor Finish Materials', materials: floorMap),
          const SizedBox(height: 12),
          _MaterialChipGroup(label: 'Roof Frame & Cover', materials: roofMap),
          if (inspection.roofCovering != null && inspection.roofCovering!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MaterialChipGroup(label: 'Roof Covering', materials: {inspection.roofCovering!: true}),
          ],
        ],
      ),
    );
  }
}

/// Defects Section
class _DefectsSection extends StatelessWidget {
  final List<Defect> defects;

  const _DefectsSection({required this.defects});

  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      title: 'Defects Inventory (${defects.length})',
      icon: Icons.report_problem_outlined,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: defects.length,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final defect = defects[index];
          final hasPhoto = defect.photoUrl != null && defect.photoUrl!.isNotEmpty;

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: NBROColors.error.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: NBROColors.error,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        defect.notation.code,
                        style: const TextStyle(
                          color: NBROColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            defect.notation.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: NBROColors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Category: ${defect.category.displayName}',
                            style: const TextStyle(fontSize: 12, color: NBROColors.grey),
                          ),
                          if (defect.floorLevel != null && defect.floorLevel!.isNotEmpty)
                            Text(
                              'Floor: ${defect.floorLevel}',
                              style: const TextStyle(fontSize: 12, color: NBROColors.grey),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Dimension pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.straighten, size: 14, color: NBROColors.darkGrey),
                      const SizedBox(width: 6),
                      Text(
                        'Length: ${defect.lengthMm}mm${defect.widthMm != null ? '  ×  Width: ${defect.widthMm}mm' : ''}',
                        style: const TextStyle(fontSize: 12, color: NBROColors.darkGrey, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                if (defect.remarks != null && defect.remarks!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Notes: ${defect.remarks}',
                    style: const TextStyle(fontSize: 12, color: NBROColors.darkGrey, fontStyle: FontStyle.italic),
                  ),
                ],

                // Defect Photo Thumbnail
                if (hasPhoto) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _showImageViewer(context, defect.photoUrl!, defect.notation.displayName),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        color: Colors.grey.shade100,
                        child: Image.network(
                          defect.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.broken_image_outlined, color: NBROColors.grey),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Remarks Section
class _RemarksSection extends StatelessWidget {
  final String remarks;

  const _RemarksSection({required this.remarks});

  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      title: 'Additional Remarks',
      icon: Icons.notes_outlined,
      child: Text(
        remarks,
        style: const TextStyle(fontSize: 14, color: NBROColors.darkGrey, height: 1.5),
      ),
    );
  }
}

// ─── HELPER WIDGETS ──────────────────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: NBROColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: NBROColors.grey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, color: NBROColors.black, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String date;
  final String officer;

  const _AuditItem({
    required this.icon,
    required this.label,
    required this.date,
    required this.officer,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: NBROColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: NBROColors.grey, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                date,
                style: const TextStyle(fontSize: 13, color: NBROColors.black, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: NBROColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            officer,
            style: const TextStyle(fontSize: 11, color: NBROColors.primary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;

  const _DataRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: NBROColors.grey)),
          Text(value, style: const TextStyle(fontSize: 13, color: NBROColors.black, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool hasService;
  final String? source;

  const _ServiceTile({
    required this.icon,
    required this.label,
    required this.hasService,
    this.source,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasService ? const Color(0xFFF4FBF7) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasService ? NBROColors.success.withValues(alpha: 0.3) : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: hasService ? NBROColors.success : NBROColors.grey),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: NBROColors.grey, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            hasService ? 'Available' : 'N/A',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: hasService ? NBROColors.success : NBROColors.grey,
            ),
          ),
          if (source != null && source!.isNotEmpty && hasService) ...[
            const SizedBox(height: 2),
            Text(
              source!,
              style: const TextStyle(fontSize: 10, color: NBROColors.darkGrey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _MaterialChipGroup extends StatelessWidget {
  final String label;
  final Map<String, bool> materials;

  const _MaterialChipGroup({required this.label, required this.materials});

  @override
  Widget build(BuildContext context) {
    final selected = materials.entries.where((e) => e.value).map((e) => e.key).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: NBROColors.grey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: selected
              .map((material) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: NBROColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: NBROColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      material,
                      style: const TextStyle(fontSize: 12, color: NBROColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final SyncStatus status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == SyncStatus.synced ? NBROColors.success : NBROColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status == SyncStatus.synced ? Icons.check_circle : Icons.sync, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

class _PDFOptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PDFOptionButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: NBROColors.black)),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: NBROColors.grey)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

void _showImageViewer(BuildContext context, String imageUrl, String title) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => Scaffold(
        backgroundColor: NBROColors.black,
        appBar: AppBar(
          backgroundColor: NBROColors.black,
          title: Text(title, style: const TextStyle(color: NBROColors.white)),
          leading: IconButton(
            icon: const Icon(Icons.close, color: NBROColors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(Icons.broken_image_outlined, size: 64, color: NBROColors.white),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
