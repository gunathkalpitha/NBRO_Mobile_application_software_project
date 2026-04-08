import 'package:flutter/material.dart';
import 'package:nbro_mobile_application/core/services/first_login_guide_service.dart';
import 'package:nbro_mobile_application/core/theme/app_theme.dart';

class FirstLoginGuideScreen extends StatefulWidget {
  const FirstLoginGuideScreen({super.key});

  @override
  State<FirstLoginGuideScreen> createState() => _FirstLoginGuideScreenState();
}

class _GuideStep {
  final IconData icon;
  final String title;
  final String description;

  const _GuideStep({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _FirstLoginGuideScreenState extends State<FirstLoginGuideScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isCompleting = false;

  static const List<_GuideStep> _steps = [
    _GuideStep(
      icon: Icons.map_outlined,
      title: 'Smart Site Navigation',
      description: 'Use maps and location tools to quickly reach sites and review inspection areas.',
    ),
    _GuideStep(
      icon: Icons.draw_outlined,
      title: 'Mark Defects Visually',
      description: 'Capture photos and highlight cracks with freehand, rectangle, or circle annotations.',
    ),
    _GuideStep(
      icon: Icons.cloud_upload_outlined,
      title: 'Save and Sync',
      description: 'Your inspection data is stored securely and can be synced for reporting anytime.',
    ),
    _GuideStep(
      icon: Icons.assessment_outlined,
      title: 'Generate Reports',
      description: 'Create detailed PDF reports with photos, measurements, and findings for stakeholders.',
    ),
    _GuideStep(
      icon: Icons.people_alt_outlined,
      title: 'Collaborate with Teams',
      description: 'Share inspections with team members and track changes in real-time securely.',
    ),
    _GuideStep(
      icon: Icons.cloud_done_outlined,
      title: 'Work Offline',
      description: 'Inspections are saved locally and automatically synced when internet is available.',
    ),
  ];

  Future<void> _completeGuide() async {
    if (_isCompleting) {
      return;
    }

    setState(() {
      _isCompleting = true;
    });

    await FirstLoginGuideService.markSeenForCurrentUser();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacementNamed('/home');
  }

  void _goNext() {
    if (_currentIndex == _steps.length - 1) {
      _completeGuide();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentIndex == _steps.length - 1;
    final step = _steps[_currentIndex];

    return Scaffold(
      body: Container(
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
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isCompleting ? null : _completeGuide,
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: NBROColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                key: ValueKey<int>(_currentIndex),
                tween: Tween<double>(begin: 0.92, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  width: 142,
                  height: 142,
                  decoration: BoxDecoration(
                    color: NBROColors.white.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: NBROColors.white.withValues(alpha: 0.22),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    step.icon,
                    size: 62,
                    color: NBROColors.white,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _steps.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final item = _steps[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 280),
                        opacity: _currentIndex == index ? 1 : 0.55,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: NBROColors.white,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              item.description,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: NBROColors.white.withValues(alpha: 0.92),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _steps.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentIndex == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentIndex == index
                          ? NBROColors.accent
                          : NBROColors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Row(
                  children: [
                    if (_currentIndex > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOutCubic,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: NBROColors.white.withValues(alpha: 0.65),
                            ),
                            foregroundColor: NBROColors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Back'),
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isCompleting ? null : _goNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: NBROColors.accent,
                          foregroundColor: NBROColors.black,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isCompleting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(NBROColors.black),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(isLast ? 'Get Started' : 'Next'),
                                  const SizedBox(width: 8),
                                  Icon(isLast ? Icons.check_circle_outline : Icons.arrow_forward_rounded),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
