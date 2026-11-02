export interface ParsedExpiry {
  expiryDate: Date | null;
  daysRemaining: number | null;
  status: 'active' | 'expiring-soon' | 'expired' | 'no-expiry';
  customerName: string;
  formattedExpiry: string;
}

const MONTH_MAP: Record<string, number> = {
  jan: 0, januari: 0, january: 0,
  feb: 1, februari: 1, february: 1,
  mar: 2, maret: 2, march: 2,
  apr: 3, april: 3,
  mei: 4, may: 4,
  jun: 5, juni: 5, june: 5,
  jul: 6, juli: 6, july: 6,
  ags: 7, agu: 7, agustus: 7, aug: 7, august: 7,
  sep: 8, september: 8,
  okt: 9, oktober: 9, oct: 9, october: 9,
  nov: 10, november: 10,
  des: 11, desember: 11, dec: 11, december: 11,
};

/**
 * Parse expiry date and customer note from a PPPoE secret comment.
 * Common formats:
 * - "exp: 2026-11-19 | Bpk Budi"
 * - "expired: 2026-11-19"
 * - "2026-11-19"
 * - "exp: 19-11-2026 | Bpk Budi"
 * - "exp: 19.11.2026 | Bpk Budi"
 * - "exp: 19 Oktober 2026 | Bpk Budi"
 * - "exp: 2026-11-19 14:30:00 | Bpk Budi"
 */
function tryParseDate(text: string): { date: Date | null; raw: string } {
  const trimmed = text.trim();
  if (!trimmed) return { date: null, raw: '' };

  // 1. Try ISO date: YYYY-MM-DD or YYYY/MM/DD or YYYY.MM.DD with optional time
  const isoMatch = trimmed.match(
    /\b(\d{4})[-/.](1[0-2]|0?[1-9])[-/.]([12]\d|3[01]|0?[1-9])(?:[T\s]\d{1,2}:\d{2}(?::\d{2})?(?:Z|[+-]\d{2}:?\d{2})?)?\b/i
  );
  if (isoMatch) {
    const year = parseInt(isoMatch[1], 10);
    const month = parseInt(isoMatch[2], 10) - 1;
    const day = parseInt(isoMatch[3], 10);
    const candidate = new Date(year, month, day);
    if (
      candidate.getFullYear() === year &&
      candidate.getMonth() === month &&
      candidate.getDate() === day
    ) {
      return { date: candidate, raw: isoMatch[0] };
    }
  }

  // 2. Try DD-MM-YYYY, DD/MM/YYYY, or DD.MM.YYYY (4-digit year) with optional time
  const dmyMatch = trimmed.match(
    /\b([12]\d|3[01]|0?[1-9])[-/.](1[0-2]|0?[1-9])[-/.](\d{4})(?:[T\s]\d{1,2}:\d{2}(?::\d{2})?(?:Z|[+-]\d{2}:?\d{2})?)?\b/i
  );
  if (dmyMatch) {
    const day = parseInt(dmyMatch[1], 10);
    const month = parseInt(dmyMatch[2], 10) - 1;
    const year = parseInt(dmyMatch[3], 10);
    const candidate = new Date(year, month, day);
    if (
      candidate.getFullYear() === year &&
      candidate.getMonth() === month &&
      candidate.getDate() === day
    ) {
      return { date: candidate, raw: dmyMatch[0] };
    }
  }

  // 3. Try Named month: DD Mon YYYY or DD-Mon-YYYY (Indonesian and English)
  const namedMatch = trimmed.match(
    /\b([12]\d|3[01]|0?[1-9])[-/\s,]+([a-zA-Z]{3,9})[-/\s,]+(\d{4})(?:[T\s]\d{1,2}:\d{2}(?::\d{2})?(?:Z|[+-]\d{2}:?\d{2})?)?\b/i
  );
  if (namedMatch && MONTH_MAP[namedMatch[2].toLowerCase()] !== undefined) {
    const day = parseInt(namedMatch[1], 10);
    const month = MONTH_MAP[namedMatch[2].toLowerCase()];
    const year = parseInt(namedMatch[3], 10);
    const candidate = new Date(year, month, day);
    if (
      candidate.getFullYear() === year &&
      candidate.getMonth() === month &&
      candidate.getDate() === day
    ) {
      return { date: candidate, raw: namedMatch[0] };
    }
  }

  // 4. Try Month-first named: Mon DD, YYYY
  const namedRevMatch = trimmed.match(
    /\b([a-zA-Z]{3,9})[-/\s,]+([12]\d|3[01]|0?[1-9])[-/\s,]+(\d{4})(?:[T\s]\d{1,2}:\d{2}(?::\d{2})?(?:Z|[+-]\d{2}:?\d{2})?)?\b/i
  );
  if (namedRevMatch && MONTH_MAP[namedRevMatch[1].toLowerCase()] !== undefined) {
    const day = parseInt(namedRevMatch[2], 10);
    const month = MONTH_MAP[namedRevMatch[1].toLowerCase()];
    const year = parseInt(namedRevMatch[3], 10);
    const candidate = new Date(year, month, day);
    if (
      candidate.getFullYear() === year &&
      candidate.getMonth() === month &&
      candidate.getDate() === day
    ) {
      return { date: candidate, raw: namedRevMatch[0] };
    }
  }

  // 5. Try 2-digit year: DD-MM-YY, DD/MM/YY, DD.MM.YY with optional time
  const dmy2Match = trimmed.match(
    /\b([12]\d|3[01]|0?[1-9])[-/.](1[0-2]|0?[1-9])[-/.](\d{2})(?:[T\s]\d{1,2}:\d{2}(?::\d{2})?(?:Z|[+-]\d{2}:?\d{2})?)?\b/i
  );
  if (dmy2Match) {
    const day = parseInt(dmy2Match[1], 10);
    const month = parseInt(dmy2Match[2], 10) - 1;
    const yr2 = parseInt(dmy2Match[3], 10);
    const year = yr2 <= 70 ? 2000 + yr2 : 1900 + yr2;
    const candidate = new Date(year, month, day);
    if (
      candidate.getFullYear() === year &&
      candidate.getMonth() === month &&
      candidate.getDate() === day
    ) {
      return { date: candidate, raw: dmy2Match[0] };
    }
  }

  return { date: null, raw: '' };
}

/**
 * Parse expiry date and customer note from a PPPoE secret comment.
 * Common formats:
 * - "exp: 2026-11-19 | Bpk Budi"
 * - "expired: 2026-11-19"
 * - "2026-11-19"
 * - "exp: 19-11-2026 | Bpk Budi"
 * - "exp: 19.11.2026 | Bpk Budi"
 * - "exp: 19 Oktober 2026 | Bpk Budi"
 * - "exp: 2026-11-19 14:30:00 | Bpk Budi"
 * - "exp: 19/11/26 | Bpk Budi"
 */
export function parseExpiryFromComment(comment?: string): ParsedExpiry {
  if (!comment || !comment.trim()) {
    return {
      expiryDate: null,
      daysRemaining: null,
      status: 'no-expiry',
      customerName: '',
      formattedExpiry: 'Tidak diatur',
    };
  }

  const trimmed = comment.trim();
  let foundDate: Date | null = null;
  let rawDateMatch = '';

  // 1. Prioritize explicit expiry token: exp: or expired:
  const explicitMatch = trimmed.match(
    /(?:^|[|\(\[\s])(?:exp(?:ired)?[:\s]+)([^|\)\]]+)/i
  );
  if (explicitMatch) {
    const candidate = tryParseDate(explicitMatch[1]);
    if (candidate.date) {
      foundDate = candidate.date;
      rawDateMatch = candidate.raw;
    }
  }

  // 2. If no explicit token or explicit token didn't contain a valid date, parse whole string
  if (!foundDate) {
    const candidate = tryParseDate(trimmed);
    if (candidate.date) {
      foundDate = candidate.date;
      rawDateMatch = candidate.raw;
    }
  }

  let customerNote = trimmed;

  // Helper to determine if a string segment is purely prefix or date specification
  const isPrefixOrDate = (p: string) => {
    const s = p.trim();
    if (!s) return true;
    if (/^(?:exp(?:ired)?:?)$/i.test(s)) return true;
    if (rawDateMatch && s.replace(/^(?:exp(?:ired)?:?\s*)/i, '').trim() === rawDateMatch) return true;
    const candidate = tryParseDate(s.replace(/^(?:exp(?:ired)?:?\s*)/i, ''));
    if (candidate.date && candidate.raw === s.replace(/^(?:exp(?:ired)?:?\s*)/i, '').trim()) return true;
    // Check syntactic date patterns even if invalid calendar day (e.g. 2026-02-31)
    if (/^(?:exp(?:ired)?:?\s*)?\d{4}[-/.]\d{1,2}[-/.]\d{1,2}(?:[T\s]\d{1,2}:\d{2}(?::\d{2})?)?$/i.test(s)) return true;
    if (/^(?:exp(?:ired)?:?\s*)?\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}(?:[T\s]\d{1,2}:\d{2}(?::\d{2})?)?$/i.test(s)) return true;
    if (/^(?:exp(?:ired)?:?\s*)?\d{1,2}[-/\s,]+[a-zA-Z]{3,9}[-/\s,]+\d{4}$/i.test(s)) return true;
    if (/^(?:exp(?:ired)?:?\s*)?[a-zA-Z]{3,9}[-/\s,]+\d{1,2}[-/\s,]+\d{4}$/i.test(s)) return true;
    return false;
  };

  // Extract customer name / note if present
  if (trimmed.includes('|')) {
    const parts = trimmed.split('|').map((p) => p.trim());
    const noteParts = parts.filter((p) => !isPrefixOrDate(p));
    customerNote = noteParts.join(' | ').trim();
  } else if (rawDateMatch) {
    // Escape regex special chars in rawDateMatch
    const escapedRaw = rawDateMatch.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&');
    customerNote = trimmed
      .replace(new RegExp('(?:exp(?:ired)?:?\\s*)?' + escapedRaw, 'i'), '')
      .replace(/\(\s*\)/g, '')
      .replace(/\[\s*\]/g, '')
      .replace(/^[\s-:|,]+|[\s-:|,]+$/g, '')
      .trim();
  } else {
    // Strip prefixes like "exp: YYYY-MM-DD" and empty wrapping brackets/parentheses
    customerNote = trimmed
      .replace(/^exp(?:ired)?:\s*/i, '')
      .replace(/\(\s*\)/g, '')
      .replace(/\[\s*\]/g, '')
      .replace(/^[\s-:|,]+|[\s-:|,]+$/g, '')
      .trim();
  }

  // Clean trailing or leading separators and collapse extra whitespace in customerNote
  customerNote = customerNote
    .replace(/^exp(?:ired)?:\s*/i, '')
    .replace(/^[\s-:|,]+|[\s-:|,]+$/g, '')
    .replace(/\s{2,}/g, ' ')
    .trim();

  if (!foundDate || isNaN(foundDate.getTime())) {
    return {
      expiryDate: null,
      daysRemaining: null,
      status: 'no-expiry',
      customerName: customerNote,
      formattedExpiry: 'Tidak diatur',
    };
  }

  // Calculate days remaining (comparing dates at local 00:00:00 midnight)
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const expDay = new Date(foundDate.getFullYear(), foundDate.getMonth(), foundDate.getDate());

  const diffTime = expDay.getTime() - today.getTime();
  const daysRemaining = Math.round(diffTime / (1000 * 60 * 60 * 24)) + 0;

  let status: 'active' | 'expiring-soon' | 'expired' = 'active';
  if (daysRemaining < 0) {
    status = 'expired';
  } else if (daysRemaining <= 7) {
    status = 'expiring-soon';
  }

  const formattedExpiry = expDay.toLocaleDateString('id-ID', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });

  return {
    expiryDate: expDay,
    daysRemaining,
    status,
    customerName: customerNote,
    formattedExpiry,
  };
}

/**
 * Extend or set an expiry date on a PPPoE secret comment.
 * If expired or no date, extends from today.
 * If active (today or future), extends from existing expiry date.
 */
export function extendExpiryDate(currentComment?: string, daysToAdd: number = 30): string {
  const parsed = parseExpiryFromComment(currentComment);
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  let baseDate = today;
  if (parsed.expiryDate) {
    const expDay = new Date(
      parsed.expiryDate.getFullYear(),
      parsed.expiryDate.getMonth(),
      parsed.expiryDate.getDate()
    );
    if (expDay.getTime() >= today.getTime()) {
      baseDate = expDay;
    }
  }

  const newDate = new Date(baseDate);
  newDate.setDate(newDate.getDate() + daysToAdd);

  const yyyy = newDate.getFullYear();
  const mm = String(newDate.getMonth() + 1).padStart(2, '0');
  const dd = String(newDate.getDate()).padStart(2, '0');
  const dateStr = `${yyyy}-${mm}-${dd} 23:59:59`;

  const note = parsed.customerName.trim();
  if (note) {
    return `${dateStr} | ${note}`;
  }
  return dateStr;
}

/**
 * Build comment for a new PPPoE secret or updated expiry date.
 * Format for MikroTik Scheduler compatibility:
 * - "YYYY-MM-DD 23:59:59 | Catatan Pelanggan" or "YYYY-MM-DD 23:59:59"
 */
export function buildExpiryComment(dateIso: string, customerNote?: string): string {
  let note = (customerNote || '').trim();
  if (note) {
    const parsed = parseExpiryFromComment(note);
    if (parsed.customerName) {
      note = parsed.customerName;
    } else if (parsed.expiryDate) {
      note = '';
    } else {
      note = note.replace(/^exp(?:ired)?:\s*\|?\s*/i, '').trim();
    }
  }
  if (!dateIso) return note;

  // Pastikan format tanggal memiliki waktu 23:59:59
  const cleanDate = dateIso.trim().split(' ')[0]; // Ambil YYYY-MM-DD
  const fullDateTime = `${cleanDate} 23:59:59`;

  if (note) {
    return `${fullDateTime} | ${note}`;
  }
  return fullDateTime;
}
