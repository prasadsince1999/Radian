import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_strings.dart';
import '../../core/services/device_settings_service.dart';
import '../../core/theme/expressive_shapes.dart';
import '../controllers/clock_controller.dart';
import '../widgets/common/bouncy_pressable.dart';
import 'home_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isBatteryIgnored = false;
  bool _areNotificationsEnabled = true;
  bool _hasHealthPermissions = false;

  @override
  void initState() {
    super.initState();
    _checkSystemSettings();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkSystemSettings() async {
    final battery = await DeviceSettingsService.isBatteryOptimizationIgnored();
    final notifs = await DeviceSettingsService.areNotificationsEnabled();
    final health = await DeviceSettingsService.hasHealthPermissions();
    if (mounted) {
      setState(() {
        _isBatteryIgnored = battery;
        _areNotificationsEnabled = notifs;
        _hasHealthPermissions = health;
      });
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs =
        ref.read(sharedPreferencesProvider) ??
        await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, _, _) => const HomeScreen(),
          transitionsBuilder: (context, animation, _, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = colorScheme.primary;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Brand & Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: ShapeDecoration(
                          shape: ExpressiveShapes.squircle(10),
                          color: colorScheme.primaryContainer,
                        ),
                        child: Icon(
                          Icons.radar_rounded,
                          color: primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        AppStrings.appName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                  if (_currentPage < 2)
                    BouncyPressable.standard(
                      onTap: _completeOnboarding,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: ShapeDecoration(
                          shape: ExpressiveShapes.full,
                          color: colorScheme.surfaceContainerHigh,
                        ),
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Page View
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                  _checkSystemSettings();
                },
                children: [
                  _buildPage1VisualDial(colorScheme),
                  _buildPage2ThemesAndHealth(colorScheme),
                  _buildPage3McpAndPermissions(colorScheme),
                ],
              ),
            ),

            // Bottom Bar: Dots & Next/Get Started Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Indicators
                  Row(
                    children: List.generate(3, (index) {
                      final isSelected = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.only(right: 6),
                        width: isSelected ? 26 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: isSelected
                              ? primary
                              : colorScheme.outlineVariant.withValues(
                                  alpha: 0.5,
                                ),
                        ),
                      );
                    }),
                  ),

                  // Button
                  BouncyPressable.standard(
                    onTap: () {
                      if (_currentPage < 2) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                        );
                      } else {
                        _completeOnboarding();
                      }
                    },
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: ShapeDecoration(
                        shape: ExpressiveShapes.squircle(16),
                        color: _currentPage == 2
                            ? colorScheme.primary
                            : colorScheme.primaryContainer,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentPage == 2 ? 'Get Started' : 'Next',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: _currentPage == 2
                                  ? colorScheme.onPrimary
                                  : colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentPage == 2
                                ? Icons.check_circle_rounded
                                : Icons.arrow_forward_rounded,
                            size: 18,
                            color: _currentPage == 2
                                ? colorScheme.onPrimary
                                : colorScheme.onPrimaryContainer,
                          ),
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
    );
  }

  // Slide 1: 360° Circular Time Blocking
  Widget _buildPage1VisualDial(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 170,
            height: 170,
            decoration: ShapeDecoration(
              shape: const CircleBorder(),
              color: colorScheme.surfaceContainerLowest,
              shadows: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.35),
                      width: 8,
                    ),
                  ),
                ),
                Icon(
                  Icons.timelapse_rounded,
                  size: 58,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          Text(
            '360° Circular Time Blocking',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Radian transforms your schedule into intuitive swept sectors on an analog clock dial. Instantly see what is active right now, upcoming focus blocks, and free gaps in 12h or 24h modes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // Slide 2: Living Themes & Health Balance
  Widget _buildPage2ThemesAndHealth(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 170,
            height: 170,
            decoration: ShapeDecoration(
              shape: ExpressiveShapes.squircle(36),
              color: colorScheme.surfaceContainerHigh,
              shadows: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _colorDot(const Color(0xFF10B981)), // Emerald
                  _colorDot(const Color(0xFF6366F1)), // Indigo
                  _colorDot(const Color(0xFF8B5CF6)), // Purple
                  _colorDot(const Color(0xFFF59E0B)), // Amber
                  _colorDot(const Color(0xFFF43F5E)), // Coral
                  _colorDot(const Color(0xFF06B6D4)), // Cyan
                ],
              ),
            ),
          ),
          const SizedBox(height: 36),
          Text(
            'Living Themes & Health Balance',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Powered by Material 3 Expressive palettes with light, dark, and system modes. Connect Google Health Connect to overlay steps, sleep, and active calories directly on your circular dial.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorDot(Color color) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  // Slide 3: AI-Native Agent Scheduling & Permissions
  Widget _buildPage3McpAndPermissions(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: ShapeDecoration(
              shape: ExpressiveShapes.squircle(20),
              color: colorScheme.primaryContainer,
            ),
            child: Icon(
              Icons.smart_toy_rounded,
              size: 38,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'AI-Native Agent Scheduling',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Radian features an embedded Model Context Protocol (MCP) server. Claude, ChatGPT, Grok, and Antigravity can autonomously schedule your day, find free gaps, and optimize your routine.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          // Battery Optimization Card
          _permissionCard(
            colorScheme: colorScheme,
            icon: Icons.battery_charging_full_rounded,
            iconColor: const Color(0xFFF59E0B),
            title: 'Battery Optimization',
            subtitle: _isBatteryIgnored
                ? 'Exemption active (Unrestricted)'
                : 'Recommended for home screen widget',
            isGranted: _isBatteryIgnored,
            onAction: () async {
              await DeviceSettingsService.requestIgnoreBatteryOptimization();
              await Future.delayed(const Duration(milliseconds: 500));
              _checkSystemSettings();
            },
          ),
          const SizedBox(height: 10),

          // Notifications Card
          _permissionCard(
            colorScheme: colorScheme,
            icon: Icons.notifications_active_rounded,
            iconColor: colorScheme.primary,
            title: 'Routine Notifications',
            subtitle: _areNotificationsEnabled
                ? 'Notifications enabled'
                : 'Required for routine alerts',
            isGranted: _areNotificationsEnabled,
            onAction: () async {
              await DeviceSettingsService.openNotificationSettings();
              await Future.delayed(const Duration(milliseconds: 500));
              _checkSystemSettings();
            },
          ),
          const SizedBox(height: 10),

          // Health Connect Card
          _permissionCard(
            colorScheme: colorScheme,
            icon: Icons.favorite_rounded,
            iconColor: const Color(0xFFF43F5E),
            title: 'Google Health Connect',
            subtitle: _hasHealthPermissions
                ? 'Connected & syncing'
                : 'Sync steps, sleep & workouts',
            isGranted: _hasHealthPermissions,
            onAction: () async {
              await DeviceSettingsService.openHealthConnectSettings();
              await Future.delayed(const Duration(milliseconds: 500));
              _checkSystemSettings();
            },
          ),
        ],
      ),
    );
  }

  Widget _permissionCard({
    required ColorScheme colorScheme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: ShapeDecoration(
        shape: ExpressiveShapes.squircle(
          14,
          side: BorderSide(
            color: isGranted
                ? const Color(0xFF10B981).withValues(alpha: 0.4)
                : colorScheme.outlineVariant,
            width: 1.2,
          ),
        ),
        color: colorScheme.surfaceContainerHigh,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: ShapeDecoration(
              shape: ExpressiveShapes.squircle(10),
              color: iconColor.withValues(alpha: 0.16),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isGranted
                        ? const Color(0xFF10B981)
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          BouncyPressable.standard(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: ShapeDecoration(
                shape: ExpressiveShapes.squircle(8),
                color: isGranted
                    ? const Color(0xFF10B981).withValues(alpha: 0.16)
                    : colorScheme.primaryContainer,
              ),
              child: Text(
                isGranted ? 'Active ✓' : 'Enable',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isGranted
                      ? const Color(0xFF10B981)
                      : colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
