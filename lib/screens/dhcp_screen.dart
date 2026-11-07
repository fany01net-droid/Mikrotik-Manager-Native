import 'package:flutter/material.dart';
import '../models/mikrotik_models.dart';
import '../services/mikrotik_api_service.dart';
import '../theme/fnet_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/toast_banner.dart';

class DhcpScreen extends StatefulWidget {
  final RouterProfile profile;
  final void Function({required String name, required String ip, required String comment}) onConvertToPppoe;

  const DhcpScreen({
    super.key,
    required this.profile,
    required this.onConvertToPppoe,
  });

  @override
  State<DhcpScreen> createState() => DhcpScreenState();
}

class DhcpScreenState extends State<DhcpScreen> {
  bool _isLoading = true;
  List<DhcpLease> _leases = [];
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    refreshData();
  }

  Future<void> refreshData() async {
    setState(() => _isLoading = true);
    try {
      final leases = await MikrotikApiService.instance.getDhcpLeases(widget.profile);
      if (mounted) {
        setState(() {
          _leases = leases;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
      if (_statusFilter == 'bound') {
        return l.status == 'bound';
      } else if (_statusFilter == 'dynamic') {
        return l.isDynamic;
      } else if (_statusFilter == 'static') {
        return !l.isDynamic;
      } else if (_statusFilter == 'waiting') {
        return l.status == 'waiting';
      }
      return true;
    }).toList();

    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : RefreshIndicator(
              onRefresh: refreshData,
              color: colorScheme.primary,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  // Official M3 SearchBar
                  SearchBar(
                    hintText: 'Cari IP, MAC, hostname ONT...',
                    leading: const Icon(Icons.search),
                    elevation: const WidgetStatePropertyAll(0),
                    backgroundColor: WidgetStatePropertyAll(colorScheme.surfaceContainerLowest),
                    side: WidgetStatePropertyAll(BorderSide(color: colorScheme.outlineVariant)),
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  const SizedBox(height: 12),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('all', 'Semua (${_leases.length})'),
                        _buildFilterChip('bound', 'Bound (Terhubung)'),
                        _buildFilterChip('static', 'Static'),
                        _buildFilterChip('dynamic', 'Dynamic'),
                        _buildFilterChip('waiting', 'Menunggu'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (filtered.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(36),
                        child: Text('Tidak ada DHCP lease yang cocok.', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
                      ),
                    )
                  else
                    ...filtered.map((lease) {
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
                                        backgroundColor: isBound ? FNetTheme.emerald : Colors.grey,
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

                              Text(
                                'IP: ${lease.address} • MAC: ${lease.macAddress}',
                                style: FNetTheme.monoStyle(fontSize: 12, color: colorScheme.onSurface, fontWeight: FontWeight.w700),
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
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _statusFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (_) => setState(() => _statusFilter = key),
      ),
    );
  }
}
