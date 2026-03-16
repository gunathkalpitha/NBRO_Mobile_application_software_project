import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/app_shell.dart';

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

  // ✅ FIX: Removed _screenContext entirely. It is an antipattern that causes
  // stale context bugs. All dialogs and snackbars now use 'context' directly,
  // which is always valid inside mounted widget methods.

  @override
  void initState() {
    super.initState();
    _loadOfficers();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
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

  Widget _codeBlock(String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: NBROColors.darkGrey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        code,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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

  // ─── Data ─────────────────────────────────────────────────────────────────────

  Future<void> _loadOfficers() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('profile')
          .select('id, full_name, role, created_at')
          .eq('role', 'officer')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _officers = List<Map<String, dynamic>>.from(response as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading officers: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Error loading officers: $e', isError: true);
      }
    }
  }

  // ─── Add Officer ──────────────────────────────────────────────────────────────

  Future<void> _addOfficer() async {
    final email = _emailController.text.trim();
    final fullName = _nameController.text.trim();

    if (email.isEmpty || fullName.isEmpty) {
      _showSnackBar('Please enter email and name', isWarning: true);
      return;
    }

    // Close the add-officer dialog
    if (mounted) Navigator.pop(context);
    if (!mounted) return;

    // Show loading dialog and capture its context for safe dismissal
    BuildContext? loadingCtx;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        loadingCtx = ctx;
        return const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Sending invitation...'),
                ],
              ),
            ),
          ),
        );
      },
    );

    void dismissLoading() {
      final ctx = loadingCtx;
      if (ctx != null && ctx.mounted) {
        Navigator.of(ctx).pop();
      }
    }

    try {
      debugPrint('[AddOfficer] Invoking invite-officer for: $email');

      final response = await Supabase.instance.client.functions.invoke(
        'invite-officer',
        body: {
          'email': email,
          'fullName': fullName,
        },
      );

      debugPrint('[AddOfficer] Status: ${response.status}');
      debugPrint('[AddOfficer] Data:   ${response.data}');

      dismissLoading();

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
        debugPrint('[AddOfficer] Success flag: ${data['success']}');
        debugPrint('[AddOfficer] Password: ${data['password']}');
        
        if (data['success'] == true) {
          _emailController.clear();
          _nameController.clear();
          final password = data['password'] ?? 'N/A';
          debugPrint('[AddOfficer] Showing dialog with password: $password');
          _showInvitationSentDialog(email, password, fullName);
          await _loadOfficers();
        } else {
          throw Exception(data['error'] ?? 'Unknown error');
        }
      } else {
        final errData = response.data;
        final errMsg = errData is Map
            ? errData['error'] ?? 'HTTP ${response.status}'
            : 'HTTP ${response.status}';
        throw Exception(errMsg);
      }
    } catch (e) {
      debugPrint('[AddOfficer] Error: $e');
      dismissLoading();
      if (!mounted) return;

      final msg = e.toString();
      if (msg.contains('404') ||
          msg.contains('not found') ||
          msg.contains('FunctionsRelayError')) {
        _showEdgeFunctionSetupDialog();
      } else if (msg.contains('already exists') || msg.contains('409')) {
        _showSnackBar('Email already exists. Use a different email.',
            isError: true);
      } else {
        _showSnackBar('Error: $msg', isError: true);
      }
    }
  }

  // ─── Add Officer Directly (without email invitation) ─────────────────────────

  Future<void> _addOfficerDirect() async {
    final email = _emailController.text.trim();
    final fullName = _nameController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || fullName.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill all fields', isWarning: true);
      return;
    }

    if (password.length < 6) {
      _showSnackBar('Password must be at least 6 characters', isWarning: true);
      return;
    }

    Navigator.pop(context); // Close dialog

    BuildContext? loadingCtx;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        loadingCtx = ctx;
        return const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Creating officer account...'),
                ],
              ),
            ),
          ),
        );
      },
    );

    void dismissLoading() {
      final ctx = loadingCtx;
      if (ctx != null && ctx.mounted) {
        Navigator.of(ctx).pop();
      }
    }

    try {
      debugPrint('[AddOfficerDirect] Creating account for: $email');

      final response = await Supabase.instance.client.functions.invoke(
        'create-officer',
        body: {
          'email': email,
          'password': password,
          'fullName': fullName,
        },
      );

      debugPrint('[AddOfficerDirect] Status: ${response.status}');
      debugPrint('[AddOfficerDirect] Data: ${response.data}');

      dismissLoading();

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] != true) {
          throw Exception(data['error'] ?? 'Unknown error');
        }
        
        debugPrint('[AddOfficerDirect] Officer created successfully');

        _emailController.clear();
        _nameController.clear();
        _passwordController.clear();

        _showSnackBar('Officer account created successfully!');
        await _loadOfficers();
      } else {
        final errData = response.data;
        final errMsg = errData is Map
            ? errData['error'] ?? 'HTTP ${response.status}'
            : 'HTTP ${response.status}';
        throw Exception(errMsg);
      }
    } catch (e) {
      debugPrint('[AddOfficerDirect] Error: $e');
      dismissLoading();
      if (!mounted) return;

      final msg = e.toString();
      if (msg.contains('already exists') || msg.contains('duplicate') || msg.contains('409')) {
        _showSnackBar('Email already exists. Use a different email.',
            isError: true);
      } else {
        _showSnackBar('Error creating account: $msg', isError: true);
      }
    }
  }

  // ─── Remove Officer ───────────────────────────────────────────────────────────

  Future<void> _removeOfficer(String officerId, String officerName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_outlined, color: NBROColors.error),
            const SizedBox(width: 12),
            const Text('Remove Officer'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove $officerName? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: NBROColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;

    final deleteController = TextEditingController();
    final doubleConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isMatch = deleteController.text.trim().toUpperCase() == 'DELETE';
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.delete_forever, color: NBROColors.error),
                const SizedBox(width: 12),
                const Text('Confirm Deletion'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will disable $officerName\'s account. '
                  'They will no longer be able to log in.',
                ),
                const SizedBox(height: 12),
                const Text('Type DELETE to confirm.'),
                const SizedBox(height: 12),
                TextField(
                  controller: deleteController,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    hintText: 'DELETE',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: NBROColors.light,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isMatch ? () => Navigator.pop(ctx, true) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: NBROColors.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      ),
    );

    deleteController.dispose();

    if (doubleConfirmed != true) return;
    
    if (!mounted) return;

    try {
      final client = Supabase.instance.client;
      
      // Disable the officer account by setting is_active to false
      await client.from('profile').update({'is_active': false}).eq('id', officerId);
      
      // Remove immediately from UI for instant feedback
      if (mounted) {
        setState(() {
          _officers.removeWhere((officer) => officer['id'] == officerId);
        });
      }
      
      _showSnackBar('Officer account disabled successfully');
    } catch (e) {
      debugPrint('Error disabling officer: $e');
      _showSnackBar('Error disabling officer: $e', isError: true);
    }
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────────

  void _showAddOfficerDialog() {
    _emailController.clear();
    _nameController.clear();
    _passwordController.clear();

    // Show method selection dialog first
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
              child: const Icon(Icons.person_add, color: NBROColors.primary),
            ),
            const SizedBox(width: 12),
            const Text('Add New Officer'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose how to add the officer:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            
            // Option 1: Email Invitation
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
                subtitle: const Text('Officer signs in with Google account'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEmailInvitationDialog();
                },
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Option 2: Direct Creation
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
                subtitle: const Text('Set password without email (bypasses rate limit)'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDirectCreationDialog();
                },
              ),
            ),
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

  void _showEmailInvitationDialog() {
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
            const Text('Send Email Invitation'),
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
                  helperText: 'Officer will receive an invitation email',
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
            onPressed: _addOfficer,
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

  void _showDirectCreationDialog() {
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
            const Text('Create Account Directly'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NBROColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: NBROColors.warning, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Officer can login immediately with email and password',
                        style: TextStyle(fontSize: 12, color: NBROColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: NBROColors.light,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
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
            onPressed: _addOfficerDirect,
            icon: const Icon(Icons.add),
            label: const Text('Create Account'),
            style: ElevatedButton.styleFrom(
              backgroundColor: NBROColors.success,
            ),
          ),
        ],
      ),
    );
  }

  void _showInvitationSentDialog(String email, String password, String fullName) {
    showDialog(
      context: context,
      barrierDismissible: false,  // Prevent accidental dismissal
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: NBROColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.check_circle, color: NBROColors.success),
            ),
            const SizedBox(width: 12),
            const Text('Officer Created'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Officer account created successfully!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NBROColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NBROColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LOGIN CREDENTIALS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: NBROColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.email, size: 16, color: NBROColors.darkGrey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Email:',
                              style: TextStyle(
                                fontSize: 11,
                                color: NBROColors.darkGrey,
                              ),
                            ),
                            Text(
                              email,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: NBROColors.black,
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
                      const Icon(Icons.lock, size: 16, color: NBROColors.darkGrey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Password:',
                              style: TextStyle(
                                fontSize: 11,
                                color: NBROColors.darkGrey,
                              ),
                            ),
                            Text(
                              password,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: NBROColors.primary,
                                letterSpacing: 2,
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NBROColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NBROColors.warning.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: NBROColors.warning, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No email sent! You must share these credentials with the officer manually.',
                      style: TextStyle(
                        fontSize: 11,
                        color: NBROColors.warning,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NBROColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Instructions:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: NBROColors.info,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Copy or note down these credentials\n'
                    '2. Share with the officer via SMS/WhatsApp/Call\n'
                    '3. Officer opens the mobile app\n'
                    '4. Officer logs in with email and password',
                    style: TextStyle(
                      fontSize: 12,
                      color: NBROColors.info,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Copy credentials to clipboard
              final credentials = 'NBRO Login Credentials\n\nName: $fullName\nEmail: $email\nPassword: $password\n\nPlease log in to the NBRO Field Surveyor mobile app using these credentials.';
              // Simple text copy (you can add clipboard package for better UX)
              debugPrint('Credentials: $credentials');
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Credentials logged to console. Copy them to share with officer.'),
                  backgroundColor: NBROColors.info,
                ),
              );
            },
            child: const Text('Copy Info'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              backgroundColor: NBROColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showEdgeFunctionSetupDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: NBROColors.info),
            SizedBox(width: 12),
            Text('Edge Function Not Found'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The invite-officer Edge Function needs to be deployed.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Run these commands:'),
              const SizedBox(height: 12),
              _codeBlock('npm install -g supabase'),
              const SizedBox(height: 8),
              _codeBlock('supabase functions deploy invite-officer'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: NBROColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'See EDGE_FUNCTION_SETUP.md for detailed instructions.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

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
                    'Manage Officers',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: NBROColors.white,
                    ),
                  ),
                  Text(
                    'View, add, or remove officers',
                    style: TextStyle(fontSize: 12, color: NBROColors.white),
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
                valueColor:
                    AlwaysStoppedAnimation<Color>(NBROColors.primary),
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
                        'No officers yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: NBROColors.darkGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add your first officer to get started',
                        style: TextStyle(color: NBROColors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadOfficers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _officers.length,
                    itemBuilder: (context, index) {
                      final officer = _officers[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: NBROColors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: NBROColors.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: NBROColors.primary,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      officer['full_name'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: NBROColors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _officerSecondaryText(officer),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: NBROColors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: NBROColors.success
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'OFFICER',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: NBROColors.success,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                color: NBROColors.error,
                                onPressed: () => _removeOfficer(
                                  officer['id'],
                                  officer['full_name'] ?? 'this officer',
                                ),
                                tooltip: 'Remove Officer',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOfficerDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Officer'),
        backgroundColor: NBROColors.primary,
      ),
    );
  }
}