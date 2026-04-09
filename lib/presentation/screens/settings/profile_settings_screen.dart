import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nbro_mobile_application/core/services/profile_completion_service.dart';
import 'package:nbro_mobile_application/core/services/profile_state_service.dart';
import 'package:nbro_mobile_application/core/theme/app_theme.dart';
import 'package:nbro_mobile_application/data/repositories/profile_repository.dart';
import 'package:nbro_mobile_application/domain/models/user_profile.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _repo = ProfileRepository();
  final _picker = ImagePicker();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _positionController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _workRoleController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  UserProfile? _profile;
  String _email = '';
  Uint8List? _newAvatarBytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _positionController.dispose();
    _employeeIdController.dispose();
    _workRoleController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      _email = user?.email ?? '';

      final profile = await _repo.getCurrentProfile();
      _profile = profile;

      _nameController.text = profile.fullName;
      _phoneController.text = profile.phoneNumber ?? '';
      _positionController.text = profile.positionTitle ?? '';
      _employeeIdController.text = profile.employeeId ?? '';
      _workRoleController.text = profile.workRole ?? '';
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load profile: $e'),
          backgroundColor: NBROColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );

    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _newAvatarBytes = bytes;
    });
  }

  Future<void> _save() async {
    final profile = _profile;
    if (profile == null) return;

    final fullName = _nameController.text.trim();
    if (fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name is required'),
          backgroundColor: NBROColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? avatarUrl = profile.avatarUrl;
      if (_newAvatarBytes != null) {
        avatarUrl = await _repo.uploadAvatar(
          userId: profile.id,
          bytes: _newAvatarBytes!,
        );
      }

      final updated = profile.copyWith(
        fullName: fullName,
        phoneNumber: _phoneController.text,
        positionTitle: _positionController.text,
        employeeId: _employeeIdController.text,
        workRole: _workRoleController.text,
        avatarUrl: avatarUrl,
      );

      await _repo.saveProfile(updated);

      _profile = updated;
      _newAvatarBytes = null;

      await ProfileCompletionService.refresh();
      await ProfileStateService.refresh();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: NBROColors.success,
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: $e'),
          backgroundColor: NBROColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final profile = _profile;
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile Settings')),
        body: const Center(child: Text('Profile unavailable')),
      );
    }

    final completion = profile
        .copyWith(
          fullName: _nameController.text,
          phoneNumber: _phoneController.text,
          positionTitle: _positionController.text,
          employeeId: _employeeIdController.text,
          workRole: _workRoleController.text,
          avatarUrl: _newAvatarBytes != null ? 'local-preview' : profile.avatarUrl,
        )
        .completionPercentage(email: _email);

    return Scaffold(
      backgroundColor: NBROColors.light,
      appBar: AppBar(
        title: const Text('Profile Settings'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(profile, completion),
              const SizedBox(height: 16),
              _buildFieldCard(
                title: 'Identity',
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  _buildReadOnlyField('Email Address', _email),
                ],
              ),
              const SizedBox(height: 12),
              _buildFieldCard(
                title: 'Professional Details',
                children: [
                  _buildTextField(
                    controller: _positionController,
                    label: 'Position / Designation',
                    icon: Icons.work_outline,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _workRoleController,
                    label: 'Working Role',
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _employeeIdController,
                    label: 'Working ID Number',
                    icon: Icons.credit_card_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildFieldCard(
                title: 'Contact',
                children: [
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(NBROColors.white),
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Saving...' : 'Save Profile'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(UserProfile profile, int completion) {
    final avatarProvider = _newAvatarBytes != null
        ? MemoryImage(_newAvatarBytes!) as ImageProvider
        : (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
            ? NetworkImage(profile.avatarUrl!) as ImageProvider
            : null);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [NBROColors.primary, NBROColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: NBROColors.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: NBROColors.white,
                backgroundImage: avatarProvider,
                child: avatarProvider == null
                    ? Text(
                        _initials(profile.fullName),
                        style: const TextStyle(
                          color: NBROColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: InkWell(
                  onTap: _pickPhoto,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: NBROColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: NBROColors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName.isEmpty ? 'Set your name' : profile.fullName,
                  style: const TextStyle(
                    color: NBROColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.role.toUpperCase(),
                  style: TextStyle(
                    color: NBROColors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: completion / 100,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation<Color>(NBROColors.accent),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Profile completion: $completion%',
                  style: const TextStyle(color: NBROColors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: NBROColors.black,
              ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.alternate_email),
      ),
      child: Text(
        value.isEmpty ? '-' : value,
        style: const TextStyle(color: NBROColors.darkGrey),
      ),
    );
  }

  String _initials(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return 'U';

    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}