import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../common/bouncy_pressable.dart';
import '../common/radian_app_logo.dart';

/// Expressive Material 3 & KSM × Tech About Dialog for Radian.
///
/// Combines App Identity, live Over-The-Air (OTA) update status,
/// numbered system architecture (01-04), developer heritage, and verified links.
class AboutRadianDialog extends ConsumerWidget {
  const AboutRadianDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const AboutRadianDialog(),
    );
  }

  Future<void> _copyText(
    BuildContext context,
    String text,
    String label,
  ) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$label copied: $text',
            style: TextStyle(
              color: colorScheme.brightness == Brightness.dark
                  ? colorScheme.onSurface
                  : colorScheme.onInverseSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: colorScheme.brightness == Brightness.dark
              ? colorScheme.surfaceContainerHighest
              : colorScheme.inverseSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = colorScheme.primary;
    final onSurface = colorScheme.onSurface;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;
    final outlineVariant = colorScheme.outlineVariant;

    return Dialog(
      backgroundColor: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Top Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About Radian',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: onSurface,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'KSM × Tech System Specifications',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: onSurfaceVariant,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  BouncyPressable(
                    scaleDownFactor: 0.88,
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: outlineVariant, width: 1.1),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 0.8),

            // ── Scrollable Body ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. App Identity Card
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 22,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Center(child: RadianAppLogo(size: 76)),
                          const SizedBox(height: 14),
                          Text(
                            AppStrings.appName,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                              color: onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'रेडियन · अहोरात्र चक्र',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Version & Build Badge (Updated to v1.0.1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'v${AppStrings.appVersion} (Build ${AppStrings.appBuildNumber}) · Production Edge',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onPrimaryContainer,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppStrings.appTagline,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your day is a continuous circle, not an anxiety checklist.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. Numbered Architecture & Specifications (01 - 04)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SYSTEM SPECIFICATIONS',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const _SpecRow(
                            number: '01',
                            title: '360° Circular Polar Dial',
                            subtitle: '12H Indian Day Dial & 24H Global Circadian routine layers mapped to polar coordinates.',
                          ),
                          const Divider(height: 16, thickness: 0.6),
                          const _SpecRow(
                            number: '02',
                            title: 'AI-Native MCP Engine',
                            subtitle: 'Autonomous time blocking tools via Model Context Protocol for Claude & ChatGPT.',
                          ),
                          const Divider(height: 16, thickness: 0.6),
                          const _SpecRow(
                            number: '03',
                            title: 'Edge Cloud Sync Vault',
                            subtitle: 'Private tenant keys and end-to-end QR pairing between laptop screen and phone camera.',
                          ),
                          const Divider(height: 16, thickness: 0.6),
                          const _SpecRow(
                            number: '04',
                            title: 'Material 3 & Dark Espresso',
                            subtitle: 'Warm espresso chassis, Vrindavan accents, and Nothing OS monochrome icon.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 4. Developer & KSM Heritage Card (BYF Inspired)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Avatar mark with 'P'
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.primaryContainer,
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'P',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'serif',
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'DESIGNED & DEVELOPED BY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'PrasaD',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'BSc Computer Science · Applied AI Sprint · India',
                            style: TextStyle(
                              fontSize: 11,
                              color: onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 14),
                          // KSM Vow Seal
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: outlineVariant.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'KSM × Tech Heritage',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: primaryColor,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const _KsmLine(
                                  letter: 'K',
                                  meaning: 'Family, roots, and identity.',
                                ),
                                const _KsmLine(
                                  letter: 'S',
                                  meaning: 'Satya, honest public service.',
                                ),
                                const _KsmLine(
                                  letter: 'M',
                                  meaning:
                                      'Manga, grounding & spiritual poise.',
                                ),
                                const _KsmLine(
                                  letter: '×',
                                  meaning:
                                      'The forge of heritage and modern tools.',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 5. Support & Links Card (BYF Inspired)
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                            child: Text(
                              'VERIFIED LINKS & CHANNELS',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                                color: primaryColor,
                              ),
                            ),
                          ),
                          _LinkRow(
                            icon: Icons.language_rounded,
                            title: 'Official Website',
                            subtitle: 'ksmxtech.com/radian',
                            onTap: () => _copyText(
                              context,
                              AppStrings.websiteUrl,
                              'Website URL',
                            ),
                          ),
                          const Divider(height: 1, thickness: 0.5),
                          _LinkRow(
                            icon: Icons.code_rounded,
                            title: 'Open Source Repository',
                            subtitle: 'github.com/prasadsince1999/Radian',
                            onTap: () => _copyText(
                              context,
                              AppStrings.githubUrl,
                              'GitHub URL',
                            ),
                          ),
                          const Divider(height: 1, thickness: 0.5),
                          _LinkRow(
                            icon: Icons.article_outlined,
                            title: 'Engineering Notebook',
                            subtitle: 'x.com/otto_explorer',
                            onTap: () => _copyText(
                              context,
                              AppStrings.xTwitterUrl,
                              'X Notebook URL',
                            ),
                          ),
                          const Divider(height: 1, thickness: 0.5),
                          _LinkRow(
                            icon: Icons.mail_outline_rounded,
                            title: 'Contact & Feedback',
                            subtitle: AppStrings.supportEmail,
                            onTap: () => _copyText(
                              context,
                              AppStrings.supportEmail,
                              'Email Address',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 6. Close Button
                    FilledButton.tonal(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;

  const _SpecRow({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(7),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KsmLine extends StatelessWidget {
  final String letter;
  final String meaning;

  const _KsmLine({required this.letter, required this.meaning});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            letter,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              meaning,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.copy_rounded,
              size: 14,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}
