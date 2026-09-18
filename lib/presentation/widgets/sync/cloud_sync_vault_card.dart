import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_strings.dart';
import '../../controllers/clock_controller.dart';
import '../../controllers/cloud_sync_controller.dart';
import '../common/bouncy_pressable.dart';
import '../editor/components/dial_editor_styles.dart';

/// Card displayed inside Custom Dial settings showcasing the private sync key,
/// eye visibility toggle, warning backup alert, and web-pairing QR code.
class CloudSyncVaultCard extends ConsumerStatefulWidget {
  const CloudSyncVaultCard({super.key});

  @override
  ConsumerState<CloudSyncVaultCard> createState() => _CloudSyncVaultCardState();
}

class _CloudSyncVaultCardState extends ConsumerState<CloudSyncVaultCard> {
  bool _isKeyRevealed = false;
  bool _isPairingOpen = false;
  late final TextEditingController _pairKeyController;

  @override
  void initState() {
    super.initState();
    _pairKeyController = TextEditingController();
  }

  @override
  void dispose() {
    _pairKeyController.dispose();
    super.dispose();
  }

  String _obscureKey(String key) {
    if (key.length <= 4) return '••••••••';
    // e.g. RAD-7A4B-9E2C -> RAD-••••-••••
    final parts = key.split('-');
    if (parts.length == 3) {
      return '${parts[0]}-••••-••••';
    }
    return '${key.substring(0, 3)}-••••-••••';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final syncState = ref.watch(cloudSyncControllerProvider);
    final key = syncState.syncKey.isNotEmpty
        ? syncState.syncKey
        : 'RAD-INIT-SYNC';
    final pairingUrl = '${AppStrings.productionWebBaseUrl}/?sync=$key';

    final primaryText = colorScheme.onSurface;
    final secondaryText = colorScheme.onSurfaceVariant;
    final accentColor = colorScheme.primary;
    final accentBg = colorScheme.primaryContainer;
    final accentBorder = colorScheme.primary.withValues(alpha: 0.35);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: DialEditorStyles.cardDecoration(colorScheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentBorder, width: 1.2),
                ),
                child: Icon(
                  Icons.vpn_key_rounded,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sync & Web Pairing Vault',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Zero-leak private multi-device sync',
                      style: TextStyle(fontSize: 12, color: secondaryText),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: syncState.isSyncing
                      ? colorScheme.tertiaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      syncState.isSyncing
                          ? Icons.sync_rounded
                          : Icons.cloud_done_rounded,
                      size: 13,
                      color: syncState.isSyncing
                          ? colorScheme.tertiary
                          : colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      syncState.isSyncing
                          ? 'Syncing...'
                          : syncState.formattedLastSync,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Private Key Showcase (Hidden by default with Eye button)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.8),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PRIVATE VAULT KEY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: secondaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isKeyRevealed ? key : _obscureKey(key),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          letterSpacing: _isKeyRevealed ? 1.2 : 2.5,
                          color: _isKeyRevealed ? accentColor : primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                // Eye button to toggle visibility
                IconButton(
                  tooltip: _isKeyRevealed ? 'Hide Key' : 'Reveal Key',
                  icon: Icon(
                    _isKeyRevealed
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color: _isKeyRevealed ? accentColor : secondaryText,
                    size: 22,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isKeyRevealed = !_isKeyRevealed;
                    });
                  },
                ),
                // Copy Key Button
                IconButton(
                  tooltip: 'Copy Sync Key',
                  icon: Icon(Icons.copy_rounded, color: accentColor, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: key));
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Vault key "$key" copied to clipboard!'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Warning Box: Advise user to save/backup key otherwise they lose data
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.amber.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BACKUP THIS KEY TO PREVENT DATA LOSS',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 0.5,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Keep this key safe! If you clear your browser cache, reinstall the app, or change devices without saving this key, your cloud routines cannot be recovered.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: primaryText.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Web Pairing QR Code Section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Instant Web Pairing QR Code',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scan with your phone or camera to open and sync your web version:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: secondaryText),
                ),
                const SizedBox(height: 12),
                // QR Code Image (White background ensures high contrast in all themes)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: pairingUrl,
                    version: QrVersions.auto,
                    size: 160,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF1E293B),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Copy Web Pairing Link Button
                BouncyPressable(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: pairingUrl));
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Web sync link copied to clipboard! Open in any browser.',
                        ),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: accentBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accentBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.link_rounded, size: 16, color: accentColor),
                        const SizedBox(width: 6),
                        Text(
                          'Copy Web Sync Link',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Pair Another Device or Change Vault Key
          BouncyPressable(
            onTap: () => setState(() => _isPairingOpen = !_isPairingOpen),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Link Existing Key / Another Phone',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Enter key from another device to merge schedules',
                          style: TextStyle(fontSize: 11, color: secondaryText),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isPairingOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: secondaryText,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_isPairingOpen) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pairKeyController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. RAD-7A4B-9E2C',
                      hintStyle: TextStyle(
                        fontFamily: 'monospace',
                        color: secondaryText.withValues(alpha: 0.6),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                BouncyPressable(
                  onTap: () async {
                    final input = _pairKeyController.text.trim();
                    if (input.isEmpty) return;
                    HapticFeedback.mediumImpact();
                    await ref
                        .read(cloudSyncControllerProvider.notifier)
                        .setSyncKey(input);
                    _pairKeyController.clear();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Vault linked to "$input". Synchronizing...',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Link Vault',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),

          // Action Buttons: Manual Sync & Offline JSON Backup
          Row(
            children: [
              // Manual Sync Button
              Expanded(
                child: BouncyPressable(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    await ref
                        .read(cloudSyncControllerProvider.notifier)
                        .syncNow();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sync pass completed!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: accentBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accentBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sync_rounded, size: 16, color: accentColor),
                        const SizedBox(width: 6),
                        Text(
                          'Sync Now',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Export JSON Backup
              Expanded(
                child: BouncyPressable(
                  onTap: () async {
                    final repo = ref.read(eventRepositoryProvider);
                    final allEvents = await repo.getAllEvents();
                    final jsonText = jsonEncode(
                      allEvents.map((e) => e.toJson()).toList(),
                    );
                    Clipboard.setData(ClipboardData(text: jsonText));
                    HapticFeedback.lightImpact();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${allEvents.length} events exported as JSON backup to clipboard!',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.file_download_outlined,
                          size: 16,
                          color: primaryText,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Export JSON',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
