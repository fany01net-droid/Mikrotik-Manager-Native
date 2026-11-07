import 'package:flutter/material.dart';

enum ToastType {
  success,
  error,
  info,
}

/// Standard Material 3 SnackBar notification helper
class ToastBanner {
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();

    final colorScheme = Theme.of(context).colorScheme;

    IconData icon;
    Color iconColor;
    switch (type) {
      case ToastType.success:
        icon = Icons.check_circle_outline;
        iconColor = colorScheme.primary;
        break;
      case ToastType.error:
        icon = Icons.error_outline;
        iconColor = colorScheme.error;
        break;
      case ToastType.info:
        icon = Icons.info_outline;
        iconColor = colorScheme.secondary;
        break;
    }

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
