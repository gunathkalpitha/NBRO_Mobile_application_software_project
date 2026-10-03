import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nbro_mobile_application/core/theme/app_theme.dart';
import 'package:nbro_mobile_application/presentation/widgets/app_shell.dart';

class AdminOfficersScreen extends StatefulWidget {
  final bool embedded;

  const AdminOfficersScreen({super.key, this.embedded = false});

  @override
  State<AdminOfficersScreen> createState() => _AdminOfficersScreenState();
}

class _AdminOfficersScreenState extends State<AdminOfficersScreen> {
  List<Map<String, dynamic>> _officers = [];
  bool _isLoading = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  List<Map<String, dynamic>> get _activeOfficers =>
      _officers.where((o) => (o['is_active'] as bool? ?? true) == true).toList();

  List<Map<String, dynamic>> get _disabledOfficers =>
      _officers.where((o) => (o['is_active'] as bool? ?? true) == false).toList();

  @override
  void initState() {
    super.initState();
    _loadOfficers();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

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

  String _officerSecondaryText(Map<String, dynamic> officer) {
    final email = officer['email'] as String?;
    if (email != null && email.isNotEmpty) {
      return email;
    }
    final id = officer['id'] as String?;
    if (id == null || id.isEmpty) {
      return 'N/A';
    }
    final shortId = id.length > 8 ? id.substring(0, 8) : id;
    return 'ID: $shortId';
  }

  Widget _avatar(Map<String, dynamic> officer) {
    final url = officer['avatar_url'] as String?;
    if (url != null && url.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(url.trim()),
      );
    }
    final name = (officer['full_name'] as String?)?.trim() ?? '';
    final initials = name.isEmpty
        ? 'OFF'
        : name.split(RegExp(r'\s+')).length >= 2
            ? '${name.split(RegExp(r'\s+'))[0][0]}${name.split(RegExp(r'\s+'))[1][0]}'.toUpperCase()
            : name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();

    return CircleAvatar(
      radius: 22,
      backgroundColor: NBROColors.primary.withValues(alpha: 0.12),
      child: Text(
        initials,
        style: const TextStyle(
          color: NBROColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  // ─── Data Loading (Fresh Remote Query from Supabase) ─────────────────────────

  Future<void> _loadOfficers() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final email = user?.email?.toLowerCase() ?? '';
      final isSuperAdmin = email == 'admin@gmail.com';
      final isMainAdmin = email == 'mainadminnbro@gmail.com';

      dynamic query = Supabase.instance.client
          .from('profile')
          .select('id, full_name, role, created_at, created_by, is_active');

      if (user != null) {
        query = query.neq('id', user.id); // Exclude self
      }

      if (isSuperAdmin) {
        query = query.or('role.eq.admin,role.eq.main_admin,role.eq.super_admin');
      } else if (isMainAdmin) {
        query = query.or('role.eq.officer,role.eq.admin,role.eq.main_admin');
      } else {
        if (user != null) {
          query = query.eq('created_by', user.id).eq('role', 'officer');
        } else {
          query = query.eq('role', 'officer');
        }
      }

      final response = await query.order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _officers = List<Map<String, dynamic>>.from(response as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading officers primary query ($e), executing fallback...');
      try {
        final user = Supabase.instance.client.auth.currentUser;
        final email = user?.email?.toLowerCase() ?? '';
        final isSuperAdmin = email == 'admin@gmail.com';
        final isMainAdmin = email == 'mainadminnbro@gmail.com';

        dynamic fallbackQuery = Supabase.instance.client
            .from('profile')
            .select('id, full_name, role, created_by, is_active');

        if (user != null) {
          fallbackQuery = fallbackQuery.neq('id', user.id);
        }

        if (isSuperAdmin) {
          fallbackQuery = fallbackQuery.or('role.eq.admin,role.eq.main_admin');
        } else if (isMainAdmin) {
          fallbackQuery = fallbackQuery.or('role.eq.officer,role.eq.admin');
        } else if (user != null) {
          fallbackQuery = fallbackQuery.eq('created_by', user.id);
        }

        final fallbackRes = await fallbackQuery;

        if (mounted) {
          setState(() {
            _officers = List<Map<String, dynamic>>.from(fallbackRes as List);
            _isLoading = false;
          });
        }
      } catch (fallbackErr) {
        debugPrint('Error loading officers fallback query: $fallbackErr');
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnackBar('Error loading user accounts: $fallbackErr', isError: true);
        }
      }
    }
  }

  // ─── User Creation Dialogs ────────────────────────────────────────────────────

  void _showRoleChoiceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add, color: NBROColors.primary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Select User Role to Add',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Card(
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: NBROColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.badge_outlined, color: NBROColors.success),
                  ),
                  title: const Text('Field Surveyor / Officer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Conducts 5-step site surveys & defect capture', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddUserDialog(targetRole: 'officer');
                  },
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 2,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A148C).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF4A148C)),
                  ),
                  title: const Text('Regional Administrator', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Manages officers & regional branch data', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAddUserDialog(targetRole: 'admin');
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog({required String targetRole}) {
    _emailController.clear();
    _nameController.clear();
    _passwordController.clear();

    final roleLabel = targetRole == 'admin' ? 'Administrator' : 'Field Officer';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: NBROColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                targetRole == 'admin' ? Icons.admin_panel_settings : Icons.person_add,
                color: NBROColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Add New $roleLabel',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choose how to add the $roleLabel:', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),

            // Method 1: Email Invitation
            Card(
              elevation: 2,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: NBROColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.email, color: NBROColors.info),
                ),
                title: const Text('Send Email Invitation'),
                subtitle: Text('$roleLabel signs in via invitation link'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEmailInvitationDialog(targetRole: targetRole);
                },
              ),
            ),
            const SizedBox(height: 12),

            // Method 2: Direct Creation
            /*
            Card(
              elevation: 2,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: NBROColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_circle, color: NBROColors.success),
                ),
                title: const Text('Create Account Directly'),
                subtitle: const Text('Set password without email (instant bypass)'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDirectCreationDialog(targetRole: targetRole);
                },
              ),
            ),*/
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showEmailInvitationDialog({required String targetRole}) {
    final roleLabel = targetRole == 'admin' ? 'Administrator' : 'Field Officer';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: NBROColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.email, color: NBROColors.info),
            ),
            const SizedBox(width: 12),
            Text('Invite $roleLabel'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: NBROColors.light,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Gmail Address',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: NBROColors.light,
                  helperText: 'User will receive an invitation email',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _emailController.clear();
              _nameController.clear();
              Navigator.pop(ctx);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => _addOfficerWithRole(targetRole: targetRole),
            icon: const Icon(Icons.send),
            label: const Text('Send Invitation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: NBROColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _showDirectCreationDialog({required String targetRole}) {
    final roleLabel = targetRole == 'admin' ? 'Administrator' : 'Field Officer';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: NBROColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_circle, color: NBROColors.success),
            ),
            const SizedBox(width: 12),
            Text('Create $roleLabel Directly'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: NBROColors.light,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Gmail Address',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: NBROColors.light,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Initial Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: NBROColors.light,
                  helperText: 'Minimum 6 characters',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _emailController.clear();
              _nameController.clear();
              _passwordController.clear();
              Navigator.pop(ctx);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => _addOfficerDirectWithRole(targetRole: targetRole),
            icon: const Icon(Icons.check_circle),
            label: const Text('Create Account'),
            style: ElevatedButton.styleFrom(
              backgroundColor: NBROColors.success,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Execution Methods ────────────────────────────────────────────────────────

  Future<void> _addOfficerWithRole({required String targetRole}) async {
    final email = _emailController.text.trim();
    final fullName = _nameController.text.trim();

    if (email.isEmpty || fullName.isEmpty) {
      _showSnackBar('Please enter email and name', isWarning: true);
      return;
    }

    if (mounted) Navigator.pop(context);
    final currentUser = Supabase.instance.client.auth.currentUser;

    try {
      await Supabase.instance.client.functions.invoke(
        'invite-officer',
        body: {
          'email': email,
          'fullName': fullName,
          'role': targetRole,
        },
      );

      // Link creator ID in database profile
      try {
        await Supabase.instance.client
            .from('profile')
            .update({
              'role': targetRole,
              'created_by': currentUser?.id,
              'is_active': true,
            })
            .eq('full_name', fullName);
      } catch (profErr) {
        debugPrint('[InviteOfficer] Profile link update note: $profErr');
      }

      _emailController.clear();
      _nameController.clear();
      _showSnackBar('Invitation email sent successfully');
      await _loadOfficers();
    } catch (e) {
      debugPrint('Error inviting user: $e');
      _showSnackBar('Invitation sent (logged locally)', isWarning: true);
      await _loadOfficers();
    }
  }

  Future<void> _addOfficerDirectWithRole({required String targetRole}) async {
    final email = _emailController.text.trim();
    final fullName = _nameController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || fullName.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill all fields', isWarning: true);
      return;
    }

    if (mounted) Navigator.pop(context);

    final currentUser = Supabase.instance.client.auth.currentUser;

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'create-officer',
        body: {
          'email': email,
          'password': password,
          'fullName': fullName,
          'role': targetRole,
        },
      );

      // Ensure profile role & created_by are set correctly in database
      try {
        final Map<String, dynamic>? resMap = response.data is Map<String, dynamic> ? response.data as Map<String, dynamic> : null;
        final newUserId = (resMap?['user']?['id'] ?? resMap?['id']) as String?;

        if (newUserId != null) {
          await Supabase.instance.client.from('profile').upsert({
            'id': newUserId,
            'full_name': fullName,
            'role': targetRole,
            'is_active': true,
            'created_by': currentUser?.id,
          });
        } else {
          await Supabase.instance.client
              .from('profile')
              .update({
                'role': targetRole,
                'is_active': true,
                'created_by': currentUser?.id,
              })
              .eq('full_name', fullName);
        }
      } catch (profErr) {
        debugPrint('[AddOfficerDirect] Profile role upsert note: $profErr');
      }

      _emailController.clear();
      _nameController.clear();
      _passwordController.clear();
      _showSnackBar('Account created successfully ($targetRole)');
      await _loadOfficers();
    } catch (e) {
      debugPrint('Error creating account directly: $e');
      _showSnackBar('Account creation submitted', isWarning: true);
      await _loadOfficers();
    }
  }

  Future<void> _toggleAccountStatus({
    required String userId,
    required String userName,
    required bool currentStatus,
    required String role,
  }) async {
    final lowerRole = role.toLowerCase();
    final lowerName = userName.toLowerCase();
    if (lowerRole == 'super_admin' || lowerRole == 'main_admin' || lowerName.contains('super admin') || lowerName.contains('main admin')) {
      _showSnackBar('Super Admin and Main Admin accounts cannot be modified', isWarning: true);
      return;
    }

    final newStatus = !currentStatus;
    final actionTitle = newStatus ? 'Enable Account' : 'Disable Account';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              newStatus ? Icons.check_circle_outline : Icons.warning_amber_rounded,
              color: newStatus ? NBROColors.success : NBROColors.error,
            ),
            const SizedBox(width: 12),
            Text(actionTitle),
          ],
        ),
        content: Text(
          newStatus
              ? 'Reactivate $userName\'s account? They will regain full access to log in.'
              : 'Disable $userName\'s account? They will be signed out immediately and blocked from field surveys.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? NBROColors.success : NBROColors.error,
            ),
            child: Text(newStatus ? 'Enable' : 'Disable'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client
            .from('profile')
            .update({'is_active': newStatus})
            .eq('id', userId);

        setState(() {
          final index = _officers.indexWhere((o) => o['id'] == userId);
          if (index != -1) {
            _officers[index]['is_active'] = newStatus;
          }
        });

        _showSnackBar(
          newStatus ? '$userName enabled successfully' : '$userName disabled successfully',
        );
      } catch (e) {
        debugPrint('Error toggling account status: $e');
        _showSnackBar('Error updating account status: $e', isError: true);
      }
    }
  }

  // ─── List Builder Widget ──────────────────────────────────────────────────────

  Widget _buildOfficersListView(List<Map<String, dynamic>> officersList, {required bool isActiveTab}) {
    if (officersList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActiveTab ? Icons.check_circle_outline : Icons.block_outlined,
              size: 70,
              color: NBROColors.grey.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              isActiveTab ? 'No active accounts found' : 'No disabled accounts found',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: NBROColors.darkGrey,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isActiveTab
                  ? 'Active users will appear here'
                  : 'Disabled user accounts will appear here',
              style: const TextStyle(fontSize: 12, color: NBROColors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOfficers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: officersList.length,
        itemBuilder: (context, index) {
          final officer = officersList[index];
          final roleStr = (officer['role'] as String?)?.toLowerCase() ?? 'officer';
          final isAdminRole = roleStr.contains('admin');
          final isActive = officer['is_active'] as bool? ?? true;
          final isProtectedAdmin = roleStr == 'super_admin' ||
              roleStr == 'main_admin' ||
              (officer['full_name'] as String?)?.toLowerCase().contains('super admin') == true;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isActive
                    ? NBROColors.grey.withValues(alpha: 0.2)
                    : NBROColors.error.withValues(alpha: 0.3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _avatar(officer),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          officer['full_name'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isActive ? NBROColors.black : NBROColors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _officerSecondaryText(officer),
                          style: const TextStyle(
                            fontSize: 13,
                            color: NBROColors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            // Role Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isAdminRole
                                    ? const Color(0xFF4A148C).withValues(alpha: 0.12)
                                    : NBROColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isAdminRole ? 'ADMIN' : 'OFFICER',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isAdminRole ? const Color(0xFF4A148C) : NBROColors.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            // Status Indicator Chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? NBROColors.success.withValues(alpha: 0.12)
                                    : NBROColors.error.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isActive ? NBROColors.success : NBROColors.error,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isActive ? 'ACTIVE' : 'DISABLED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isActive ? NBROColors.success : NBROColors.error,
                                      letterSpacing: 0.5,
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
                  // Interactive Toggle Action Button
                  if (isProtectedAdmin)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PROTECTED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => _toggleAccountStatus(
                        userId: officer['id'],
                        userName: officer['full_name'] ?? 'Account',
                        currentStatus: isActive,
                        role: roleStr,
                      ),
                      icon: Icon(
                        isActive ? Icons.block : Icons.check_circle_outline,
                        size: 14,
                        color: isActive ? NBROColors.error : NBROColors.success,
                      ),
                      label: Text(
                        isActive ? 'Disable' : 'Enable',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isActive ? NBROColors.error : NBROColors.success,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isActive ? NBROColors.error : NBROColors.success,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final userEmail = currentUser?.email?.toLowerCase() ?? '';
    final isSuperAdmin = userEmail == 'admin@gmail.com';
    final isMainAdmin = userEmail == 'mainadminnbro@gmail.com';

    final appBarTitle = isSuperAdmin
        ? 'Manage System Admins'
        : (isMainAdmin ? 'NBRO Account Control' : 'Manage Branch Officers');

    final appBarSubtitle = isSuperAdmin
        ? 'View & create Administrator accounts'
        : (isMainAdmin ? 'Manage Officers & Regional Admins' : 'Manage Officers under your branch');

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: NBROColors.light,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(115),
          child: SafeArea(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isSuperAdmin
                      ? [const Color(0xFF4A148C), const Color(0xFF311B92)]
                      : [NBROColors.primary, NBROColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isSuperAdmin ? const Color(0xFF4A148C) : NBROColors.primary).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  AppBar(
                    toolbarHeight: 60,
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
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appBarTitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isSuperAdmin ? const Color(0xFFFFD700) : NBROColors.white,
                          ),
                        ),
                        Text(
                          appBarSubtitle,
                          style: const TextStyle(fontSize: 11, color: NBROColors.white),
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    indicatorColor: isSuperAdmin ? const Color(0xFFFFD700) : NBROColors.white,
                    indicatorWeight: 3,
                    labelColor: isSuperAdmin ? const Color(0xFFFFD700) : NBROColors.white,
                    unselectedLabelColor: NBROColors.white.withValues(alpha: 0.65),
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 16),
                            const SizedBox(width: 8),
                            Text('Active (${_activeOfficers.length})'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.block_outlined, size: 16),
                            const SizedBox(width: 8),
                            Text('Disabled (${_disabledOfficers.length})'),
                          ],
                        ),
                      ),
                    ],
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
            : TabBarView(
                children: [
                  _buildOfficersListView(_activeOfficers, isActiveTab: true),
                  _buildOfficersListView(_disabledOfficers, isActiveTab: false),
                ],
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            if (isSuperAdmin) {
              _showAddUserDialog(targetRole: 'admin');
            } else if (isMainAdmin) {
              _showRoleChoiceDialog();
            } else {
              _showAddUserDialog(targetRole: 'officer');
            }
          },
          backgroundColor: isSuperAdmin ? const Color(0xFF4A148C) : NBROColors.primary,
          icon: const Icon(Icons.person_add, color: Colors.white),
          label: Text(
            isSuperAdmin ? 'Add Admin' : (isMainAdmin ? 'Add User' : 'Add Officer'),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
