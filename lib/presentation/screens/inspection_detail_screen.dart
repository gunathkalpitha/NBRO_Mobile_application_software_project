import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/inspection.dart';
import '../../data/services/pdf_report_service.dart';

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

  @override
  void initState() {
    super.initState();
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
                        'Inspection ${widget.inspection.id}',
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
              subtitle: 'View before download or share',
              color: NBROColors.accent,
              onTap: () async {
                Navigator.of(context).pop();
                await _previewPDF(context);
              },
            ),
            const SizedBox(height: 12),
            _PDFOptionButton(
              icon: Icons.download,
              label: 'Download PDF',
              subtitle: 'Save to device storage',
              color: NBROColors.primary,
              onTap: () async {
                Navigator.of(context).pop();
                await _downloadPDF(context);
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
      // Generate PDF
      await PDFReportService.previewPDF(widget.inspection);
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
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

  Future<void> _downloadPDF(BuildContext context) async {
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
                Text('Downloading PDF...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final file = await PDFReportService.generateInspectionReport(widget.inspection);
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved to: ${file.path}'),
            backgroundColor: NBROColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OPEN',
              textColor: NBROColors.white,
              onPressed: () async {
                await PDFReportService.openPDF(file);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading PDF: $e'),
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
                Text('Preparing PDF...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final file = await PDFReportService.generateInspectionReport(widget.inspection);
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        // Share the PDF
        await PDFReportService.sharePDF(file, 'NBRO_Inspection_${widget.inspection.id}.pdf');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing PDF: $e'),
            backgroundColor: NBROColors.error,
            behavior: SnackBarBehavior.floating,
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
                children: [
                  const Text(
                    'Inspection Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: NBROColors.white,
                    ),
                  ),
                  Text(
                    'ID: ${widget.inspection.id}',
                    style: TextStyle(
                      fontSize: 12,
                      color: NBROColors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf, color: NBROColors.white),
                  onPressed: () {
                    _generatePDFReport(context);
                  },
                  tooltip: 'Generate PDF Report',
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: widget.inspection.syncStatus),
                const SizedBox(width: 16),
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
              child: _ProfileHeader(inspection: widget.inspection),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Key Information Section
            SliverToBoxAdapter(
              child: _KeyInformationSection(inspection: widget.inspection),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Timestamps Section
            SliverToBoxAdapter(
              child: _TimestampsSection(inspection: widget.inspection),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // General Observations Section
            SliverToBoxAdapter(
              child: _GeneralObservationsSection(inspection: widget.inspection),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // External Services Section
            SliverToBoxAdapter(
              child: _ExternalServicesSection(inspection: widget.inspection),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Building Profile Section
            SliverToBoxAdapter(
              child: _BuildingProfileSection(inspection: widget.inspection),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Defects Section
            if (widget.inspection.defects.isNotEmpty)
              SliverToBoxAdapter(
                child: _DefectsSection(defects: widget.inspection.defects),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // Remarks Section
            if (widget.inspection.remarks != null &&
                widget.inspection.remarks!.isNotEmpty)
              SliverToBoxAdapter(
                child: _RemarksSection(remarks: widget.inspection.remarks!),
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
                        fontSize: 18,
                        color: NBROColors.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Owner: ${inspection.ownerName}',
                      style: TextStyle(
                        fontSize: 14,
                        color: NBROColors.grey,
                      ),
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
            _InfoCard(
              label: 'GPS Coordinates',
              value: '${inspection.latitude!.toStringAsFixed(6)}, ${inspection.longitude!.toStringAsFixed(6)}',
              icon: Icons.location_on,
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
            'Timeline',
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

  const _InfoCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
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
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: NBROColors.black,
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

  const _TimelineItem({
    required this.icon,
    required this.label,
    required this.date,
    required this.color,
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
