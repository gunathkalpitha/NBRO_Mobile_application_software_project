import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';

/// Controls the NavigationRail expanded/collapsed state for Admin
class AdminNavRailController {
  static final ValueNotifier<bool> isVisible = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> isExtended = ValueNotifier<bool>(true);

  static void toggleVisibility() => isVisible.value = !isVisible.value;
  static void show() => isVisible.value = true;
  static void hide() => isVisible.value = false;

  static void toggleExtended() => isExtended.value = !isExtended.value;
  static void setExtended(bool value) => isExtended.value = value;
}

enum AdminNavItem { dashboard, officers, inspections, profile }

class AdminAppShell extends StatefulWidget {
  final Widget child;
  final AdminNavItem currentItem;
  final Function(AdminNavItem) onNavItemSelected;

  const AdminAppShell({
    super.key,
    required this.child,
    required this.currentItem,
    required this.onNavItemSelected,
  });

  @override
  State<AdminAppShell> createState() => _AdminAppShellState();
}

class _AdminAppShellState extends State<AdminAppShell> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        widget.child,

        // Optional dimmed scrim when rail is visible
        ValueListenableBuilder<bool>(
          valueListenable: AdminNavRailController.isVisible,
          builder: (_, visible, __) => visible
              ? Positioned.fill(
                  child: GestureDetector(
                    onTap: AdminNavRailController.hide,
                    child: Container(color: Colors.black.withValues(alpha: 0.3)),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // Slide-in side navigation rail
        ValueListenableBuilder<bool>(
          valueListenable: AdminNavRailController.isVisible,
          builder: (_, visible, __) => AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            top: 0,
            bottom: 0,
            left: visible ? 0 : -264,
            width: 264,
            child: Material(
              elevation: 16,
              shadowColor: NBROColors.primary.withValues(alpha: 0.3),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      NBROColors.primary,
                      NBROColors.primaryDark,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Header with Logo and Branding
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: NBROColors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/icons/pasted-image.png',
                                width: 56,
                                height: 56,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'NBRO',
                              style: TextStyle(
                                color: NBROColors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Admin Panel',
                              style: TextStyle(
                                color: NBROColors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Navigation Items
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          children: [
                            _AdminNavItem(
                              icon: Icons.dashboard_rounded,
                              label: 'Dashboard',
                              isSelected: widget.currentItem == AdminNavItem.dashboard,
                              onTap: () {
                                widget.onNavItemSelected(AdminNavItem.dashboard);
                                AdminNavRailController.hide();
                              },
                            ),
                            _AdminNavItem(
                              icon: Icons.people_rounded,
                              label: 'Officers',
                              isSelected: widget.currentItem == AdminNavItem.officers,
                              onTap: () {
                                widget.onNavItemSelected(AdminNavItem.officers);
                                AdminNavRailController.hide();
                              },
                            ),
                            _AdminNavItem(
                              icon: Icons.assignment_rounded,
                              label: 'Inspections',
                              isSelected: widget.currentItem == AdminNavItem.inspections,
                              onTap: () {
                                widget.onNavItemSelected(AdminNavItem.inspections);
                                AdminNavRailController.hide();
                              },
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.2),
                                thickness: 1,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _AdminNavItem(
                              icon: Icons.admin_panel_settings_rounded,
                              label: 'Profile',
                              isSelected: widget.currentItem == AdminNavItem.profile,
                              onTap: () {
                                widget.onNavItemSelected(AdminNavItem.profile);
                                AdminNavRailController.hide();
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      // Footer with User Info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                        ),
                        child: const _AdminUserInfoSection(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Custom Navigation Item Widget
class _AdminNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AdminNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected 
                  ? NBROColors.white.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(
                      color: NBROColors.white.withValues(alpha: 0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected 
                      ? NBROColors.white 
                      : NBROColors.white.withValues(alpha: 0.7),
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected 
                          ? NBROColors.white 
                          : NBROColors.white.withValues(alpha: 0.7),
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: NBROColors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Admin User Info Section Widget
class _AdminUserInfoSection extends StatelessWidget {
  const _AdminUserInfoSection();

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    
    String userName = 'Admin';
    String initials = 'AD';
    
    if (user != null) {
      userName = user.userMetadata?['full_name'] ?? 
                 user.userMetadata?['name'] ?? 
                 user.email?.split('@').first ?? 
                 'Admin';
      
      final nameParts = userName.split(' ');
      if (nameParts.length >= 2) {
        initials = nameParts[0][0].toUpperCase() + nameParts[1][0].toUpperCase();
      } else if (userName.isNotEmpty) {
        initials = userName.substring(0, userName.length >= 2 ? 2 : 1).toUpperCase();
      }
    }
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: NBROColors.white.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: NBROColors.white,
            child: Text(
              initials,
              style: const TextStyle(
                color: NBROColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                userName,
                style: const TextStyle(
                  color: NBROColors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Administrator',
                style: TextStyle(
                  color: NBROColors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: NBROColors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: const Icon(Icons.logout_rounded, color: NBROColors.white),
            iconSize: 20,
            tooltip: 'Logout',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
            onPressed: () async {
              AdminNavRailController.hide();
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ),
      ],
    );
  }
}
