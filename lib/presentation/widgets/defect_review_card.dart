import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/inspection.dart';

class DefectReviewCard extends StatefulWidget {
  final Defect defect;
  final Function(Defect) onDefectUpdate;
  final Function() onDefectDelete;

  const DefectReviewCard({
    super.key,
    required this.defect,
    required this.onDefectUpdate,
    required this.onDefectDelete,
  });

  @override
  State<DefectReviewCard> createState() => _DefectReviewCardState();
}

class _DefectReviewCardState extends State<DefectReviewCard> {
  late TextEditingController _lengthController;
  late TextEditingController _widthController;
  late TextEditingController _remarksController;
  late DefectNotation _selectedType;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _lengthController = TextEditingController(text: widget.defect.lengthMm.toString());
    _widthController = TextEditingController(text: widget.defect.widthMm?.toString() ?? '0');
    _remarksController = TextEditingController(text: widget.defect.remarks ?? '');
    _selectedType = widget.defect.notation;
  }

  @override
  void dispose() {
    _lengthController.dispose();
    _widthController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    final updatedDefect = Defect(
      id: widget.defect.id,
      inspectionId: widget.defect.inspectionId,
      notation: _selectedType,
      category: widget.defect.category,
      floorLevel: widget.defect.floorLevel,
      lengthMm: double.parse(_lengthController.text),
      widthMm: double.tryParse(_widthController.text),
      photoPath: widget.defect.photoPath,
      remarks: _remarksController.text.isNotEmpty ? _remarksController.text : null,
      createdAt: widget.defect.createdAt,
    );

    widget.onDefectUpdate(updatedDefect);
    setState(() => _isEditing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Defect updated successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with type and action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Defect: ${widget.defect.notation.displayName}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: NBROColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${widget.defect.id.substring(0, 8)}...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isEditing)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: NBROColors.primary),
                        onPressed: () => setState(() => _isEditing = true),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: NBROColors.error),
                        onPressed: widget.onDefectDelete,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Content
            if (_isEditing)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type Dropdown
                  Text('Type', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<DefectNotation>(
                    initialValue: _selectedType,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: DefectNotation.values.map((notation) {
                      return DropdownMenuItem(
                        value: notation,
                        child: Text(notation.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Dimensions
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Length (mm)', style: Theme.of(context).textTheme.bodyLarge),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _lengthController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.straighten),
                                hintText: 'e.g., 150',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Width (mm)', style: Theme.of(context).textTheme.bodyLarge),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _widthController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.straighten),
                                hintText: 'e.g., 100',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Remarks
                  Text('Remarks', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _remarksController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Add any additional remarks...',
                      prefixIcon: Icon(Icons.note_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => setState(() => _isEditing = false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _saveChanges,
                        child: const Text('Save Changes'),
                      ),
                    ],
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Type', widget.defect.notation.displayName),
                  _buildDetailRow('Length', '${widget.defect.lengthMm.toStringAsFixed(2)} mm'),
                  _buildDetailRow('Width', '${widget.defect.widthMm?.toStringAsFixed(2) ?? '-'} mm'),
                  if (widget.defect.photoPath != null)
                    _buildDetailRow('Photo', widget.defect.photoPath!.split('/').last)
                  else
                    _buildDetailRow('Photo', 'Not captured (skipped)'),
                  if (widget.defect.remarks != null)
                    _buildDetailRow('Remarks', widget.defect.remarks!),
                  _buildDetailRow('Created', _formatDate(widget.defect.createdAt)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
  }
}
