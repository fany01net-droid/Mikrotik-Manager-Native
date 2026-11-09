import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/mikrotik_models.dart';
import '../services/mikrotik_api_service.dart';
import '../theme/fnet_theme.dart';
import '../utils/format_utils.dart';
import '../utils/hotspot_utils.dart';
import '../widgets/loading_indicator_m3e.dart';
import '../widgets/toast_banner.dart';
import '../widgets/user_card_m3.dart';

class HotspotScreen extends StatefulWidget {
  final RouterProfile profile;
  final String searchQuery;

  const HotspotScreen({
    super.key,
    required this.profile,
    this.searchQuery = '',
  });

  @override
  State<HotspotScreen> createState() => HotspotScreenState();
}

class HotspotScreenState extends State<HotspotScreen> {
  int _selectedSubTab = 0; // 0: Users/Vouchers, 1: Active, 2: Profiles
  bool _isLoading = true;
  String? _errorMessage;

  List<HotspotUser> _users = [];
  List<HotspotActive> _activeSessions = [];
  List<HotspotProfile> _profiles = [];
  List<IpPool> _ipPools = [];

  bool _isSystemProfile(String name) {
    final lower = name.toLowerCase().trim();
    return lower == 'default';
  }

  List<HotspotProfile> get _filteredProfiles =>
      _profiles.where((p) => !_isSystemProfile(p.name)).toList();

  String _searchQuery = '';
  String _userFilter = 'all';

  // Multi-select / Hold-to-select support
  final Set<String> _selectedVoucherIds = {};

  // Lazy Load Chunking (25 data per chunk) & Scroll Controllers
  int _visibleVouchersCount = 25;
  int _visibleActiveCount = 25;
  int _visibleProfilesCount = 25;

  String _activeSearchQuery = '';
  String _profileSearchQuery = '';

  final ScrollController _voucherScrollController = ScrollController();
  final ScrollController _activeScrollController = ScrollController();
  final ScrollController _profileScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.searchQuery;
    _activeSearchQuery = widget.searchQuery;
    _profileSearchQuery = widget.searchQuery;
    _voucherScrollController.addListener(_onVoucherScroll);
    _activeScrollController.addListener(_onActiveScroll);
    _profileScrollController.addListener(_onProfileScroll);
    refreshData();
  }

  @override
  void didUpdateWidget(covariant HotspotScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _searchQuery = widget.searchQuery;
      _activeSearchQuery = widget.searchQuery;
      _profileSearchQuery = widget.searchQuery;
      _visibleVouchersCount = 25;
      _visibleActiveCount = 25;
      _visibleProfilesCount = 25;
    }
    if (oldWidget.profile.id != widget.profile.id ||
        oldWidget.profile.host != widget.profile.host ||
        oldWidget.profile.port != widget.profile.port) {
      _errorMessage = null;
      _visibleVouchersCount = 25;
      _visibleActiveCount = 25;
      _visibleProfilesCount = 25;
      _users = [];
      _activeSessions = [];
      _profiles = [];
      _ipPools = [];
      refreshData();
    }
  }

  void setSearchQuery(String query) {
    setState(() {
      _searchQuery = query;
      _activeSearchQuery = query;
      _profileSearchQuery = query;
      _visibleVouchersCount = 25;
      _visibleActiveCount = 25;
      _visibleProfilesCount = 25;
    });
  }

  @override
  void dispose() {
    _voucherScrollController.removeListener(_onVoucherScroll);
    _activeScrollController.removeListener(_onActiveScroll);
    _profileScrollController.removeListener(_onProfileScroll);
    _voucherScrollController.dispose();
    _activeScrollController.dispose();
    _profileScrollController.dispose();
    super.dispose();
  }

  void _onVoucherScroll() {
    if (_voucherScrollController.hasClients &&
        _voucherScrollController.position.pixels >= _voucherScrollController.position.maxScrollExtent - 250) {
      if (_visibleVouchersCount < _users.length) {
        setState(() {
          _visibleVouchersCount = (_visibleVouchersCount + 25).clamp(0, _users.length);
        });
      }
    }
  }

  void _onActiveScroll() {
    if (_activeScrollController.hasClients &&
        _activeScrollController.position.pixels >= _activeScrollController.position.maxScrollExtent - 250) {
      if (_visibleActiveCount < _activeSessions.length) {
        setState(() {
          _visibleActiveCount = (_visibleActiveCount + 25).clamp(0, _activeSessions.length);
        });
      }
    }
  }

  void _onProfileScroll() {
    if (_profileScrollController.hasClients &&
        _profileScrollController.position.pixels >= _profileScrollController.position.maxScrollExtent - 250) {
      if (_visibleProfilesCount < _profiles.length) {
        setState(() {
          _visibleProfilesCount = (_visibleProfilesCount + 25).clamp(0, _profiles.length);
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
      final uFuture = MikrotikApiService.instance.getHotspotUsers(widget.profile);
      final aFuture = MikrotikApiService.instance.getHotspotActive(widget.profile);
      final pFuture = MikrotikApiService.instance.getHotspotProfiles(widget.profile);
      final poolFuture = MikrotikApiService.instance.getIpPools(widget.profile);

      final results = await Future.wait([uFuture, aFuture, pFuture, poolFuture]);

      if (mounted) {
        setState(() {
          _users = results[0] as List<HotspotUser>;
          _activeSessions = results[1] as List<HotspotActive>;
          _profiles = results[2] as List<HotspotProfile>;
          _ipPools = results[3] as List<IpPool>;
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

  Future<void> _handleResetMac(HotspotUser user) async {
    try {
      await MikrotikApiService.instance.updateHotspotUser(widget.profile, user.id, {
        'mac-address': '00:00:00:00:00:00',
      });
      final active = _activeSessions.where((a) => a.user == user.name).toList();
      for (final act in active) {
        try {
          await MikrotikApiService.instance.disconnectHotspotActive(widget.profile, act.id);
        } catch (_) {}
      }
      if (mounted) {
        ToastBanner.show(
          context,
          message: 'Kuncian MAC voucher ${user.name} berhasil di-reset.',
          type: ToastType.success,
        );
      }
      refreshData();
    } catch (e) {
      if (mounted) {
        ToastBanner.show(
          context,
          message: 'Gagal mereset MAC: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _handleDisconnectActive(HotspotActive active) async {
    try {
      await MikrotikApiService.instance.disconnectHotspotActive(widget.profile, active.id);
      if (mounted) {
        ToastBanner.show(
          context,
          message: 'Sesi voucher ${active.user} berhasil diputuskan.',
          type: ToastType.success,
        );
      }
      refreshData();
    } catch (e) {
      if (mounted) {
        ToastBanner.show(
          context,
          message: 'Gagal memutuskan sesi: $e',
          type: ToastType.error,
        );
      }
    }
  }

  void _toggleSelectVoucher(String id) {
    setState(() {
      if (_selectedVoucherIds.contains(id)) {
        _selectedVoucherIds.remove(id);
      } else {
        _selectedVoucherIds.add(id);
      }
    });
  }

  void _selectAllVouchers(List<HotspotUser> items) {
    setState(() {
      if (_selectedVoucherIds.length == items.length) {
        _selectedVoucherIds.clear();
      } else {
        _selectedVoucherIds.addAll(items.map((e) => e.id));
      }
    });
  }

  void _clearVoucherSelection() {
    setState(() {
      _selectedVoucherIds.clear();
    });
  }

  void _confirmDeleteSelectedVouchers() {
    if (_selectedVoucherIds.isEmpty) return;
    final selectedCount = _selectedVoucherIds.length;
    final singleUser = selectedCount == 1
        ? _users.firstWhere((u) => u.id == _selectedVoucherIds.first, orElse: () => _users.first)
        : null;

    final title = selectedCount == 1 ? 'Hapus Voucher Hotspot?' : 'Hapus $selectedCount Voucher?';
    final content = selectedCount == 1
        ? 'Apakah Anda yakin ingin menghapus voucher "${singleUser?.name}" dari router?'
        : 'Apakah Anda yakin ingin menghapus $selectedCount voucher hotspot terpilih dari router?';

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
              final idsToDelete = List<String>.from(_selectedVoucherIds);
              _clearVoucherSelection();

              int successCount = 0;
              for (final id in idsToDelete) {
                try {
                  await MikrotikApiService.instance.deleteHotspotUser(widget.profile, id);
                  successCount++;
                } catch (_) {}
              }

              if (mounted) {
                if (successCount == idsToDelete.length) {
                  ToastBanner.show(
                    context,
                    message: selectedCount == 1
                        ? 'Voucher berhasil dihapus.'
                        : '$successCount voucher berhasil dihapus.',
                    type: ToastType.success,
                  );
                } else {
                  ToastBanner.show(
                    context,
                    message: '$successCount dari ${idsToDelete.length} voucher berhasil dihapus.',
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

  // --- M3 Thermal Slip Receipt Modal ---
  void _showPrintVoucherReceipt(HotspotUser user) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;

        return AlertDialog(
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                child: const Icon(Icons.wifi, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                'FNet Hotspot Voucher',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                'Internet Cepat & Handal',
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Divider(thickness: 1, color: colorScheme.outlineVariant),
              const SizedBox(height: 14),

              // Code Box
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  child: Column(
                    children: [
                      Text('KODE LOGIN VOUCHER', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      SelectableText(
                        user.name,
                        style: FNetTheme.monoStyle(fontSize: 24, fontWeight: FontWeight.w900, color: colorScheme.primary),
                      ),
                      if (user.password.isNotEmpty && user.password != user.name) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Password: ${user.password}',
                          style: FNetTheme.monoStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Paket / Profil:', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                  Text(user.profile, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ),
              if (user.limitUptime.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Masa Aktif:', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                    Text(user.limitUptime, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: user.name));
                        ToastBanner.show(ctx, message: 'Kode voucher berhasil disalin!', type: ToastType.success);
                      },
                      icon: const Icon(Icons.copy_outlined, size: 16),
                      label: const Text('Salin'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Tutup'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- M3 Add / Edit Single Voucher Modal ---
  void _showSingleVoucherModal({HotspotUser? editingUser}) {
    final isEditing = editingUser != null;
    final nameCtrl = TextEditingController(text: editingUser?.name ?? '');
    final passCtrl = TextEditingController(text: editingUser?.password ?? '');
    final limitCtrl = TextEditingController(text: editingUser?.limitUptime ?? '3h');
    final commentCtrl = TextEditingController(text: editingUser?.comment ?? '');
    final availableProfiles = _filteredProfiles.toList();
    if (editingUser != null &&
        _isSystemProfile(editingUser.profile) &&
        !availableProfiles.any((p) => p.name == editingUser.profile)) {
      final existing = _profiles.firstWhere(
        (p) => p.name == editingUser.profile,
        orElse: () => HotspotProfile(id: '', name: editingUser.profile),
      );
      availableProfiles.insert(0, existing);
    }

    String selectedProfile = editingUser?.profile ??
        (availableProfiles.isNotEmpty ? availableProfiles.first.name : (_profiles.isNotEmpty ? _profiles.first.name : 'default'));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final theme = Theme.of(ctx);
          final colorScheme = theme.colorScheme;

          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 8,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? 'Edit Voucher Hotspot' : 'Buat Voucher Manual',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: nameCtrl,
                    enabled: !isEditing,
                    decoration: const InputDecoration(
                      labelText: 'Kode / Username Voucher',
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: passCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Password (Biarkan kosong jika sama)',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    initialValue: availableProfiles.any((p) => p.name == selectedProfile) ? selectedProfile : null,
                    decoration: const InputDecoration(
                      labelText: 'Paket Hotspot',
                      prefixIcon: Icon(Icons.speed),
                    ),
                    items: availableProfiles.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name))).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedProfile = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: limitCtrl,
                    style: FNetTheme.monoStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Limit Waktu (Contoh: 3h, 1d)',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: commentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Penjualan / Nama Pembeli',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),

                  FilledButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final pass = passCtrl.text.trim().isNotEmpty ? passCtrl.text.trim() : name;
                      if (name.isEmpty) {
                        ToastBanner.show(ctx, message: 'Username tidak boleh kosong.', type: ToastType.error);
                        return;
                      }

                      final payload = <String, dynamic>{
                        'name': name,
                        'password': pass,
                        'profile': selectedProfile,
                        if (limitCtrl.text.trim().isNotEmpty) 'limit-uptime': limitCtrl.text.trim(),
                        if (commentCtrl.text.trim().isNotEmpty) 'comment': commentCtrl.text.trim(),
                      };

                      Navigator.pop(ctx);
                      try {
                        if (isEditing) {
                          await MikrotikApiService.instance.updateHotspotUser(widget.profile, editingUser.id, payload);
                          if (mounted) {
                            ToastBanner.show(context, message: 'Voucher $name diperbarui.', type: ToastType.success);
                          }
                        } else {
                          await MikrotikApiService.instance.createHotspotUser(widget.profile, payload);
                          if (mounted) {
                            ToastBanner.show(context, message: 'Voucher $name berhasil dibuat.', type: ToastType.success);
                          }
                        }
                        refreshData();
                      } catch (e) {
                        if (mounted) {
                          ToastBanner.show(context, message: 'Gagal menyimpan voucher: $e', type: ToastType.error);
                        }
                      }
                    },
                    child: Text(isEditing ? 'Simpan Perubahan' : 'Buat Voucher'),
                  ),

                  if (isEditing) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Hapus Voucher Hotspot'),
                      onPressed: () {
                        showDialog(
                          context: ctx,
                          builder: (dialogCtx) => AlertDialog(
                            icon: Icon(Icons.delete_outline, color: colorScheme.error),
                            title: const Text('Hapus Voucher'),
                            content: Text('Apakah Anda yakin ingin menghapus voucher "${editingUser.name}"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogCtx),
                                child: const Text('Batal'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
                                onPressed: () async {
                                  Navigator.pop(dialogCtx);
                                  Navigator.pop(ctx);
                                  try {
                                    await MikrotikApiService.instance.deleteHotspotUser(widget.profile, editingUser.id);
                                    if (mounted) {
                                      ToastBanner.show(context, message: 'Voucher ${editingUser.name} telah dihapus.', type: ToastType.success);
                                    }
                                    refreshData();
                                  } catch (e) {
                                    if (mounted) {
                                      ToastBanner.show(context, message: 'Gagal menghapus voucher: $e', type: ToastType.error);
                                    }
                                  }
                                },
                                child: const Text('Hapus'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showHotspotProfileModal({HotspotProfile? editingProfile}) {
    final isEditing = editingProfile != null;
    final nameCtrl = TextEditingController(text: editingProfile?.name ?? '');
    final sharedCtrl = TextEditingController(text: editingProfile?.sharedUsers ?? (isEditing ? '1' : '1'));
    final rateCtrl = TextEditingController(text: editingProfile?.rateLimit ?? (isEditing ? '' : '5M/5M'));

    final initialPool = editingProfile?.addressPool ?? '';
    final poolNames = _ipPools.map((p) => p.name).toSet();
    final bool isCustomInitial = initialPool.isNotEmpty && initialPool != 'none' && !poolNames.contains(initialPool);

    String selectedPool = isCustomInitial ? '__custom__' : (initialPool == 'none' ? '' : initialPool);
    final customPoolCtrl = TextEditingController(text: isCustomInitial ? initialPool : '');

    void Function(void Function())? modalSetter;
    if (_ipPools.isEmpty) {
      MikrotikApiService.instance.getIpPools(widget.profile).then((pools) {
        if (mounted && pools.isNotEmpty) {
          setState(() => _ipPools = pools);
          modalSetter?.call(() {
            if (initialPool.isNotEmpty && pools.any((p) => p.name == initialPool)) {
              selectedPool = initialPool;
            }
          });
        }
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          modalSetter = setModalState;
          final theme = Theme.of(ctx);
          final colorScheme = theme.colorScheme;

          final List<DropdownMenuItem<String>> poolDropdownItems = [
            DropdownMenuItem<String>(
              value: '',
              child: Text(
                '-- Tidak Ada / none --',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
            ..._ipPools.map((pool) {
              return DropdownMenuItem<String>(
                value: pool.name,
                child: Text(
                  pool.ranges.isNotEmpty ? '${pool.name} (${pool.ranges})' : pool.name,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
            const DropdownMenuItem<String>(
              value: '__custom__',
              child: Row(
                children: [
                  Icon(Icons.edit_note, size: 18),
                  SizedBox(width: 8),
                  Text('Input Manual / Kustom...'),
                ],
              ),
            ),
          ];

          final validValues = poolDropdownItems.map((item) => item.value).toSet();
          if (!validValues.contains(selectedPool)) {
            selectedPool = selectedPool.isNotEmpty ? '__custom__' : '';
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 8,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEditing ? 'Edit Paket Hotspot' : 'Tambah Paket Hotspot',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Profil Hotspot',
                      hintText: 'Contoh: 1Jam-3K',
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: sharedCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Shared Users (Perangkat Simultan)',
                      hintText: '1',
                      prefixIcon: Icon(Icons.devices),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: rateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Rate Limit (Tx/Rx)',
                      hintText: 'Contoh: 5M/5M',
                      prefixIcon: Icon(Icons.speed),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: ValueKey('hpool_$selectedPool'),
                    initialValue: selectedPool,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Address Pool (Opsional)',
                      prefixIcon: Icon(Icons.lan_outlined),
                      helperText: 'Pilih IP Pool MikroTik untuk paket ini',
                    ),
                    items: poolDropdownItems,
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedPool = val;
                        });
                      }
                    },
                  ),
                  if (selectedPool == '__custom__') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: customPoolCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama IP Pool Kustom',
                        hintText: 'Contoh: hs-pool-khusus',
                        prefixIcon: Icon(Icons.edit_note),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ToastBanner.show(ctx, message: 'Nama paket hotspot wajib diisi.', type: ToastType.error);
                        return;
                      }

                      final finalPool = selectedPool == '__custom__'
                          ? customPoolCtrl.text.trim()
                          : selectedPool.trim();

                      Navigator.pop(ctx);
                      try {
                        final data = <String, dynamic>{
                          'name': name,
                          'shared-users': sharedCtrl.text.trim().isNotEmpty ? sharedCtrl.text.trim() : '1',
                          if (rateCtrl.text.trim().isNotEmpty) 'rate-limit': rateCtrl.text.trim(),
                          if (finalPool.isNotEmpty)
                            'address-pool': finalPool
                          else if (isEditing)
                            'address-pool': 'none',
                        };

                        if (isEditing) {
                          await MikrotikApiService.instance.updateHotspotProfile(widget.profile, editingProfile.id, data);
                          if (mounted) {
                            ToastBanner.show(context, message: 'Paket Hotspot $name berhasil diperbarui.', type: ToastType.success);
                          }
                        } else {
                          await MikrotikApiService.instance.createHotspotProfile(widget.profile, data);
                          if (mounted) {
                            ToastBanner.show(context, message: 'Paket Hotspot $name berhasil dibuat.', type: ToastType.success);
                          }
                        }
                        refreshData();
                      } catch (e) {
                        if (mounted) {
                          ToastBanner.show(context, message: 'Gagal menyimpan paket: $e', type: ToastType.error);
                        }
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: Text(isEditing ? 'Simpan Perubahan' : 'Simpan Paket'),
                  ),
                  if (isEditing) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Hapus Paket Hotspot'),
                      onPressed: () {
                        showDialog(
                          context: ctx,
                          builder: (dialogCtx) => AlertDialog(
                            icon: Icon(Icons.delete_outline, color: colorScheme.error),
                            title: const Text('Hapus Paket'),
                            content: Text('Apakah Anda yakin ingin menghapus paket "${editingProfile.name}"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogCtx),
                                child: const Text('Batal'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
                                onPressed: () async {
                                  Navigator.pop(dialogCtx);
                                  Navigator.pop(ctx);
                                  try {
                                    await MikrotikApiService.instance.deleteHotspotProfile(widget.profile, editingProfile.id);
                                    if (mounted) {
                                      ToastBanner.show(context, message: 'Paket ${editingProfile.name} berhasil dihapus.', type: ToastType.success);
                                    }
                                    refreshData();
                                  } catch (e) {
                                    if (mounted) {
                                      ToastBanner.show(context, message: 'Gagal menghapus paket: $e', type: ToastType.error);
                                    }
                                  }
                                },
                                child: const Text('Hapus'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<HotspotUser> _getFilteredVouchers() {
    return _users.where((u) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!u.name.toLowerCase().contains(q) && !u.comment.toLowerCase().contains(q)) {
          return false;
        }
      }
      final exp = HotspotUtils.calculateHotspotUserExpiry(u, _profiles);
      if (_userFilter == 'active') {
        return exp.status == HotspotStatus.active || exp.status == HotspotStatus.expiringSoon;
      } else if (_userFilter == 'waiting' || _userFilter == 'unused') {
        return exp.status == HotspotStatus.unused;
      }
      return true;
    }).toList();
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
                'Memuat data Hotspot...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isVoucherSelectionMode = _selectedVoucherIds.isNotEmpty && _selectedSubTab == 0;
    final filteredVouchers = _getFilteredVouchers();

    return DefaultTabController(
      length: 3,
      initialIndex: _selectedSubTab,
      child: Builder(
        builder: (ctx) {
          return Scaffold(
            body: Column(
              children: [
                // Official Material 3 Secondary TabBar or Pinned Top Selection Bar
                if (isVoucherSelectionMode)
                  Container(
                    color: colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Batal Pilih',
                          onPressed: _clearVoucherSelection,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_selectedVoucherIds.length} dipilih',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _selectAllVouchers(filteredVouchers),
                          icon: Icon(
                            _selectedVoucherIds.length == filteredVouchers.length
                                ? Icons.deselect_rounded
                                : Icons.select_all_rounded,
                            size: 18,
                          ),
                          label: Text(_selectedVoucherIds.length == filteredVouchers.length
                              ? 'Batal Semua'
                              : 'Pilih Semua'),
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
                          label: Text('Hapus (${_selectedVoucherIds.length})'),
                          onPressed: _confirmDeleteSelectedVouchers,
                        ),
                      ],
                    ),
                  )
                else
                  TabBar(
                    onTap: (index) {
                      _clearVoucherSelection();
                      setState(() => _selectedSubTab = index);
                    },
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: colorScheme.primary,
                    unselectedLabelColor: colorScheme.onSurfaceVariant,
                    tabs: [
                      Tab(text: 'Voucher (${_users.length})'),
                      Tab(text: 'Aktif (${_activeSessions.length})'),
                      Tab(text: 'Paket (${_filteredProfiles.length})'),
                    ],
                  ),

                // Content body
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: refreshData,
                    color: colorScheme.primary,
                    child: _buildSubTabContent(),
                  ),
                ),
              ],
            ),
            floatingActionButton: isVoucherSelectionMode
                ? null
                : (_selectedSubTab == 0
                    ? FloatingActionButton(
                        heroTag: 'singleUser',
                        onPressed: () => _showSingleVoucherModal(),
                        tooltip: 'Tambah Voucher',
                        child: const Icon(Icons.add),
                      )
                    : _selectedSubTab == 2
                        ? FloatingActionButton(
                            heroTag: 'addHotspotProfile',
                            onPressed: () => _showHotspotProfileModal(),
                            tooltip: 'Tambah Paket',
                            child: const Icon(Icons.add),
                          )
                        : null),
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
              _errorMessage ?? 'Terjadi kesalahan saat memuat data Hotspot dari router.',
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

  Widget _buildSubTabContent() {
    switch (_selectedSubTab) {
      case 0:
        return _buildVouchersTab();
      case 1:
        return _buildActiveSessionsTab();
      case 2:
        return _buildProfilesTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- TAB 0: Hotspot Vouchers ---
  Widget _buildVouchersTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final totalCount = _users.length;
    final activeCount = _users.where((u) {
      final exp = HotspotUtils.calculateHotspotUserExpiry(u, _profiles);
      return exp.status == HotspotStatus.active || exp.status == HotspotStatus.expiringSoon;
    }).length;
    final waitingCount = _users.where((u) {
      final exp = HotspotUtils.calculateHotspotUserExpiry(u, _profiles);
      return exp.status == HotspotStatus.unused;
    }).length;

    final filtered = _getFilteredVouchers();
    final visibleItems = filtered.take(_visibleVouchersCount).toList();

    return ListView(
      controller: _voucherScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // M3 Status Filter Buttons on Top (Semua, Aktif, Menunggu)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterButton('all', 'Semua', totalCount, Icons.list_alt, colorScheme),
              const SizedBox(width: 8),
              _buildFilterButton('active', 'Aktif', activeCount, Icons.check_circle_outline, colorScheme),
              const SizedBox(width: 8),
              _buildFilterButton('waiting', 'Menunggu', waitingCount, Icons.hourglass_empty_outlined, colorScheme),
            ],
          ),
        ),
        const SizedBox(height: 12),

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
              child: Text('Tidak ada voucher yang cocok.', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
            ),
          )
        else ...[
          ...visibleItems.map((user) {
            final exp = HotspotUtils.calculateHotspotUserExpiry(user, _profiles);
            final isOnline = _activeSessions.any((a) => a.user == user.name);

            Color? badgeCol;
            Color? badgeTextCol;
            final isDark = theme.brightness == Brightness.dark;

            switch (exp.status) {
              case HotspotStatus.active:
                badgeCol = isDark ? const Color(0xFF1E2E38) : colorScheme.primaryContainer;
                badgeTextCol = isDark ? const Color(0xFF86B9EC) : colorScheme.onPrimaryContainer;
                break;
              case HotspotStatus.expiringSoon:
                badgeCol = isDark ? const Color(0xFF382F1E) : colorScheme.tertiaryContainer;
                badgeTextCol = isDark ? const Color(0xFFF7DEB1) : colorScheme.onTertiaryContainer;
                break;
              case HotspotStatus.expired:
                badgeCol = isDark ? const Color(0xFF381E1E) : colorScheme.errorContainer;
                badgeTextCol = isDark ? const Color(0xFFF7B1A5) : colorScheme.onErrorContainer;
                break;
              case HotspotStatus.unused:
                badgeCol = isDark ? const Color(0xFF262D38) : colorScheme.surfaceContainerHighest;
                badgeTextCol = isDark ? const Color(0xFFCFD6E2) : colorScheme.onSurfaceVariant;
                break;
              case HotspotStatus.disabled:
                badgeCol = isDark ? const Color(0xFF202020) : colorScheme.surfaceContainer;
                badgeTextCol = isDark ? Colors.grey : colorScheme.outline;
                break;
            }

            final totalBytes = user.bytesIn + user.bytesOut;
            final usageText = totalBytes > 0 ? FormatUtils.formatBytes(totalBytes) : null;
            final jatuhTempo = exp.formattedDate != '-' ? exp.formattedDate : null;
            final badgeLabel = exp.status == HotspotStatus.expired
                ? 'Kadaluarsa'
                : (exp.sisaText.isNotEmpty ? exp.sisaText : exp.badgeText);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: UserCardM3(
                username: user.name,
                profile: user.profile,
                customerNote: user.comment.isNotEmpty ? user.comment : null,
                usage: usageText,
                jatuhTempo: jatuhTempo,
                sisaHari: badgeLabel,
                isOnline: isOnline,
                badgeColor: badgeCol,
                badgeTextColor: badgeTextCol,
                primaryActionLabel: 'Cetak Slip',
                primaryActionIcon: Icons.receipt_long_outlined,
                onPrimaryAction: () => _showPrintVoucherReceipt(user),
                secondaryActionLabel: 'Reset MAC',
                secondaryActionIcon: Icons.phonelink_erase,
                onSecondaryAction: () => _handleResetMac(user),
                secondaryActionColor: isDark ? const Color(0xFF86B9EC) : colorScheme.primary,
                secondaryActionBorderColor: isDark ? const Color(0xFF0F4D77) : colorScheme.outline,
                onEdit: () => _showSingleVoucherModal(editingUser: user),
                isSelected: _selectedVoucherIds.contains(user.id),
                isSelectionMode: _selectedVoucherIds.isNotEmpty,
                onLongPress: () => _toggleSelectVoucher(user.id),
                onTap: () {
                  if (_selectedVoucherIds.isNotEmpty) {
                    _toggleSelectVoucher(user.id);
                  }
                },
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
    );
  }

  Widget _buildFilterButton(String key, String label, int count, IconData icon, ColorScheme colorScheme) {
    final isSelected = _userFilter == key;
    if (isSelected) {
      return FilledButton.tonalIcon(
        onPressed: () {
          setState(() {
            _userFilter = key;
            _visibleVouchersCount = 25;
          });
        },
        icon: Icon(icon, size: 16),
        label: Text('$label ($count)'),
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );
    } else {
      return OutlinedButton.icon(
        onPressed: () {
          setState(() {
            _userFilter = key;
            _visibleVouchersCount = 25;
          });
        },
        icon: Icon(icon, size: 16),
        label: Text('$label ($count)'),
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );
    }
  }

  // --- TAB 1: Hotspot Active Sessions ---
  Widget _buildActiveSessionsTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final filtered = _activeSessions.where((a) {
      if (_activeSearchQuery.isNotEmpty) {
        final q = _activeSearchQuery.toLowerCase();
        return a.user.toLowerCase().contains(q) ||
            a.address.toLowerCase().contains(q) ||
            a.macAddress.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    final visibleItems = filtered.take(_visibleActiveCount).toList();

    return ListView(
      controller: _activeScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (_activeSearchQuery.isNotEmpty) ...[
          Row(
            children: [
              InputChip(
                avatar: const Icon(Icons.search, size: 16),
                label: Text('Pencarian: "$_activeSearchQuery"'),
                onDeleted: () => setSearchQuery(''),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (filtered.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Tidak ada sesi voucher aktif yang cocok.', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
            ),
          )
        else ...[
          ...visibleItems.map((active) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  radius: 20,
                  child: const Icon(Icons.wifi, size: 20),
                ),
                title: Text(active.user, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text('IP: ${active.address} • MAC: ${active.macAddress}', style: FNetTheme.monoStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                    Text('Sisa Sesi: ${active.sessionTimeLeft.isNotEmpty ? active.sessionTimeLeft : active.uptime}', style: FNetTheme.monoStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                  ],
                ),
                trailing: IconButton(
                  onPressed: () => _handleDisconnectActive(active),
                  icon: Icon(Icons.link_off, color: colorScheme.error, size: 22),
                  tooltip: 'Putuskan Voucher',
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
    );
  }

  // --- TAB 2: Hotspot Profiles ---
  Widget _buildProfilesTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final displayProfiles = _filteredProfiles;

    final filtered = displayProfiles.where((p) {
      if (_profileSearchQuery.isNotEmpty) {
        final q = _profileSearchQuery.toLowerCase();
        return p.name.toLowerCase().contains(q) ||
            p.rateLimit.toLowerCase().contains(q) ||
            p.addressPool.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    final visibleItems = filtered.take(_visibleProfilesCount).toList();

    if (displayProfiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Tidak ada paket profil kustom.',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
        ),
      );
    }

    return ListView(
      controller: _profileScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (_profileSearchQuery.isNotEmpty) ...[
          Row(
            children: [
              InputChip(
                avatar: const Icon(Icons.search, size: 16),
                label: Text('Pencarian: "$_profileSearchQuery"'),
                onDeleted: () => setSearchQuery(''),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (filtered.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Tidak ada paket profil yang cocok.', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
            ),
          )
        else ...[
          ...visibleItems.map((p) {
            final voucherCount = _users.where((u) => u.profile == p.name).length;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showHotspotProfileModal(editingProfile: p),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              p.name,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Badge(
                            label: Text('$voucherCount Voucher'),
                            backgroundColor: colorScheme.primaryContainer,
                            textColor: colorScheme.onPrimaryContainer,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            color: colorScheme.onSurfaceVariant,
                            tooltip: 'Edit Paket',
                            onPressed: () => _showHotspotProfileModal(editingProfile: p),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (p.rateLimit.isNotEmpty)
                        Text(
                          'Rate Limit: ${p.rateLimit}',
                          style: FNetTheme.monoStyle(fontSize: 13, fontWeight: FontWeight.w800, color: colorScheme.primary),
                        ),
                      Text(
                        'Shared Users: ${p.sharedUsers} • Pool: ${p.addressPool.isNotEmpty && p.addressPool != "none" ? p.addressPool : "-"}',
                        style: FNetTheme.monoStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
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
    );
  }
}
