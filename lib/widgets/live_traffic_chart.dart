import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/fnet_theme.dart';
import '../utils/format_utils.dart';

class TrafficPoint {
  final double rx; // Download rate (Mbps)
  final double tx; // Upload rate (Mbps)

  const TrafficPoint({required this.rx, required this.tx});
}

/// Official Material 3 Real-time Traffic Monitor Widget (Pure M3, No Custom Painters)
/// Displays Dual-Stream Upload & Download History directly without nested cards.
class LiveTrafficChart extends StatelessWidget {
  final List<TrafficPoint> points;
  final double peakRate;
  final String? interfaceName;

  const LiveTrafficChart({
    super.key,
    required this.points,
    required this.peakRate,
    this.interfaceName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final latest = points.isNotEmpty ? points.last : const TrafficPoint(rx: 0, tx: 0);

    // Compute dynamic scale ceiling based on peak rate and current points
    final maxRateInPoints = points.fold<double>(0.0, (m, p) => math.max(m, math.max(p.rx, p.tx)));
    final scaleCeil = math.max(1.0, math.max(peakRate, maxRateInPoints) * 1.15);

    final rxPercent = (latest.rx / scaleCeil).clamp(0.0, 1.0);
    final txPercent = (latest.tx / scaleCeil).clamp(0.0, 1.0);
    const maxBarHeight = 84.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live Metrics Row (Download & Upload)
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.arrow_downward_rounded, size: 16, color: colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Download (Rx)',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${FormatUtils.formatSpeed(latest.rx)}bps',
                      style: FNetTheme.monoStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: rxPercent,
                        minHeight: 6,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.arrow_upward_rounded, size: 16, color: colorScheme.secondary),
                        const SizedBox(width: 4),
                        Text(
                          'Upload (Tx)',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${FormatUtils.formatSpeed(latest.tx)}bps',
                      style: FNetTheme.monoStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: txPercent,
                        minHeight: 6,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.secondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Graph Header & Max Scale
        Row(
          children: [
            Text(
              'Histori Trafik:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              'Skala Max: ${FormatUtils.formatSpeed(scaleCeil)}bps',
              style: FNetTheme.monoStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Dual-Stream Real-Time Bar Chart (Pure M3 Containers & Tooltips)
        Container(
          height: 100,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: points.map((p) {
              final rxHeight = ((p.rx / scaleCeil) * maxBarHeight).clamp(2.0, maxBarHeight);
              final txHeight = ((p.tx / scaleCeil) * maxBarHeight).clamp(2.0, maxBarHeight);

              return Expanded(
                child: Tooltip(
                  message: 'Download (Rx): ${FormatUtils.formatSpeed(p.rx)}bps\nUpload (Tx): ${FormatUtils.formatSpeed(p.tx)}bps',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.0),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Container(
                              height: rxHeight,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 1),
                          Expanded(
                            child: Container(
                              height: txHeight,
                              decoration: BoxDecoration(
                                color: colorScheme.secondary,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),

        // Time axis labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '~60 dtk lalu',
              style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
            ),
            Text(
              'Sekarang (Live)',
              style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        const SizedBox(height: 10),

        // Legend & Peak Rate Indicator
        Row(
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Download (Rx)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colorScheme.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Upload (Tx)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Badge(
              label: Text(
                'Puncak: ${FormatUtils.formatSpeed(peakRate)}bps',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10),
              ),
              backgroundColor: colorScheme.surfaceContainerHigh,
              textColor: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ],
    );
  }
}
