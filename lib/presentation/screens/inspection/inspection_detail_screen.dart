import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nbro_mobile_application/core/theme/app_theme.dart';
import 'package:nbro_mobile_application/domain/models/inspection.dart';
import 'package:nbro_mobile_application/data/services/pdf_report_service.dart';
import 'package:nbro_mobile_application/data/repositories/inspection_repository.dart';
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
  final InspectionRepository _repository = InspectionRepository();

  @override
  void initState() {
    super.initState();
    _currentInspection = widget.inspection;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
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
                        'PDF Report Options',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: NBROColors.black,
                        ),
                      ),
                      Text(
                        'Inspection ${_currentInspection.id}',
                        style: TextStyle(
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
              icon: Icons.visibility,
              label: 'Preview PDF',
              subtitle: 'View and download PDF',
              color: NBROColors.accent,
              onTap: () async {
                Navigator.of(context).pop();
                await _previewPDF(context);
              },
            ),
            const SizedBox(height: 12),
            _PDFOptionButton(
              icon: Icons.share,
              label: 'Share PDF',
              subtitle: 'Share via apps or email',
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
    // Show loading dialog
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
                Text('Preparing PDF...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Close loading dialog before showing PDF preview
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      // Generate and preview PDF
      await PDFReportService.previewPDF(_currentInspection);
      
      // Show helpful message after preview closes
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.download, color: NBROColors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tip: Use the save/download button in the preview to save PDF to your device',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: NBROColors.info,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Make sure loading dialog is closed
        Navigator.of(context).popUntil((route) => route.isFirst || !route.willHandlePopInternally);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error previewing PDF: $e'),
            backgroundColor: NBROColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _sharePDF(BuildContext context) async {
    // Show loading dialog
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
                Text('Preparing PDF to share...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final file = await PDFReportService.generateInspectionReport(_currentInspection);
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }
      
      // Share the PDF
      await PDFReportService.sharePDF(file, 'NBRO_Inspection_${_currentInspection.id}.pdf');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ PDF ready to share'),
            backgroundColor: NBROColors.success,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing PDF: $e'),
            backgroundColor: NBROColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
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
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              const Text('Delete Inspection'),
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
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This action cannot be undone!',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This will permanently delete:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('• Inspection data for $buildingRefNo'),
                Text('• All ${_currentInspection.defects.length} associated defects'),
                const Text('• All uploaded photos and documents'),
                const SizedBox(height: 20),
                const Text(
                  'To confirm deletion, please type the Building Reference Number:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SelectableText(
                    buildingRefNo,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmationController,
                  decoration: InputDecoration(
                    labelText: 'Type Building Reference Number',
                    hintText: buildingRefNo,
                    border: const OutlineInputBorder(),
                    errorText: canDelete == false && confirmationController.text.isNotEmpty
                        ? 'Building Reference Number does not match'
                        : null,
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
                confirmationController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: canDelete
                  ? () async {
                      confirmationController.dispose();
                      Navigator.pop(context);
                      await _deleteInspection();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: const Text('Delete Permanently'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteInspection() async {
    // Show loading dialog
    if (!mounted) return;
    
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
                Text('Deleting inspection...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await _repository.deleteInspection(_currentInspection.id);
      
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Inspection deleted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Pop back to list with refresh signal
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting inspection: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
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
        preferredSize: const Size.fromHeight(80),
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
              toolbarHeight: 80,
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: NBROColors.white),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Inspection Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: NBROColors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${_currentInspection.id}',
                    style: TextStyle(
                      fontSize: 13,
                      color: NBROColors.white.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: NBROColors.white),
                  tooltip: 'More actions',
                  onSelected: (value) async {
                    switch (value) {
                      case 'edit':
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
                        break;
                      case 'delete':
                        _showDeleteDialog();
                        break;
                      case 'pdf':
                        _generatePDFReport(context);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20, color: NBROColors.info),
                          SizedBox(width: 12),
                          Text('Edit Inspection'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'pdf',
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf, size: 20, color: NBROColors.primary),
                          SizedBox(width: 12),
                          Text('PDF Report'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: NBROColors.error),
                          SizedBox(width: 12),
                          Text('Delete Inspection'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Profile Header
            SliverToBoxAdapter(
              child: _ProfileHeader(inspection: _currentInspection),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Key Information Section
            SliverToBoxAdapter(
              child: _KeyInformationSection(inspection: _currentInspection),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Timestamps Section
            SliverToBoxAdapter(
              child: _TimestampsSection(inspection: _currentInspection),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // General Observations Section
            SliverToBoxAdapter(
              child: _GeneralObservationsSection(inspection: _currentInspection),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // External Services Section
            SliverToBoxAdapter(
              child: _ExternalServicesSection(inspection: _currentInspection),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Building Profile Section
            SliverToBoxAdapter(
              child: _BuildingProfileSection(inspection: _currentInspection),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Defects Section
            if (_currentInspection.defects.isNotEmpty)
              SliverToBoxAdapter(
                child: _DefectsSection(defects: _currentInspection.defects),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // Remarks Section
            if (_currentInspection.remarks != null &&
                _currentInspection.remarks!.isNotEmpty)
              SliverToBoxAdapter(
                child: _RemarksSection(remarks: _currentInspection.remarks!),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final Inspection inspection;

  const _ProfileHeader({required this.inspection});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            NBROColors.primary.withValues(alpha: 0.05),
            NBROColors.primaryLight.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: NBROColors.primary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [NBROColors.primary, NBROColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.business_center,
                  color: NBROColors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inspection.siteAddress,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: NBROColors.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: NBROColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ID: ${inspection.id}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: NBROColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Owner: ${inspection.ownerName}',
                            style: TextStyle(
                              fontSize: 14,
                              color: NBROColors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(status: inspection.syncStatus),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (inspection.contactNo != null && inspection.contactNo!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NBROColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone, size: 18, color: NBROColors.info),
                  const SizedBox(width: 12),
                  Text(
                    inspection.contactNo!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: NBROColors.info,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Building Front View Photo
          if (inspection.buildingPhotoUrl != null && inspection.buildingPhotoUrl!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
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
                  child: Hero(
                    tag: 'building_${inspection.id}',
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: NBROColors.light,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: NBROColors.grey.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              inspection.buildingPhotoUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.error_outline, size: 48, color: NBROColors.error),
                                      SizedBox(height: 8),
                                      Text('Failed to load image', style: TextStyle(color: NBROColors.error)),
                                    ],
                                  ),
                                );
                              },
                            ),
                            // Tap to view indicator
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: NBROColors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.zoom_in,
                                      size: 14,
                                      color: NBROColors.white,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Tap to view',
                                      style: TextStyle(
                                        color: NBROColors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
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
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _KeyInformationSection extends StatelessWidget {
  final Inspection inspection;

  const _KeyInformationSection({required this.inspection});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key Information',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: NBROColors.black,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _InfoCard(
                  label: 'Building Ref',
                  value: inspection.id,
                  icon: Icons.badge,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoCard(
                  label: 'Type',
                  value: inspection.typeOfStructure ?? 'N/A',
                  icon: Icons.domain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (inspection.latitude != null && inspection.longitude != null)
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
              child: _InfoCard(
                label: 'GPS Coordinates',
                value: '${inspection.latitude!.toStringAsFixed(6)}, ${inspection.longitude!.toStringAsFixed(6)}',
                icon: Icons.location_on,
                isClickable: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _TimestampsSection extends StatelessWidget {
  final Inspection inspection;

  const _TimestampsSection({required this.inspection});

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MMM dd, yyyy • hh:mm a');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Timeline & Modifications',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: NBROColors.black,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NBROColors.light,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: NBROColors.grey.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                _TimelineItem(
                  icon: Icons.add_circle,
                  label: 'Created',
                  date: dateFormatter.format(inspection.createdAt),
                  color: NBROColors.success,
                  officer: inspection.createdBy != null ? 'Officer: ${inspection.createdBy}' : null,
                ),
                if (inspection.updatedAt != null) ...[
                  const SizedBox(height: 16),
                  Divider(
                    height: 0,
                    color: NBROColors.grey.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  _TimelineItem(
                    icon: Icons.edit,
                    label: 'Last Modified',
                    date: dateFormatter.format(inspection.updatedAt!),
                    color: NBROColors.info,
                    officer: inspection.updatedBy != null ? 'Modified by: ${inspection.updatedBy}' : null,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneralObservationsSection extends StatelessWidget {
  final Inspection inspection;

  const _GeneralObservationsSection({required this.inspection});

  @override
  Widget build(BuildContext context) {
    if (inspection.ageOfStructure == null &&
        inspection.typeOfStructure == null &&
        inspection.presentCondition == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'General Observations',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: NBROColors.black,
            ),
          ),
          const SizedBox(height: 16),
          if (inspection.ageOfStructure != null)
            _DetailRow(
              label: 'Age of Structure',
              value: '${inspection.ageOfStructure} years',
              icon: Icons.calendar_today,
            ),
          if (inspection.presentCondition != null)
            _DetailRow(
              label: 'Present Condition',
              value: inspection.presentCondition!,
              icon: Icons.info,
            ),
          if (inspection.numberOfFloors != null)
            _DetailRow(
              label: 'Number of Floors',
              value: inspection.numberOfFloors!,
              icon: Icons.layers,
            ),
        ],
      ),
    );
  }
}

class _ExternalServicesSection extends StatelessWidget {
  final Inspection inspection;

  const _ExternalServicesSection({required this.inspection});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'External Services',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: NBROColors.black,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ServiceCard(
                  icon: Icons.water,
                  label: 'Water',
                  hasService: inspection.hasPipeBorneWater ?? false,
                  source: inspection.waterSource,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ServiceCard(
                  icon: Icons.electric_bolt,
                  label: 'Electricity',
                  hasService: inspection.hasElectricity ?? false,
                  source: inspection.electricitySource,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ServiceCard(
                  icon: Icons.plumbing,
                  label: 'Sewage',
                  hasService: inspection.hasSewageWaste ?? false,
                  source: inspection.sewageType,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BuildingProfileSection extends StatelessWidget {
  final Inspection inspection;

  const _BuildingProfileSection({required this.inspection});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Building Profile',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: NBROColors.black,
            ),
          ),
          const SizedBox(height: 16),
          if (inspection.wallMaterials != null && inspection.wallMaterials!.isNotEmpty)
            _MaterialsDisplay(
              label: 'Wall Materials',
              materials: inspection.wallMaterials!,
            ),
          if (inspection.doorMaterials != null && inspection.doorMaterials!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MaterialsDisplay(
              label: 'Door Materials',
              materials: inspection.doorMaterials!,
            ),
          ],
          if (inspection.floorMaterials != null && inspection.floorMaterials!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MaterialsDisplay(
              label: 'Floor Materials',
              materials: inspection.floorMaterials!,
            ),
          ],
          if (inspection.roofMaterials != null && inspection.roofMaterials!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MaterialsDisplay(
              label: 'Roof Materials',
              materials: inspection.roofMaterials!,
            ),
          ],
          if (inspection.roofCovering != null && inspection.roofCovering!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DetailRow(
              label: 'Roof Covering',
              value: inspection.roofCovering!,
              icon: Icons.roofing,
            ),
          ],
        ],
      ),
    );
  }
}

class _DefectsSection extends StatelessWidget {
  final List<Defect> defects;

  const _DefectsSection({required this.defects});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Defects Reported',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: NBROColors.black,
            ),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: defects.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final defect = defects[index];
              final hasPhoto = defect.photoUrl != null && defect.photoUrl!.isNotEmpty;
              
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NBROColors.error.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: NBROColors.error.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: NBROColors.error,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.warning_amber,
                            size: 16,
                            color: NBROColors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Category: ${defect.category.displayName}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: NBROColors.grey,
                                ),
                              ),
                              if (defect.floorLevel != null && defect.floorLevel!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Floor: ${defect.floorLevel}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: NBROColors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Defect Photo (if available)
                    if (hasPhoto) ...[
                      GestureDetector(
                        onTap: () => _showImageViewer(
                          context,
                          defect.photoUrl!,
                          'Defect: ${defect.notation.displayName}',
                        ),
                        child: Hero(
                          tag: 'defect_${defect.id}',
                          child: Container(
                            height: 180,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: NBROColors.light,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: NBROColors.grey.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    defect.photoUrl!,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                              : null,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.error_outline, size: 32, color: NBROColors.error),
                                            SizedBox(height: 8),
                                            Text('Failed to load image', style: TextStyle(color: NBROColors.error, fontSize: 12)),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  // Tap to view indicator
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: NBROColors.black.withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.zoom_in,
                                            size: 14,
                                            color: NBROColors.white,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Tap to view',
                                            style: TextStyle(
                                              color: NBROColors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
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
                      ),
                      const SizedBox(height: 8),
                    ],
                    
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: NBROColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.straighten,
                            size: 14,
                            color: NBROColors.info,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Length: ${defect.lengthMm}mm${defect.widthMm != null ? ' × Width: ${defect.widthMm}mm' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: NBROColors.darkGrey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (defect.remarks != null &&
                        defect.remarks!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: NBROColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.notes,
                              size: 14,
                              color: NBROColors.warning,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Note: ${defect.remarks}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: NBROColors.darkGrey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _RemarksSection extends StatelessWidget {
  final String remarks;

  const _RemarksSection({required this.remarks});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Remarks',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: NBROColors.black,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NBROColors.light,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: NBROColors.grey.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Text(
              remarks,
              style: TextStyle(
                fontSize: 14,
                color: NBROColors.darkGrey,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper Widgets
class _StatusBadge extends StatelessWidget {
  final SyncStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == SyncStatus.synced
        ? NBROColors.success
        : status == SyncStatus.syncing
            ? NBROColors.warning
            : NBROColors.error;

    final icon = status == SyncStatus.synced
        ? Icons.check_circle
        : status == SyncStatus.syncing
            ? Icons.sync
            : Icons.cloud_off;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            status.displayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isClickable;

  const _InfoCard({
    required this.label,
    required this.value,
    required this.icon,
    this.isClickable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NBROColors.light,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isClickable 
              ? NBROColors.primary.withValues(alpha: 0.3)
              : NBROColors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: NBROColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: NBROColors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isClickable) ...[
                const Spacer(),
                Icon(
                  Icons.open_in_new,
                  size: 14,
                  color: NBROColors.primary.withValues(alpha: 0.7),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: isClickable ? NBROColors.primary : NBROColors.black,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String date;
  final Color color;
  final String? officer;

  const _TimelineItem({
    required this.icon,
    required this.label,
    required this.date,
    required this.color,
    this.officer,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: NBROColors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 13,
                  color: NBROColors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (officer != null) ...[
                const SizedBox(height: 6),
                Text(
                  officer!,
                  style: TextStyle(
                    fontSize: 11,
                    color: NBROColors.grey.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: NBROColors.light,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: NBROColors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: NBROColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: NBROColors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: NBROColors.black,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
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

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool hasService;
  final String? source;

  const _ServiceCard({
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
        color: hasService
            ? NBROColors.success.withValues(alpha: 0.1)
            : NBROColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasService
              ? NBROColors.success.withValues(alpha: 0.2)
              : NBROColors.error.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: hasService ? NBROColors.success : NBROColors.error,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: NBROColors.darkGrey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasService ? 'Available' : 'Not Available',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: hasService ? NBROColors.success : NBROColors.error,
            ),
          ),
          if (source != null && source!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              source!,
              style: const TextStyle(
                fontSize: 10,
                color: NBROColors.grey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _MaterialsDisplay extends StatelessWidget {
  final String label;
  final Map<String, bool> materials;

  const _MaterialsDisplay({
    required this.label,
    required this.materials,
  });

  @override
  Widget build(BuildContext context) {
    final selected = materials.entries.where((e) => e.value).map((e) => e.key).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NBROColors.light,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: NBROColors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: NBROColors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selected
                .map((material) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: NBROColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: NBROColors.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                material,
                style: const TextStyle(
                  fontSize: 12,
                  color: NBROColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ))
                .toList(),
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: NBROColors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: NBROColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper function to show image viewer (used by multiple sections)
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
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                    color: NBROColors.white,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: NBROColors.error),
                      SizedBox(height: 16),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: NBROColors.white),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
