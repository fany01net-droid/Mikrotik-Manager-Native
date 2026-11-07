import 'dart:math';
import 'package:intl/intl.dart';
import '../models/mikrotik_models.dart';

enum HotspotStatus {
  unused,
  active,
  expiringSoon,
  expired,
  disabled,
}

class HotspotUserExpiryInfo {
  final bool isUsed;
  final bool hasTimestamp;
  final DateTime? timestampDate;
  final DateTime? expiryDate;
  final int? remainingMs;
  final int? daysRemaining;
  final HotspotStatus status;
  final String badgeText;
  final String sisaText;
  final String formattedDate;

  const HotspotUserExpiryInfo({
    required this.isUsed,
    required this.hasTimestamp,
    this.timestampDate,
    this.expiryDate,
    this.remainingMs,
    this.daysRemaining,
    required this.status,
    required this.badgeText,
    required this.sisaText,
    required this.formattedDate,
  });
}

class HotspotUtils {
  static int? parseHotspotDuration(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final str = text.trim();

    // 1. Clock format: "D:HH:mm:ss" or "HH:mm:ss"
    final clockMatch = RegExp(r'(?:(\d+)\s*d(?:ays?)?[\s,:]*)?(\d{1,2}):(\d{2})(?::(\d{2}))?', caseSensitive: false).firstMatch(str);
    if (clockMatch != null) {
      final days = int.tryParse(clockMatch.group(1) ?? '0') ?? 0;
      final hours = int.tryParse(clockMatch.group(2) ?? '0') ?? 0;
      final minutes = int.tryParse(clockMatch.group(3) ?? '0') ?? 0;
      final seconds = int.tryParse(clockMatch.group(4) ?? '0') ?? 0;
      final totalMs = (((days * 24 + hours) * 60 + minutes) * 60 + seconds) * 1000;
      if (totalMs > 0) return totalMs;
    }

    // 2. Unit regex matches: "hari", "jam", "bulan", "minggu", "menit", "d", "h", "m", "s"
    final dayMatch = RegExp(r'(\d+)\s*(?:hari|hr|d|days?)\b', caseSensitive: false).firstMatch(str);
    final hourMatch = RegExp(r'(\d+)\s*(?:jam|jm|h|hours?)\b', caseSensitive: false).firstMatch(str);
    final minMatch = RegExp(r'(\d+)\s*(?:menit|mnt|m|mins?)\b', caseSensitive: false).firstMatch(str);
    final secMatch = RegExp(r'(\d+)\s*(?:detik|dtk|s|secs?)\b', caseSensitive: false).firstMatch(str);
    final weekMatch = RegExp(r'(\d+)\s*(?:minggu|mgg|w|weeks?)\b', caseSensitive: false).firstMatch(str);
    final monthMatch = RegExp(r'(\d+)\s*(?:bulan|bln|months?)\b', caseSensitive: false).firstMatch(str);

    int totalMs = 0;
    bool matched = false;

    if (monthMatch != null) {
      totalMs += (int.tryParse(monthMatch.group(1)!) ?? 0) * 30 * 24 * 3600 * 1000;
      matched = true;
    }
    if (weekMatch != null) {
      totalMs += (int.tryParse(weekMatch.group(1)!) ?? 0) * 7 * 24 * 3600 * 1000;
      matched = true;
    }
    if (dayMatch != null) {
      totalMs += (int.tryParse(dayMatch.group(1)!) ?? 0) * 24 * 3600 * 1000;
      matched = true;
    }
    if (hourMatch != null) {
      totalMs += (int.tryParse(hourMatch.group(1)!) ?? 0) * 3600 * 1000;
      matched = true;
    }
    if (minMatch != null) {
      totalMs += (int.tryParse(minMatch.group(1)!) ?? 0) * 60 * 1000;
      matched = true;
    }
    if (secMatch != null) {
      totalMs += (int.tryParse(secMatch.group(1)!) ?? 0) * 1000;
      matched = true;
    }

    if (matched && totalMs > 0) return totalMs;
    return null;
  }

  static DateTime? extractTimestampFromComment(String? comment) {
    if (comment == null || comment.trim().isEmpty) return null;
    final match = RegExp(
      r'(\d{4})[-/.](1[0-2]|0?[1-9])[-/.]([12]\d|3[01]|0?[1-9])(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?',
    ).firstMatch(comment);
    if (match != null) {
      final y = int.parse(match.group(1)!);
      final m = int.parse(match.group(2)!);
      final d = int.parse(match.group(3)!);
      final h = int.tryParse(match.group(4) ?? '0') ?? 0;
      final min = int.tryParse(match.group(5) ?? '0') ?? 0;
      final s = int.tryParse(match.group(6) ?? '0') ?? 0;
      try {
        return DateTime(y, m, d, h, min, s);
      } catch (_) {}
    }
    return null;
  }

  static HotspotUserExpiryInfo calculateHotspotUserExpiry(
    HotspotUser user,
    List<HotspotProfile> profiles,
  ) {
    if (user.disabled) {
      return const HotspotUserExpiryInfo(
        isUsed: false,
        hasTimestamp: false,
        status: HotspotStatus.disabled,
        badgeText: 'Nonaktif',
        sisaText: 'Akun dinonaktifkan',
        formattedDate: '-',
      );
    }

    final timestamp = extractTimestampFromComment(user.comment);
    final hasTimestamp = timestamp != null;
    final uptimeMs = parseHotspotDuration(user.uptime) ?? 0;
    final isUsed = hasTimestamp || uptimeMs > 0;

    if (!isUsed) {
      return const HotspotUserExpiryInfo(
        isUsed: false,
        hasTimestamp: false,
        status: HotspotStatus.unused,
        badgeText: 'Belum Dipakai',
        sisaText: 'Menunggu login perdana',
        formattedDate: '-',
      );
    }

    // Determine validity duration from user's limit-uptime or profile's session-timeout / comment
    final profile = profiles.firstWhere(
      (p) => p.name.toLowerCase() == user.profile.toLowerCase(),
      orElse: () => HotspotProfile(id: '', name: user.profile),
    );

    int? validityMs;
    if (user.limitUptime.isNotEmpty) {
      validityMs = parseHotspotDuration(user.limitUptime);
    }
    validityMs ??= parseHotspotDuration(profile.sessionTimeout);
    validityMs ??= parseHotspotDuration(profile.comment);
    validityMs ??= parseHotspotDuration(profile.name);

    if (validityMs == null || validityMs <= 0) {
      final uptimeStr = user.uptime.isNotEmpty ? user.uptime : '0s';
      return HotspotUserExpiryInfo(
        isUsed: true,
        hasTimestamp: hasTimestamp,
        timestampDate: timestamp,
        status: HotspotStatus.active,
        badgeText: 'Aktif (Tanpa Batas)',
        sisaText: 'Uptime: $uptimeStr',
        formattedDate: timestamp != null ? DateFormat('d MMM yyyy HH:mm').format(timestamp) : '-',
      );
    }

    DateTime expiryDate;
    if (hasTimestamp) {
      expiryDate = timestamp.add(Duration(milliseconds: validityMs));
    } else {
      // Fallback: estimate from uptime vs limit
      final remaining = max(0, validityMs - uptimeMs);
      expiryDate = DateTime.now().add(Duration(milliseconds: remaining));
    }

    final now = DateTime.now();
    final remainingMs = expiryDate.difference(now).inMilliseconds;
    final daysRemaining = (remainingMs / (1000 * 3600 * 24)).ceil();

    HotspotStatus status;
    String badgeText;
    String sisaText;

    if (remainingMs <= 0) {
      status = HotspotStatus.expired;
      badgeText = 'Kadaluarsa';
      final elapsed = -remainingMs;
      final elapsedHours = (elapsed / (1000 * 3600)).floor();
      if (elapsedHours >= 24) {
        sisaText = 'Habis ${(elapsedHours / 24).floor()} hari lalu';
      } else {
        sisaText = 'Habis $elapsedHours jam lalu';
      }
    } else if (remainingMs <= 24 * 3600 * 1000) {
      status = HotspotStatus.expiringSoon;
      badgeText = 'Segera Habis';
      final remHours = (remainingMs / (1000 * 3600)).floor();
      final remMins = ((remainingMs % (1000 * 3600)) / (1000 * 60)).floor();
      sisaText = 'Sisa ${remHours}j ${remMins}m';
    } else {
      status = HotspotStatus.active;
      badgeText = 'Aktif';
      final remDays = (remainingMs / (1000 * 3600 * 24)).floor();
      sisaText = 'Sisa $remDays hari';
    }

    final formatted = DateFormat('d MMM yyyy HH:mm').format(expiryDate);

    return HotspotUserExpiryInfo(
      isUsed: true,
      hasTimestamp: hasTimestamp,
      timestampDate: timestamp,
      expiryDate: expiryDate,
      remainingMs: remainingMs,
      daysRemaining: daysRemaining,
      status: status,
      badgeText: badgeText,
      sisaText: sisaText,
      formattedDate: formatted,
    );
  }

  static List<Map<String, String>> generateBatchVouchers({
    required int count,
    required String prefix,
    int codeLength = 6,
    required String profile,
    String? limitUptime,
    String? comment,
    bool sameUserPass = true,
  }) {
    final list = <Map<String, String>>[];
    final rand = Random();
    const chars = '23456789abcdefghjkmnpqrstuvwxyz'; // readable characters without 0, 1, l, o

    for (int i = 0; i < count; i++) {
      String code = '';
      for (int c = 0; c < codeLength; c++) {
        code += chars[rand.nextInt(chars.length)];
      }
      final username = '$prefix$code';
      final password = sameUserPass ? username : (1000 + rand.nextInt(9000)).toString();

      list.add({
        'name': username,
        'password': password,
        'profile': profile,
        if (limitUptime != null && limitUptime.isNotEmpty) 'limit-uptime': limitUptime,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      });
    }

    return list;
  }
}
