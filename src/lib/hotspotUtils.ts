import { HotspotUser, HotspotProfile } from '../types/mikrotik';

export interface HotspotUserExpiryInfo {
  isUsed: boolean;
  hasTimestamp: boolean;
  timestampDate: Date | null;
  expiryDate: Date | null;
  remainingMs: number | null;
  daysRemaining: number | null;
  status: 'unused' | 'active' | 'expiring-soon' | 'expired' | 'disabled';
  badgeText: string;
  sisaText: string;
  colorClass: string;
  formattedDate: string;
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
 * Parses duration strings into milliseconds.
 * Supports:
 * - MikroTik duration formats: "30d", "7d", "1d", "12h", "3h", "30m", "45s", "1d12h"
 * - Clock notation: "01:00:00" (1h), "00:30:00" (30m), "1d 02:00:00"
 * - Indonesian text: "3Jam", "3 Jam", "1Hari", "7Hari", "30Hari", "1Bulan", "1Minggu", "30Menit"
 * - Profile composite names: "Voucher-3Jam", "Voucher-1Hari", "VIP-30Hari", "VC-7d-5M"
 */
export function parseHotspotDuration(text: string | null | undefined): number | null {
  if (!text || typeof text !== 'string') return null;
  const str = text.trim();
  if (!str) return null;

  // 1. Clock format: "HH:mm:ss" or "D:HH:mm:ss" or "D d HH:mm:ss"
  const clockMatch = str.match(/(?:(\d+)\s*d(?:ays?)?[\s,:]*)?(\d{1,2}):(\d{2})(?::(\d{2}))?/i);
  if (clockMatch) {
    const days = parseInt(clockMatch[1] || '0', 10);
    const hours = parseInt(clockMatch[2] || '0', 10);
    const minutes = parseInt(clockMatch[3] || '0', 10);
    const seconds = parseInt(clockMatch[4] || '0', 10);
    const totalMs = (((days * 24 + hours) * 60 + minutes) * 60 + seconds) * 1000;
    if (totalMs > 0) return totalMs;
  }

  // 2. Indonesian unit matches: "hari", "jam", "bulan", "minggu", "menit"
  const indoDayMatch = str.match(/(\d+)\s*(?:hari|hr|d|days?)\b/i);
  const indoHourMatch = str.match(/(\d+)\s*(?:jam|jm|h|hours?)\b/i);
  const indoMinMatch = str.match(/(\d+)\s*(?:menit|mnt|m|mins?)\b/i);
  const indoSecMatch = str.match(/(\d+)\s*(?:detik|dtk|s|secs?)\b/i);
  const indoWeekMatch = str.match(/(\d+)\s*(?:minggu|mgg|w|weeks?)\b/i);
  const indoMonthMatch = str.match(/(\d+)\s*(?:bulan|bln|months?)\b/i);

  let totalMs = 0;
  let matched = false;

  if (indoMonthMatch) {
    totalMs += parseInt(indoMonthMatch[1], 10) * 30 * 24 * 3600 * 1000;
    matched = true;
  }
  if (indoWeekMatch) {
    totalMs += parseInt(indoWeekMatch[1], 10) * 7 * 24 * 3600 * 1000;
    matched = true;
  }
  if (indoDayMatch) {
    totalMs += parseInt(indoDayMatch[1], 10) * 24 * 3600 * 1000;
    matched = true;
  }
  if (indoHourMatch) {
    totalMs += parseInt(indoHourMatch[1], 10) * 3600 * 1000;
    matched = true;
  }
  if (indoMinMatch) {
    totalMs += parseInt(indoMinMatch[1], 10) * 60 * 1000;
    matched = true;
  }
  if (indoSecMatch) {
    totalMs += parseInt(indoSecMatch[1], 10) * 1000;
    matched = true;
  }

  if (matched && totalMs > 0) return totalMs;

  return null;
}

/**
 * Extracts a date & time timestamp from a Hotspot User comment.
 * Handles:
 * - "2026-11-07 11:23:28" (ISO date + time)
 * - "nov/07/2026 11:23:28" (Mikhmon standard)
 * - "11:23:28 nov/07/2026"
 * - "07-nov-2026 11:23:28"
 * - "2026-11-07"
 * - "2026-11-07 11:23:28,vc-kasir1"
 * - "nov/07/2026 11:23:28 rem"
 * - "exp: 2026-11-07 11:23:28"
 */
export function parseHotspotDate(text: string | null | undefined): Date | null {
  if (!text || typeof text !== 'string') return null;
  const trimmed = text.trim();
  if (!trimmed) return null;

  // Helper to extract time parts [HH, mm, ss]
  const parseTime = (timeStr?: string): { h: number; m: number; s: number } => {
    if (!timeStr) return { h: 23, m: 59, s: 59 };
    const parts = timeStr.trim().split(':');
    return {
      h: parseInt(parts[0] || '0', 10),
      m: parseInt(parts[1] || '0', 10),
      s: parseInt(parts[2] || '0', 10),
    };
  };

  // 1. Mikhmon reversed format: "11:23:28 nov/07/2026" or "11:23:28 07/nov/2026"
  const timeFirstMatch = trimmed.match(
    /\b(\d{1,2}:\d{2}(?::\d{2})?)\s+([a-zA-Z]{3,9})[-/.]([12]\d|3[01]|0?[1-9])[-/.](\d{4})\b/i
  );
  if (timeFirstMatch && MONTH_MAP[timeFirstMatch[2].toLowerCase()] !== undefined) {
    const { h, m, s } = parseTime(timeFirstMatch[1]);
    const month = MONTH_MAP[timeFirstMatch[2].toLowerCase()];
    const day = parseInt(timeFirstMatch[3], 10);
    const year = parseInt(timeFirstMatch[4], 10);
    const candidate = new Date(year, month, day, h, m, s);
    if (!isNaN(candidate.getTime())) return candidate;
  }

  // 2. Mikhmon standard: "nov/07/2026 11:23:28" or "nov-07-2026 11:23:28" or "nov 07 2026 11:23:28"
  const mikhmonMatch = trimmed.match(
    /\b([a-zA-Z]{3,9})[-/.\s]+([12]\d|3[01]|0?[1-9])[-/.\s]+(\d{4})(?:[\s,T]+(\d{1,2}:\d{2}(?::\d{2})?))?\b/i
  );
  if (mikhmonMatch && MONTH_MAP[mikhmonMatch[1].toLowerCase()] !== undefined) {
    const month = MONTH_MAP[mikhmonMatch[1].toLowerCase()];
    const day = parseInt(mikhmonMatch[2], 10);
    const year = parseInt(mikhmonMatch[3], 10);
    const { h, m, s } = parseTime(mikhmonMatch[4]);
    const candidate = new Date(year, month, day, h, m, s);
    if (!isNaN(candidate.getTime())) return candidate;
  }

  // 3. Named month day-first: "07-nov-2026 11:23:28" or "07/nov/2026 11:23:28" or "7 November 2026"
  const namedDayFirstMatch = trimmed.match(
    /\b([12]\d|3[01]|0?[1-9])[-/.\s]+([a-zA-Z]{3,9})[-/.\s]+(\d{4})(?:[\s,T]+(\d{1,2}:\d{2}(?::\d{2})?))?\b/i
  );
  if (namedDayFirstMatch && MONTH_MAP[namedDayFirstMatch[2].toLowerCase()] !== undefined) {
    const day = parseInt(namedDayFirstMatch[1], 10);
    const month = MONTH_MAP[namedDayFirstMatch[2].toLowerCase()];
    const year = parseInt(namedDayFirstMatch[3], 10);
    const { h, m, s } = parseTime(namedDayFirstMatch[4]);
    const candidate = new Date(year, month, day, h, m, s);
    if (!isNaN(candidate.getTime())) return candidate;
  }

  // 4. ISO timestamp: "2026-11-07 11:23:28" or "2026-11-07"
  const isoMatch = trimmed.match(
    /\b(\d{4})[-/.](1[0-2]|0?[1-9])[-/.]([12]\d|3[01]|0?[1-9])(?:[\s,T]+(\d{1,2}:\d{2}(?::\d{2})?))?\b/i
  );
  if (isoMatch) {
    const year = parseInt(isoMatch[1], 10);
    const month = parseInt(isoMatch[2], 10) - 1;
    const day = parseInt(isoMatch[3], 10);
    const { h, m, s } = parseTime(isoMatch[4]);
    const candidate = new Date(year, month, day, h, m, s);
    if (!isNaN(candidate.getTime())) return candidate;
  }

  // 5. DD-MM-YYYY: "07-11-2026 11:23:28" or "07/11/2026"
  const dmyMatch = trimmed.match(
    /\b([12]\d|3[01]|0?[1-9])[-/.](1[0-2]|0?[1-9])[-/.](\d{4})(?:[\s,T]+(\d{1,2}:\d{2}(?::\d{2})?))?\b/i
  );
  if (dmyMatch) {
    const day = parseInt(dmyMatch[1], 10);
    const month = parseInt(dmyMatch[2], 10) - 1;
    const year = parseInt(dmyMatch[3], 10);
    const { h, m, s } = parseTime(dmyMatch[4]);
    const candidate = new Date(year, month, day, h, m, s);
    if (!isNaN(candidate.getTime())) return candidate;
  }

  return null;
}

/**
 * Formats a Date object to readable Indonesian string:
 * "07 Nov 2026 11:23:28" or "07 Nov 2026"
 */
export function formatHotspotDateTime(date: Date | null): string {
  if (!date || isNaN(date.getTime())) return '-';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  const d = String(date.getDate()).padStart(2, '0');
  const m = months[date.getMonth()];
  const y = date.getFullYear();
  const hh = String(date.getHours()).padStart(2, '0');
  const mm = String(date.getMinutes()).padStart(2, '0');
  const ss = String(date.getSeconds()).padStart(2, '0');
  return `${d} ${m} ${y} ${hh}:${mm}:${ss}`;
}

/**
 * Calculates remaining validity for a Hotspot User by comparing:
 * 1. Timestamp in user.comment (e.g. "2026-11-07 11:23:28")
 * 2. User profile duration / validity / limit-uptime
 * 3. User uptime and online status
 */
export function calculateHotspotUserExpiry(
  user: HotspotUser,
  profile?: HotspotProfile,
  now: Date = new Date(),
  isOnline: boolean = false
): HotspotUserExpiryInfo {
  const isDisabled = user.disabled === true || user.disabled === 'true';

  // Check if user has a parsed date in comment
  const parsedDate = parseHotspotDate(user.comment);
  const hasTimestamp = parsedDate !== null;

  // Has the user ever been used?
  // Condition: timestamp in comment, or uptime > 0, or bytes > 0, or online right now
  const uptimeMs = parseHotspotDuration(user.uptime) || 0;
  const hasUptime = uptimeMs > 0;
  const hasTraffic =
    Number(user['bytes-in'] || 0) > 0 || Number(user['bytes-out'] || 0) > 0;

  const isUsed = hasTimestamp || hasUptime || hasTraffic || isOnline;

  if (isDisabled) {
    return {
      isUsed,
      hasTimestamp,
      timestampDate: parsedDate,
      expiryDate: parsedDate,
      remainingMs: null,
      daysRemaining: null,
      status: 'disabled',
      badgeText: 'Nonaktif',
      sisaText: 'Nonaktif',
      colorClass: 'text-rose-600',
      formattedDate: formatHotspotDateTime(parsedDate),
    };
  }

  if (!isUsed) {
    return {
      isUsed: false,
      hasTimestamp: false,
      timestampDate: null,
      expiryDate: null,
      remainingMs: null,
      daysRemaining: null,
      status: 'unused',
      badgeText: 'Belum Dipakai',
      sisaText: 'Belum Dipakai',
      colorClass: 'text-sky-600',
      formattedDate: '-',
    };
  }

  // User is used (udh kepake): Calculate expiry and remaining duration
  // Determine profile validity duration
  const profileDuration =
    parseHotspotDuration((profile as any)?.validity) ||
    parseHotspotDuration((profile as any)?.comment) ||
    parseHotspotDuration((profile as any)?.['session-timeout']) ||
    parseHotspotDuration(profile?.name) ||
    parseHotspotDuration(user['limit-uptime']) ||
    null;

  let expiryDate: Date | null = null;
  let remainingMs: number | null = null;

  if (parsedDate) {
    // If timestamp in comment is in the future (> now), it is already the expiration timestamp!
    if (parsedDate.getTime() > now.getTime()) {
      expiryDate = parsedDate;
      remainingMs = parsedDate.getTime() - now.getTime();
    } else {
      // Timestamp in comment is in the past (<= now)
      // If we have a profile validity duration, check if (timestamp + validity) is in the future
      if (profileDuration && profileDuration > 0) {
        const candidateExpiry = new Date(parsedDate.getTime() + profileDuration);
        expiryDate = candidateExpiry;
        remainingMs = candidateExpiry.getTime() - now.getTime();
      } else {
        // No profile duration; timestamp was already the expiration date that passed
        expiryDate = parsedDate;
        remainingMs = parsedDate.getTime() - now.getTime();
      }
    }
  } else if (user['limit-uptime']) {
    // No timestamp in comment, but user has limit-uptime
    const limitMs = parseHotspotDuration(user['limit-uptime']);
    if (limitMs) {
      remainingMs = Math.max(0, limitMs - uptimeMs);
      expiryDate = new Date(now.getTime() + remainingMs);
    }
  } else if (profileDuration && hasUptime) {
    // No timestamp in comment, but has profile duration and uptime
    remainingMs = Math.max(0, profileDuration - uptimeMs);
    expiryDate = new Date(now.getTime() + remainingMs);
  }

  // Format remaining human-readable string
  if (remainingMs === null) {
    return {
      isUsed: true,
      hasTimestamp,
      timestampDate: parsedDate,
      expiryDate,
      remainingMs: null,
      daysRemaining: null,
      status: 'active',
      badgeText: isOnline ? 'Online' : 'Terpakai',
      sisaText: 'Aktif',
      colorClass: 'text-emerald-600',
      formattedDate: formatHotspotDateTime(expiryDate || parsedDate),
    };
  }

  const daysRemaining = Math.ceil(remainingMs / (24 * 3600 * 1000));

  if (remainingMs <= 0) {
    const elapsedMs = Math.abs(remainingMs);
    const elapsedHours = Math.floor(elapsedMs / (3600 * 1000));
    const elapsedDays = Math.floor(elapsedMs / (24 * 3600 * 1000));

    let expiredNote = 'Habis';
    if (elapsedHours < 24 && elapsedHours >= 1) {
      expiredNote = `Habis (${elapsedHours} jam lalu)`;
    } else if (elapsedDays >= 1) {
      expiredNote = `Habis (${elapsedDays} hari lalu)`;
    } else if (elapsedHours < 1) {
      const elapsedMins = Math.max(1, Math.floor(elapsedMs / (60 * 1000)));
      expiredNote = `Habis (${elapsedMins} mnt lalu)`;
    }

    return {
      isUsed: true,
      hasTimestamp,
      timestampDate: parsedDate,
      expiryDate,
      remainingMs,
      daysRemaining: Math.floor(remainingMs / (24 * 3600 * 1000)),
      status: 'expired',
      badgeText: 'Habis',
      sisaText: expiredNote,
      colorClass: 'text-rose-600',
      formattedDate: formatHotspotDateTime(expiryDate || parsedDate),
    };
  }

  // Remaining > 0
  const hoursLeft = Math.floor(remainingMs / (3600 * 1000));
  const daysLeft = Math.floor(remainingMs / (24 * 3600 * 1000));
  const minsLeft = Math.floor((remainingMs % (3600 * 1000)) / (60 * 1000));

  let sisaText = '';
  let status: 'active' | 'expiring-soon' = 'active';
  let colorClass = 'text-emerald-600';

  if (daysLeft >= 2) {
    sisaText = `Sisa ${daysRemaining} hari`;
  } else if (daysLeft === 1) {
    sisaText = `Sisa 1 hari ${hoursLeft % 24} jam`;
    status = 'expiring-soon';
    colorClass = 'text-amber-600';
  } else if (hoursLeft >= 1) {
    sisaText = minsLeft > 0 ? `Sisa ${hoursLeft} jam ${minsLeft} mnt` : `Sisa ${hoursLeft} jam`;
    status = 'expiring-soon';
    colorClass = 'text-amber-600';
  } else {
    sisaText = minsLeft > 0 ? `Sisa ${minsLeft} menit` : 'Sisa < 1 menit';
    status = 'expiring-soon';
    colorClass = 'text-amber-600';
  }

  return {
    isUsed: true,
    hasTimestamp,
    timestampDate: parsedDate,
    expiryDate,
    remainingMs,
    daysRemaining,
    status,
    badgeText: isOnline ? 'Online' : 'Terpakai',
    sisaText,
    colorClass,
    formattedDate: formatHotspotDateTime(expiryDate || parsedDate),
  };
}
