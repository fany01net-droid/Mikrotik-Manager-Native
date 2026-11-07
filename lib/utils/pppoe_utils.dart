
enum ExpiryStatus {
  active,
  expiringSoon,
  expired,
  noExpiry,
}

class ParsedExpiry {
  final DateTime? expiryDate;
  final int? daysRemaining;
  final ExpiryStatus status;
  final String customerName;
  final String formattedExpiry;

  const ParsedExpiry({
    this.expiryDate,
    this.daysRemaining,
    required this.status,
    required this.customerName,
    required this.formattedExpiry,
  });
}

class PppoeUtils {
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

  static MapEntry<DateTime?, String> _tryParseDate(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const MapEntry(null, '');

    // 1. ISO: YYYY-MM-DD or YYYY/MM/DD or YYYY.MM.DD
    final isoMatch = RegExp(
      r'\b(\d{4})[-/.](1[0-2]|0?[1-9])[-/.]([12]\d|3[01]|0?[1-9])(?:[T\s]\d{1,2}:\d{2}(?::\d{2})?(?:Z|[+-]\d{2}:?\d{2})?)?\b',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (isoMatch != null) {
      final y = int.parse(isoMatch.group(1)!);
      final m = int.parse(isoMatch.group(2)!);
      final d = int.parse(isoMatch.group(3)!);
      try {
        final cand = DateTime(y, m, d);
        if (cand.year == y && cand.month == m && cand.day == d) {
          return MapEntry(cand, isoMatch.group(0)!);
        }
      } catch (_) {}
    }

    // 2. DD-MM-YYYY
    final dmyMatch = RegExp(
      r'\b([12]\d|3[01]|0?[1-9])[-/.](1[0-2]|0?[1-9])[-/.](\d{4})(?:[T\s]\d{1,2}:\d{2}(?::\d{2})?(?:Z|[+-]\d{2}:?\d{2})?)?\b',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (dmyMatch != null) {
      final d = int.parse(dmyMatch.group(1)!);
      final m = int.parse(dmyMatch.group(2)!);
      final y = int.parse(dmyMatch.group(3)!);
      try {
        final cand = DateTime(y, m, d);
        if (cand.year == y && cand.month == m && cand.day == d) {
          return MapEntry(cand, dmyMatch.group(0)!);
        }
      } catch (_) {}
    }

    // 3. DD Mon YYYY
    final namedMatch = RegExp(
      r'\b([12]\d|3[01]|0?[1-9])[-/\s,]+([a-zA-Z]{3,9})[-/\s,]+(\d{4})(?:[T\s]\d{1,2}:\d{2}(?::\d{2})?(?:Z|[+-]\d{2}:?\d{2})?)?\b',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (namedMatch != null) {
      final mName = namedMatch.group(2)!.toLowerCase();
      if (_monthMap.containsKey(mName)) {
        final d = int.parse(namedMatch.group(1)!);
        final m = _monthMap[mName]!;
        final y = int.parse(namedMatch.group(3)!);
        try {
          final cand = DateTime(y, m, d);
          if (cand.year == y && cand.month == m && cand.day == d) {
            return MapEntry(cand, namedMatch.group(0)!);
          }
        } catch (_) {}
      }
    }

    // 4. Mon DD, YYYY
    final namedRevMatch = RegExp(
      r'\b([a-zA-Z]{3,9})[-/\s,]+([12]\d|3[01]|0?[1-9])[-/\s,]+(\d{4})(?:[T\s]\d{1,2}:\d{2}(?::\d{2})?(?:Z|[+-]\d{2}:?\d{2})?)?\b',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (namedRevMatch != null) {
      final mName = namedRevMatch.group(1)!.toLowerCase();
      if (_monthMap.containsKey(mName)) {
        final d = int.parse(namedRevMatch.group(2)!);
        final m = _monthMap[mName]!;
        final y = int.parse(namedRevMatch.group(3)!);
        try {
          final cand = DateTime(y, m, d);
          if (cand.year == y && cand.month == m && cand.day == d) {
            return MapEntry(cand, namedRevMatch.group(0)!);
          }
        } catch (_) {}
      }
    }

    // 5. 2-digit year DD-MM-YY
    final dmy2Match = RegExp(
      r'\b([12]\d|3[01]|0?[1-9])[-/.](1[0-2]|0?[1-9])[-/.](\d{2})(?:[T\s]\d{1,2}:\d{2}(?::\d{2})?(?:Z|[+-]\d{2}:?\d{2})?)?\b',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (dmy2Match != null) {
      final d = int.parse(dmy2Match.group(1)!);
      final m = int.parse(dmy2Match.group(2)!);
      final yr2 = int.parse(dmy2Match.group(3)!);
      final y = yr2 <= 70 ? 2000 + yr2 : 1900 + yr2;
      try {
        final cand = DateTime(y, m, d);
        if (cand.year == y && cand.month == m && cand.day == d) {
          return MapEntry(cand, dmy2Match.group(0)!);
        }
      } catch (_) {}
    }

    return const MapEntry(null, '');
  }

  static ParsedExpiry parseExpiryFromComment(String? comment) {
    if (comment == null || comment.trim().isEmpty) {
      return const ParsedExpiry(
        expiryDate: null,
        daysRemaining: null,
        status: ExpiryStatus.noExpiry,
        customerName: '',
        formattedExpiry: 'Tidak diatur',
      );
    }

    final trimmed = comment.trim();
    DateTime? foundDate;
    String rawDateMatch = '';

    // 1. Check explicit exp: or expired: prefix
    final explicitMatch = RegExp(
      r'(?:^|[|(\[\s])(?:exp(?:ired)?[:\s]+)([^|)\]]+)',
      caseSensitive: false,
    ).firstMatch(trimmed);

    if (explicitMatch != null) {
      final candidate = _tryParseDate(explicitMatch.group(1)!);
      if (candidate.key != null) {
        foundDate = candidate.key;
        rawDateMatch = candidate.value;
      }
    }

    // 2. Parse whole string if not found
    if (foundDate == null) {
      final candidate = _tryParseDate(trimmed);
      if (candidate.key != null) {
        foundDate = candidate.key;
        rawDateMatch = candidate.value;
      }
    }

    String customerNote = trimmed;
    if (trimmed.contains('|')) {
      final parts = trimmed.split('|').map((p) => p.trim()).toList();
      final noteParts = parts.where((p) {
        if (p.isEmpty) return false;
        if (RegExp(r'^(?:exp(?:ired)?:?)$', caseSensitive: false).hasMatch(p)) return false;
        if (rawDateMatch.isNotEmpty && p.replaceAll(RegExp(r'^(?:exp(?:ired)?:?\s*)', caseSensitive: false), '').trim() == rawDateMatch) {
          return false;
        }
        return true;
      }).toList();
      customerNote = noteParts.join(' | ').trim();
    } else if (rawDateMatch.isNotEmpty) {
      final escaped = RegExp.escape(rawDateMatch);
      customerNote = trimmed
          .replaceAll(RegExp('(?:exp(?:ired)?:?\\s*)?$escaped', caseSensitive: false), '')
          .replaceAll(RegExp(r'\(\s*\)'), '')
          .replaceAll(RegExp(r'\[\s*\]'), '')
          .replaceAll(RegExp(r'^[\s-:|,]+|[\s-:|,]+$'), '')
          .trim();
    } else {
      customerNote = trimmed
          .replaceAll(RegExp(r'^exp(?:ired)?:\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'\(\s*\)'), '')
          .replaceAll(RegExp(r'\[\s*\]'), '')
          .replaceAll(RegExp(r'^[\s-:|,]+|[\s-:|,]+$'), '')
          .trim();
    }

    customerNote = customerNote
        .replaceAll(RegExp(r'^exp(?:ired)?:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^[\s-:|,]+|[\s-:|,]+$'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    if (foundDate == null) {
      return ParsedExpiry(
        expiryDate: null,
        daysRemaining: null,
        status: ExpiryStatus.noExpiry,
        customerName: customerNote,
        formattedExpiry: 'Tidak diatur',
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expDay = DateTime(foundDate.year, foundDate.month, foundDate.day);
    final diffDays = expDay.difference(today).inDays;

    ExpiryStatus status = ExpiryStatus.active;
    if (diffDays < 0) {
      status = ExpiryStatus.expired;
    } else if (diffDays <= 7) {
      status = ExpiryStatus.expiringSoon;
    }

    const monthsId = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final formatted = '${expDay.day} ${monthsId[expDay.month]} ${expDay.year}';

    return ParsedExpiry(
      expiryDate: expDay,
      daysRemaining: diffDays,
      status: status,
      customerName: customerNote,
      formattedExpiry: formatted,
    );
  }

  static String extendExpiryDate(String? currentComment, [int daysToAdd = 30]) {
    final parsed = parseExpiryFromComment(currentComment);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime baseDate = today;
    if (parsed.expiryDate != null && parsed.expiryDate!.isAfter(today)) {
      baseDate = parsed.expiryDate!;
    }

    final newDate = baseDate.add(Duration(days: daysToAdd));
    final yyyy = newDate.year.toString().padLeft(4, '0');
    final mm = newDate.month.toString().padLeft(2, '0');
    final dd = newDate.day.toString().padLeft(2, '0');
    final dateStr = '$yyyy-$mm-$dd 23:59:59';

    final note = parsed.customerName.trim();
    if (note.isNotEmpty) {
      return '$dateStr | $note';
    }
    return dateStr;
  }

  static String buildExpiryComment(String dateIso, [String? customerNote]) {
    String note = (customerNote ?? '').trim();
    if (note.isNotEmpty) {
      final parsed = parseExpiryFromComment(note);
      if (parsed.customerName.isNotEmpty) {
        note = parsed.customerName;
      } else if (parsed.expiryDate != null) {
        note = '';
      } else {
        note = note.replaceAll(RegExp(r'^exp(?:ired)?:\s*\|?\s*', caseSensitive: false), '').trim();
      }
    }
    if (dateIso.trim().isEmpty) return note;

    final cleanDate = dateIso.trim().split(' ').first;
    final fullDateTime = '$cleanDate 23:59:59';
    if (note.isNotEmpty) {
      return '$fullDateTime | $note';
    }
    return fullDateTime;
  }
}
