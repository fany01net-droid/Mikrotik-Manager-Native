import 'dart:math' as math;
import 'package:flutter/material.dart';

enum ToastType {
  success,
  error,
  info,
}

/// Standard Material 3 SnackBar notification helper following:
/// https://m3.material.io/components/snackbar/guidelines
class ToastBanner {
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    bool atTop = false,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    IconData icon;
    Color iconColor;
    switch (type) {
      case ToastType.success:
        icon = Icons.check_circle_rounded;
        iconColor = colorScheme.primary;
        break;
      case ToastType.error:
        icon = Icons.error_rounded;
        iconColor = colorScheme.error;
        break;
      case ToastType.info:
        icon = Icons.info_rounded;
        iconColor = colorScheme.secondary;
        break;
    }

    // Adapt position if atTop is requested or if drawer is open
    final isDrawerOpen = Scaffold.maybeOf(context)?.isDrawerOpen ?? false;
    final mediaQuery = MediaQuery.maybeOf(context);
    final scaffold = Scaffold.maybeOf(context);

    EdgeInsets margin;
    if (atTop || isDrawerOpen) {
      double availableHeight = mediaQuery?.size.height ?? 800.0;
      if (scaffold != null && scaffold.mounted) {
        final renderObject = scaffold.context.findRenderObject();
        if (renderObject is RenderBox && renderObject.hasSize && renderObject.size.height > 0) {
          availableHeight = renderObject.size.height;
        }
      }
      final topPadding = mediaQuery?.padding.top ?? 24.0;
      final bottomMargin = math.max(16.0, availableHeight - topPadding - 85.0);
      margin = EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottomMargin,
      );
    } else {
      margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 14);
    }

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: margin,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: colorScheme.surfaceContainerHighest,
        showCloseIcon: true,
        closeIconColor: colorScheme.onSurfaceVariant,
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
