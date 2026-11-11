import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mikrotik_models.dart';
import '../services/mikrotik_api_service.dart';
import '../theme/fnet_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/gauge_widget.dart';
import '../widgets/live_traffic_chart.dart';
import '../widgets/loading_indicator_m3e.dart';

class BerandaScreen extends StatefulWidget {
  final RouterProfile profile;
  final ValueChanged<int>? onNavigateTab;

  const BerandaScreen({
    super.key,
    required this.profile,
    this.onNavigateTab,
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

  int _pppoeActiveCount = 0;
  int _hotspotActiveCount = 0;
  int _dhcpLeasesCount = 0;
  int _pollCount = 0;

  PublicIpInfo _publicIpInfo = const PublicIpInfo();
  bool _isLoadingPublicIp = false;

  String _selectedInterfaceName = '';
  List<TrafficPoint> _trafficPoints = List.generate(28, (_) => const TrafficPoint(rx: 0, tx: 0));
  final Map<String, List<TrafficPoint>> _interfaceTrafficHistory = {};
  final Map<String, _PreviousInterfaceTraffic> _prevTraffic = {};
  Timer? _pollingTimer;

  static const List<String> _allCardKeys = [
    'identity',
    'gauges',
    'clients_summary',
    'traffic',
    'interfaces_status',
    'storage_health',
    'hardware_specs',
    'quick_actions',
    'public_ip',
  ];

  static const Map<String, String> _cardTitles = {
    'identity': 'Informasi Router',
    'gauges': 'Beban CPU & RAM',
    'clients_summary': 'Ringkasan Klien & Layanan',
    'traffic': 'Grafik Trafik Jaringan',
    'interfaces_status': 'Status Interface & Port',
    'storage_health': 'Penyimpanan & Suhu/Voltase',
    'hardware_specs': 'Spesifikasi Perangkat Keras',
    'quick_actions': 'Aksi Cepat & Pintasan',
    'public_ip': 'IP Publik & Provider',
  };

  static const Map<String, IconData> _cardIcons = {
    'identity': Icons.router_outlined,
    'gauges': Icons.speed_rounded,
    'clients_summary': Icons.people_outline_rounded,
    'traffic': Icons.insights_rounded,
    'interfaces_status': Icons.settings_ethernet_rounded,
    'storage_health': Icons.thermostat_outlined,
    'hardware_specs': Icons.developer_board_rounded,
    'quick_actions': Icons.bolt_rounded,
    'public_ip': Icons.public_rounded,
  };

  static const Map<String, String> _defaultCardStyles = {
    'identity': 'detailed',
    'gauges': 'gauge',
    'clients_summary': 'cards',
    'traffic': 'chart',
    'interfaces_status': 'grid',
    'storage_health': 'standard',
    'hardware_specs': 'grid',
    'quick_actions': 'buttons',
    'public_ip': 'banner',
  };

  static const Map<String, Map<String, String>> _styleOptionsMap = {
    'identity': {
      'detailed': 'Lengkap',
      'compact': 'Minimalis',
    },
    'gauges': {
      'gauge': 'Gauge Lingkaran',
      'bar': 'Progress Bar',
      'minimal': 'Kartu Angka',
    },
    'clients_summary': {
      'cards': '3 Kartu Mini',
      'list': 'Daftar Layanan',
      'chips': 'Chip Ringkas',
    },
    'traffic': {
      'chart': 'Grafik Real-time',
      'compact': 'Kecepatan Angka',
    },
    'interfaces_status': {
      'grid': 'Grid Port Switch',
      'list': 'Daftar Port Detail',
      'compact': 'Ringkasan Port',
    },
    'storage_health': {
      'standard': 'Dua Kartu',
      'compact': 'Kartu Terpadu',
    },
    'hardware_specs': {
      'grid': 'Grid Kartu',
      'list': 'Daftar Rincian',
      'compact': 'Minimalis',
    },
    'quick_actions': {
      'buttons': 'Tombol Tonal',
      'chips': 'Pill Chips',
    },
    'public_ip': {
      'banner': 'Banner Status',
      'compact': 'Tile Ringkas',
      'cards': 'Kartu Rincian ISP',
    },
  };

  List<String> _cardOrder = List.from(_allCardKeys);
  Map<String, bool> _cardVisibility = {for (final k in _allCardKeys) k: true};
  Map<String, String> _cardStyles = Map.from(_defaultCardStyles);

  Future<void> _loadDashboardCustomization() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pId = widget.profile.id;

      // 1. Order
      final savedOrder = prefs.getStringList('dashboard_card_order_$pId');
      if (savedOrder != null && savedOrder.isNotEmpty) {
        final mappedOrder = savedOrder.map((k) => k == 'uptime_clock' ? 'public_ip' : k).toList();
        final order = mappedOrder.where((k) => _allCardKeys.contains(k)).toList();
        for (final k in _allCardKeys) {
          if (!order.contains(k)) order.add(k);
        }
        _cardOrder = order;
      } else {
        _cardOrder = List.from(_allCardKeys);
      }

      // 2. Visibility
      final savedVis = prefs.getString('dashboard_card_visibility_$pId');
      if (savedVis != null) {
        final Map<String, dynamic> decoded = jsonDecode(savedVis);
        decoded.forEach((k, v) {
          final targetKey = k == 'uptime_clock' ? 'public_ip' : k;
          if (_cardVisibility.containsKey(targetKey) && v is bool) {
            _cardVisibility[targetKey] = v;
          }
        });
      }

      // 3. Styles
      final savedStyles = prefs.getString('dashboard_card_styles_$pId');
      if (savedStyles != null) {
        final Map<String, dynamic> decoded = jsonDecode(savedStyles);
        decoded.forEach((k, v) {
          final targetKey = k == 'uptime_clock' ? 'public_ip' : k;
          if (_cardStyles.containsKey(targetKey) && v is String) {
            _cardStyles[targetKey] = v;
          }
        });
      }

      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _saveDashboardCustomization() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pId = widget.profile.id;
      await prefs.setStringList('dashboard_card_order_$pId', _cardOrder);
      await prefs.setString('dashboard_card_visibility_$pId', jsonEncode(_cardVisibility));
      await prefs.setString('dashboard_card_styles_$pId', jsonEncode(_cardStyles));
    } catch (_) {}
  }

  Future<void> resetAllDashboardSettings() async {
    setState(() {
      _cardOrder = List.from(_allCardKeys);
      _cardVisibility = {for (final k in _allCardKeys) k: true};
      _cardStyles = Map.from(_defaultCardStyles);
    });
    await _saveDashboardCustomization();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaturan dashboard dikembalikan ke awal'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> showAllWidgets() async {
    setState(() {
      for (final k in _allCardKeys) {
        _cardVisibility[k] = true;
      }
    });
    await _saveDashboardCustomization();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua widget dashboard ditampilkan'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> testRouterConnection() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Menguji respon koneksi router...'),
        duration: Duration(seconds: 1),
      ),
    );
    final res = await MikrotikApiService.instance.testConnection(widget.profile);
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Koneksi normal (${res.durationMs} ms) • RouterOS v${res.data?.version ?? ""}'),
          backgroundColor: FNetTheme.emerald,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Koneksi gagal: ${res.error ?? "Timeout"}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDashboardCustomization();
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
      _loadDashboardCustomization();
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
      _fetchPublicIp();
      final resFuture = MikrotikApiService.instance.getSystemResource(widget.profile);
      final idFuture = MikrotikApiService.instance.getSystemIdentity(widget.profile);
      final healthFuture = MikrotikApiService.instance.getSystemHealth(widget.profile);
      final ifaceFuture = MikrotikApiService.instance.getInterfaces(widget.profile);
      final pppFuture = MikrotikApiService.instance.getPppActive(widget.profile).catchError((_) => <PppActive>[]);
      final hotspotFuture = MikrotikApiService.instance.getHotspotActive(widget.profile).catchError((_) => <HotspotActive>[]);
      final dhcpFuture = MikrotikApiService.instance.getDhcpLeases(widget.profile).catchError((_) => <DhcpLease>[]);

      final results = await Future.wait([
        resFuture,
        idFuture,
        healthFuture,
        ifaceFuture,
        pppFuture,
        hotspotFuture,
        dhcpFuture,
      ]);

      if (mounted) {
        setState(() {
          _resource = results[0] as SystemResource;
          _identity = results[1] as String;
          _health = results[2] as List<SystemHealth>;
          _interfaces = results[3] as List<NetworkInterface>;
          _pppoeActiveCount = (results[4] as List<PppActive>).length;
          _hotspotActiveCount = (results[5] as List<HotspotActive>).length;
          _dhcpLeasesCount = (results[6] as List<DhcpLease>).length;
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

  Future<void> _fetchPublicIp({bool showFeedback = false}) async {
    if (!mounted) return;
    setState(() => _isLoadingPublicIp = true);
    if (showFeedback) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Memeriksa info IP Publik & ISP...'), duration: Duration(seconds: 1)),
      );
    }
    try {
      final info = await MikrotikApiService.instance.getPublicIpInfo(widget.profile);
      if (mounted) {
        setState(() {
          _publicIpInfo = info;
          _isLoadingPublicIp = false;
        });
        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('IP Publik diperbarui: ${info.ip} (${info.isp})'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingPublicIp = false);
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
      final ifaceFuture = MikrotikApiService.instance
          .getInterfaces(widget.profile)
          .catchError((_) => <NetworkInterface>[]);
      final resFuture = MikrotikApiService.instance
          .getSystemResource(widget.profile)
          .catchError((_) => SystemResource());

      final results = await Future.wait([ifaceFuture, resFuture]);
      final newInterfaces = results[0] as List<NetworkInterface>;
      final newResource = results[1] as SystemResource;

      if (!mounted) return;

      if (newInterfaces.isNotEmpty) {
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
          if (newResource.totalMemory > 0) {
            _resource = newResource;
          }
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
      } else if (newResource.totalMemory > 0) {
        setState(() {
          _resource = newResource;
        });
      }

      _pollCount++;
      if (_pollCount % 5 == 0) {
        MikrotikApiService.instance.getPppActive(widget.profile).then((list) {
          if (mounted) setState(() => _pppoeActiveCount = list.length);
        }).catchError((_) {});
        MikrotikApiService.instance.getHotspotActive(widget.profile).then((list) {
          if (mounted) setState(() => _hotspotActiveCount = list.length);
        }).catchError((_) {});
        MikrotikApiService.instance.getDhcpLeases(widget.profile).then((list) {
          if (mounted) setState(() => _dhcpLeasesCount = list.length);
        }).catchError((_) {});
      }
    } catch (_) {}
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

    final tempStatus = temperature != null && temperature >= 70 ? 'Overheat' : 'Normal';
    String voltStatus = 'Stabil';
    if (voltage != null) {
      if (voltage < 10.0 || (voltage > 15.0 && voltage < 20.0)) {
        voltStatus = 'Undervolt';
      } else if ((voltage > 28.0 && voltage < 40.0) || voltage > 56.0) {
        voltStatus = 'Overvolt';
      } else {
        voltStatus = 'Stabil';
      }
    }

    final visibleCardKeys = _cardOrder.where((k) => _cardVisibility[k] != false).toList();

    if (visibleCardKeys.isEmpty) {
      return RefreshIndicator(
        onRefresh: refreshData,
        color: colorScheme.primary,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 60),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.dashboard_customize_outlined, size: 48, color: colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Semua Card Disembunyikan',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Anda dapat mengaktifkan kembali widget yang diinginkan melalui menu kustomisasi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: openCustomizeSheet,
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text('Edit Widget Dashboard'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: refreshData,
      color: colorScheme.primary,
      child: ReorderableListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        buildDefaultDragHandles: false,
        proxyDecorator: (child, index, animation) {
          return Material(
            elevation: 8,
            color: Colors.transparent,
            shadowColor: Colors.black38,
            borderRadius: BorderRadius.circular(12),
            child: child,
          );
        },
        onReorderItem: (oldIndex, newIndex) {
          setState(() {
            final movingKey = visibleCardKeys[oldIndex];
            final targetKey = visibleCardKeys[newIndex];
            final originalOldIndex = _cardOrder.indexOf(movingKey);
            final originalNewIndex = _cardOrder.indexOf(targetKey);

            final item = _cardOrder.removeAt(originalOldIndex);
            _cardOrder.insert(originalNewIndex, item);
          });
          _saveDashboardCustomization();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tata letak dashboard disimpan'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        children: [
          for (int i = 0; i < visibleCardKeys.length; i++)
            ReorderableDelayedDragStartListener(
              key: ValueKey(visibleCardKeys[i]),
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildDashboardCard(
                  visibleCardKeys[i],
                  context,
                  colorScheme,
                  theme,
                  temperature,
                  voltage,
                  peakRate,
                  tempStatus,
                  voltStatus,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void openCustomizeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.8,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (ctx, scrollController) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    Row(
                      children: [
                        Icon(Icons.dashboard_customize_rounded, color: colorScheme.primary, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Tata Letak & Widget',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                'Pilih gaya tampilan atau sembunyikan/tampilkan card',
                                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    const SizedBox(height: 16),

                    for (final cardKey in _allCardKeys) ...[
                      _buildWidgetCustomizerItem(cardKey, colorScheme, theme, setSheetState),
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              resetAllDashboardSettings();
                              setSheetState(() {});
                            },
                            icon: const Icon(Icons.restart_alt_rounded, size: 18),
                            label: const Text('Reset Default'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('Selesai'),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildWidgetCustomizerItem(
    String cardKey,
    ColorScheme colorScheme,
    ThemeData theme,
    void Function(void Function()) setSheetState,
  ) {
    final isVisible = _cardVisibility[cardKey] ?? true;
    final currentStyle = _cardStyles[cardKey] ?? _defaultCardStyles[cardKey]!;
    final styleOptions = _styleOptionsMap[cardKey] ?? {};

    return Card(
      elevation: 0,
      color: isVisible ? colorScheme.surfaceContainerLow : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isVisible ? colorScheme.outlineVariant : colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _cardIcons[cardKey] ?? Icons.widgets_outlined,
                  size: 20,
                  color: isVisible ? colorScheme.primary : colorScheme.outline,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _cardTitles[cardKey] ?? cardKey,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isVisible ? colorScheme.onSurface : colorScheme.outline,
                    ),
                  ),
                ),
                Switch(
                  value: isVisible,
                  onChanged: (val) {
                    setState(() {
                      _cardVisibility[cardKey] = val;
                    });
                    setSheetState(() {});
                    _saveDashboardCustomization();
                  },
                ),
              ],
            ),
            if (isVisible && styleOptions.length > 1) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 10),
              Text(
                'Pilih Gaya:',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: styleOptions.entries.map((entry) {
                  final isSelected = currentStyle == entry.key;
                  return ChoiceChip(
                    selected: isSelected,
                    selectedColor: colorScheme.primary,
                    backgroundColor: colorScheme.surface,
                    side: BorderSide(
                      color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    label: Text(entry.value),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _cardStyles[cardKey] = entry.key;
                        });
                        setSheetState(() {});
                        _saveDashboardCustomization();
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    String key,
    BuildContext context,
    ColorScheme colorScheme,
    ThemeData theme,
    double? temperature,
    double? voltage,
    double peakRate,
    String tempStatus,
    String voltStatus,
  ) {
    final style = _cardStyles[key] ?? _defaultCardStyles[key]!;

    switch (key) {
      case 'identity':
        return style == 'compact'
            ? _buildIdentityCompact(context, colorScheme, theme)
            : _buildIdentityDetailed(context, colorScheme, theme);

      case 'gauges':
        if (style == 'bar') {
          return _buildGaugesLinearBar(context, colorScheme, theme);
        } else if (style == 'minimal') {
          return _buildGaugesMinimal(context, colorScheme, theme);
        }
        return _buildGaugesCircular(context, colorScheme, theme);

      case 'clients_summary':
        return _buildClientsSummary(context, colorScheme, theme);

      case 'traffic':
        return style == 'compact'
            ? _buildTrafficCompact(context, colorScheme, theme, peakRate)
            : _buildTrafficChart(context, colorScheme, theme, peakRate);

      case 'interfaces_status':
        return _buildInterfacesStatus(context, colorScheme, theme);

      case 'storage_health':
        return style == 'compact'
            ? _buildStorageHealthCompact(context, colorScheme, theme, temperature, voltage, tempStatus, voltStatus)
            : _buildStorageHealthStandard(context, colorScheme, theme, temperature, voltage, tempStatus, voltStatus);

      case 'hardware_specs':
        return _buildHardwareSpecs(context, colorScheme, theme);

      case 'quick_actions':
        return _buildQuickActions(context, colorScheme, theme);

      case 'public_ip':
        return _buildPublicIpWidget(context, colorScheme, theme);

      default:
        return const SizedBox.shrink();
    }
  }

  // --- Router Identity Card Styles ---
  Widget _buildIdentityDetailed(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Badge(
                    label: Text(
                      _resource.version.isNotEmpty ? 'v${_resource.version}' : 'RouterOS',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    backgroundColor: colorScheme.primaryContainer,
                    textColor: colorScheme.onPrimaryContainer,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 20, color: colorScheme.onSurfaceVariant),
                    tooltip: 'Opsi Dashboard',
                    onSelected: (val) {
                      if (val == 'edit') {
                        openCustomizeSheet();
                      } else if (val == 'show_all') {
                        showAllWidgets();
                      } else if (val == 'reset') {
                        resetAllDashboardSettings();
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.dashboard_customize_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Edit Gaya & Widget'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'show_all',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Tampilkan Semua'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'reset',
                        child: Row(
                          children: [
                            Icon(Icons.restart_alt_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Reset Tata Letak'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
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
    );
  }

  Widget _buildIdentityCompact(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              radius: 18,
              child: const Icon(Icons.router, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _identity.isNotEmpty ? _identity : widget.profile.name,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${widget.profile.host}:${widget.profile.port} • ${_resource.version.isNotEmpty ? 'v${_resource.version}' : 'RouterOS'}',
                    style: FNetTheme.monoStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Text(
              _resource.uptime,
              style: FNetTheme.monoStyle(fontSize: 11, color: colorScheme.primary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  // --- CPU & RAM Card Styles ---
  Widget _buildGaugesCircular(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
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
    );
  }

  Widget _buildGaugesLinearBar(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.memory_rounded, size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Beban CPU', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                Text(
                  '${_resource.cpuLoad}%',
                  style: FNetTheme.monoStyle(fontSize: 16, fontWeight: FontWeight.w900, color: colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (_resource.cpuLoad / 100.0).clamp(0.0, 1.0),
              backgroundColor: colorScheme.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              borderRadius: BorderRadius.circular(6),
              minHeight: 8,
            ),
            const SizedBox(height: 6),
            Text(
              '${_resource.cpuFrequency} MHz • ${_resource.cpuCount} Core CPU',
              style: FNetTheme.monoStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: colorScheme.outlineVariant),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.developer_board_rounded, size: 18, color: colorScheme.secondary),
                    const SizedBox(width: 8),
                    Text('Memori RAM', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                Text(
                  '${_resource.memoryLoadPercent}%',
                  style: FNetTheme.monoStyle(fontSize: 16, fontWeight: FontWeight.w900, color: colorScheme.secondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (_resource.memoryLoadPercent / 100.0).clamp(0.0, 1.0),
              backgroundColor: colorScheme.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.secondary),
              borderRadius: BorderRadius.circular(6),
              minHeight: 8,
            ),
            const SizedBox(height: 6),
            Text(
              '${FormatUtils.formatBytes(_resource.freeMemory)} bebas dari ${FormatUtils.formatBytes(_resource.totalMemory)}',
              style: FNetTheme.monoStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGaugesMinimal(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.memory_rounded, size: 16, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Text('CPU', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_resource.cpuLoad}%',
                    style: FNetTheme.monoStyle(fontSize: 24, fontWeight: FontWeight.w900, color: colorScheme.primary),
                  ),
                  Text(
                    '${_resource.cpuCount} Core • ${_resource.cpuFrequency}MHz',
                    style: FNetTheme.monoStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Container(width: 1, height: 48, color: colorScheme.outlineVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.developer_board_rounded, size: 16, color: colorScheme.secondary),
                      const SizedBox(width: 6),
                      Text('RAM', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_resource.memoryLoadPercent}%',
                    style: FNetTheme.monoStyle(fontSize: 24, fontWeight: FontWeight.w900, color: colorScheme.secondary),
                  ),
                  Text(
                    '${FormatUtils.formatBytes(_resource.freeMemory)} Bebas',
                    style: FNetTheme.monoStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Storage & Health Card Styles ---
  Widget _buildStorageHealthStandard(
    BuildContext context,
    ColorScheme colorScheme,
    ThemeData theme,
    double? temperature,
    double? voltage,
    String tempStatus,
    String voltStatus,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // M3 Storage HDD Card
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          temperature != null ? '${temperature.toStringAsFixed(0)}°C' : 'N/A',
                          style: FNetTheme.monoStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: (temperature ?? 0) >= 70 ? colorScheme.error : colorScheme.onSurface,
                          ),
                        ),
                        if (voltage != null)
                          Text(
                            '${voltage.toStringAsFixed(1)}V',
                            style: FNetTheme.monoStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.secondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: temperature != null ? (temperature / 80.0).clamp(0.0, 1.0) : 0.0,
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        (temperature ?? 0) >= 70 ? colorScheme.error : colorScheme.tertiary,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      minHeight: 6,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tempStatus,
                          style: FNetTheme.monoStyle(
                            fontSize: 11,
                            color: temperature != null && temperature >= 70
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
                            fontWeight: temperature != null && temperature >= 70
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        Text(
                          voltStatus,
                          style: FNetTheme.monoStyle(
                            fontSize: 11,
                            color: voltStatus == 'Overvolt' || voltStatus == 'Undervolt'
                                ? colorScheme.error
                                : colorScheme.onSurfaceVariant,
                            fontWeight: voltStatus == 'Overvolt' || voltStatus == 'Undervolt'
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
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
    );
  }

  Widget _buildStorageHealthCompact(
    BuildContext context,
    ColorScheme colorScheme,
    ThemeData theme,
    double? temperature,
    double? voltage,
    String tempStatus,
    String voltStatus,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.storage_outlined, size: 16, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Penyimpanan (${_resource.hddLoadPercent}%)', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                Text(
                  '${FormatUtils.formatBytes(_resource.freeHddSpace)} bebas',
                  style: FNetTheme.monoStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: (_resource.hddLoadPercent / 100.0).clamp(0.0, 1.0),
              backgroundColor: colorScheme.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              borderRadius: BorderRadius.circular(6),
              minHeight: 6,
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.thermostat_outlined, size: 16, color: colorScheme.tertiary),
                    const SizedBox(width: 8),
                    Text(
                      temperature != null ? '${temperature.toStringAsFixed(0)}°C ($tempStatus)' : 'Suhu N/A',
                      style: FNetTheme.monoStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: (temperature ?? 0) >= 70 ? colorScheme.error : colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.bolt_outlined, size: 16, color: colorScheme.secondary),
                    const SizedBox(width: 4),
                    Text(
                      voltage != null ? '${voltage.toStringAsFixed(1)}V ($voltStatus)' : 'Tegangan N/A',
                      style: FNetTheme.monoStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: voltStatus == 'Overvolt' || voltStatus == 'Undervolt' ? colorScheme.error : colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Traffic Card Styles ---
  Widget _buildTrafficChart(BuildContext context, ColorScheme colorScheme, ThemeData theme, double peakRate) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

            LiveTrafficChart(
              points: _trafficPoints,
              peakRate: peakRate,
              interfaceName: _selectedInterfaceName,
            ),

            const SizedBox(height: 16),
            _buildInterfaceChoiceChips(colorScheme, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTrafficCompact(BuildContext context, ColorScheme colorScheme, ThemeData theme, double peakRate) {
    final currentRx = _trafficPoints.isNotEmpty ? _trafficPoints.last.rx : 0.0;
    final currentTx = _trafficPoints.isNotEmpty ? _trafficPoints.last.tx : 0.0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.speed_rounded, color: colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Kecepatan Trafik Real-time',
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
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.primary.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.arrow_downward_rounded, size: 16, color: colorScheme.primary),
                            const SizedBox(width: 4),
                            Text('Download (Rx)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colorScheme.primary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${currentRx.toStringAsFixed(2)} Mbps',
                          style: FNetTheme.monoStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colorScheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.arrow_upward_rounded, size: 16, color: colorScheme.secondary),
                            const SizedBox(width: 4),
                            Text('Upload (Tx)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colorScheme.secondary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${currentTx.toStringAsFixed(2)} Mbps',
                          style: FNetTheme.monoStyle(fontSize: 18, fontWeight: FontWeight.w900, color: colorScheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInterfaceChoiceChips(colorScheme, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildInterfaceChoiceChips(ColorScheme colorScheme, ThemeData theme) {
    if (_interfaces.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune_rounded, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              'Pilih Interface Jaringan',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _interfaces.map((i) {
              final isSelected = i.name == _selectedInterfaceName;
              final isRunning = i.running && !i.disabled;
              final comment = i.comment.trim();
              final shortComment = comment.length > 16 ? '${comment.substring(0, 14)}…' : comment;
              final label = shortComment.isNotEmpty ? '${i.name} • $shortComment' : i.name;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  showCheckmark: false,
                  selected: isSelected,
                  selectedColor: colorScheme.primary,
                  backgroundColor: colorScheme.surface,
                  side: BorderSide(
                    color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  avatar: Icon(
                    Icons.circle,
                    size: 7,
                    color: isSelected
                        ? colorScheme.onPrimary
                        : (isRunning ? FNetTheme.emerald : colorScheme.outline),
                  ),
                  label: Text(label),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                  ),
                  onSelected: (selected) {
                    if (selected && !isSelected) {
                      _switchInterface(i.name);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // --- Clients & Services Summary Card Styles ---
  Widget _buildClientsSummary(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    final style = _cardStyles['clients_summary'] ?? _defaultCardStyles['clients_summary']!;
    switch (style) {
      case 'list':
        return _buildClientsSummaryList(context, colorScheme, theme);
      case 'chips':
        return _buildClientsSummaryChips(context, colorScheme, theme);
      case 'cards':
      default:
        return _buildClientsSummaryCards(context, colorScheme, theme);
    }
  }

  Widget _buildClientsSummaryCards(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    final totalClients = _pppoeActiveCount + _hotspotActiveCount + _dhcpLeasesCount;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.people_outline_rounded, color: colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Klien & Layanan Aktif',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Badge(
                  label: Text(
                    '$totalClients TOTAL',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10),
                  ),
                  backgroundColor: colorScheme.primaryContainer,
                  textColor: colorScheme.onPrimaryContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => widget.onNavigateTab?.call(1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.group_rounded, color: colorScheme.primary, size: 22),
                          const SizedBox(height: 6),
                          Text(
                            '$_pppoeActiveCount',
                            style: FNetTheme.monoStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'PPPoE Aktif',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => widget.onNavigateTab?.call(2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.secondary.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.wifi_rounded, color: colorScheme.secondary, size: 22),
                          const SizedBox(height: 6),
                          Text(
                            '$_hotspotActiveCount',
                            style: FNetTheme.monoStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Hotspot Aktif',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.secondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => widget.onNavigateTab?.call(3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.tertiary.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.lan_rounded, color: colorScheme.tertiary, size: 22),
                          const SizedBox(height: 6),
                          Text(
                            '$_dhcpLeasesCount',
                            style: FNetTheme.monoStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'DHCP Lease',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.tertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  Widget _buildClientsSummaryList(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Klien & Layanan Terhubung',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.primary,
                child: const Icon(Icons.group_rounded, size: 20),
              ),
              title: const Text('PPPoE Active Sessions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: const Text('Klien dial-up PPPoE online', style: TextStyle(fontSize: 11)),
              trailing: Badge(
                label: Text('$_pppoeActiveCount User', style: const TextStyle(fontWeight: FontWeight.w700)),
                backgroundColor: colorScheme.primaryContainer,
                textColor: colorScheme.onPrimaryContainer,
              ),
              onTap: () => widget.onNavigateTab?.call(1),
            ),
            Divider(height: 1, indent: 16, endIndent: 16, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: colorScheme.secondaryContainer,
                foregroundColor: colorScheme.secondary,
                child: const Icon(Icons.wifi_rounded, size: 20),
              ),
              title: const Text('Hotspot Active Users', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: const Text('Voucher & member hotspot aktif', style: TextStyle(fontSize: 11)),
              trailing: Badge(
                label: Text('$_hotspotActiveCount User', style: const TextStyle(fontWeight: FontWeight.w700)),
                backgroundColor: colorScheme.secondaryContainer,
                textColor: colorScheme.onSecondaryContainer,
              ),
              onTap: () => widget.onNavigateTab?.call(2),
            ),
            Divider(height: 1, indent: 16, endIndent: 16, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: colorScheme.tertiaryContainer,
                foregroundColor: colorScheme.tertiary,
                child: const Icon(Icons.lan_rounded, size: 20),
              ),
              title: const Text('DHCP Server Leases', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: const Text('Perangkat terdaftar pada IP Pool', style: TextStyle(fontSize: 11)),
              trailing: Badge(
                label: Text('$_dhcpLeasesCount Leases', style: const TextStyle(fontWeight: FontWeight.w700)),
                backgroundColor: colorScheme.tertiaryContainer,
                textColor: colorScheme.onTertiaryContainer,
              ),
              onTap: () => widget.onNavigateTab?.call(3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientsSummaryChips(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ActionChip(
              avatar: Icon(Icons.group_rounded, size: 16, color: colorScheme.primary),
              label: Text('PPPoE: $_pppoeActiveCount'),
              onPressed: () => widget.onNavigateTab?.call(1),
            ),
            ActionChip(
              avatar: Icon(Icons.wifi_rounded, size: 16, color: colorScheme.secondary),
              label: Text('Hotspot: $_hotspotActiveCount'),
              onPressed: () => widget.onNavigateTab?.call(2),
            ),
            ActionChip(
              avatar: Icon(Icons.lan_rounded, size: 16, color: colorScheme.tertiary),
              label: Text('DHCP: $_dhcpLeasesCount'),
              onPressed: () => widget.onNavigateTab?.call(3),
            ),
          ],
        ),
      ),
    );
  }

  // --- Network Interface Status Card Styles ---
  Widget _buildInterfacesStatus(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    final style = _cardStyles['interfaces_status'] ?? _defaultCardStyles['interfaces_status']!;
    switch (style) {
      case 'list':
        return _buildInterfacesStatusList(context, colorScheme, theme);
      case 'compact':
        return _buildInterfacesStatusCompact(context, colorScheme, theme);
      case 'grid':
      default:
        return _buildInterfacesStatusGrid(context, colorScheme, theme);
    }
  }

  Widget _buildInterfacesStatusGrid(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    final upCount = _interfaces.where((i) => i.running && !i.disabled).length;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.settings_ethernet_rounded, color: colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Status Interface & Port',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Badge(
                  label: Text(
                    '$upCount / ${_interfaces.length} LINK UP',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10),
                  ),
                  backgroundColor: upCount > 0 ? FNetTheme.emerald.withValues(alpha: 0.2) : colorScheme.surfaceContainerHigh,
                  textColor: upCount > 0 ? FNetTheme.emerald : colorScheme.outline,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_interfaces.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Tidak ada interface terdeteksi', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _interfaces.map((i) {
                  final isUp = i.running && !i.disabled;
                  final isSelected = i.name == _selectedInterfaceName;
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _switchInterface(i.name),
                    child: Container(
                      width: 100,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                            : colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant.withValues(alpha: 0.5),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Icon(
                                i.type.toLowerCase().contains('wlan') || i.type.toLowerCase().contains('wifi')
                                    ? Icons.wifi_rounded
                                    : Icons.settings_ethernet_rounded,
                                size: 14,
                                color: isUp ? colorScheme.primary : colorScheme.outline,
                              ),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isUp ? FNetTheme.emerald : colorScheme.outline.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            i.name,
                            style: FNetTheme.monoStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isUp ? colorScheme.onSurface : colorScheme.outline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            isUp ? 'RUNNING' : (i.disabled ? 'DISABLED' : 'NO LINK'),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isUp ? FNetTheme.emerald : colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterfacesStatusList(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Daftar Interface Jaringan', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  Text('${_interfaces.length} Port', style: FNetTheme.monoStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ..._interfaces.take(6).map((i) {
              final isUp = i.running && !i.disabled;
              return ListTile(
                dense: true,
                leading: Icon(
                  i.type.toLowerCase().contains('wlan') ? Icons.wifi_rounded : Icons.settings_ethernet_rounded,
                  color: isUp ? colorScheme.primary : colorScheme.outline,
                  size: 20,
                ),
                title: Text(
                  i.name + (i.comment.isNotEmpty ? ' (${i.comment})' : ''),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Rx: ${FormatUtils.formatBytes(i.rxByte)} • Tx: ${FormatUtils.formatBytes(i.txByte)}',
                  style: FNetTheme.monoStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                ),
                trailing: Badge(
                  label: Text(isUp ? 'UP' : 'DOWN', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 9)),
                  backgroundColor: isUp ? FNetTheme.emerald.withValues(alpha: 0.2) : colorScheme.surfaceContainerHigh,
                  textColor: isUp ? FNetTheme.emerald : colorScheme.outline,
                ),
                onTap: () => _switchInterface(i.name),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInterfacesStatusCompact(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    final upCount = _interfaces.where((i) => i.running && !i.disabled).length;
    final ratio = _interfaces.isNotEmpty ? (upCount / _interfaces.length) : 0.0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.settings_ethernet_rounded, size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Port Link Status', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
                Text(
                  '$upCount / ${_interfaces.length} Port Aktif',
                  style: FNetTheme.monoStyle(fontSize: 12, fontWeight: FontWeight.w800, color: colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              backgroundColor: colorScheme.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              borderRadius: BorderRadius.circular(6),
              minHeight: 6,
            ),
          ],
        ),
      ),
    );
  }

  // --- Hardware Specs Card Styles ---
  Widget _buildHardwareSpecs(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    final style = _cardStyles['hardware_specs'] ?? _defaultCardStyles['hardware_specs']!;
    switch (style) {
      case 'list':
        return _buildHardwareSpecsList(context, colorScheme, theme);
      case 'compact':
        return _buildHardwareSpecsCompact(context, colorScheme, theme);
      case 'grid':
      default:
        return _buildHardwareSpecsGrid(context, colorScheme, theme);
    }
  }

  Widget _buildHardwareSpecsGrid(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    Widget buildSpecItem(IconData icon, String label, String value, [Color? valueColor]) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: FNetTheme.monoStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: valueColor ?? colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    final board = _resource.boardName.isNotEmpty ? _resource.boardName : (_resource.architectureName.isNotEmpty ? _resource.architectureName : 'RouterBOARD');
    final arch = _resource.architectureName.isNotEmpty ? _resource.architectureName : 'MIPS / ARM';
    final cpuInfo = '${_resource.cpuCount} Core @ ${_resource.cpuFrequency}MHz';
    final badBlocksText = '${_resource.badBlocks}% ${_resource.badBlocks == 0 ? "(Sehat)" : ""}';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.developer_board_rounded, color: colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Spesifikasi Perangkat Keras',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Badge(
                  label: Text(
                    _resource.platform.isNotEmpty ? _resource.platform.toUpperCase() : 'MIKROTIK',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10),
                  ),
                  backgroundColor: colorScheme.secondaryContainer,
                  textColor: colorScheme.onSecondaryContainer,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: buildSpecItem(Icons.router_outlined, 'Model Board', board)),
                const SizedBox(width: 8),
                Expanded(child: buildSpecItem(Icons.architecture_rounded, 'Arsitektur', arch)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: buildSpecItem(Icons.memory_rounded, 'Prosesor CPU', cpuInfo)),
                const SizedBox(width: 8),
                Expanded(
                  child: buildSpecItem(
                    Icons.health_and_safety_outlined,
                    'Bad Blocks',
                    badBlocksText,
                    _resource.badBlocks > 0 ? colorScheme.error : FNetTheme.emerald,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHardwareSpecsList(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Rincian Spesifikasi Router', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ),
            ListTile(
              dense: true,
              leading: Icon(Icons.router_outlined, color: colorScheme.primary, size: 20),
              title: const Text('Model Board & Arsitektur', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${_resource.boardName} (${_resource.architectureName})',
                style: FNetTheme.monoStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
              ),
            ),
            Divider(height: 1, indent: 16, endIndent: 16, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ListTile(
              dense: true,
              leading: Icon(Icons.memory_rounded, color: colorScheme.secondary, size: 20),
              title: const Text('Spesifikasi CPU & Frekuensi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${_resource.cpu} • ${_resource.cpuCount} Core @ ${_resource.cpuFrequency} MHz',
                style: FNetTheme.monoStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
              ),
            ),
            Divider(height: 1, indent: 16, endIndent: 16, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ListTile(
              dense: true,
              leading: Icon(Icons.verified_outlined, color: FNetTheme.emerald, size: 20),
              title: const Text('Kondisi Bad Blocks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${_resource.badBlocks}% ${_resource.badBlocks == 0 ? "• Memori Sehat" : "• Waspada sektor rusak"}',
                style: FNetTheme.monoStyle(
                  fontSize: 11,
                  color: _resource.badBlocks > 0 ? colorScheme.error : FNetTheme.emerald,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHardwareSpecsCompact(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.developer_board_rounded, size: 20, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${_resource.boardName.isNotEmpty ? _resource.boardName : "RouterBOARD"} • ${_resource.cpuCount} Core ${_resource.cpuFrequency}MHz',
                style: FNetTheme.monoStyle(fontSize: 12, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Badge(
              label: Text(_resource.architectureName.isNotEmpty ? _resource.architectureName : 'MIPS'),
              backgroundColor: colorScheme.surfaceContainerHighest,
              textColor: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  // --- Quick Actions Card Styles ---
  Widget _buildQuickActions(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    final style = _cardStyles['quick_actions'] ?? _defaultCardStyles['quick_actions']!;
    if (style == 'chips') {
      return _buildQuickActionsChips(context, colorScheme, theme);
    }
    return _buildQuickActionsButtons(context, colorScheme, theme);
  }

  Widget _buildQuickActionsButtons(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bolt_rounded, color: colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Aksi Cepat & Pintasan',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      refreshData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Menyegarkan data dashboard...'), duration: Duration(seconds: 1)),
                      );
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Segarkan', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      final ipText = _publicIpInfo.ip.isNotEmpty ? _publicIpInfo.ip : widget.profile.host;
                      Clipboard.setData(ClipboardData(text: ipText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('IP Publik disalin: $ipText'), duration: const Duration(seconds: 2)),
                      );
                    },
                    icon: const Icon(Icons.public_rounded, size: 16),
                    label: const Text('Salin IP', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.profile.host));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Host router disalin: ${widget.profile.host}'), duration: const Duration(seconds: 2)),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Salin Host', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: openCustomizeSheet,
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('Edit Widget', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsChips(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Segarkan'),
              onPressed: () {
                refreshData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Menyegarkan data dashboard...'), duration: Duration(seconds: 1)),
                );
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.public_rounded, size: 16),
              label: const Text('Salin IP Publik'),
              onPressed: () {
                final ipText = _publicIpInfo.ip.isNotEmpty ? _publicIpInfo.ip : widget.profile.host;
                Clipboard.setData(ClipboardData(text: ipText));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('IP Publik disalin: $ipText'), duration: const Duration(seconds: 2)),
                );
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Salin Host'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: widget.profile.host));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Host router disalin: ${widget.profile.host}'), duration: const Duration(seconds: 2)),
                );
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.tune_rounded, size: 16),
              label: const Text('Atur Widget'),
              onPressed: openCustomizeSheet,
            ),
          ],
        ),
      ),
    );
  }

  // --- IP Publik & Provider Card Styles (Material 3 Standar) ---
  Widget _buildPublicIpWidget(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    final style = _cardStyles['public_ip'] ?? _defaultCardStyles['public_ip']!;
    if (style == 'compact') {
      return _buildPublicIpCompact(context, colorScheme, theme);
    } else if (style == 'cards') {
      return _buildPublicIpCards(context, colorScheme, theme);
    }
    return _buildPublicIpBanner(context, colorScheme, theme);
  }

  Widget _buildPublicIpBanner(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    final ipText = _publicIpInfo.ip.isNotEmpty ? _publicIpInfo.ip : widget.profile.host;
    final rawIsp = _publicIpInfo.isp.trim();
    final ispName = (rawIsp.isEmpty || rawIsp.toLowerCase().contains('cloud') || rawIsp.toLowerCase().contains('mikrotik'))
        ? 'SpaceX Starlink'
        : rawIsp;
    final sourceText = _publicIpInfo.source.isNotEmpty ? _publicIpInfo.source : 'Starlink Internet Services';

    return Card(
      margin: EdgeInsets.zero,
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
                radius: 20,
                child: const Icon(Icons.public_rounded, size: 22),
              ),
              title: Text(
                ispName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              subtitle: Text(
                sourceText,
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    tooltip: 'Salin IP Publik',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: ipText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('IP Publik disalin: $ipText'), duration: const Duration(seconds: 2)),
                      );
                    },
                  ),
                  IconButton(
                    icon: _isLoadingPublicIp
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Perbarui dari Router',
                    onPressed: _isLoadingPublicIp ? null : () => _fetchPublicIp(showFeedback: true),
                  ),
                ],
              ),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IP PUBLIK MIKROTIK',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      ipText,
                      style: FNetTheme.monoStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                if (_publicIpInfo.dnsName.isNotEmpty)
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'CLOUD DDNS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _publicIpInfo.dnsName,
                          style: FNetTheme.monoStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPublicIpCompact(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    final ipText = _publicIpInfo.ip.isNotEmpty ? _publicIpInfo.ip : widget.profile.host;
    final rawIsp = _publicIpInfo.isp.trim();
    final ispName = (rawIsp.isEmpty || rawIsp.toLowerCase().contains('cloud') || rawIsp.toLowerCase().contains('mikrotik'))
        ? 'SpaceX Starlink'
        : rawIsp;
    final sourceText = _publicIpInfo.source.isNotEmpty ? _publicIpInfo.source : 'Starlink Internet Services';

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          radius: 18,
          child: const Icon(Icons.public_rounded, size: 20),
        ),
        title: Text(ispName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        subtitle: Text(
          '$ipText • $sourceText',
          style: FNetTheme.monoStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy_rounded, size: 18),
          tooltip: 'Salin IP',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: ipText));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('IP Publik disalin: $ipText'), duration: const Duration(seconds: 2)),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPublicIpCards(BuildContext context, ColorScheme colorScheme, ThemeData theme) {
    final ipText = _publicIpInfo.ip.isNotEmpty ? _publicIpInfo.ip : widget.profile.host;
    final rawIsp = _publicIpInfo.isp.trim();
    final ispName = (rawIsp.isEmpty || rawIsp.toLowerCase().contains('cloud') || rawIsp.toLowerCase().contains('mikrotik'))
        ? 'SpaceX Starlink'
        : rawIsp;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PROVIDER / WAN',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ispName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IP PUBLIK',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    ipText,
                    style: FNetTheme.monoStyle(fontSize: 14, fontWeight: FontWeight.w800, color: colorScheme.primary),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 18),
              tooltip: 'Salin IP',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: ipText));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('IP Publik disalin: $ipText'), duration: const Duration(seconds: 2)),
                );
              },
            ),
          ],
        ),
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
