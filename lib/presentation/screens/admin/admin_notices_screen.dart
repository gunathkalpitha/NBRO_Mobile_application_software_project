import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/models/notice.dart';
import '../../widgets/app_shell.dart';

enum NoticeTargetType { all, individual, selected }

class AdminNoticesScreen extends StatefulWidget {
  final bool embedded;

  const AdminNoticesScreen({super.key, this.embedded = false});

  @override
  State<AdminNoticesScreen> createState() => _AdminNoticesScreenState();
}

class _AdminNoticesScreenState extends State<AdminNoticesScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  NoticePriority _priority = NoticePriority.normal;
  NoticeTargetType _targetType = NoticeTargetType.all;

  List<Map<String, dynamic>> _officers = [];
  String? _selectedOfficerId;
  final Set<String> _selectedOfficerIds = {};

  bool _isLoading = true;
  bool _isSending = false;
  List<Notice> _notices = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    await Future.wait([
      _loadOfficers(),
      _loadNotices(),
    ]);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadOfficers() async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, email, full_name')
          .eq('role', 'officer')
          .eq('is_active', true)
          .order('full_name', ascending: true);

      if (mounted) {
        setState(() {
          _officers = List<Map<String, dynamic>>.from(response as List);
        });
      }
    } catch (e) {
      _showSnackBar('Error loading officers: $e', isError: true);
    }
  }

  Future<void> _loadNotices() async {
    try {
      final response = await Supabase.instance.client
          .from('notices')
          .select('id, title, message, priority, published_at, published_by_name')
          .order('published_at', ascending: false);

      final notices = (response as List)
          .map((json) => Notice(
                id: json['id'] as String,
                title: json['title'] as String,
                message: json['message'] as String,
                publishedAt: DateTime.parse(json['published_at'] as String),
                publishedBy: json['published_by_name'] as String? ?? 'Admin',
                priority: NoticePriority.values.firstWhere(
                  (e) => e.name == (json['priority'] as String? ?? 'normal'),
                  orElse: () => NoticePriority.normal,
                ),
              ))
          .toList();

      if (mounted) {
        setState(() {
          _notices = notices;
        });
      }
    } catch (e) {
      _showSnackBar('Error loading notices: $e', isError: true);
    }
  }

  Future<void> _sendNotice() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      _showSnackBar('Please enter title and message', isWarning: true);
      return;
    }

    if (_targetType == NoticeTargetType.individual && _selectedOfficerId == null) {
      _showSnackBar('Select an officer to send', isWarning: true);
      return;
    }

    if (_targetType == NoticeTargetType.selected && _selectedOfficerIds.isEmpty) {
      _showSnackBar('Select at least one officer', isWarning: true);
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final publishedByName = user?.userMetadata?['full_name'] ??
          user?.userMetadata?['name'] ??
          user?.email?.split('@').first ??
          'Admin';

      final targetType = _targetType.name;

      final noticeResponse = await Supabase.instance.client
          .from('notices')
          .insert({
            'title': title,
            'message': message,
            'priority': _priority.name,
            'target_type': targetType,
            'published_by': user?.id,
            'published_by_name': publishedByName,
          })
          .select('id')
          .single();

      final noticeId = noticeResponse['id'] as String;

        final recipients = _targetType == NoticeTargetType.all
          ? _officers
            .map((officer) => officer['id'] as String)
            .toList()
          : _targetType == NoticeTargetType.individual
            ? [_selectedOfficerId!]
            : _selectedOfficerIds.toList();

        if (recipients.isNotEmpty) {
        final rows = recipients
            .map((officerId) => {
                  'notice_id': noticeId,
                  'officer_id': officerId,
              'is_read': false,
                })
            .toList();

        await Supabase.instance.client.from('notice_recipients').insert(rows);
      }

      _titleController.clear();
      _messageController.clear();
      _selectedOfficerId = null;
      _selectedOfficerIds.clear();
      _priority = NoticePriority.normal;
      _targetType = NoticeTargetType.all;

      _showSnackBar('Notice sent successfully');
      await _loadNotices();
    } catch (e) {
      _showSnackBar('Failed to send notice: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _showSnackBar(
    String message, {
    bool isError = false,
    bool isWarning = false,
  }) {
    if (!mounted) return;
    final color = isError
        ? NBROColors.error
        : isWarning
            ? NBROColors.darkGrey
            : NBROColors.success;
    final icon = isError
        ? Icons.error_outline
        : isWarning
            ? Icons.warning_amber_outlined
            : Icons.check_circle;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: NBROColors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
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
              leadingWidth: 48,
              leading: widget.embedded
                  ? IconButton(
                      icon: const Icon(Icons.menu, color: NBROColors.white),
                      iconSize: 24,
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        NavRailController.toggleVisibility();
                      },
                    )
                  : IconButton(
                      icon: const Icon(Icons.arrow_back, color: NBROColors.white),
                      iconSize: 24,
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
              title: const Text(
                'Notices',
                style: TextStyle(
                  color: NBROColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              titleSpacing: 4,
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
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildComposeCard(),
                    const SizedBox(height: 24),
                    Text(
                      'Recent Notices',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: NBROColors.black,
                          ),
                    ),
                    const SizedBox(height: 12),
                    if (_notices.isEmpty)
                      _buildEmptyState()
                    else
                      ..._notices.map((notice) => _NoticeCard(notice: notice)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildComposeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Notice',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: NBROColors.black,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<NoticePriority>(
              value: _priority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
              ),
              items: NoticePriority.values
                  .map(
                    (priority) => DropdownMenuItem(
                      value: priority,
                      child: Text(priority.displayName),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _priority = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Send To',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All Officers'),
                  selected: _targetType == NoticeTargetType.all,
                  onSelected: (_) {
                    setState(() {
                      _targetType = NoticeTargetType.all;
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Individual'),
                  selected: _targetType == NoticeTargetType.individual,
                  onSelected: (_) {
                    setState(() {
                      _targetType = NoticeTargetType.individual;
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Selected Officers'),
                  selected: _targetType == NoticeTargetType.selected,
                  onSelected: (_) {
                    setState(() {
                      _targetType = NoticeTargetType.selected;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_targetType == NoticeTargetType.individual)
              _buildOfficerDropdown()
            else if (_targetType == NoticeTargetType.selected)
              _buildOfficerMultiSelect(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _sendNotice,
                icon: const Icon(Icons.send),
                label: Text(_isSending ? 'Sending...' : 'Send Notice'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: NBROColors.primary,
                  foregroundColor: NBROColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficerDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedOfficerId,
      decoration: const InputDecoration(
        labelText: 'Select Officer',
        border: OutlineInputBorder(),
      ),
      items: _officers
          .map(
            (officer) => DropdownMenuItem<String>(
              value: officer['id'] as String,
              child: Text(
                officer['full_name'] ?? officer['email'] ?? 'Unknown Officer',
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedOfficerId = value;
        });
      },
    );
  }

  Widget _buildOfficerMultiSelect() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _officers.map((officer) {
        final officerId = officer['id'] as String;
        final isSelected = _selectedOfficerIds.contains(officerId);
        return FilterChip(
          label: Text(
            officer['full_name'] ?? officer['email'] ?? 'Unknown Officer',
          ),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedOfficerIds.add(officerId);
              } else {
                _selectedOfficerIds.remove(officerId);
              }
            });
          },
          selectedColor: NBROColors.primary.withValues(alpha: 0.2),
          checkmarkColor: NBROColors.primary,
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: NBROColors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: NBROColors.grey.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            'No notices yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: NBROColors.darkGrey,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a notice to notify officers',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: NBROColors.grey,
                ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final Notice notice;

  const _NoticeCard({required this.notice});

  Color _getPriorityColor() {
    switch (notice.priority) {
      case NoticePriority.urgent:
        return NBROColors.error;
      case NoticePriority.high:
        return NBROColors.accent;
      case NoticePriority.normal:
        return NBROColors.info;
      case NoticePriority.low:
        return NBROColors.grey;
    }
  }

  IconData _getPriorityIcon() {
    switch (notice.priority) {
      case NoticePriority.urgent:
        return Icons.error;
      case NoticePriority.high:
        return Icons.priority_high;
      case NoticePriority.normal:
        return Icons.info;
      case NoticePriority.low:
        return Icons.notes;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _getPriorityColor();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: priorityColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: priorityColor.withValues(alpha: 0.05),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getPriorityIcon(),
                    color: priorityColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notice.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: NBROColors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'By ${notice.publishedBy} • ${_formatDate(notice.publishedAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: NBROColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    notice.priority.displayName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: priorityColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              notice.message,
              style: const TextStyle(
                fontSize: 13,
                color: NBROColors.darkGrey,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
