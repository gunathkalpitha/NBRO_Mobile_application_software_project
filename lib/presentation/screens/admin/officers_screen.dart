import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import 'dart:math';

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
  bool _obscurePassword = true;
  bool _isAutoGeneratePassword = true;

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

  String _generateRandomPassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#\$%^&*';
    final random = Random.secure();
    return List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
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

  // ─── Data ─────────────────────────────────────────────────────────────────────

  Future<void> _loadOfficers() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, email, full_name, role, created_at')
          .eq('role', 'officer')
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

    final password = _isAutoGeneratePassword
        ? _generateRandomPassword()
        : _passwordController.text.trim();

    if (!_isAutoGeneratePassword && password.isEmpty) {
      _showSnackBar('Please enter a password', isWarning: true);
      return;
    }

    if (password.length < 6) {
      _showSnackBar('Password must be at least 6 characters', isWarning: true);
      return;
    }

    // ✅ FIX: Get the access token from currentSession.
    // DO NOT use supabase.supabaseKey or supabase.httpClient — those
    // getters do not exist on SupabaseClient and cause compile errors.
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;

    if (token == null || token.isEmpty) {
      _showSnackBar(
        'Not authenticated. Please log out and log in again.',
        isError: true,
      );
      debugPrint(
        '[AddOfficer] ERROR: currentSession is null. '
        'This means Supabase.initialize() has not completed yet '
        'OR the user is not logged in. Check main.dart uses await.',
      );
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
      debugPrint('[AddOfficer] Invoking create-officer for: $email');
      debugPrint('[AddOfficer] Token length: ${token.length}');

      // ✅ FIX: Use supabase.functions.invoke() — this is the correct
      // Supabase Flutter API. It automatically attaches the auth token.
      // Raw http.post also works, but functions.invoke() is simpler and
      // uses the already-authenticated client.
      final response = await Supabase.instance.client.functions.invoke(
        'create-officer',
        body: {
          'email': email,
          'fullName': fullName,
          'password': password,
        },
      );

      debugPrint('[AddOfficer] Status: ${response.status}');
      debugPrint('[AddOfficer] Data:   ${response.data}');

      dismissLoading();

      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true) {
          _emailController.clear();
          _nameController.clear();
          _passwordController.clear();
          _showPasswordDialog(email, password);
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

    try {
      final client = Supabase.instance.client;
      try {
        await client.auth.admin.deleteUser(officerId);
      } catch (e) {
        debugPrint('Auth delete skipped (needs service role key): $e');
      }
      await client.from('profiles').delete().eq('id', officerId);
      await _loadOfficers();
      _showSnackBar('Officer removed successfully');
    } catch (e) {
      debugPrint('Error removing officer: $e');
      _showSnackBar('Error removing officer: $e', isError: true);
    }
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────────

  void _showAddOfficerDialog() {
    _emailController.clear();
    _nameController.clear();
    _passwordController.clear();
    setState(() {
      _isAutoGeneratePassword = true;
      _obscurePassword = true;
    });

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
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
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: NBROColors.light,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Auto-generate password'),
                  subtitle:
                      const Text('System will create a secure password'),
                  value: _isAutoGeneratePassword,
                  onChanged: (v) =>
                      setDialogState(() => _isAutoGeneratePassword = v),
                  contentPadding: EdgeInsets.zero,
                ),
                if (!_isAutoGeneratePassword) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setDialogState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: NBROColors.light,
                      helperText: 'Minimum 6 characters',
                    ),
                  ),
                ],
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
              onPressed: _addOfficer,
              icon: const Icon(Icons.add),
              label: const Text('Create Officer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: NBROColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPasswordDialog(String email, String password) {
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NBROColors.light,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: NBROColors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Login Credentials',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: NBROColors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.email,
                          size: 16, color: NBROColors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(email,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.lock,
                          size: 16, color: NBROColors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          password,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
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
                color: NBROColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: NBROColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Share these credentials with the officer. '
                      'They can change their password after first login.',
                      style:
                          TextStyle(fontSize: 12, color: NBROColors.info),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
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
                'The create-officer Edge Function needs to be deployed.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Run these commands:'),
              const SizedBox(height: 12),
              _codeBlock('npm install -g supabase'),
              const SizedBox(height: 8),
              _codeBlock('supabase functions deploy create-officer'),
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
                icon: const Icon(Icons.arrow_back, color: NBROColors.white),
                onPressed: () => Navigator.pop(context),
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
                                      officer['email'] ?? '',
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