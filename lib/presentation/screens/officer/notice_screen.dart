import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nbro_mobile_application/core/theme/app_theme.dart';
import 'package:nbro_mobile_application/domain/models/notice.dart';
import 'package:nbro_mobile_application/presentation/widgets/branding.dart';

class NoticeScreen extends StatefulWidget {
  const NoticeScreen({super.key});

  @override
  State<NoticeScreen> createState() => _NoticeScreenState();
}

class _NoticeScreenState extends State<NoticeScreen> {
  List<Notice> _notices = [];
  final Map<String, String> _noticeTargetType = {};
  final Map<String, bool> _recipientReadState = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _notices = [];
          _isLoading = false;
        });
        return;
      }

      final noticesResponse = await Supabase.instance.client
          .from('notices')
          .select('id, title, message, priority, published_at, published_by_name, target_type')
          .order('published_at', ascending: false);

      final recipientsResponse = await Supabase.instance.client
          .from('notice_recipients')
          .select('notice_id, is_read')
          .eq('officer_id', user.id);

      final recipientMap = <String, bool>{};
      for (final row in (recipientsResponse as List)) {
        final noticeId = row['notice_id'] as String?;
        if (noticeId != null) {
          recipientMap[noticeId] = row['is_read'] as bool? ?? false;
        }
      }

      final List<Notice> parsed = [];
      final Map<String, String> targetTypeMap = {};

      for (final row in (noticesResponse as List)) {
        final json = row as Map<String, dynamic>;
        final noticeId = json['id'] as String;
        final targetType = (json['target_type'] as String?) ?? 'all';

        final isVisible = targetType == 'all' || recipientMap.containsKey(noticeId);
        if (!isVisible) continue;

        targetTypeMap[noticeId] = targetType;
        parsed.add(
          Notice(
            id: noticeId,
            title: json['title'] as String,
            message: json['message'] as String,
            publishedAt: DateTime.parse(json['published_at'] as String),
            publishedBy: json['published_by_name'] as String? ?? 'Admin',
            priority: NoticePriority.values.firstWhere(
              (e) => e.name == (json['priority'] as String? ?? 'normal'),
              orElse: () => NoticePriority.normal,
            ),
            isRead: recipientMap[noticeId] ?? true,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _recipientReadState
          ..clear()
          ..addAll(recipientMap);
        _noticeTargetType
          ..clear()
          ..addAll(targetTypeMap);
        _notices = parsed;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load notices: $e'),
          backgroundColor: NBROColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _markAsRead(Notice notice) async {
    setState(() {
      _notices = _notices
          .map((n) => n.id == notice.id ? n.copyWith(isRead: true) : n)
          .toList();
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client
          .from('notice_recipients')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('notice_id', notice.id)
          .eq('officer_id', user.id);
    } catch (_) {
      // Keep optimistic UI state; ignore update errors for UX continuity.
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notices.where((n) => !n.isRead).length;

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
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: NBROColors.white),
                iconSize: 24,
                padding: EdgeInsets.zero,
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              title: const NBROBrand(
                title: 'Notices',
                showFullName: true,
                logoSize: 60,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              titleSpacing: 4,
              actions: [
                if (unreadCount > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: NBROColors.error,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$unreadCount New',
                      style: const TextStyle(
                        color: NBROColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
          : _notices.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: NBROColors.grey.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_none,
                      size: 80,
                      color: NBROColors.grey.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No notices yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: NBROColors.darkGrey,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll see important announcements here',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: NBROColors.grey,
                        ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notices.length,
              itemBuilder: (context, index) {
                final notice = _notices[index];
                return _NoticeCard(
                  notice: notice,
                  onTap: () => _markAsRead(notice),
                );
              },
            ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final Notice notice;
  final VoidCallback onTap;

  const _NoticeCard({
    required this.notice,
    required this.onTap,
  });

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
      elevation: notice.isRead ? 1 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: notice.isRead
              ? NBROColors.grey.withValues(alpha: 0.2)
              : priorityColor.withValues(alpha: 0.3),
          width: notice.isRead ? 1 : 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: notice.isRead
                ? Colors.transparent
                : priorityColor.withValues(alpha: 0.05),
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
                          style: TextStyle(
                            fontWeight:
                                notice.isRead ? FontWeight.w600 : FontWeight.bold,
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
                  if (!notice.isRead)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: priorityColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                notice.message,
                style: TextStyle(
                  fontSize: 14,
                  color: NBROColors.darkGrey,
                  height: 1.5,
                ),
              ),
              if (notice.priority == NoticePriority.urgent ||
                  notice.priority == NoticePriority.high)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flag,
                          size: 14,
                          color: priorityColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          notice.priority.displayName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: priorityColor,
                            letterSpacing: 0.5,
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
    );
  }
}
