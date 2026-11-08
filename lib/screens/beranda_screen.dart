import 'dart:async';
import 'package:flutter/material.dart';
import '../models/mikrotik_models.dart';
import '../services/mikrotik_api_service.dart';
import '../theme/fnet_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/gauge_widget.dart';
import '../widgets/live_traffic_chart.dart';
import '../widgets/loading_indicator_m3e.dart';
import '../widgets/toast_banner.dart';

class BerandaScreen extends StatefulWidget {
  final RouterProfile profile;

  const BerandaScreen({
    super.key,
    required this.profile,
  });

  @override
  State<BerandaScreen> createState() => BerandaScreenState();
}

class BerandaScreenState extends State<BerandaScreen> {
  SystemResource _resource = SystemResource();
  String _identity = '';
  List<SystemHealth> _health = [];
  List<NetworkInterface> _interfaces = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _selectedInterfaceName = '';
  List<TrafficPoint> _trafficPoints = List.generate(28, (_) => const TrafficPoint(rx: 0, tx: 0));
  final Map<String, List<TrafficPoint>> _interfaceTrafficHistory = {};
  final Map<String, _PreviousInterfaceTraffic> _prevTraffic = {};
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    refreshData();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollLiveMetrics();
    });
  }

  @override
  void didUpdateWidget(covariant BerandaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id ||
        oldWidget.profile.host != widget.profile.host ||
        oldWidget.profile.port != widget.profile.port) {
      _prevTraffic.clear();
      _interfaceTrafficHistory.clear();
      refreshData();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> refreshData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final resFuture = MikrotikApiService.instance.getSystemResource(widget.profile);
      final idFuture = MikrotikApiService.instance.getSystemIdentity(widget.profile);
      final healthFuture = MikrotikApiService.instance.getSystemHealth(widget.profile);
      final ifaceFuture = MikrotikApiService.instance.getInterfaces(widget.profile);

      final results = await Future.wait([resFuture, idFuture, healthFuture, ifaceFuture]);

      if (mounted) {
        setState(() {
          _resource = results[0] as SystemResource;
          _identity = results[1] as String;
          _health = results[2] as List<SystemHealth>;
          _interfaces = results[3] as List<NetworkInterface>;
          _isLoading = false;
          _errorMessage = null;

          if (_interfaces.isNotEmpty && (_selectedInterfaceName.isEmpty || !_interfaces.any((i) => i.name == _selectedInterfaceName))) {
            _selectedInterfaceName = _interfaces.first.name;
          }
          if (_selectedInterfaceName.isNotEmpty) {
            _trafficPoints = _interfaceTrafficHistory.putIfAbsent(
              _selectedInterfaceName,
              () => List.generate(28, (_) => const TrafficPoint(rx: 0, tx: 0)),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _switchInterface(String name) {
    if (_selectedInterfaceName == name) return;
    setState(() {
      _selectedInterfaceName = name;
      _trafficPoints = _interfaceTrafficHistory.putIfAbsent(
        name,
        () => List.generate(28, (_) => const TrafficPoint(rx: 0, tx: 0)),
      );
    });
  }

  Future<void> _pollLiveMetrics() async {
    try {
      final newInterfaces = await MikrotikApiService.instance.getInterfaces(widget.profile);
      if (!mounted || newInterfaces.isEmpty) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final currentIface = newInterfaces.firstWhere(
        (i) => i.name == _selectedInterfaceName,
        orElse: () => newInterfaces.first,
      );

      final rxBytes = currentIface.rxByte;
      final txBytes = currentIface.txByte;

      double rxSpeedMbps = 0.0;
      double txSpeedMbps = 0.0;

      final prev = _prevTraffic[currentIface.name];
      if (prev != null && prev.timestamp > 0) {
        final elapsedSec = (now - prev.timestamp) / 1000.0;
        if (elapsedSec > 0.4) {
          final rxDelta = (rxBytes - prev.rxBytes).clamp(0, 999999999999);
          final txDelta = (txBytes - prev.txBytes).clamp(0, 999999999999);

          final rateRx = (rxDelta * 8) / (elapsedSec * 1000000.0);
          final rateTx = (txDelta * 8) / (elapsedSec * 1000000.0);

          final nameLower = currentIface.name.toLowerCase();
          final commentLower = currentIface.comment.toLowerCase();
          final typeLower = currentIface.type.toLowerCase();

          final isClientVlan = typeLower == 'vlan' ||
              typeLower == 'bridge' ||
              RegExp(r'(vlan|bridge|lan|hotspot|wlan|client|pelanggan)').hasMatch('$nameLower $commentLower') ||
              (!RegExp(r'(wan|isp|uplink|internet|modem|gateway)').hasMatch('$nameLower $commentLower') &&
                  !RegExp(r'^(ether2|ether3|eth2|eth3)').hasMatch(nameLower));

          rxSpeedMbps = isClientVlan ? rateTx : rateRx;
          txSpeedMbps = isClientVlan ? rateRx : rateTx;
        }
      }

      _prevTraffic[currentIface.name] = _PreviousInterfaceTraffic(
        rxBytes: rxBytes,
        txBytes: txBytes,
        timestamp: now,
      );

      setState(() {
        _interfaces = newInterfaces;
        final history = _interfaceTrafficHistory.putIfAbsent(
          currentIface.name,
          () => List.generate(28, (_) => const TrafficPoint(rx: 0, tx: 0)),
        );
        history.removeAt(0);
        history.add(TrafficPoint(rx: rxSpeedMbps, tx: txSpeedMbps));
        if (currentIface.name == _selectedInterfaceName) {
          _trafficPoints = history;
        }
      });
    } catch (_) {}
  }

  Future<void> _toggleInterface(NetworkInterface iface) async {
    final newDisabled = !iface.disabled;
    try {
      await MikrotikApiService.instance.setInterfaceDisabled(widget.profile, iface.id, newDisabled);
      if (mounted) {
        ToastBanner.show(
          context,
          message: 'Interface ${iface.name} berhasil di-${newDisabled ? "nonaktifkan" : "aktifkan"}.',
          type: ToastType.success,
        );
      }
      refreshData();
    } catch (e) {
      if (mounted) {
        ToastBanner.show(
          context,
          message: 'Gagal mengubah status ${iface.name}: $e',
          type: ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: LoadingIndicatorM3E(
                size: 36,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Memuat data Dashboard...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null && _resource.boardName.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  size: 32,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Gagal Menghubungi Router',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: refreshData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    double? temperature;
    double? voltage;
    for (final h in _health) {
      final n = h.name.toLowerCase();
      if (n.contains('temperature')) {
        temperature = double.tryParse(h.value);
      } else if (n.contains('voltage')) {
        voltage = double.tryParse(h.value);
      }
    }

    final peakRate = _trafficPoints.map((p) => p.rx > p.tx ? p.rx : p.tx).fold<double>(0.0, (m, v) => v > m ? v : m);

    return RefreshIndicator(
      onRefresh: refreshData,
      color: colorScheme.primary,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // M3 Router Identity Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      foregroundColor: colorScheme.onPrimaryContainer,
                      radius: 24,
                      child: const Icon(Icons.router, size: 24),
                    ),
                    title: Text(
                      _identity.isNotEmpty ? _identity : widget.profile.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${widget.profile.host}:${widget.profile.port}',
                      style: FNetTheme.monoStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Badge(
                      label: Text(
                        _resource.version.isNotEmpty ? 'v${_resource.version}' : 'RouterOS',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      backgroundColor: colorScheme.primaryContainer,
                      textColor: colorScheme.onPrimaryContainer,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Uptime: ${_resource.uptime}',
                        style: FNetTheme.monoStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        _resource.boardName.isNotEmpty ? _resource.boardName : _resource.architectureName,
                        style: FNetTheme.monoStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // M3 Gauges Card (CPU & RAM)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: IntrinsicHeight(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: SmoothGauge(
                        percent: _resource.cpuLoad,
                        label: 'Beban CPU',
                        secondaryText: '${_resource.cpuFrequency} MHz • ${_resource.cpuCount} Core',
                      ),
                    ),
                    VerticalDivider(
                      width: 24,
                      thickness: 1,
                      color: colorScheme.outlineVariant,
                    ),
                    Expanded(
                      child: SmoothGauge(
                        percent: _resource.memoryLoadPercent,
                        label: 'Memori RAM',
                        secondaryText: '${FormatUtils.formatBytes(_resource.freeMemory)} Bebas',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // M3 Storage & Health Row
          Row(
            children: [
              // M3 Storage HDD Card
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.storage_outlined, size: 18, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Penyimpanan',
                              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${_resource.hddLoadPercent}%',
                          style: FNetTheme.monoStyle(fontSize: 20, fontWeight: FontWeight.w900, color: colorScheme.onSurface),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _resource.hddLoadPercent / 100.0,
                          backgroundColor: colorScheme.surfaceContainerHigh,
                          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                          borderRadius: BorderRadius.circular(6),
                          minHeight: 6,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${FormatUtils.formatBytes(_resource.freeHddSpace)} bebas',
                          style: FNetTheme.monoStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // M3 Health Card
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.thermostat_outlined, size: 18, color: colorScheme.tertiary),
                            const SizedBox(width: 8),
                            Text(
                              'Suhu & Voltase',
                              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  temperature != null ? '${temperature.toStringAsFixed(0)}°C' : 'N/A',
                                  style: FNetTheme.monoStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: (temperature ?? 0) >= 70 ? colorScheme.error : colorScheme.primary,
                                  ),
                                ),
                                Text(
                                  (temperature ?? 0) >= 70 ? 'Overheat' : 'Normal',
                                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  voltage != null ? '${voltage.toStringAsFixed(1)}V' : 'N/A',
                                  style: FNetTheme.monoStyle(fontSize: 16, fontWeight: FontWeight.w800, color: colorScheme.secondary),
                                ),
                                Text(
                                  voltage != null && (voltage < 20 || voltage > 27.5) ? 'Fluktuasi' : 'Stabil',
                                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // M3 Live Traffic Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Live Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.insights_rounded, color: colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Grafik Trafik Jaringan',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      Badge(
                        label: const Text('LIVE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10)),
                        backgroundColor: colorScheme.primaryContainer,
                        textColor: colorScheme.onPrimaryContainer,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (_interfaces.isNotEmpty) ...[
                    // M3 DropdownButtonFormField for selecting Interface
                    DropdownButtonFormField<String>(
                      key: ValueKey(_selectedInterfaceName),
                      initialValue: _selectedInterfaceName.isNotEmpty ? _selectedInterfaceName : _interfaces.first.name,
                      decoration: InputDecoration(
                        labelText: 'Pilih Interface Jaringan',
                        prefixIcon: const Icon(Icons.lan_outlined),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      dropdownColor: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      items: _interfaces.map((i) {
                        final isRunning = i.running && !i.disabled;
                        return DropdownMenuItem<String>(
                          value: i.name,
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: isRunning ? colorScheme.primary : colorScheme.outline,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                i.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              if (i.comment.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '(${i.comment})',
                                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _switchInterface(val);
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    // Quick 1-Tap ChoiceChips for fast interface switching
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _interfaces.map((i) {
                          final isSelected = i.name == _selectedInterfaceName;
                          final isRunning = i.running && !i.disabled;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              avatar: Icon(
                                Icons.circle,
                                size: 8,
                                color: isRunning ? colorScheme.primary : colorScheme.outline,
                              ),
                              label: Text(i.name),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  _switchInterface(i.name);
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  LiveTrafficChart(
                    points: _trafficPoints,
                    peakRate: peakRate,
                    interfaceName: _selectedInterfaceName,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // M3 Interfaces Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Interface Jaringan (${_interfaces.length})',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Port & Status Link',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_interfaces.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Tidak ada interface terdeteksi.',
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ..._interfaces.map((iface) {
                      final isRunning = iface.running;
                      final isDisabled = iface.disabled;

                      Color statusCol = colorScheme.primary;
                      String statusText = 'Running';
                      if (isDisabled) {
                        statusCol = colorScheme.outline;
                        statusText = 'Disabled';
                      } else if (!isRunning) {
                        statusCol = colorScheme.error;
                        statusText = 'Down';
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        color: colorScheme.surfaceContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: statusCol.withValues(alpha: 0.16),
                            foregroundColor: statusCol,
                            radius: 18,
                            child: Icon(
                              iface.type == 'vlan' ? Icons.lan_outlined : Icons.settings_ethernet,
                              size: 18,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                iface.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Badge(
                                label: Text(statusText),
                                backgroundColor: statusCol.withValues(alpha: 0.18),
                                textColor: statusCol,
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (iface.comment.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  iface.comment,
                                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                              const SizedBox(height: 2),
                              Text(
                                'Rx: ${FormatUtils.formatBytes(iface.rxByte)} • Tx: ${FormatUtils.formatBytes(iface.txByte)}',
                                style: FNetTheme.monoStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                          trailing: Switch(
                            value: !isDisabled,
                            onChanged: (_) => _toggleInterface(iface),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviousInterfaceTraffic {
  final int rxBytes;
  final int txBytes;
  final int timestamp;

  _PreviousInterfaceTraffic({
    required this.rxBytes,
    required this.txBytes,
    required this.timestamp,
  });
}
