import 'package:flutter/material.dart';

import '../../../core/constants/app_layout_constants.dart';
import '../common/bouncy_pressable.dart';
import 'cloud_sync_vault_card.dart';

/// Modal bottom sheet dedicated to Cloud Vault & Web Sync pairing.
class CloudSyncModal extends StatelessWidget {
  const CloudSyncModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      constraints: const BoxConstraints(
        maxWidth: AppLayoutConstants.modalMaxWidth,
      ),
      builder: (_) => const CloudSyncModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: AppLayoutConstants.dragHandleWidth,
                    height: AppLayoutConstants.dragHandleHeight,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        Icons.cloud_sync_rounded,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Cloud Sync & Web Pairing',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    BouncyPressable(
                      scaleDownFactor: 0.88,
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colorScheme.outlineVariant,
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Vault Card with obscured key, eye toggle, warning, and QR code
                const CloudSyncVaultCard(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
