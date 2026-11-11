import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/mikrotik_models.dart';
import '../services/mikrotik_api_service.dart';
import '../theme/fnet_theme.dart';
import '../widgets/loading_indicator_m3e.dart';
import '../widgets/toast_banner.dart';

class DhcpScreen extends StatefulWidget {
  final RouterProfile profile;
  final String searchQuery;
  final void Function({required String name, required String ip, required String comment})? onConvertToPppoe;

  const DhcpScreen({
    super.key,
    required this.profile,
    this.searchQuery = '',
    this.onConvertToPppoe,
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
  String _sortBy = 'ip_asc';

  // Multi-select / Hold-to-select support
  final Set<String> _selectedLeaseIds = {};

  int _compareIp(String ipA, String ipB) {
    final partsA = ipA.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final partsB = ipB.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < 4; i++) {
      final a = i < partsA.length ? partsA[i] : 0;
      final b = i < partsB.length ? partsB[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    return 0;
  }

  void _sortLeases(List<DhcpLease> list) {
    switch (_sortBy) {
      case 'ip_asc':
        list.sort((a, b) => _compareIp(a.address, b.address));
        break;
      case 'ip_desc':
        list.sort((a, b) => _compareIp(b.address, a.address));
        break;
      case 'mac_asc':
        list.sort((a, b) => a.macAddress.toLowerCase().compareTo(b.macAddress.toLowerCase()));
        break;
      case 'static_first':
        list.sort((a, b) {
          if (a.isDynamic != b.isDynamic) {
            return a.isDynamic ? 1 : -1;
          }
          return _compareIp(a.address, b.address);
        });
        break;
      case 'dynamic_first':
        list.sort((a, b) {
          if (a.isDynamic != b.isDynamic) {
            return a.isDynamic ? -1 : 1;
          }
          return _compareIp(a.address, b.address);
        });
        break;
      case 'server_asc':
        list.sort((a, b) {
          final cmp = a.server.toLowerCase().compareTo(b.server.toLowerCase());
          if (cmp != 0) return cmp;
          return _compareIp(a.address, b.address);
        });
        break;
    }
  }

  String _getSortLabel(String key) {
    switch (key) {
      case 'ip_asc':
        return 'IP (Terkecil)';
      case 'ip_desc':
        return 'IP (Terbesar)';
      case 'mac_asc':
        return 'MAC (A - Z)';
      case 'static_first':
        return 'Static Duluan';
      case 'dynamic_first':
        return 'Dynamic Duluan';
      case 'server_asc':
        return 'Server (A - Z)';
      default:
        return 'Default';
    }
  }

  void showSortOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;
        final bottomInset = MediaQuery.of(ctx).padding.bottom;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset + 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.sort_rounded, color: colorScheme.primary),
                            const SizedBox(width: 12),
                            Text(
                              'Urutkan DHCP Lease',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      RadioGroup<String>(
                        groupValue: _sortBy,
                        onChanged: (val) {
                          if (val != null) {
                            Navigator.pop(ctx);
                            setState(() {
                              _sortBy = val;
                              _visibleLeasesCount = 25;
                            });
                            ToastBanner.show(
                              context,
                              message: 'Diurutkan berdasarkan ${_getSortLabel(val)}.',
                              type: ToastType.info,
                            );
                          }
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RadioListTile<String>(
                              value: 'ip_asc',
                              title: const Text('IP Address (Terkecil ke Terbesar)'),
                              subtitle: const Text('Contoh: 192.168.1.2 sebelum 192.168.1.10'),
                            ),
                            RadioListTile<String>(
                              value: 'ip_desc',
                              title: const Text('IP Address (Terbesar ke Terkecil)'),
                              subtitle: const Text('Urutkan dari alamat host paling tinggi'),
                            ),
                            RadioListTile<String>(
                              value: 'mac_asc',
                              title: const Text('MAC Address (A - Z)'),
                              subtitle: const Text('Urutkan menurut alamat fisik hardware'),
                            ),
                            RadioListTile<String>(
                              value: 'static_first',
                              title: const Text('Status: Static Duluan'),
                              subtitle: const Text('Perangkat yang telah dikunci/reservasi di atas'),
                            ),
                            RadioListTile<String>(
                              value: 'dynamic_first',
                              title: const Text('Status: Dynamic Duluan'),
                              subtitle: const Text('Perangkat dynamic lease aktif di atas'),
                            ),
                            RadioListTile<String>(
                              value: 'server_asc',
                              title: const Text('Server DHCP (A - Z)'),
                              subtitle: const Text('Dikelompokkan menurut nama interface server'),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

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

  void _toggleSelectLease(String id) {
    setState(() {
      if (_selectedLeaseIds.contains(id)) {
        _selectedLeaseIds.remove(id);
      } else {
        _selectedLeaseIds.add(id);
      }
    });
  }

  void _selectAllLeases(List<DhcpLease> items) {
    setState(() {
      if (_selectedLeaseIds.length == items.length) {
        _selectedLeaseIds.clear();
      } else {
        _selectedLeaseIds.addAll(items.map((e) => e.id));
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedLeaseIds.clear();
    });
  }

  void _confirmDeleteSelectedLeases() {
    if (_selectedLeaseIds.isEmpty) return;

    final selectedCount = _selectedLeaseIds.length;
    final singleLease = selectedCount == 1
        ? _leases.firstWhere((l) => l.id == _selectedLeaseIds.first, orElse: () => _leases.first)
        : null;

    final title = selectedCount == 1 ? 'Hapus DHCP Lease?' : 'Hapus $selectedCount Lease?';
    final content = selectedCount == 1
        ? 'Hapus lease untuk IP ${singleLease?.address} (${singleLease?.macAddress})?'
        : 'Hapus $selectedCount DHCP lease terpilih dari router?';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              final idsToDelete = List<String>.from(_selectedLeaseIds);
              _clearSelection();

              int successCount = 0;
              for (final id in idsToDelete) {
                try {
                  await MikrotikApiService.instance.deleteDhcpLease(widget.profile, id);
                  successCount++;
                } catch (_) {}
              }

              if (mounted) {
                if (successCount == idsToDelete.length) {
                  ToastBanner.show(
                    context,
                    message: selectedCount == 1
                        ? 'Lease berhasil dihapus.'
                        : '$successCount lease berhasil dihapus.',
                    type: ToastType.success,
                  );
                } else {
                  ToastBanner.show(
                    context,
                    message: '$successCount dari ${idsToDelete.length} lease berhasil dihapus.',
                    type: ToastType.info,
                  );
                }
              }
              refreshData();
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

    _sortLeases(filtered);

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
                // Official Material 3 Secondary TabBar or Pinned Top Selection Bar
                if (_selectedLeaseIds.isNotEmpty)
                  Container(
                    color: colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Batal Pilih',
                          onPressed: _clearSelection,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_selectedLeaseIds.length} dipilih',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _selectAllLeases(filtered),
                          icon: Icon(
                            _selectedLeaseIds.length == filtered.length ? Icons.deselect_rounded : Icons.select_all_rounded,
                            size: 18,
                          ),
                          label: Text(_selectedLeaseIds.length == filtered.length ? 'Batal Semua' : 'Pilih Semua'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.error,
                            foregroundColor: colorScheme.onError,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: Text('Hapus (${_selectedLeaseIds.length})'),
                          onPressed: _confirmDeleteSelectedLeases,
                        ),
                      ],
                    ),
                  )
                else
                  TabBar(
                    onTap: (index) {
                      _clearSelection();
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
                        // Server Filter row
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 40, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Tidak ada DHCP lease yang cocok dengan "$_searchQuery".'
                                  : 'Tidak ada data DHCP lease yang ditemukan.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    ...visibleItems.map((lease) {
                      final isSelected = _selectedLeaseIds.contains(lease.id);
                      final isSelectionMode = _selectedLeaseIds.isNotEmpty;

                      final cardBg = isSelected
                          ? colorScheme.primaryContainer.withValues(alpha: 0.35)
                          : colorScheme.surface;
                      final borderColor = isSelected ? colorScheme.primary : colorScheme.outlineVariant;
                      final titleColor = colorScheme.onSurface;
                      final subtitleColor = colorScheme.onSurfaceVariant;

                      final isBound = lease.status == 'bound';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Card(
                          elevation: 0,
                          color: cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                            side: BorderSide(color: borderColor, width: isSelected ? 2 : 1),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16.0),
                            onTap: () {
                              if (isSelectionMode) {
                                _toggleSelectLease(lease.id);
                              }
                            },
                            onLongPress: () => _toggleSelectLease(lease.id),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                              leading: isSelectionMode
                                  ? Icon(
                                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                      color: isSelected ? colorScheme.primary : subtitleColor,
                                      size: 20,
                                    )
                                  : Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isBound ? FNetTheme.emerald : colorScheme.outline,
                                      ),
                                    ),
                              minLeadingWidth: 0,
                              title: Row(
                                children: [
                                  Flexible(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(4),
                                      onTap: isSelectionMode
                                          ? () => _toggleSelectLease(lease.id)
                                          : () {
                                              Clipboard.setData(ClipboardData(text: lease.address));
                                              ToastBanner.show(
                                                context,
                                                message: 'Alamat IP ${lease.address} berhasil disalin.',
                                                type: ToastType.info,
                                              );
                                            },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                                        child: Text(
                                          lease.address,
                                          style: TextStyle(
                                            color: titleColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (lease.server.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        lease.server,
                                        style: FNetTheme.monoStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(4),
                                  onTap: isSelectionMode
                                      ? () => _toggleSelectLease(lease.id)
                                      : () {
                                          Clipboard.setData(ClipboardData(text: lease.macAddress));
                                          ToastBanner.show(
                                            context,
                                            message: 'MAC Address ${lease.macAddress} berhasil disalin.',
                                            type: ToastType.info,
                                          );
                                        },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                                    child: Text(
                                      'MAC: ${lease.macAddress}',
                                      style: FNetTheme.monoStyle(
                                        fontSize: 12,
                                        color: subtitleColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  lease.isDynamic ? Icons.lock_open_rounded : Icons.lock_rounded,
                                  color: lease.isDynamic ? colorScheme.onSurfaceVariant : colorScheme.primary,
                                  size: 22,
                                ),
                                tooltip: lease.isDynamic ? 'Jadikan Static' : 'Lepas Reservasi',
                                onPressed: isSelectionMode ? null : () => _handleToggleStatic(lease),
                              ),
                            ),
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
