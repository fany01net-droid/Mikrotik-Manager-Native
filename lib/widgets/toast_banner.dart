import 'package:flutter/material.dart';
import '../theme/fnet_theme.dart';

enum ToastType {
  success,
  error,
  info,
}

/// Official Material 3 SnackBar notification helper
class ToastBanner {
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color iconColor;
    IconData icon;
    String prefix;

    switch (type) {
      case ToastType.success:
        iconColor = FNetTheme.emerald;
        icon = Icons.check_circle_outline;
        prefix = 'Berhasil';
        break;
      case ToastType.error:
        iconColor = colorScheme.error;
        icon = Icons.error_outline;
        prefix = 'Perhatian';
        break;
      case ToastType.info:
        iconColor = colorScheme.primary;
        icon = Icons.info_outline;
        prefix = 'Sistem';
        break;
    }

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        closeIconColor: colorScheme.onSurfaceVariant,
        backgroundColor: colorScheme.surfaceContainerHighest,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FNet • $prefix',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
