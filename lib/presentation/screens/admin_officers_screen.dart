import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';

class AdminOfficersScreen extends StatefulWidget {
  const AdminOfficersScreen({super.key});

  @override
  State<AdminOfficersScreen> createState() => _AdminOfficersScreenState();
}

class _AdminOfficersScreenState extends State<AdminOfficersScreen> {
  List<Map<String, dynamic>> _officers = [];
  bool _isLoading = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

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

  Future<void> _loadOfficers() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('profiles')
          .select('id, email, full_name, role, created_at')
          .eq('role', 'officer')
          .order('created_at', ascending: false);

      setState(() {
        _officers = List<Map<String, dynamic>>.from(response as List);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading officers: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading officers: $e'),
            backgroundColor: NBROColors.error,
          ),
        );
      }
    }
  }

  Future<void> _addOfficer() async {
    if (_emailController.text.trim().isEmpty || _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both email and name'),
          backgroundColor: NBROColors.warning,
        ),
      );
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      
      // In a real app, you would send an invitation email
      // For now, we'll create a profile entry
      await supabase.from('profiles').insert({
        'email': _emailController.text.trim(),
        'full_name': _nameController.text.trim(),
        'role': 'officer',
      });

      _emailController.clear();
      _nameController.clear();
      
      if (!mounted) return;
      Navigator.pop(context);
      _loadOfficers();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Officer added successfully!'),
          backgroundColor: NBROColors.success,
        ),
      );
    } catch (e) {
      debugPrint('Error adding officer: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding officer: $e'),
          backgroundColor: NBROColors.error,
        ),
      );
    }
  }

  Future<void> _removeOfficer(String officerId, String officerName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Officer'),
        content: Text('Are you sure you want to remove $officerName?'),
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
        await supabase
            .from('profiles')
            .delete()
            .eq('id', officerId);

        _loadOfficers();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Officer removed successfully'),
              backgroundColor: NBROColors.success,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error removing officer: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing officer: $e'),
              backgroundColor: NBROColors.error,
            ),
          );
        }
      }
    }
  }

  void _showAddOfficerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Officer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _emailController.clear();
              _nameController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _addOfficer,
            child: const Text('Add Officer'),
          ),
        ],
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
