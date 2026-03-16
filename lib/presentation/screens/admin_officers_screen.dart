import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
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

  Future<void> _loadOfficers() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      
   
      dynamic response;
      
      // DEBUGGING: First check ALL profiles to see what's in the database
      try {
        final debugResponse = await supabase
            .from('profile')
            .select('id, full_name, role, created_at')
            .order('created_at', ascending: false);
        debugPrint('🔍 DEBUG: Total profiles in database: ${(debugResponse as List).length}');
        for (var profile in debugResponse) {
          debugPrint('   - ${profile['id']} | Role: ${profile['role']} | Name: ${profile['full_name']}');
        }
      } catch (e) {
        debugPrint('🔍 DEBUG: Could not fetch all profiles: $e');
      }
      
      try {
        response = await supabase
          .from('profile')
          .select('id, full_name, role, created_at')
            .eq('role', 'officer')
            .order('created_at', ascending: false);
        debugPrint('✅ Loaded officers from "profiles" table (plural)');
      } catch (pluralError) {
        debugPrint('⚠️ Failed to load from "profiles": $pluralError');
        debugPrint('🔄 Trying singular table name "profile"...');
        
        // Fallback to singular table name (old schema)
        try {
          response = await supabase
              .from('profile')
              .select('id, full_name, role, created_at')
              .eq('role', 'officer')
              .order('created_at', ascending: false);
          debugPrint('✅ Loaded officers from "profile" table (singular)');
        } catch (singularError) {
          debugPrint('❌ Failed to load from "profile": $singularError');
          throw Exception('Could not load officers from either "profiles" or "profile" table. Error: $pluralError');
        }
      }

      setState(() {
        _officers = List<Map<String, dynamic>>.from(response as List);
        _isLoading = false;
      });
      
      debugPrint('📊 Loaded ${_officers.length} officer(s) with role="officer"');
      if (_officers.isEmpty) {
        debugPrint('⚠️ WARNING: No officers found! This could mean:');
        debugPrint('   1. No officer profiles exist in the database');
        debugPrint('   2. Officers exist but with role != "officer"');
        debugPrint('   3. The handle_new_user() trigger is not creating profiles');
        debugPrint('   4. Check Supabase Dashboard > Database > profiles table');
      }
    } catch (e) {
      debugPrint('❌ Error loading officers: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: NBROColors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error loading officers: $e')),
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

  Future<void> _addOfficer() async {
    // Validate inputs
    if (_emailController.text.trim().isEmpty || _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: NBROColors.white),
              SizedBox(width: 12),
              Text('Please enter email and name'),
            ],
          ),
          backgroundColor: NBROColors.darkGrey,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Generate or use provided password
    final password = _isAutoGeneratePassword 
        ? _generateRandomPassword() 
        : _passwordController.text.trim();

    if (!_isAutoGeneratePassword && password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: NBROColors.white),
              SizedBox(width: 12),
              Text('Please enter a password'),
            ],
          ),
          backgroundColor: NBROColors.darkGrey,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: NBROColors.white),
              SizedBox(width: 12),
              Text('Password must be at least 6 characters'),
            ],
          ),
          backgroundColor: NBROColors.darkGrey,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Close add officer dialog and show loading
    Navigator.pop(context);
    
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
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
      ),
    );

    try {
      final supabase = Supabase.instance.client;
      final email = _emailController.text.trim();
      final fullName = _nameController.text.trim();
      
      debugPrint('Creating officer: email=$email, fullName=$fullName');
      
      // Use Supabase functions.invoke() - the proper SDK method
      final response = await supabase.functions.invoke(
        'create-officer',
        body: {
          'email': email,
          'fullName': fullName,
          'password': password,
        },
      );

      if (!mounted) return;
      Navigator.pop(context);

      // FunctionResponse has a 'data' property that contains the body
      final Map<String, dynamic> data = response.data is Map ? response.data : {};
      
      if (data['success'] == true) {
        debugPrint('✅ Officer created successfully: $email');
        debugPrint('🔄 Reloading officers list...');
        
        // Reload the officers list BEFORE showing the dialog
        await _loadOfficers();
        
        // Show password dialog
        _showPasswordDialog(email, password);
        
        // Clear form
        _emailController.clear();
        _nameController.clear();
        _passwordController.clear();
      } else {
        final error = data['error'] ?? 'Unknown error';
        throw Exception(error);
      }
      
    } catch (e) {
      debugPrint('Error adding officer: $e');
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      
      // Check if it's an edge function not found error
      final errorMessage = e.toString();
      if (errorMessage.contains('FunctionsRelayError') || 
          errorMessage.contains('not found') ||
          errorMessage.contains('404')) {
        _showEdgeFunctionSetupDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: NBROColors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: ${e.toString()}')),
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

  String _generateRandomPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#\$%^&*';
    final random = Random.secure();
    return List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
  }

  void _showEdgeFunctionSetupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: NBROColors.info),
            SizedBox(width: 12),
            Text('Edge Function Setup Required'),
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
              const Text('Follow these steps:'),
              const SizedBox(height: 12),
              const Text('1. Install Supabase CLI:'),
              Container(
                margin: const EdgeInsets.only(left: 16, top: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: NBROColors.darkGrey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'npm install -g supabase',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              const Text('2. Deploy the function:'),
              Container(
                margin: const EdgeInsets.only(left: 16, top: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: NBROColors.darkGrey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'supabase functions deploy create-officer',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
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
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Alternative: Create manually in Supabase Dashboard',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                'Go to Dashboard → Authentication → Users → Add user',
                style: TextStyle(fontSize: 12, color: NBROColors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showPasswordDialog(String email, String password) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: NBROColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle, color: NBROColors.success),
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
                      const Icon(Icons.email, size: 16, color: NBROColors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          email,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.lock, size: 16, color: NBROColors.grey),
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
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: NBROColors.info,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Share these credentials with the officer. They can change their password after first login.',
                      style: TextStyle(
                        fontSize: 12,
                        color: NBROColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeOfficer(String officerId, String officerName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_outlined,
              color: NBROColors.error,
            ),
            const SizedBox(width: 12),
            const Text('Remove Officer'),
          ],
        ),
        content: Text('Are you sure you want to remove $officerName? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: NBROColors.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final supabase = Supabase.instance.client;
        
        // Delete user from auth (requires admin privileges)
        try {
          await supabase.auth.admin.deleteUser(officerId);
        } catch (e) {
          debugPrint('Note: Could not delete from auth (admin privilege may be required): $e');
        }
        
        // Delete from profiles table
        await supabase
          .from('profile')
            .delete()
            .eq('id', officerId);

        _loadOfficers();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: NBROColors.white),
                  SizedBox(width: 12),
                  Text('Officer removed successfully'),
                ],
              ),
              backgroundColor: NBROColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error removing officer: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: NBROColors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Error removing officer: $e')),
                ],
              ),
              backgroundColor: NBROColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showAddOfficerDialog() {
    // Reset controllers
    _emailController.clear();
    _nameController.clear();
    _passwordController.clear();
    _isAutoGeneratePassword = true;
    _obscurePassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: NBROColors.light,
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                
                // Password generation option
                SwitchListTile(
                  title: const Text('Auto-generate password'),
                  subtitle: const Text('System will create a secure password'),
                  value: _isAutoGeneratePassword,
                  onChanged: (value) {
                    setDialogState(() {
                      _isAutoGeneratePassword = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                
                if (!_isAutoGeneratePassword) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: NBROColors.light,
                      helperText: 'Minimum 6 characters',
                    ),
                    obscureText: _obscurePassword,
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
                Navigator.pop(context);
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
                    'Manage Officers',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: NBROColors.white,
                    ),
                  ),
                  Text(
                    'View, add, or remove officers',
                    style: TextStyle(
                      fontSize: 12,
                      color: NBROColors.white,
                    ),
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
                        style: TextStyle(
                          color: NBROColors.grey,
                        ),
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
                            width: 1,
                          ),
                        ),
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
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                        color: NBROColors.success.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
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
