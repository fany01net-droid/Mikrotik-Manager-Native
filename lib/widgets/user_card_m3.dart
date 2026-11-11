import 'package:flutter/material.dart';
import '../theme/fnet_theme.dart';

class UserCardM3 extends StatelessWidget {
  final String username;
  final String profile;
  final String? jatuhTempo;
  final String sisaHari;
  final bool isOnline;
  final bool isIsolir;
  final String? ipAddress;
  final String? customerNote;
  final String? usage;
  final String? timeRemaining;
  final Color? badgeColor;
  final Color? badgeTextColor;
  final VoidCallback? onAddDays;
  final VoidCallback? onIsolir;
  final VoidCallback? onEdit;

  // Custom Primary Action (Overrides onAddDays if provided)
  final String? primaryActionLabel;
  final IconData? primaryActionIcon;
  final VoidCallback? onPrimaryAction;

  // Custom Secondary Action (Overrides onIsolir if provided)
  final String? secondaryActionLabel;
  final IconData? secondaryActionIcon;
  final VoidCallback? onSecondaryAction;
  final Color? secondaryActionColor;
  final Color? secondaryActionBorderColor;

  // Selection / Hold-to-select support
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isSelectionMode;

  const UserCardM3({
    super.key,
    required this.username,
    required this.profile,
    this.jatuhTempo,
    required this.sisaHari,
    this.isOnline = true,
    this.isIsolir = false,
    this.ipAddress,
    this.customerNote,
    this.usage,
    this.timeRemaining,
    this.badgeColor,
    this.badgeTextColor,
    this.onAddDays,
    this.onIsolir,
    this.onEdit,
    this.primaryActionLabel,
    this.primaryActionIcon,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.secondaryActionIcon,
    this.onSecondaryAction,
    this.secondaryActionColor,
    this.secondaryActionBorderColor,
    this.onLongPress,
    this.onTap,
    this.isSelected = false,
    this.isSelectionMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final cardBg = isSelected
        ? colorScheme.primaryContainer.withValues(alpha: 0.35)
        : colorScheme.surface;
    final borderColor = isSelected
        ? colorScheme.primary
        : colorScheme.outlineVariant;
    final titleColor = colorScheme.onSurface;
    final subtitleColor = colorScheme.onSurfaceVariant;
    final dividerColor = colorScheme.outlineVariant;

    final defaultBadgeBg = colorScheme.surfaceContainerHighest;
    final defaultBadgeFg = colorScheme.onSurfaceVariant;

    final hasPrimaryAction = onPrimaryAction != null || onAddDays != null;
    final hasSecondaryAction = onSecondaryAction != null || onIsolir != null;

    return Card(
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(color: borderColor, width: isSelected ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(16.0),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bagian Utama: Status dot, Username, Detail profil & Sisa hari/Status
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
                          color: isOnline ? FNetTheme.emerald : colorScheme.outline,
                        ),
                      ),
                minLeadingWidth: 0,
              title: Text(
                username,
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (customerNote != null && customerNote!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: Text(
                          'Catatan: $customerNote',
                          style: TextStyle(color: subtitleColor, fontSize: 13),
                        ),
                      ),
                    Text(
                      'Profil: $profile',
                      style: TextStyle(color: subtitleColor, fontSize: 13),
                    ),
                    if (ipAddress != null && ipAddress!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'IP: $ipAddress',
                        style: TextStyle(color: subtitleColor, fontSize: 13),
                      ),
                    ],
                    if (usage != null && usage!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Pemakaian: $usage',
                        style: TextStyle(color: subtitleColor, fontSize: 13),
                      ),
                    ],
                    if (timeRemaining != null && timeRemaining!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        timeRemaining!,
                        style: TextStyle(color: subtitleColor, fontSize: 13),
                      ),
                    ],
                    if (jatuhTempo != null && jatuhTempo!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Jatuh Tempo: $jatuhTempo',
                        style: TextStyle(color: subtitleColor, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor ?? defaultBadgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  sisaHari,
                  style: TextStyle(
                    color: badgeTextColor ?? defaultBadgeFg,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            if (hasPrimaryAction || hasSecondaryAction || onEdit != null) ...[
              const SizedBox(height: 4),
              Divider(color: dividerColor, height: 1, thickness: 1),
              const SizedBox(height: 10),

              // Bagian Aksi / Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  children: [
                    // Tombol Aksi 1 (Filled Tonal Button M3)
                    if (hasPrimaryAction)
                      FilledButton.tonalIcon(
                        onPressed: onPrimaryAction ?? onAddDays,
                        icon: Icon(primaryActionIcon ?? Icons.more_time_rounded, size: 18),
                        label: Text(
                          primaryActionLabel ?? '+30 Hari',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.secondaryContainer,
                          foregroundColor: colorScheme.onSecondaryContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    if (hasPrimaryAction && hasSecondaryAction)
                      const SizedBox(width: 10),

                    // Tombol Aksi 2 (Outlined Button M3)
                    if (hasSecondaryAction)
                      OutlinedButton.icon(
                        onPressed: onSecondaryAction ?? onIsolir,
                        icon: Icon(
                          secondaryActionIcon ??
                              (isIsolir ? Icons.lock_open_rounded : Icons.lock_outline_rounded),
                          size: 18,
                        ),
                        label: Text(
                          secondaryActionLabel ?? (isIsolir ? 'Buka Isolir' : 'Isolir'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: secondaryActionColor ??
                              (isIsolir ? colorScheme.primary : colorScheme.error),
                          side: BorderSide(
                            color: secondaryActionBorderColor ??
                                (isIsolir ? colorScheme.outline : colorScheme.error),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),

                    const Spacer(),

                    // Tombol Edit M3
                    if (onEdit != null)
                      IconButton(
                        onPressed: onEdit,
                        icon: Icon(Icons.edit_outlined, color: colorScheme.onSurfaceVariant, size: 20),
                        splashRadius: 20,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
}
