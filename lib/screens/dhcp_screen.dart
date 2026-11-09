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

  // Multi-select / Hold-to-select support
  final Set<String> _selectedLeaseIds = {};

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
        ? 'Apakah Anda yakin ingin menghapus lease untuk IP ${singleLease?.address} (${singleLease?.macAddress})?'
        : 'Apakah Anda yakin ingin menghapus $selectedCount DHCP lease terpilih dari router?';

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
                      final isDark = theme.brightness == Brightness.dark;
                      final cardBg = isDark ? const Color(0xFF0F151B) : colorScheme.surface;
                      final borderColor = isDark ? const Color(0xFF1E2833) : colorScheme.outlineVariant;
                      final titleColor = isDark ? Colors.white : colorScheme.onSurface;
                      final subtitleColor = isDark ? const Color(0xFF9EA7B2) : colorScheme.onSurfaceVariant;
                      final dividerColor = isDark ? const Color(0xFF1E2833) : colorScheme.outlineVariant;

                      final isBound = lease.status == 'bound';
                      final vendor = FormatUtils.detectDeviceVendor(lease.macAddress, lease.hostName);
                      final displayName = lease.hostName.isNotEmpty ? lease.hostName : lease.address;
                      final isSelected = _selectedLeaseIds.contains(lease.id);
                      final isSelectionMode = _selectedLeaseIds.isNotEmpty;

                      final badgeBg = lease.isDynamic
                          ? (isDark ? const Color(0xFF262D38) : colorScheme.surfaceContainerHighest)
                          : (isDark ? const Color(0xFF1E2E38) : colorScheme.primaryContainer);
                      final badgeFg = lease.isDynamic
                          ? (isDark ? const Color(0xFFCFD6E2) : colorScheme.onSurfaceVariant)
                          : (isDark ? const Color(0xFF86B9EC) : colorScheme.onPrimaryContainer);

                      final effectiveCardBg = isSelected
                          ? (isDark ? const Color(0xFF132838) : colorScheme.primaryContainer.withValues(alpha: 0.25))
                          : cardBg;
                      final effectiveBorderColor = isSelected ? colorScheme.primary : borderColor;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Card(
                          elevation: 0,
                          color: effectiveCardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24.0),
                            side: BorderSide(color: effectiveBorderColor, width: isSelected ? 2 : 1),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24.0),
                            onTap: () {
                              if (isSelectionMode) {
                                _toggleSelectLease(lease.id);
                              }
                            },
                            onLongPress: () => _toggleSelectLease(lease.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header: Status dot, Title, Dynamic/Static badge
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                                              color: isBound ? const Color(0xFF86B9EC) : Colors.grey,
                                            ),
                                          ),
                                    minLeadingWidth: 0,
                                    title: Text(
                                      displayName,
                                      style: TextStyle(
                                        color: titleColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      lease.isDynamic ? 'Dynamic' : 'Static',
                                      style: TextStyle(
                                        color: badgeFg,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (lease.comment.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 2.0),
                                            child: Text(
                                              'Catatan: ${lease.comment}',
                                              style: TextStyle(color: subtitleColor, fontSize: 13),
                                            ),
                                          ),
                                        InkWell(
                                          borderRadius: BorderRadius.circular(6),
                                          onTap: () {
                                            Clipboard.setData(ClipboardData(text: lease.address));
                                            ToastBanner.show(context, message: 'Alamat IP ${lease.address} berhasil disalin.', type: ToastType.info);
                                          },
                                          onLongPress: () {
                                            Clipboard.setData(ClipboardData(text: lease.macAddress));
                                            ToastBanner.show(context, message: 'MAC Address ${lease.macAddress} berhasil disalin.', type: ToastType.info);
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    'IP: ${lease.address} • MAC: ${lease.macAddress}',
                                                    style: FNetTheme.monoStyle(
                                                      fontSize: 12,
                                                      color: subtitleColor,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(Icons.copy_rounded, size: 13, color: subtitleColor),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF1E252D) : colorScheme.secondaryContainer,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                vendor,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? const Color(0xFF9EA7B2) : colorScheme.onSecondaryContainer,
                                                ),
                                              ),
                                            ),
                                            if (lease.server.isNotEmpty)
                                              Text(
                                                'Server: ${lease.server}',
                                                style: FNetTheme.monoStyle(fontSize: 11, color: subtitleColor),
                                              ),
                                            if (lease.expiresAfter.isNotEmpty)
                                              Text(
                                                '• Sisa: ${lease.expiresAfter}',
                                                style: FNetTheme.monoStyle(fontSize: 11, color: subtitleColor),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 4),
                                Divider(color: dividerColor, height: 1, thickness: 1),
                                const SizedBox(height: 10),

                                // Action Buttons (NO "Ke PPPoE")
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                  child: Row(
                                    children: [
                                      if (lease.isDynamic)
                                        FilledButton.icon(
                                          onPressed: () => _handleToggleStatic(lease),
                                          icon: const Icon(Icons.push_pin_outlined, size: 18),
                                          label: const Text('Jadikan Static', style: TextStyle(fontWeight: FontWeight.bold)),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(0xFF0F4D77),
                                            foregroundColor: const Color(0xFFD3E7FF),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          ),
                                        )
                                      else
                                        OutlinedButton.icon(
                                          onPressed: () => _handleToggleStatic(lease),
                                          icon: const Icon(Icons.push_pin, size: 18),
                                          label: const Text('Lepas Reservasi', style: TextStyle(fontWeight: FontWeight.bold)),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: isDark ? const Color(0xFF86B9EC) : colorScheme.primary,
                                            side: BorderSide(
                                              color: isDark ? const Color(0xFF0F4D77) : colorScheme.outline,
                                              width: 1.2,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          ),
                                        ),

                                      const Spacer(),

                                      IconButton(
                                        tooltip: 'Salin IP',
                                        icon: const Icon(Icons.copy_outlined, size: 20),
                                        color: subtitleColor,
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: lease.address));
                                          ToastBanner.show(context, message: 'Alamat IP ${lease.address} berhasil disalin.', type: ToastType.info);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
