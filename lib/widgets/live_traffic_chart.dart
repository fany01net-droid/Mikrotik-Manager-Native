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
/// Displays Dual-Stream Upload & Download History with Segmented Mode Selection
class LiveTrafficChart extends StatefulWidget {
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
  State<LiveTrafficChart> createState() => _LiveTrafficChartState();
}

class _LiveTrafficChartState extends State<LiveTrafficChart> {
  String _viewMode = 'both'; // 'both', 'rx', 'tx'

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final latest = widget.points.isNotEmpty ? widget.points.last : const TrafficPoint(rx: 0, tx: 0);

    // Compute dynamic scale ceiling based on peak rate and current points
    final maxRateInPoints = widget.points.fold<double>(0.0, (m, p) => math.max(m, math.max(p.rx, p.tx)));
    final scaleCeil = math.max(1.0, math.max(widget.peakRate, maxRateInPoints) * 1.15);

    final rxPercent = (latest.rx / scaleCeil).clamp(0.0, 1.0);
    final txPercent = (latest.tx / scaleCeil).clamp(0.0, 1.0);
    const maxBarHeight = 84.0;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mode Selector: Semua (Rx & Tx), Download (Rx), Upload (Tx)
            Center(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'both',
                    label: Text('Semua', style: TextStyle(fontSize: 12)),
                    icon: Icon(Icons.sync_alt_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: 'rx',
                    label: Text('Download', style: TextStyle(fontSize: 12)),
                    icon: Icon(Icons.arrow_downward_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: 'tx',
                    label: Text('Upload', style: TextStyle(fontSize: 12)),
                    icon: Icon(Icons.arrow_upward_rounded, size: 16),
                  ),
                ],
                selected: {_viewMode},
                onSelectionChanged: (val) {
                  if (val.isNotEmpty) {
                    setState(() => _viewMode = val.first);
                  }
                },
              ),
            ),
            const SizedBox(height: 14),

            // Live Metrics Cards (Download & Upload)
            Row(
              children: [
                if (_viewMode == 'both' || _viewMode == 'rx')
                  Expanded(
                    child: Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.arrow_downward_rounded, color: FNetTheme.emerald, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'Download (Rx)',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
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
                                color: FNetTheme.emerald,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: rxPercent,
                                minHeight: 6,
                                backgroundColor: colorScheme.surfaceContainerHighest,
                                valueColor: const AlwaysStoppedAnimation<Color>(FNetTheme.emerald),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_viewMode == 'both') const SizedBox(width: 10),
                if (_viewMode == 'both' || _viewMode == 'tx')
                  Expanded(
                    child: Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.arrow_upward_rounded, color: FNetTheme.sky, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'Upload (Tx)',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
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
                                color: FNetTheme.sky,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: txPercent,
                                minHeight: 6,
                                backgroundColor: colorScheme.surfaceContainerHighest,
                                valueColor: const AlwaysStoppedAnimation<Color>(FNetTheme.sky),
                              ),
                            ),
                          ],
                        ),
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
                children: widget.points.map((p) {
                  final rxHeight = ((p.rx / scaleCeil) * maxBarHeight).clamp(2.0, maxBarHeight);
                  final txHeight = ((p.tx / scaleCeil) * maxBarHeight).clamp(2.0, maxBarHeight);

                  Widget barWidget;
                  if (_viewMode == 'rx') {
                    barWidget = Container(
                      height: rxHeight,
                      decoration: const BoxDecoration(
                        color: FNetTheme.emerald,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                      ),
                    );
                  } else if (_viewMode == 'tx') {
                    barWidget = Container(
                      height: txHeight,
                      decoration: const BoxDecoration(
                        color: FNetTheme.sky,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                      ),
                    );
                  } else {
                    // Both: side-by-side slim bars
                    barWidget = Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Container(
                            height: rxHeight,
                            decoration: const BoxDecoration(
                              color: FNetTheme.emerald,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 1),
                        Expanded(
                          child: Container(
                            height: txHeight,
                            decoration: const BoxDecoration(
                              color: FNetTheme.sky,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return Expanded(
                    child: Tooltip(
                      message: 'Download (Rx): ${FormatUtils.formatSpeed(p.rx)}bps\nUpload (Tx): ${FormatUtils.formatSpeed(p.tx)}bps',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.0),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: barWidget,
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
                      decoration: const BoxDecoration(
                        color: FNetTheme.emerald,
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
                      decoration: const BoxDecoration(
                        color: FNetTheme.sky,
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
                    'Puncak: ${FormatUtils.formatSpeed(widget.peakRate)}bps',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10),
                  ),
                  backgroundColor: colorScheme.surfaceContainerHigh,
                  textColor: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
