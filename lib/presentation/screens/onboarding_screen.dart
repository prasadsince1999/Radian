import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/device_settings_service.dart';
import '../../core/theme/expressive_shapes.dart';
import '../controllers/clock_controller.dart';
import '../widgets/common/bouncy_pressable.dart';
import '../widgets/common/radian_logo.dart';
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
            // Top Bar: Official Radian Brand Logo & Skip Action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const RadianLogo(emblemSize: 26, fontSize: 20),
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

            // Main Carousel
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

            // Bottom Bar: Animated Indicators & Next / Get Started CTA
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

                  // Action Button
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

  // Slide 1: 360° Circular Time Blocking with Authentic Vector Dial Preview
  Widget _buildPage1VisualDial(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildDialMockup(colorScheme),
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

  Widget _buildDialMockup(ColorScheme colorScheme) {
    return Container(
      width: 190,
      height: 190,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0B0F19),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: CustomPaint(
        size: const Size(190, 190),
        painter: _OnboardingDialPainter(colorScheme: colorScheme),
      ),
    );
  }

  // Slide 2: Living Themes, Subtask Capsule & Health Balance
  Widget _buildPage2ThemesAndHealth(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildThemesAndHealthCard(colorScheme),
          const SizedBox(height: 28),
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
          const SizedBox(height: 12),
          Text(
            'Powered by Material 3 Expressive palettes with dynamic color schemes. Connect Google Health Connect to overlay steps, sleep, and active calories directly on your circular dial.',
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

  Widget _buildThemesAndHealthCard(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        shape: ExpressiveShapes.squircle(24),
        color: colorScheme.surfaceContainerHigh,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Subtask Pill Slider Preview (from v1.0.4)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: ShapeDecoration(
              shape: ExpressiveShapes.squircle(
                14,
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  width: 1.0,
                ),
              ),
              color: const Color(0xFF0F172A),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: ShapeDecoration(
                    shape: ExpressiveShapes.squircle(6),
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  child: const Text(
                    '10:00',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    decoration: ShapeDecoration(
                      shape: ExpressiveShapes.squircle(8),
                      color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 13,
                          color: Color(0xFF818CF8),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '25m Deep Focus',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: ShapeDecoration(
                    shape: ExpressiveShapes.squircle(6),
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                  child: const Text(
                    '10:25',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Palette Swatches Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _colorDot(const Color(0xFF10B981), isSelected: true), // Emerald
              _colorDot(const Color(0xFF6366F1)), // Indigo
              _colorDot(const Color(0xFF8B5CF6)), // Purple
              _colorDot(const Color(0xFFF59E0B)), // Amber
              _colorDot(const Color(0xFFF43F5E)), // Coral
              _colorDot(const Color(0xFF06B6D4)), // Cyan
            ],
          ),
          const SizedBox(height: 14),

          // Health Connect Metric Chips
          Row(
            children: [
              Expanded(
                child: _metricChip(
                  icon: Icons.directions_walk_rounded,
                  color: const Color(0xFF10B981),
                  label: '8,420 steps',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _metricChip(
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFF59E0B),
                  label: '520 kcal',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _metricChip(
                  icon: Icons.bedtime_rounded,
                  color: const Color(0xFF8B5CF6),
                  label: '7h 45m',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricChip({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: ShapeDecoration(
        shape: ExpressiveShapes.squircle(10),
        color: color.withValues(alpha: 0.12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorDot(Color color, {bool isSelected = false}) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: isSelected
            ? Border.all(color: Colors.white, width: 2.2)
            : Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.0,
              ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isSelected ? 0.6 : 0.3),
            blurRadius: isSelected ? 10 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  // Slide 3: AI-Native Agent Scheduling & Permissions
  Widget _buildPage3McpAndPermissions(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          _buildMcpHero(colorScheme),
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
            'Radian features an embedded Model Context Protocol (MCP) server. Claude, ChatGPT, Gemini, and Antigravity can autonomously schedule your day, find free gaps, and optimize your routine.',
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

  Widget _buildMcpHero(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: ShapeDecoration(
        shape: ExpressiveShapes.squircle(20),
        color: colorScheme.surfaceContainerHigh,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: ShapeDecoration(
              shape: ExpressiveShapes.squircle(12),
              color: colorScheme.primaryContainer,
            ),
            child: Icon(
              Icons.hub_rounded,
              size: 24,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _providerPill('Claude', const Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  _providerPill('Gemini', const Color(0xFF0284C7)),
                  const SizedBox(width: 6),
                  _providerPill('ChatGPT', const Color(0xFF10B981)),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'Model Context Protocol (MCP) Ready',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _providerPill(String name, Color dotColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: ShapeDecoration(
        shape: ExpressiveShapes.squircle(6),
        color: const Color(0xFF0F172A),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            name,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
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

/// Custom painter rendering an authentic, high-fidelity 360° circular schedule dial
/// for the Onboarding Hero.
class _OnboardingDialPainter extends CustomPainter {
  final ColorScheme colorScheme;

  const _OnboardingDialPainter({required this.colorScheme});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Dial Outer Track Ring
    final trackPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius - 4, trackPaint);

    // 2. 12 Hour Tick Marks
    final tickPaint = Paint()
      ..color = const Color(0xFF475569)
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30 - 90) * math.pi / 180;
      final isCardinal = (i % 3 == 0);
      final tickLength = isCardinal ? 8.0 : 4.5;
      tickPaint.strokeWidth = isCardinal ? 2.0 : 1.2;
      tickPaint.color = isCardinal ? const Color(0xFF94A3B8) : const Color(0xFF475569);

      final startR = radius - 6;
      final endR = startR - tickLength;

      final p1 = Offset(
        center.dx + startR * math.cos(angle),
        center.dy + startR * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + endR * math.cos(angle),
        center.dy + endR * math.sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    // 3. Swept Time Block Sectors
    final sectorRect = Rect.fromCircle(center: center, radius: radius - 26);
    final sectorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24.0
      ..strokeCap = StrokeCap.round;

    // Sector 1: Deep Focus (Indigo) 09:00 - 11:30 (approx -90° to -15°)
    sectorPaint.color = const Color(0xFF6366F1);
    canvas.drawArc(sectorRect, -math.pi * 0.5, math.pi * 0.42, false, sectorPaint);

    // Sector 2: Team Sync (Emerald) 11:30 - 13:00 (approx 0° to 45°)
    sectorPaint.color = const Color(0xFF10B981);
    canvas.drawArc(sectorRect, 0.05, math.pi * 0.25, false, sectorPaint);

    // Sector 3: Design Sprint (Amber) 14:00 - 15:30 (approx 60° to 105°)
    sectorPaint.color = const Color(0xFFF59E0B);
    canvas.drawArc(sectorRect, math.pi * 0.35, math.pi * 0.26, false, sectorPaint);

    // Sector 4: Workout (Sky Cyan) 16:30 - 17:45 (approx 135° to 175°)
    sectorPaint.color = const Color(0xFF38BDF8);
    canvas.drawArc(sectorRect, math.pi * 0.75, math.pi * 0.22, false, sectorPaint);

    // 4. Center Knockout Circle (The Dial Hub)
    const centerRadius = 38.0;
    final hubBgPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, centerRadius, hubBgPaint);

    final hubBorderPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawCircle(center, centerRadius, hubBorderPaint);

    // Center Digital Time Text
    final timeTp = TextPainter(
      text: const TextSpan(
        text: '10:15',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    timeTp.paint(
      canvas,
      Offset(center.dx - timeTp.width / 2, center.dy - timeTp.height / 2 - 5),
    );

    // Center "AM" / "Focus" Subtitle Text
    final subTp = TextPainter(
      text: TextSpan(
        text: 'FOCUS',
        style: TextStyle(
          color: colorScheme.primary,
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    subTp.paint(
      canvas,
      Offset(center.dx - subTp.width / 2, center.dy + 7),
    );

    // 5. Active Crimson Needle (Pointing at ~10:15 = -52.5° = -0.916 rad)
    const needleAngle = -52.5 * math.pi / 180.0;
    final needlePaint = Paint()
      ..color = const Color(0xFFF43F5E) // Crimson / Coral
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;

    final needleEnd = Offset(
      center.dx + (radius - 12) * math.cos(needleAngle),
      center.dy + (radius - 12) * math.sin(needleAngle),
    );
    canvas.drawLine(center, needleEnd, needlePaint);

    // Needle arrowhead indicator at outer edge
    final arrowPaint = Paint()
      ..color = const Color(0xFFF43F5E)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(needleEnd, 3.5, arrowPaint);

    // Needle Center Pivot
    final pivotWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4.0, pivotWhite);

    final pivotCoral = Paint()
      ..color = const Color(0xFFF43F5E)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2.0, pivotCoral);
  }

  @override
  bool shouldRepaint(covariant _OnboardingDialPainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme;
}
