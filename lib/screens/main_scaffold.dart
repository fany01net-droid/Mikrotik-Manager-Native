import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/mikrotik_models.dart';
import '../services/mikrotik_api_service.dart';
import '../services/storage_service.dart';
import '../theme/fnet_theme.dart';
import 'beranda_screen.dart';
import 'dhcp_screen.dart';
import 'hotspot_screen.dart';
import 'pppoe_screen.dart';
import 'settings_screen.dart';

class MainScaffold extends StatefulWidget {
  final bool isDark;
  final ValueChanged<bool> onThemeToggle;
  final VoidCallback onLogout;

  const MainScaffold({
    super.key,
    required this.isDark,
    required this.onThemeToggle,
    required this.onLogout,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentTabIndex = 0;
  List<RouterProfile> _profiles = [];
  String _activeProfileId = 'default-profile';
  bool _isLoadingProfiles = true;
  int _lastLatencyMs = -1;
  Timer? _latencyTimer;

  final GlobalKey<BerandaScreenState> _berandaKey = GlobalKey<BerandaScreenState>();
  final GlobalKey<PppoeScreenState> _pppoeKey = GlobalKey<PppoeScreenState>();
  final GlobalKey<HotspotScreenState> _hotspotKey = GlobalKey<HotspotScreenState>();
  final GlobalKey<DhcpScreenState> _dhcpKey = GlobalKey<DhcpScreenState>();

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    _latencyTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkActiveLatency();
    });
  }

  @override
  void dispose() {
    _latencyTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    final profiles = await StorageService.getProfiles();
    final activeId = await StorageService.getActiveProfileId();
    if (mounted) {
      setState(() {
        _profiles = profiles;
        _activeProfileId = activeId;
        _isLoadingProfiles = false;
      });
      _checkActiveLatency();
    }
  }

  RouterProfile get _activeProfile {
    return _profiles.firstWhere(
      (p) => p.id == _activeProfileId,
      orElse: () => _profiles.isNotEmpty ? _profiles.first : StorageService.defaultProfile,
    );
  }

  Future<void> _checkActiveLatency() async {
    try {
      final res = await MikrotikApiService.instance.testConnection(_activeProfile);
      if (mounted) {
        setState(() {
          _lastLatencyMs = res.success ? res.durationMs : -1;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _lastLatencyMs = -1);
    }
  }

  void _handleSwitchProfile(String id) async {
    await StorageService.setActiveProfileId(id);
    setState(() {
      _activeProfileId = id;
    });
    _checkActiveLatency();
    _refreshCurrentView();
  }

  void _refreshCurrentView() {
    HapticFeedback.lightImpact();
    switch (_currentTabIndex) {
      case 0:
        _berandaKey.currentState?.refreshData();
        break;
      case 1:
        _pppoeKey.currentState?.refreshData();
        break;
      case 2:
        _hotspotKey.currentState?.refreshData();
        break;
      case 3:
        _dhcpKey.currentState?.refreshData();
        break;
    }
    _checkActiveLatency();
  }

  void _handleConvertToPppoe({required String name, required String ip, required String comment}) {
    setState(() => _currentTabIndex = 1);
    Future.delayed(const Duration(milliseconds: 150), () {
      _pppoeKey.currentState?.openAddSecretPrefilled(name: name, ip: ip, comment: comment);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoadingProfiles) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      );
    }

    final active = _activeProfile;
    final statusColor = FNetTheme.latencyColor(_lastLatencyMs);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            // Official M3 Router Indicator Avatar
            Badge(
              alignment: Alignment.bottomRight,
              backgroundColor: statusColor,
              smallSize: 10,
              child: CircleAvatar(
                radius: 19,
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                child: const Icon(Icons.router_outlined, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          active.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_lastLatencyMs > 0) ...[
                        const SizedBox(width: 8),
                        Badge(
                          label: Text('${_lastLatencyMs}ms'),
                          backgroundColor: statusColor.withValues(alpha: 0.16),
                          textColor: statusColor,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '${active.host}:${active.port}',
                    style: FNetTheme.monoStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => widget.onThemeToggle(!widget.isDark),
            icon: Icon(widget.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            tooltip: widget.isDark ? 'Mode Terang' : 'Mode Gelap',
          ),
          IconButton(
            onPressed: _refreshCurrentView,
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan Data',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          BerandaScreen(key: _berandaKey, profile: active),
          PppoeScreen(key: _pppoeKey, profile: active),
          HotspotScreen(key: _hotspotKey, profile: active),
          DhcpScreen(key: _dhcpKey, profile: active, onConvertToPppoe: _handleConvertToPppoe),
          SettingsScreen(
            profiles: _profiles,
            activeProfileId: _activeProfileId,
            onSwitchProfile: _handleSwitchProfile,
            onProfilesUpdated: _loadProfiles,
            isDark: widget.isDark,
            onThemeToggle: widget.onThemeToggle,
            onLogout: widget.onLogout,
          ),
        ],
      ),

      // Official Material 3 NavigationBar
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (index) {
          HapticFeedback.selectionClick();
          setState(() => _currentTabIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.speed_outlined),
            selectedIcon: Icon(Icons.speed),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'PPPoE',
          ),
          NavigationDestination(
            icon: Icon(Icons.wifi_outlined),
            selectedIcon: Icon(Icons.wifi),
            label: 'Hotspot',
          ),
          NavigationDestination(
            icon: Icon(Icons.lan_outlined),
            selectedIcon: Icon(Icons.lan),
            label: 'DHCP',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}
