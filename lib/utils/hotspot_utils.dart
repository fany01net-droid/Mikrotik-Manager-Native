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

  static const Map<String, int> _monthMap = {
    'jan': 1, 'januari': 1, 'january': 1,
    'feb': 2, 'februari': 2, 'february': 2,
    'mar': 3, 'maret': 3, 'march': 3,
    'apr': 4, 'april': 4,
    'mei': 5, 'may': 5,
    'jun': 6, 'juni': 6, 'june': 6,
    'jul': 7, 'juli': 7, 'july': 7,
    'ags': 8, 'agu': 8, 'agustus': 8, 'aug': 8, 'august': 8,
    'sep': 9, 'september': 9,
    'okt': 10, 'oktober': 10, 'oct': 10, 'october': 10,
    'nov': 11, 'november': 11,
    'des': 12, 'desember': 12, 'dec': 12, 'december': 12,
  };

  static DateTime? extractTimestampFromComment(String? comment) {
    if (comment == null || comment.trim().isEmpty) return null;
    final trimmed = comment.trim();

    // 1. ISO format: YYYY-MM-DD or YYYY/MM/DD or YYYY.MM.DD
    final isoMatch = RegExp(
      r'(\d{4})[-/.](1[0-2]|0?[1-9])[-/.]([12]\d|3[01]|0?[1-9])(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?',
    ).firstMatch(trimmed);
    if (isoMatch != null) {
      final y = int.parse(isoMatch.group(1)!);
      final m = int.parse(isoMatch.group(2)!);
      final d = int.parse(isoMatch.group(3)!);
      final h = int.tryParse(isoMatch.group(4) ?? '0') ?? 0;
      final min = int.tryParse(isoMatch.group(5) ?? '0') ?? 0;
      final s = int.tryParse(isoMatch.group(6) ?? '0') ?? 0;
      try {
        final dt = DateTime(y, m, d, h, min, s);
        if (dt.year == y && dt.month == m && dt.day == d) return dt;
      } catch (_) {}
    }

    // 2. Mikhmon format: Mon/DD/YYYY or Mon-DD-YYYY e.g. nov/29/2026 17:47:51
    final monDayYearMatch = RegExp(
      r'([a-zA-Z]{3,9})[-/.]([12]\d|3[01]|0?[1-9])[-/.](\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?',
    ).firstMatch(trimmed);
    if (monDayYearMatch != null) {
      final mName = monDayYearMatch.group(1)!.toLowerCase();
      if (_monthMap.containsKey(mName)) {
        final m = _monthMap[mName]!;
        final d = int.parse(monDayYearMatch.group(2)!);
        final y = int.parse(monDayYearMatch.group(3)!);
        final h = int.tryParse(monDayYearMatch.group(4) ?? '0') ?? 0;
        final min = int.tryParse(monDayYearMatch.group(5) ?? '0') ?? 0;
        final s = int.tryParse(monDayYearMatch.group(6) ?? '0') ?? 0;
        try {
          final dt = DateTime(y, m, d, h, min, s);
          if (dt.year == y && dt.month == m && dt.day == d) return dt;
        } catch (_) {}
      }
    }

    // 3. DD-Mon-YYYY or DD Mon YYYY e.g. 29-nov-2026 17:47:51 or 29 Nov 2026
    final dayMonYearMatch = RegExp(
      r'([12]\d|3[01]|0?[1-9])[-/.\s]+([a-zA-Z]{3,9})[-/.\s]+(\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?',
    ).firstMatch(trimmed);
    if (dayMonYearMatch != null) {
      final mName = dayMonYearMatch.group(2)!.toLowerCase();
      if (_monthMap.containsKey(mName)) {
        final d = int.parse(dayMonYearMatch.group(1)!);
        final m = _monthMap[mName]!;
        final y = int.parse(dayMonYearMatch.group(3)!);
        final h = int.tryParse(dayMonYearMatch.group(4) ?? '0') ?? 0;
        final min = int.tryParse(dayMonYearMatch.group(5) ?? '0') ?? 0;
        final s = int.tryParse(dayMonYearMatch.group(6) ?? '0') ?? 0;
        try {
          final dt = DateTime(y, m, d, h, min, s);
          if (dt.year == y && dt.month == m && dt.day == d) return dt;
        } catch (_) {}
      }
    }

    // 4. DD-MM-YYYY or DD/MM/YYYY e.g. 29/11/2026 17:47:51
    final dmyMatch = RegExp(
      r'([12]\d|3[01]|0?[1-9])[-/.](1[0-2]|0?[1-9])[-/.](\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?',
    ).firstMatch(trimmed);
    if (dmyMatch != null) {
      final d = int.parse(dmyMatch.group(1)!);
      final m = int.parse(dmyMatch.group(2)!);
      final y = int.parse(dmyMatch.group(3)!);
      final h = int.tryParse(dmyMatch.group(4) ?? '0') ?? 0;
      final min = int.tryParse(dmyMatch.group(5) ?? '0') ?? 0;
      final s = int.tryParse(dmyMatch.group(6) ?? '0') ?? 0;
      try {
        final dt = DateTime(y, m, d, h, min, s);
        if (dt.year == y && dt.month == m && dt.day == d) return dt;
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

    DateTime expiryDate;
    if (hasTimestamp) {
      // Tanggal di komentar (dari Mikhmon / skrip MikroTik) adalah waktu jatuh tempo (expiry)
      expiryDate = timestamp;
    } else if (validityMs != null && validityMs > 0) {
      // Fallback tanpa timestamp: hitung sisa dari limit uptime vs uptime saat ini
      final remaining = max(0, validityMs - uptimeMs);
      expiryDate = DateTime.now().add(Duration(milliseconds: remaining));
    } else {
      final uptimeStr = user.uptime.isNotEmpty ? user.uptime : '0s';
      return HotspotUserExpiryInfo(
        isUsed: true,
        hasTimestamp: hasTimestamp,
        timestampDate: timestamp,
        status: HotspotStatus.active,
        badgeText: 'Aktif (Tanpa Batas)',
        sisaText: 'Uptime: $uptimeStr',
        formattedDate: '-',
      );
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
