import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/mikrotik_models.dart';
import '../services/mikrotik_api_service.dart';
import '../theme/fnet_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/loading_indicator_m3e.dart';
import '../widgets/toast_banner.dart';

class DhcpScreen extends StatefulWidget {
  final RouterProfile profile;
  final String searchQuery;
  final void Function({required String name, required String ip, required String comment}) onConvertToPppoe;

  const DhcpScreen({
    super.key,
    required this.profile,
    this.searchQuery = '',
    required this.onConvertToPppoe,
  });

  @override
  State<DhcpScreen> createState() => DhcpScreenState();
}

class DhcpScreenState extends State<DhcpScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<DhcpLease> _leases = [];
  String _searchQuery = '';
  int _selectedSubTab = 0; // 0: Semua, 1: Aktif, 2: Menunggu
  String _serverFilter = 'all';

  // Infinite Scroll Lazy Load Chunking (25 data per chunk)
  int _visibleLeasesCount = 25;
  final ScrollController _leaseScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.searchQuery;
    _leaseScrollController.addListener(_onScroll);
    refreshData();
  }

  @override
  void didUpdateWidget(covariant DhcpScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _searchQuery = widget.searchQuery;
      _visibleLeasesCount = 25;
    }
    if (oldWidget.profile.id != widget.profile.id ||
        oldWidget.profile.host != widget.profile.host ||
        oldWidget.profile.port != widget.profile.port) {
      _errorMessage = null;
      _visibleLeasesCount = 25;
      _leases = [];
      refreshData();
    }
  }

  void setSearchQuery(String query) {
    setState(() {
      _searchQuery = query;
      _visibleLeasesCount = 25;
    });
  }

  @override
  void dispose() {
    _leaseScrollController.removeListener(_onScroll);
    _leaseScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_leaseScrollController.hasClients &&
        _leaseScrollController.position.pixels >= _leaseScrollController.position.maxScrollExtent - 250) {
      if (_visibleLeasesCount < _leases.length) {
        setState(() {
          _visibleLeasesCount = (_visibleLeasesCount + 25).clamp(0, _leases.length);
        });
      }
    }
  }

  Future<void> refreshData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final leases = await MikrotikApiService.instance.getDhcpLeases(widget.profile);
      if (mounted) {
        setState(() {
          _leases = leases;
          _isLoading = false;
          _errorMessage = null;
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

  Future<void> _handleToggleStatic(DhcpLease lease) async {
    try {
      if (lease.isDynamic) {
        await MikrotikApiService.instance.makeDhcpLeaseStatic(widget.profile, lease.id);
        if (mounted) {
          ToastBanner.show(
            context,
            message: 'Lease ${lease.address} berhasil dijadikan Static.',
            type: ToastType.success,
          );
        }
      } else {
        await MikrotikApiService.instance.releaseDhcpLeaseStatic(widget.profile, lease.id);
        if (mounted) {
          ToastBanner.show(
            context,
            message: 'Reservasi static ${lease.address} dilepas.',
            type: ToastType.success,
          );
        }
      }
      refreshData();
    } catch (e) {
      if (mounted) {
        ToastBanner.show(
          context,
          message: 'Gagal mengubah reservasi: $e',
          type: ToastType.error,
        );
      }
    }
  }

  void _confirmDeleteLease(DhcpLease lease) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
        title: const Text('Hapus DHCP Lease?'),
        content: Text('Apakah Anda yakin ingin menghapus lease untuk IP ${lease.address} (${lease.macAddress})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await MikrotikApiService.instance.deleteDhcpLease(widget.profile, lease.id);
                if (mounted) {
                  ToastBanner.show(context, message: 'Lease ${lease.address} berhasil dihapus.', type: ToastType.success);
                }
                refreshData();
              } catch (e) {
                if (mounted) {
                  ToastBanner.show(context, message: 'Gagal menghapus lease: $e', type: ToastType.error);
                }
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool hasError = _errorMessage != null;

    if (hasError) {
      return Scaffold(
        body: _buildErrorEmptyState(theme, colorScheme),
      );
    }

    if (_isLoading) {
      return Scaffold(
        body: Center(
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
                'Memuat data DHCP Server...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _leases.where((l) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!l.address.toLowerCase().contains(q) &&
            !l.macAddress.toLowerCase().contains(q) &&
            !l.hostName.toLowerCase().contains(q) &&
            !l.comment.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (_selectedSubTab == 1) {
        if (l.status != 'bound') return false;
      } else if (_selectedSubTab == 2) {
        if (l.status == 'bound') return false;
      }
      if (_serverFilter != 'all') {
        if (l.server != _serverFilter) return false;
      }
      return true;
    }).toList();

    final visibleItems = filtered.take(_visibleLeasesCount).toList();
    final servers = _leases.map((l) => l.server).where((s) => s.isNotEmpty).toSet().toList();

    final totalCount = _leases.length;
    final boundCount = _leases.where((l) => l.status == 'bound').length;
    final waitingCount = _leases.where((l) => l.status != 'bound').length;

    return DefaultTabController(
      length: 3,
      initialIndex: _selectedSubTab,
      child: Builder(
        builder: (ctx) {
          return Scaffold(
            body: Column(
              children: [
                // Official Material 3 Secondary TabBar
                TabBar(
                  onTap: (index) {
                    setState(() {
                      _selectedSubTab = index;
                      _visibleLeasesCount = 25;
                    });
                  },
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: colorScheme.primary,
                  unselectedLabelColor: colorScheme.onSurfaceVariant,
                  tabs: [
                    Tab(text: 'Semua ($totalCount)'),
                    Tab(text: 'Aktif ($boundCount)'),
                    Tab(text: 'Menunggu ($waitingCount)'),
                  ],
                ),

                // Content body
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: refreshData,
                    color: colorScheme.primary,
                    child: ListView(
                      controller: _leaseScrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      children: [
                              // Optional Server Filter Buttons (if router has multiple DHCP servers)
                              if (servers.length > 1) ...[
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _buildServerButton('all', 'Semua Server', colorScheme),
                                      const SizedBox(width: 8),
                                      ...servers.map((s) => Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: _buildServerButton(s, 'Server: $s', colorScheme),
                                      )),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],

                              // Active search indicator (if searched from AppBar)
                              if (_searchQuery.isNotEmpty) ...[
                                Row(
                                  children: [
                                    InputChip(
                                      avatar: const Icon(Icons.search, size: 16),
                                      label: Text('Pencarian: "$_searchQuery"'),
                                      onDeleted: () => setSearchQuery(''),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],

                  if (filtered.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(36),
                        child: Text('Tidak ada DHCP lease yang cocok.', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
                      ),
                    )
                  else ...[
                    ...visibleItems.map((lease) {
                      final vendor = FormatUtils.detectDeviceVendor(lease.macAddress, lease.hostName);
                      final isBound = lease.status == 'bound';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
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
                                      Badge(
                                        smallSize: 10,
                                        backgroundColor: isBound ? colorScheme.primary : colorScheme.outline,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        lease.hostName.isNotEmpty ? lease.hostName : lease.address,
                                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                  Badge(
                                    label: Text(lease.isDynamic ? 'Dynamic' : 'Static'),
                                    backgroundColor: lease.isDynamic ? colorScheme.surfaceContainerHighest : colorScheme.primaryContainer,
                                    textColor: lease.isDynamic ? colorScheme.onSurfaceVariant : colorScheme.onPrimaryContainer,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: lease.address));
                                  ToastBanner.show(context, message: 'Alamat IP ${lease.address} berhasil disalin.', type: ToastType.info);
                                },
                                onLongPress: () {
                                  Clipboard.setData(ClipboardData(text: lease.macAddress));
                                  ToastBanner.show(context, message: 'MAC Address ${lease.macAddress} berhasil disalin.', type: ToastType.info);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'IP: ${lease.address} • MAC: ${lease.macAddress}',
                                          style: FNetTheme.monoStyle(fontSize: 12, color: colorScheme.onSurface, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      Icon(Icons.copy_rounded, size: 14, color: colorScheme.onSurfaceVariant),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),

                              Row(
                                children: [
                                  Badge(
                                    label: Text(vendor),
                                    backgroundColor: colorScheme.secondaryContainer,
                                    textColor: colorScheme.onSecondaryContainer,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  ),
                                  if (lease.server.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text('Server: ${lease.server}', style: FNetTheme.monoStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                                  ],
                                  if (lease.expiresAfter.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text('Sisa: ${lease.expiresAfter}', style: FNetTheme.monoStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                                  ],
                                ],
                              ),
                              if (lease.comment.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text('Catatan: ${lease.comment}', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                                ),
                              const SizedBox(height: 12),
                              Divider(height: 1, color: colorScheme.outlineVariant),
                              const SizedBox(height: 8),

                              // Quick Action Buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _handleToggleStatic(lease),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: lease.isDynamic ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                          minimumSize: const Size(48, 40),
                                        ),
                                        icon: Icon(lease.isDynamic ? Icons.push_pin_outlined : Icons.remove_circle_outline, size: 18),
                                        label: Text(
                                          lease.isDynamic ? 'Jadikan Static' : 'Lepas Reservasi',
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        tooltip: 'Hapus Lease',
                                        icon: const Icon(Icons.delete_outline, size: 20),
                                        color: colorScheme.error,
                                        onPressed: () => _confirmDeleteLease(lease),
                                      ),
                                    ],
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: () {
                                      final rawName = lease.hostName.isNotEmpty ? lease.hostName.toLowerCase() : 'user';
                                      final sanitizedName = rawName.replaceAll(RegExp(r'[^a-z0-9]'), '');
                                      widget.onConvertToPppoe(
                                        name: sanitizedName.isNotEmpty ? sanitizedName : 'user-${lease.address.split('.').last}',
                                        ip: lease.address,
                                        comment: '${lease.hostName.isNotEmpty ? lease.hostName : "Client"} | MAC: ${lease.macAddress}',
                                      );
                                    },
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(48, 40),
                                    ),
                                    icon: const Icon(Icons.swap_horiz, size: 18),
                                    label: const Text('Ke PPPoE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (visibleItems.length < filtered.length)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: LoadingIndicatorM3E(
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Memuat lebih banyak (${visibleItems.length} dari ${filtered.length})...',
                                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 70),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  },
),
);
  }

  Widget _buildErrorEmptyState(ThemeData theme, ColorScheme colorScheme) {
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
              _errorMessage ?? 'Terjadi kesalahan saat memuat data DHCP dari router.',
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

  Widget _buildServerButton(String server, String label, ColorScheme colorScheme) {
    final isSelected = _serverFilter == server;
    if (isSelected) {
      return FilledButton.tonal(
        onPressed: () {
          setState(() {
            _serverFilter = server;
            _visibleLeasesCount = 25;
          });
        },
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Text(label),
      );
    } else {
      return OutlinedButton(
        onPressed: () {
          setState(() {
            _serverFilter = server;
            _visibleLeasesCount = 25;
          });
        },
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Text(label),
      );
    }
  }
}
