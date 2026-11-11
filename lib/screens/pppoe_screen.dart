import 'package:flutter/material.dart';
import '../models/mikrotik_models.dart';
import '../services/mikrotik_api_service.dart';
import '../theme/fnet_theme.dart';
import '../utils/pppoe_utils.dart';
import '../widgets/loading_indicator_m3e.dart';
import '../widgets/toast_banner.dart';
import '../widgets/user_card_m3.dart';

class PppoeScreen extends StatefulWidget {
  final RouterProfile profile;
  final Map<String, String>? initialSecretData;
  final String searchQuery;

  const PppoeScreen({
    super.key,
    required this.profile,
    this.initialSecretData,
    this.searchQuery = '',
  });

  @override
  State<PppoeScreen> createState() => PppoeScreenState();
}

class PppoeScreenState extends State<PppoeScreen> {
  int _selectedSubTab = 0; // 0: Secrets, 1: Active, 2: Profiles
  bool _isLoading = true;
  String? _errorMessage;

  List<PppSecret> _secrets = [];
  List<PppActive> _activeSessions = [];
  List<PppProfile> _profiles = [];
  List<IpPool> _ipPools = [];

  bool _isSystemProfile(String name) {
    final lower = name.toLowerCase().trim();
    return lower == 'default' || lower == 'default-encryption';
  }

  List<PppProfile> get _filteredProfiles =>
      _profiles.where((p) => !_isSystemProfile(p.name)).toList();

  String _searchQuery = '';
  String _secretFilter = 'all';
  final TextEditingController _searchController = TextEditingController();

  // Multi-select / Hold-to-select support
  final Set<String> _selectedSecretIds = {};
  final Set<String> _selectedProfileIds = {};

  // Infinite Scroll Lazy Load Chunking (25 data per chunk)
  int _visibleSecretsCount = 25;
  int _visibleActiveCount = 25;
  final ScrollController _secretScrollController = ScrollController();
  final ScrollController _activeScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.searchQuery;
    _secretScrollController.addListener(_onSecretScroll);
    _activeScrollController.addListener(_onActiveScroll);
    refreshData();
    if (widget.initialSecretData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        openAddSecretPrefilled(
          name: widget.initialSecretData!['name'] ?? '',
          ip: widget.initialSecretData!['ip'] ?? '',
          comment: widget.initialSecretData!['comment'] ?? '',
        );
      });
    }
  }

  @override
  void didUpdateWidget(covariant PppoeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _searchQuery = widget.searchQuery;
      _visibleSecretsCount = 25;
      _visibleActiveCount = 25;
    }
    if (oldWidget.profile.id != widget.profile.id ||
        oldWidget.profile.host != widget.profile.host ||
        oldWidget.profile.port != widget.profile.port) {
      _errorMessage = null;
      _visibleSecretsCount = 25;
      _visibleActiveCount = 25;
      _secrets = [];
      _activeSessions = [];
      _profiles = [];
      _ipPools = [];
      refreshData();
    }
  }

  void setSearchQuery(String query) {
    setState(() {
      _searchQuery = query;
      _visibleSecretsCount = 25;
      _visibleActiveCount = 25;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _secretScrollController.removeListener(_onSecretScroll);
    _activeScrollController.removeListener(_onActiveScroll);
    _secretScrollController.dispose();
    _activeScrollController.dispose();
    super.dispose();
  }

  void _onSecretScroll() {
    if (_secretScrollController.hasClients &&
        _secretScrollController.position.pixels >= _secretScrollController.position.maxScrollExtent - 250) {
      if (_visibleSecretsCount < _secrets.length) {
        setState(() {
          _visibleSecretsCount = (_visibleSecretsCount + 25).clamp(0, _secrets.length);
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

  Future<void> refreshData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final sFuture = MikrotikApiService.instance.getPppSecrets(widget.profile);
      final aFuture = MikrotikApiService.instance.getPppActive(widget.profile);
      final pFuture = MikrotikApiService.instance.getPppProfiles(widget.profile);
      final poolFuture = MikrotikApiService.instance.getIpPools(widget.profile);

      final results = await Future.wait([sFuture, aFuture, pFuture, poolFuture]);

      if (mounted) {
        setState(() {
          _secrets = results[0] as List<PppSecret>;
          _activeSessions = results[1] as List<PppActive>;
          _profiles = results[2] as List<PppProfile>;
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

  Future<void> _handleExtend30Days(PppSecret secret) async {
    final updatedComment = PppoeUtils.extendExpiryDate(secret.comment);
    try {
      await MikrotikApiService.instance.updatePppSecret(widget.profile, secret.id, {
        'comment': updatedComment,
        'disabled': 'false',
      });
      if (mounted) {
        ToastBanner.show(
          context,
          message: 'Masa aktif ${secret.name} berhasil diperpanjang +30 hari.',
          type: ToastType.success,
        );
      }
      refreshData();
    } catch (e) {
      if (mounted) {
        ToastBanner.show(
          context,
          message: 'Gagal memperpanjang masa aktif: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _handleToggleIsolir(PppSecret secret) async {
    final newDisabled = !secret.disabled;
    try {
      await MikrotikApiService.instance.updatePppSecret(widget.profile, secret.id, {
        'disabled': newDisabled ? 'true' : 'false',
      });
      if (newDisabled) {
        final active = _activeSessions.where((a) => a.name == secret.name).toList();
        for (final act in active) {
          try {
            await MikrotikApiService.instance.disconnectPppActive(widget.profile, act.id);
          } catch (_) {}
        }
      }
      if (mounted) {
        ToastBanner.show(
          context,
          message: 'Pelanggan ${secret.name} berhasil di-${newDisabled ? "isolir" : "buka isolir"}.',
          type: ToastType.success,
        );
      }
      refreshData();
    } catch (e) {
      if (mounted) {
        ToastBanner.show(
          context,
          message: 'Gagal mengubah status: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _handleDisconnectActive(PppActive active) async {
    try {
      await MikrotikApiService.instance.disconnectPppActive(widget.profile, active.id);
      if (mounted) {
        ToastBanner.show(
          context,
          message: 'Sesi PPPoE ${active.name} berhasil diputuskan.',
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

  void _toggleSelectSecret(String id) {
    setState(() {
      if (_selectedSecretIds.contains(id)) {
        _selectedSecretIds.remove(id);
      } else {
        _selectedSecretIds.add(id);
      }
    });
  }

  void _selectAllSecrets(List<PppSecret> items) {
    setState(() {
      if (_selectedSecretIds.length == items.length) {
        _selectedSecretIds.clear();
      } else {
        _selectedSecretIds.addAll(items.map((e) => e.id));
      }
    });
  }

  void _clearSecretSelection() {
    setState(() {
      _selectedSecretIds.clear();
    });
  }

  void _confirmDeleteSelectedSecrets() {
    if (_selectedSecretIds.isEmpty) return;
    final selectedCount = _selectedSecretIds.length;
    final singleSecret = selectedCount == 1
        ? _secrets.firstWhere((s) => s.id == _selectedSecretIds.first, orElse: () => _secrets.first)
        : null;

    final title = selectedCount == 1 ? 'Hapus Pelanggan PPPoE?' : 'Hapus $selectedCount Pelanggan?';
    final content = selectedCount == 1
        ? 'Hapus pelanggan "${singleSecret?.name}" dari router?'
        : 'Hapus $selectedCount pelanggan PPPoE terpilih dari router?';

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
              final idsToDelete = List<String>.from(_selectedSecretIds);
              _clearSecretSelection();

              int successCount = 0;
              for (final id in idsToDelete) {
                try {
                  await MikrotikApiService.instance.deletePppSecret(widget.profile, id);
                  successCount++;
                } catch (_) {}
              }

              if (mounted) {
                if (successCount == idsToDelete.length) {
                  ToastBanner.show(
                    context,
                    message: selectedCount == 1
                        ? 'Pelanggan PPPoE berhasil dihapus.'
                        : '$successCount pelanggan berhasil dihapus.',
                    type: ToastType.success,
                  );
                } else {
                  ToastBanner.show(
                    context,
                    message: '$successCount dari ${idsToDelete.length} pelanggan berhasil dihapus.',
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

  void _toggleSelectProfile(String id) {
    setState(() {
      if (_selectedProfileIds.contains(id)) {
        _selectedProfileIds.remove(id);
      } else {
        _selectedProfileIds.add(id);
      }
    });
  }

  void _selectAllProfiles(List<PppProfile> items) {
    setState(() {
      final ids = items.map((e) => e.id.isNotEmpty ? e.id : e.name).toList();
      if (_selectedProfileIds.length == ids.length) {
        _selectedProfileIds.clear();
      } else {
        _selectedProfileIds.addAll(ids);
      }
    });
  }

  void _clearProfileSelection() {
    setState(() {
      _selectedProfileIds.clear();
    });
  }

  void _confirmDeleteSelectedProfiles(List<PppProfile> allProfiles) {
    if (_selectedProfileIds.isEmpty) return;
    final selectedCount = _selectedProfileIds.length;
    final singleProfile = selectedCount == 1
        ? allProfiles.firstWhere(
            (p) => (p.id.isNotEmpty ? p.id : p.name) == _selectedProfileIds.first,
            orElse: () => allProfiles.first,
          )
        : null;

    final inUseCount = allProfiles
        .where((p) => _selectedProfileIds.contains(p.id.isNotEmpty ? p.id : p.name))
        .map((p) => _secrets.where((s) => s.profile == p.name).length)
        .fold(0, (a, b) => a + b);

    final title = selectedCount == 1 ? 'Hapus Paket PPPoE?' : 'Hapus $selectedCount Paket PPPoE?';
    final content = selectedCount == 1
        ? 'Hapus paket "${singleProfile?.name}" dari router?${inUseCount > 0 ? "\n\nPerhatian: Paket ini masih digunakan oleh $inUseCount pelanggan." : ""}'
        : 'Hapus $selectedCount paket PPPoE terpilih dari router?${inUseCount > 0 ? "\n\nPerhatian: Beberapa paket masih digunakan oleh $inUseCount pelanggan." : ""}';

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
              final idsToDelete = List<String>.from(_selectedProfileIds);
              _clearProfileSelection();

              int successCount = 0;
              for (final id in idsToDelete) {
                try {
                  await MikrotikApiService.instance.deletePppProfile(widget.profile, id);
                  successCount++;
                } catch (_) {}
              }

              if (mounted) {
                if (successCount == idsToDelete.length) {
                  ToastBanner.show(
                    context,
                    message: selectedCount == 1
                        ? 'Paket PPPoE berhasil dihapus.'
                        : '$successCount paket PPPoE berhasil dihapus.',
                    type: ToastType.success,
                  );
                } else {
                  ToastBanner.show(
                    context,
                    message: '$successCount dari ${idsToDelete.length} paket PPPoE berhasil dihapus.',
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

  // --- M3 Add / Edit Secret Modal BottomSheet ---
  void _showSecretDialog({PppSecret? editingSecret, String? initialName, String? initialIp, String? initialComment}) {
    final isEditing = editingSecret != null;
    final nameCtrl = TextEditingController(text: editingSecret?.name ?? initialName ?? '');
    final passCtrl = TextEditingController(text: editingSecret?.password ?? '');

    // Cari sesi aktif yang cocok untuk mengambil IP
    final currentTargetName = editingSecret?.name ?? initialName ?? '';
    final activeSession = _activeSessions.cast<PppActive?>().firstWhere(
      (a) => a?.name.toLowerCase() == currentTargetName.toLowerCase(),
      orElse: () => null,
    );

    // Ambil IP: jika static sudah ada gunakan itu, jika kosong ambil dari sesi aktif
    String defaultIp = editingSecret?.remoteAddress ?? '';
    if (defaultIp.isEmpty && (activeSession?.address.isNotEmpty ?? false)) {
      defaultIp = activeSession!.address;
    } else if (defaultIp.isEmpty && initialIp != null && initialIp.isNotEmpty) {
      defaultIp = initialIp;
    }

    final remoteIpCtrl = TextEditingController(text: defaultIp);
    final noteCtrl = TextEditingController(
      text: editingSecret != null
          ? PppoeUtils.parseExpiryFromComment(editingSecret.comment).customerName
          : initialComment ?? '',
    );

    DateTime? selectedDate = editingSecret != null
        ? PppoeUtils.parseExpiryFromComment(editingSecret.comment).expiryDate
        : DateTime.now().add(const Duration(days: 30));

    final availableProfiles = _filteredProfiles.toList();
    if (editingSecret != null &&
        _isSystemProfile(editingSecret.profile) &&
        !availableProfiles.any((p) => p.name == editingSecret.profile)) {
      final existing = _profiles.firstWhere(
        (p) => p.name == editingSecret.profile,
        orElse: () => PppProfile(id: '', name: editingSecret.profile),
      );
      availableProfiles.insert(0, existing);
    }

    String selectedProfile = editingSecret?.profile ??
        (availableProfiles.isNotEmpty ? availableProfiles.first.name : (_profiles.isNotEmpty ? _profiles.first.name : 'default'));
    bool obscurePass = true;

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
                        isEditing ? 'Edit Pelanggan PPPoE' : 'Tambah Pelanggan PPPoE',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Username
                  TextField(
                    controller: nameCtrl,
                    enabled: !isEditing,
                    decoration: const InputDecoration(
                      labelText: 'Username Pelanggan',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Password
                  TextField(
                    controller: passCtrl,
                    obscureText: obscurePass,
                    decoration: InputDecoration(
                      labelText: 'Kata Sandi PPPoE',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setModalState(() => obscurePass = !obscurePass),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Profile Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: availableProfiles.any((p) => p.name == selectedProfile) ? selectedProfile : null,
                    decoration: const InputDecoration(
                      labelText: 'Paket Kecepatan (PPP Profile)',
                      prefixIcon: Icon(Icons.speed),
                    ),
                    items: availableProfiles.map((p) {
                      return DropdownMenuItem(
                        value: p.name,
                        child: Text('${p.name} ${p.rateLimit.isNotEmpty ? "(${p.rateLimit})" : ""}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedProfile = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Remote Address
                  TextField(
                    controller: remoteIpCtrl,
                    style: FNetTheme.monoStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'IP Static Remote (Opsional)',
                      hintText: '10.10.10.x',
                      prefixIcon: Icon(Icons.router_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Note / Customer Name
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap / Alamat / Catatan',
                      hintText: 'Pak Ahmad - Blok B2 No. 5',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Expiry Date Picker Row
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Tanggal Jatuh Tempo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      selectedDate != null
                          ? '${selectedDate!.day.toString().padLeft(2, "0")}-${selectedDate!.month.toString().padLeft(2, "0")}-${selectedDate!.year}'
                          : 'Tidak ada batas waktu',
                      style: FNetTheme.monoStyle(fontSize: 13, color: colorScheme.primary, fontWeight: FontWeight.w700),
                    ),
                    trailing: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      child: const Text('Pilih'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // M3 Submit Button
                  FilledButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final pass = passCtrl.text;
                      final remoteIp = remoteIpCtrl.text.trim();
                      final note = noteCtrl.text.trim();

                      if (name.isEmpty) {
                        ToastBanner.show(ctx, message: 'Username tidak boleh kosong.', type: ToastType.error);
                        return;
                      }

                      final dateStr = selectedDate != null
                          ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, "0")}-${selectedDate!.day.toString().padLeft(2, "0")}'
                          : '';
                      final comment = PppoeUtils.buildExpiryComment(dateStr, note);

                      final payload = <String, String>{
                        'name': name,
                        'service': 'pppoe',
                        'profile': selectedProfile,
                        'comment': comment,
                      };
                      if (pass.isNotEmpty) payload['password'] = pass;
                      if (remoteIp.isNotEmpty) payload['remote-address'] = remoteIp;

                      Navigator.pop(ctx);

                      try {
                        if (isEditing) {
                          await MikrotikApiService.instance.updatePppSecret(widget.profile, editingSecret.id, payload);
                          if (mounted) {
                            ToastBanner.show(context, message: 'Pelanggan $name berhasil diperbarui.', type: ToastType.success);
                          }
                        } else {
                          await MikrotikApiService.instance.createPppSecret(widget.profile, payload);
                          if (mounted) {
                            ToastBanner.show(context, message: 'Pelanggan $name berhasil ditambahkan.', type: ToastType.success);
                          }
                        }
                        refreshData();
                      } catch (e) {
                        if (mounted) {
                          ToastBanner.show(context, message: 'Gagal menyimpan: $e', type: ToastType.error);
                        }
                      }
                    },
                    child: Text(isEditing ? 'Simpan Perubahan' : 'Buat Pelanggan PPPoE'),
                  ),

                  if (isEditing) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
                      ),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Hapus Pelanggan PPPoE'),
                      onPressed: () {
                        showDialog(
                          context: ctx,
                          builder: (dialogCtx) => AlertDialog(
                            icon: Icon(Icons.delete_outline, color: colorScheme.error),
                            title: const Text('Hapus Pelanggan'),
                            content: Text('Apakah Anda yakin ingin menghapus pelanggan "${editingSecret.name}"?'),
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
                                    await MikrotikApiService.instance.deletePppSecret(widget.profile, editingSecret.id);
                                    if (mounted) {
                                      ToastBanner.show(context, message: 'Pelanggan ${editingSecret.name} telah dihapus.', type: ToastType.success);
                                    }
                                    refreshData();
                                  } catch (e) {
                                    if (mounted) {
                                      ToastBanner.show(context, message: 'Gagal menghapus: $e', type: ToastType.error);
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

  void openCreateSecret({String? initialName, String? initialIp, String? initialComment}) {
    setState(() => _selectedSubTab = 0);
    _showSecretDialog(initialName: initialName, initialIp: initialIp, initialComment: initialComment);
  }

  void openAddSecretPrefilled({required String name, required String ip, required String comment}) {
    openCreateSecret(initialName: name, initialIp: ip, initialComment: comment);
  }

  void _showProfileDialog({PppProfile? editingProfile}) {
    final isEditing = editingProfile != null;
    final nameCtrl = TextEditingController(text: editingProfile?.name ?? '');
    final rateCtrl = TextEditingController(text: editingProfile?.rateLimit ?? (isEditing ? '' : '10M/10M'));
    final localCtrl = TextEditingController(text: editingProfile?.localAddress ?? '');

    final initialRemote = editingProfile?.remoteAddress ?? '';
    final poolNames = _ipPools.map((p) => p.name).toSet();
    final bool isCustomInitial = initialRemote.isNotEmpty && !poolNames.contains(initialRemote);

    String selectedRemotePool = isCustomInitial ? '__custom__' : initialRemote;
    final customRemoteCtrl = TextEditingController(text: isCustomInitial ? initialRemote : '');

    void Function(void Function())? modalSetter;
    if (_ipPools.isEmpty) {
      MikrotikApiService.instance.getIpPools(widget.profile).then((pools) {
        if (mounted && pools.isNotEmpty) {
          setState(() => _ipPools = pools);
          modalSetter?.call(() {
            if (initialRemote.isNotEmpty && pools.any((p) => p.name == initialRemote)) {
              selectedRemotePool = initialRemote;
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

          // Dropdown items untuk Remote Address / IP Pool
          final List<DropdownMenuItem<String>> poolDropdownItems = [
            DropdownMenuItem<String>(
              value: '',
              child: Text(
                '-- Tidak Ada / Kosong --',
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

          // Validasi agar value selalu ada di items list
          final validValues = poolDropdownItems.map((item) => item.value).toSet();
          if (!validValues.contains(selectedRemotePool)) {
            selectedRemotePool = selectedRemotePool.isNotEmpty ? '__custom__' : '';
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
                        isEditing ? 'Edit Paket PPPoE' : 'Tambah Paket PPPoE',
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
                      labelText: 'Nama Profil / Paket',
                      prefixIcon: Icon(Icons.speed),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: rateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Rate Limit (Tx/Rx)',
                      hintText: 'Contoh: 10M/10M',
                      prefixIcon: Icon(Icons.tune),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: localCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Local Address (Opsional)',
                      hintText: 'Contoh: 192.168.10.1',
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: ValueKey('pool_$selectedRemotePool'),
                    initialValue: selectedRemotePool,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Remote Address Pool (IP Pool)',
                      prefixIcon: Icon(Icons.lan_outlined),
                      helperText: 'Pilih IP Pool MikroTik untuk pelanggan',
                    ),
                    items: poolDropdownItems,
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedRemotePool = val;
                        });
                      }
                    },
                  ),
                  if (selectedRemotePool == '__custom__') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: customRemoteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'IP / Pool Kustom',
                        hintText: 'Contoh: 192.168.10.10 atau pool-khusus',
                        prefixIcon: Icon(Icons.edit_note),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ToastBanner.show(ctx, message: 'Nama profil wajib diisi.', type: ToastType.error);
                        return;
                      }

                      final finalRemote = selectedRemotePool == '__custom__'
                          ? customRemoteCtrl.text.trim()
                          : selectedRemotePool.trim();

                      Navigator.pop(ctx);
                      try {
                        final data = <String, dynamic>{
                          'name': name,
                          if (rateCtrl.text.trim().isNotEmpty) 'rate-limit': rateCtrl.text.trim(),
                          if (localCtrl.text.trim().isNotEmpty) 'local-address': localCtrl.text.trim(),
                          if (finalRemote.isNotEmpty)
                            'remote-address': finalRemote
                          else if (isEditing)
                            'remote-address': '',
                        };
                        if (isEditing) {
                          await MikrotikApiService.instance.updatePppProfile(widget.profile, editingProfile.id, data);
                          if (mounted) {
                            ToastBanner.show(context, message: 'Paket PPPoE $name berhasil diperbarui.', type: ToastType.success);
                          }
                        } else {
                          await MikrotikApiService.instance.createPppProfile(widget.profile, data);
                          if (mounted) {
                            ToastBanner.show(context, message: 'Paket PPPoE $name berhasil dibuat.', type: ToastType.success);
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
                      label: const Text('Hapus Paket PPPoE'),
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
                                    await MikrotikApiService.instance.deletePppProfile(widget.profile, editingProfile.id);
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

  List<PppSecret> _getFilteredSecrets() {
    return _secrets.where((s) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!s.name.toLowerCase().contains(q) && !s.comment.toLowerCase().contains(q)) {
          return false;
        }
      }
      final parsed = PppoeUtils.parseExpiryFromComment(s.comment);
      if (_secretFilter == 'active') {
        return !s.disabled && parsed.status == ExpiryStatus.active;
      } else if (_secretFilter == 'expiringSoon') {
        return !s.disabled && parsed.status == ExpiryStatus.expiringSoon;
      } else if (_secretFilter == 'expired') {
        return !s.disabled && parsed.status == ExpiryStatus.expired;
      } else if (_secretFilter == 'isolated') {
        return s.disabled;
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
                'Memuat data PPPoE...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isSecretSelectionMode = _selectedSecretIds.isNotEmpty && _selectedSubTab == 0;
    final isProfileSelectionMode = _selectedProfileIds.isNotEmpty && _selectedSubTab == 2;
    final filteredSecrets = _getFilteredSecrets();
    final filteredProfiles = _filteredProfiles;

    return DefaultTabController(
      length: 3,
      initialIndex: _selectedSubTab,
      child: Builder(
        builder: (ctx) {
          return Scaffold(
            body: Column(
              children: [
                // Official Material 3 Secondary TabBar or Pinned Top Selection Bar
                if (isSecretSelectionMode)
                  Container(
                    color: colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Batal Pilih',
                          onPressed: _clearSecretSelection,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_selectedSecretIds.length} dipilih',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _selectAllSecrets(filteredSecrets),
                          icon: Icon(
                            _selectedSecretIds.length == filteredSecrets.length
                                ? Icons.deselect_rounded
                                : Icons.select_all_rounded,
                            size: 18,
                          ),
                          label: Text(_selectedSecretIds.length == filteredSecrets.length
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
                          label: Text('Hapus (${_selectedSecretIds.length})'),
                          onPressed: _confirmDeleteSelectedSecrets,
                        ),
                      ],
                    ),
                  )
                else if (isProfileSelectionMode)
                  Container(
                    color: colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Batal Pilih',
                          onPressed: _clearProfileSelection,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_selectedProfileIds.length} dipilih',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _selectAllProfiles(filteredProfiles),
                          icon: Icon(
                            _selectedProfileIds.length == filteredProfiles.length
                                ? Icons.deselect_rounded
                                : Icons.select_all_rounded,
                            size: 18,
                          ),
                          label: Text(_selectedProfileIds.length == filteredProfiles.length
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
                          label: Text('Hapus (${_selectedProfileIds.length})'),
                          onPressed: () => _confirmDeleteSelectedProfiles(filteredProfiles),
                        ),
                      ],
                    ),
                  )
                else
                  TabBar(
                    onTap: (index) {
                      _clearSecretSelection();
                      _clearProfileSelection();
                      setState(() => _selectedSubTab = index);
                    },
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: colorScheme.primary,
                    unselectedLabelColor: colorScheme.onSurfaceVariant,
                    tabs: [
                      Tab(text: 'Pelanggan (${_secrets.length})'),
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
            floatingActionButton: (isSecretSelectionMode || isProfileSelectionMode)
                ? null
                : (_selectedSubTab == 0
                    ? FloatingActionButton(
                        onPressed: () => _showSecretDialog(),
                        tooltip: 'Tambah Pelanggan',
                        child: const Icon(Icons.add),
                      )
                    : _selectedSubTab == 2
                        ? FloatingActionButton(
                            onPressed: () => _showProfileDialog(),
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
              _errorMessage ?? 'Terjadi kesalahan saat memuat data PPPoE dari router.',
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
        return _buildSecretsTab();
      case 1:
        return _buildActiveSessionsTab();
      case 2:
        return _buildProfilesTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- TAB 0: PPPoE Secrets ---
  Widget _buildSecretsTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final totalCount = _secrets.length;
    final activeCount = _secrets.where((s) {
      final p = PppoeUtils.parseExpiryFromComment(s.comment);
      return !s.disabled && p.status == ExpiryStatus.active;
    }).length;
    final expiringCount = _secrets.where((s) {
      final p = PppoeUtils.parseExpiryFromComment(s.comment);
      return !s.disabled && p.status == ExpiryStatus.expiringSoon;
    }).length;
    final expiredCount = _secrets.where((s) {
      final p = PppoeUtils.parseExpiryFromComment(s.comment);
      return !s.disabled && p.status == ExpiryStatus.expired;
    }).length;
    final isolatedCount = _secrets.where((s) => s.disabled).length;

    final filtered = _getFilteredSecrets();
    final visibleItems = filtered.take(_visibleSecretsCount).toList();

    return ListView(
      controller: _secretScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // M3 Status Filter Buttons on Top
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterButton('all', 'Semua', totalCount, Icons.list_alt, colorScheme),
              const SizedBox(width: 8),
              _buildFilterButton('active', 'Aktif', activeCount, Icons.check_circle_outline, colorScheme),
              const SizedBox(width: 8),
              _buildFilterButton('expiringSoon', 'Segera Habis', expiringCount, Icons.schedule, colorScheme),
              const SizedBox(width: 8),
              _buildFilterButton('expired', 'Kadaluarsa', expiredCount, Icons.cancel_outlined, colorScheme),
              const SizedBox(width: 8),
              _buildFilterButton('isolated', 'Terisolir', isolatedCount, Icons.block_outlined, colorScheme),
            ],
          ),
        ),

        // Active search indicator (if searched from AppBar)
        if (_searchQuery.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              InputChip(
                avatar: const Icon(Icons.search, size: 16),
                label: Text('Pencarian: "$_searchQuery"'),
                onDeleted: () => setSearchQuery(''),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),

        if (filtered.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: Text(
                'Tidak ada pelanggan yang cocok.',
                style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else ...[
          ...visibleItems.map((secret) {
            final parsed = PppoeUtils.parseExpiryFromComment(secret.comment);
            final isOnline = _activeSessions.any((a) => a.name.toLowerCase() == secret.name.toLowerCase());

            Color? badgeCol;
            Color? badgeTextCol;
            String badgeText;

            if (secret.disabled) {
              badgeCol = colorScheme.errorContainer;
              badgeTextCol = colorScheme.onErrorContainer;
              badgeText = 'Isolir';
            } else {
              switch (parsed.status) {
                case ExpiryStatus.expired:
                  badgeCol = colorScheme.errorContainer;
                  badgeTextCol = colorScheme.onErrorContainer;
                  badgeText = 'Kadaluarsa';
                  break;
                case ExpiryStatus.expiringSoon:
                  badgeCol = colorScheme.tertiaryContainer;
                  badgeTextCol = colorScheme.onTertiaryContainer;
                  badgeText = 'Sisa ${parsed.daysRemaining} hari';
                  break;
                case ExpiryStatus.active:
                  badgeCol = colorScheme.primaryContainer;
                  badgeTextCol = colorScheme.onPrimaryContainer;
                  badgeText = 'Sisa ${parsed.daysRemaining} hari';
                  break;
                case ExpiryStatus.noExpiry:
                  badgeCol = null;
                  badgeTextCol = null;
                  badgeText = 'Tanpa Batas';
                  break;
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: UserCardM3(
                username: secret.name,
                profile: secret.profile,
                ipAddress: secret.remoteAddress.isNotEmpty ? secret.remoteAddress : null,
                customerNote: parsed.customerName.isNotEmpty ? parsed.customerName : null,
                jatuhTempo: parsed.formattedExpiry.isNotEmpty ? parsed.formattedExpiry : 'Tidak ada batas waktu',
                sisaHari: badgeText,
                isOnline: isOnline,
                isIsolir: secret.disabled,
                badgeColor: badgeCol,
                badgeTextColor: badgeTextCol,
                onAddDays: () => _handleExtend30Days(secret),
                onIsolir: () => _handleToggleIsolir(secret),
                onEdit: () => _showSecretDialog(editingSecret: secret),
                isSelected: _selectedSecretIds.contains(secret.id),
                isSelectionMode: _selectedSecretIds.isNotEmpty,
                onLongPress: () => _toggleSelectSecret(secret.id),
                onTap: () {
                  if (_selectedSecretIds.isNotEmpty) {
                    _toggleSelectSecret(secret.id);
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
    final isSelected = _secretFilter == key;
    if (isSelected) {
      return FilledButton.tonalIcon(
        onPressed: () {
          setState(() {
            _secretFilter = key;
            _visibleSecretsCount = 25;
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
            _secretFilter = key;
            _visibleSecretsCount = 25;
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

  // --- TAB 1: PPPoE Active Sessions ---
  Widget _buildActiveSessionsTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_activeSessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('Tidak ada sesi PPPoE aktif.', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
        ),
      );
    }

    final visibleActive = _activeSessions.take(_visibleActiveCount).toList();

    return ListView.builder(
      controller: _activeScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: visibleActive.length + (visibleActive.length < _activeSessions.length ? 1 : 0),
      itemBuilder: (ctx, idx) {
        if (idx == visibleActive.length) {
          return Padding(
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
                    'Memuat lebih banyak (${visibleActive.length} dari ${_activeSessions.length})...',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          );
        }

        final active = visibleActive[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              radius: 20,
              child: const Icon(Icons.wifi_tethering, size: 20),
            ),
            title: Text(active.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text('IP: ${active.address} • MAC: ${active.callerId}', style: FNetTheme.monoStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                Text('Uptime: ${active.uptime}', style: FNetTheme.monoStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
              ],
            ),
            trailing: IconButton(
              onPressed: () => _handleDisconnectActive(active),
              icon: Icon(Icons.link_off, color: colorScheme.error, size: 22),
              tooltip: 'Putuskan Sesi',
            ),
          ),
        );
      },
    );
  }

  // --- TAB 2: PPPoE Profiles ---
  Widget _buildProfilesTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayProfiles = _filteredProfiles;

    if (displayProfiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Tidak ada paket PPPoE kustom.',
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        ...displayProfiles.map((p) {
          final clientCount = _secrets.where((s) => s.profile == p.name).length;
          final effectiveId = p.id.isNotEmpty ? p.id : p.name;
          final isSelected = _selectedProfileIds.contains(effectiveId);
          final isSelectionMode = _selectedProfileIds.isNotEmpty;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            color: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.35)
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onLongPress: () => _toggleSelectProfile(effectiveId),
              onTap: () {
                if (isSelectionMode) {
                  _toggleSelectProfile(effectiveId);
                } else {
                  _showProfileDialog(editingProfile: p);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (isSelectionMode) ...[
                          Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Text(p.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                        Badge(
                          label: Text('$clientCount Pelanggan'),
                          backgroundColor: colorScheme.primaryContainer,
                          textColor: colorScheme.onPrimaryContainer,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (p.rateLimit.isNotEmpty)
                      Text('Rate Limit: ${p.rateLimit}', style: FNetTheme.monoStyle(fontSize: 13, fontWeight: FontWeight.w800, color: colorScheme.primary)),
                    if (p.localAddress.isNotEmpty || p.remoteAddress.isNotEmpty)
                      Text(
                        'Local: ${p.localAddress.isNotEmpty ? p.localAddress : "-"} • Pool: ${p.remoteAddress.isNotEmpty ? p.remoteAddress : "-"}',
                        style: FNetTheme.monoStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
