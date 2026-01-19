import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'branding.dart';

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
    return Scaffold(
      body: Stack(
        children: [
          // Main content
          Positioned.fill(child: widget.child),

          // Optional dimmed scrim when rail is visible (click to close)
          ValueListenableBuilder<bool>(
            valueListenable: NavRailController.isVisible,
            builder: (_, visible, __) => visible
                ? Positioned.fill(
                    child: GestureDetector(
                      onTap: NavRailController.hide,
                      child: Container(color: Colors.black.withValues(alpha: 0.04)),
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
                elevation: 2,
                child: SafeArea(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: NBROBrand(title: 'Menu', color: NBROColors.primary),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: NavigationRail(
                          selectedIndex: widget.currentItem.index,
                          onDestinationSelected: (index) {
                            widget.onNavItemSelected(NavItem.values[index]);
                            NavRailController.hide();
                          },
                          extended: true,
                          labelType: NavigationRailLabelType.none,
                          destinations: const [
                            NavigationRailDestination(
                              icon: Icon(Icons.dashboard),
                              label: Text('Dashboard'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.assignment),
                              label: Text('Inspection'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.analytics),
                              label: Text('Analysis'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.settings),
                              label: Text('Settings'),
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
        ],
      ),
    );
  }
}
