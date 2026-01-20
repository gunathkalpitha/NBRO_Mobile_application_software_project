import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Controls the NavigationRail expanded/collapsed state from child screens
class NavRailController {
  // Whether the rail panel is visible at all
  static final ValueNotifier<bool> isVisible = ValueNotifier<bool>(false);
  // Whether the rail shows labels (extended) when visible
  static final ValueNotifier<bool> isExtended = ValueNotifier<bool>(true);

  static void toggleVisibility() => isVisible.value = !isVisible.value;
  static void show() => isVisible.value = true;
  static void hide() => isVisible.value = false;

  static void toggleExtended() => isExtended.value = !isExtended.value;
  static void setExtended(bool value) => isExtended.value = value;
}

enum NavItem { dashboard, inspection, analysis, settings }

class AppShell extends StatefulWidget {
  final Widget child;
  final NavItem currentItem;
  final Function(NavItem) onNavItemSelected;

  const AppShell({
    super.key,
    required this.child,
    required this.currentItem,
    required this.onNavItemSelected,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  Widget build(BuildContext context) {
    // Unified layout with slide-in side navigation for all devices
    return Stack(
      children: [
        // Main content - directly render without Positioned.fill
        widget.child,

        // Optional dimmed scrim when rail is visible (click to close)
        ValueListenableBuilder<bool>(
          valueListenable: NavRailController.isVisible,
          builder: (_, visible, __) => visible
              ? Positioned.fill(
                  child: GestureDetector(
                    onTap: NavRailController.hide,
                    child: Container(color: Colors.black.withValues(alpha: 0.3)),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // Slide-in side navigation rail (all devices)
        ValueListenableBuilder<bool>(
          valueListenable: NavRailController.isVisible,
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
                decoration: BoxDecoration(
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
                        padding: const EdgeInsets.all(20),
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
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: NBROColors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/icons/pasted-image.png',
                                width: 48,
                                height: 48,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'NBRO',
                              style: TextStyle(
                                color: NBROColors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Field Surveyor',
                              style: TextStyle(
                                color: NBROColors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w300,
                              ),
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
                            _NavItem(
                              icon: Icons.dashboard_rounded,
                              label: 'Dashboard',
                              isSelected: widget.currentItem == NavItem.dashboard,
                              onTap: () {
                                widget.onNavItemSelected(NavItem.dashboard);
                                NavRailController.hide();
                              },
                            ),
                            _NavItem(
                              icon: Icons.assignment_rounded,
                              label: 'Inspections',
                              isSelected: widget.currentItem == NavItem.inspection,
                              onTap: () {
                                widget.onNavItemSelected(NavItem.inspection);
                                NavRailController.hide();
                              },
                            ),
                            _NavItem(
                              icon: Icons.analytics_rounded,
                              label: 'Analytics',
                              isSelected: widget.currentItem == NavItem.analysis,
                              onTap: () {
                                widget.onNavItemSelected(NavItem.analysis);
                                NavRailController.hide();
                              },
                            ),
                            _NavItem(
                              icon: Icons.folder_rounded,
                              label: 'Reports',
                              isSelected: false,
                              onTap: () {
                                NavRailController.hide();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Reports feature coming soon')),
                                );
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
                            _NavItem(
                              icon: Icons.help_rounded,
                              label: 'Help & Support',
                              isSelected: false,
                              onTap: () {
                                NavRailController.hide();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Help & Support coming soon')),
                                );
                              },
                            ),
                            _NavItem(
                              icon: Icons.settings_rounded,
                              label: 'Settings',
                              isSelected: widget.currentItem == NavItem.settings,
                              onTap: () {
                                widget.onNavItemSelected(NavItem.settings);
                                NavRailController.hide();
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
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: NBROColors.white,
                              child: Text(
                                'TU',
                                style: TextStyle(
                                  color: NBROColors.primary,
                                  fontWeight: FontWeight.bold,
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
                                    'Test User',
                                    style: TextStyle(
                                      color: NBROColors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Field Officer',
                                    style: TextStyle(
                                      color: NBROColors.white.withValues(alpha: 0.7),
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.logout_rounded, color: NBROColors.white),
                              iconSize: 20,
                              onPressed: () {
                                NavRailController.hide();
                                Navigator.of(context).pushReplacementNamed('/');
                              },
                            ),
                          ],
                        ),
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
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
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
