import 'package:flutter/material.dart';
import '../theme/fnet_theme.dart';

/// Official Material 3 Determinate Circular Progress Indicator Metric Gauge
class SmoothGauge extends StatelessWidget {
  final int percent;
  final String label;
  final String secondaryText;

  const SmoothGauge({
    super.key,
    required this.percent,
    required this.label,
    required this.secondaryText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final clamped = percent.clamp(0, 100);

    Color indicatorColor;
    if (clamped >= 85) {
      indicatorColor = colorScheme.error;
    } else if (clamped >= 60) {
      indicatorColor = colorScheme.tertiary;
    } else {
      indicatorColor = colorScheme.primary;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 84,
          height: 84,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // M3 Determinate Circular Progress Indicator
              SizedBox(
                width: 84,
                height: 84,
                child: CircularProgressIndicator(
                  value: clamped / 100.0,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$clamped%',
                    style: FNetTheme.monoStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          secondaryText,
          style: FNetTheme.monoStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
