import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

import {
  parseExpiryFromComment,
  extendExpiryDate,
  buildExpiryComment,
} from './pppoeUtils.mjs';

import { mikrotikApiService } from './mikrotikApi.mjs';

describe('PPPoE RT/RW Net Comment Expiry Parsing (R2)', () => {
  test('parses standard ISO date with customer note: exp: YYYY-MM-DD | Catatan', () => {
    const comment = 'exp: 2026-11-19 | Bpk Budi - Rumah No 12';
    const parsed = parseExpiryFromComment(comment);

    assert.ok(parsed.expiryDate !== null, 'expiryDate should be parsed');
    assert.strictEqual(parsed.expiryDate.getFullYear(), 2026);
    assert.strictEqual(parsed.expiryDate.getMonth(), 10); // 0-indexed: Nov = 10
    assert.strictEqual(parsed.expiryDate.getDate(), 19);
    assert.strictEqual(parsed.customerName, 'Bpk Budi - Rumah No 12');
  });

  test('parses date without pipe prefix', () => {
    const comment = 'exp: 2026-12-31';
    const parsed = parseExpiryFromComment(comment);

    assert.ok(parsed.expiryDate !== null);
    assert.strictEqual(parsed.expiryDate.getFullYear(), 2026);
    assert.strictEqual(parsed.expiryDate.getMonth(), 11); // Dec = 11
    assert.strictEqual(parsed.expiryDate.getDate(), 31);
    assert.strictEqual(parsed.customerName, '');
  });

  test('parses inverted format: Catatan | exp: YYYY-MM-DD', () => {
    const comment = 'Ibu Siti RT 05 | exp: 2026-10-30';
    const parsed = parseExpiryFromComment(comment);

    assert.ok(parsed.expiryDate !== null);
    assert.strictEqual(parsed.customerName, 'Ibu Siti RT 05');
  });

  test('handles DD-MM-YYYY format', () => {
    const comment = 'exp: 25-11-2026 | Warnet Jaya';
    const parsed = parseExpiryFromComment(comment);

    assert.ok(parsed.expiryDate !== null);
    assert.strictEqual(parsed.expiryDate.getFullYear(), 2026);
    assert.strictEqual(parsed.expiryDate.getMonth(), 10);
    assert.strictEqual(parsed.expiryDate.getDate(), 25);
    assert.strictEqual(parsed.customerName, 'Warnet Jaya');
  });

  test('handles empty or comment without date', () => {
    const parsedEmpty = parseExpiryFromComment('');
    assert.strictEqual(parsedEmpty.status, 'no-expiry');
    assert.strictEqual(parsedEmpty.expiryDate, null);
    assert.strictEqual(parsedEmpty.daysRemaining, null);

    const parsedNoteOnly = parseExpiryFromComment('Bpk Ahmad tanpa paket');
    assert.strictEqual(parsedNoteOnly.status, 'no-expiry');
    assert.strictEqual(parsedNoteOnly.customerName, 'Bpk Ahmad tanpa paket');
  });

  test('parses slash-separated ISO date: exp: YYYY/MM/DD | Catatan', () => {
    const comment = 'exp: 2026/11/19 | Bpk Budi';
    const parsed = parseExpiryFromComment(comment);

    assert.ok(parsed.expiryDate !== null);
    assert.strictEqual(parsed.expiryDate.getFullYear(), 2026);
    assert.strictEqual(parsed.expiryDate.getMonth(), 10);
    assert.strictEqual(parsed.expiryDate.getDate(), 19);
    assert.strictEqual(parsed.customerName, 'Bpk Budi');
  });

  test('rejects invalid dates without rolling over into false future expiries', () => {
    const parsedFeb31 = parseExpiryFromComment('exp: 2026-02-31 | Pak Budi');
    assert.strictEqual(parsedFeb31.status, 'no-expiry');
    assert.strictEqual(parsedFeb31.expiryDate, null);
    assert.strictEqual(parsedFeb31.customerName, 'Pak Budi');

    const parsedNonLeap = parseExpiryFromComment('exp: 2025-02-29 | Non Leap');
    assert.strictEqual(parsedNonLeap.status, 'no-expiry');
    assert.strictEqual(parsedNonLeap.expiryDate, null);

    const parsedModelNum = parseExpiryFromComment('Model-2024-99-99 | Pak Joko');
    assert.strictEqual(parsedModelNum.status, 'no-expiry');
    assert.strictEqual(parsedModelNum.expiryDate, null);
    assert.strictEqual(parsedModelNum.customerName, 'Model-2024-99-99 | Pak Joko');
  });

  test('handles bare prefix exp: and exp: | Note without leaving exp: in customerName', () => {
    const parsedBare = parseExpiryFromComment('exp: ');
    assert.strictEqual(parsedBare.status, 'no-expiry');
    assert.strictEqual(parsedBare.customerName, '');

    const parsedPipe = parseExpiryFromComment('exp: | Bpk Budi');
    assert.strictEqual(parsedPipe.status, 'no-expiry');
    assert.strictEqual(parsedPipe.customerName, 'Bpk Budi');
  });

  test('cleans empty wrapping brackets or parentheses from customerName', () => {
    const parsedParens = parseExpiryFromComment('Pak Budi (exp: 2026-10-19)');
    assert.ok(parsedParens.expiryDate !== null);
    assert.strictEqual(parsedParens.customerName, 'Pak Budi');

    const parsedBrackets = parseExpiryFromComment('Warnet Cemerlang [exp: 2026-10-19]');
    assert.ok(parsedBrackets.expiryDate !== null);
    assert.strictEqual(parsedBrackets.customerName, 'Warnet Cemerlang');
  });

  test('parses single-digit day and month in date', () => {
    const parsed = parseExpiryFromComment('exp: 2026-5-4 | Pelanggan');
    assert.ok(parsed.expiryDate !== null);
    assert.strictEqual(parsed.expiryDate.getFullYear(), 2026);
    assert.strictEqual(parsed.expiryDate.getMonth(), 4); // May = 4
    assert.strictEqual(parsed.expiryDate.getDate(), 4);
    assert.strictEqual(parsed.customerName, 'Pelanggan');
  });

  test('parses dot-separated dates: DD.MM.YYYY and YYYY.MM.DD', () => {
    const parsedDmy = parseExpiryFromComment('exp: 19.11.2026 | Pak Budi');
    assert.ok(parsedDmy.expiryDate !== null);
    assert.strictEqual(parsedDmy.expiryDate.getFullYear(), 2026);
    assert.strictEqual(parsedDmy.expiryDate.getMonth(), 10);
    assert.strictEqual(parsedDmy.expiryDate.getDate(), 19);
    assert.strictEqual(parsedDmy.customerName, 'Pak Budi');

    const parsedYmd = parseExpiryFromComment('exp: 2026.11.19 | Bu Siti');
    assert.ok(parsedYmd.expiryDate !== null);
    assert.strictEqual(parsedYmd.expiryDate.getFullYear(), 2026);
    assert.strictEqual(parsedYmd.expiryDate.getMonth(), 10);
    assert.strictEqual(parsedYmd.expiryDate.getDate(), 19);
    assert.strictEqual(parsedYmd.customerName, 'Bu Siti');
  });

  test('parses date with timestamp and strips time cleanly from customer note', () => {
    const parsed = parseExpiryFromComment('exp: 2026-11-19 14:30:00 | Pak Budi');
    assert.ok(parsed.expiryDate !== null);
    assert.strictEqual(parsed.expiryDate.getFullYear(), 2026);
    assert.strictEqual(parsed.expiryDate.getMonth(), 10);
    assert.strictEqual(parsed.expiryDate.getDate(), 19);
    assert.strictEqual(parsed.customerName, 'Pak Budi');
    assert.strictEqual(parsed.customerName.includes('14:30'), false);

    const parsedIsoT = parseExpiryFromComment('exp: 2026-11-19T23:59:59Z | Server Auto');
    assert.ok(parsedIsoT.expiryDate !== null);
    assert.strictEqual(parsedIsoT.expiryDate.getFullYear(), 2026);
    assert.strictEqual(parsedIsoT.customerName, 'Server Auto');
  });

  test('parses date with timestamp inside brackets without leaving orphaned time or brackets', () => {
    const parsed = parseExpiryFromComment('Pak Budi [exp: 2026-11-19 23:59:59]');
    assert.ok(parsed.expiryDate !== null);
    assert.strictEqual(parsed.expiryDate.getFullYear(), 2026);
    assert.strictEqual(parsed.expiryDate.getMonth(), 10);
    assert.strictEqual(parsed.expiryDate.getDate(), 19);
    assert.strictEqual(parsed.customerName, 'Pak Budi');
  });

  test('parses Indonesian and English named month names and abbreviations', () => {
    // Indonesian full month
    const parsedIndoFull = parseExpiryFromComment('exp: 19 Oktober 2026 | Bpk Budi');
    assert.ok(parsedIndoFull.expiryDate !== null);
    assert.strictEqual(parsedIndoFull.expiryDate.getFullYear(), 2026);
    assert.strictEqual(parsedIndoFull.expiryDate.getMonth(), 9); // Okt = 9
    assert.strictEqual(parsedIndoFull.expiryDate.getDate(), 19);
    assert.strictEqual(parsedIndoFull.customerName, 'Bpk Budi');

    // Indonesian 3-letter abbreviation with dash
    const parsedIndoDash = parseExpiryFromComment('exp: 19-Nov-2026 | Ibu Siti');
    assert.ok(parsedIndoDash.expiryDate !== null);
    assert.strictEqual(parsedIndoDash.expiryDate.getFullYear(), 2026);
    assert.strictEqual(parsedIndoDash.expiryDate.getMonth(), 10); // Nov = 10
    assert.strictEqual(parsedIndoDash.customerName, 'Ibu Siti');

    // English Month-First format
    const parsedMonthFirst = parseExpiryFromComment('exp: Nov 19 2026 | Customer');
    assert.ok(parsedMonthFirst.expiryDate !== null);
    assert.strictEqual(parsedMonthFirst.expiryDate.getFullYear(), 2026);
    assert.strictEqual(parsedMonthFirst.expiryDate.getMonth(), 10);
    assert.strictEqual(parsedMonthFirst.customerName, 'Customer');
  });

  test('preserves phone numbers and legitimate parentheses in customer notes', () => {
    const parsed = parseExpiryFromComment('exp: 2026-11-19 | Bpk Budi (08123456789)');
    assert.ok(parsed.expiryDate !== null);
    assert.strictEqual(parsed.customerName, 'Bpk Budi (08123456789)');
  });

  test('prioritizes explicit exp: date when customer note contains earlier dates', () => {
    const comment = 'Pak Joko pasang 2024-01-01 | exp: 2026-11-19';
    const parsed = parseExpiryFromComment(comment);

    assert.ok(parsed.expiryDate !== null);
    assert.strictEqual(parsed.expiryDate.getFullYear(), 2026);
    assert.strictEqual(parsed.expiryDate.getMonth(), 10);
    assert.strictEqual(parsed.expiryDate.getDate(), 19);
    assert.strictEqual(parsed.customerName, 'Pak Joko pasang 2024-01-01');
    assert.strictEqual(parsed.status, 'active');
  });

  test('parses 2-digit years in DD-MM-YY and DD/MM/YY formats', () => {
    const parsedDash = parseExpiryFromComment('exp: 19-11-26 | Pak Budi');
    assert.ok(parsedDash.expiryDate !== null);
    assert.strictEqual(parsedDash.expiryDate.getFullYear(), 2026);
    assert.strictEqual(parsedDash.expiryDate.getMonth(), 10);
    assert.strictEqual(parsedDash.expiryDate.getDate(), 19);
    assert.strictEqual(parsedDash.customerName, 'Pak Budi');

    const parsedSlash = parseExpiryFromComment('exp: 25/12/26 | Bu Siti');
    assert.ok(parsedSlash.expiryDate !== null);
    assert.strictEqual(parsedSlash.expiryDate.getFullYear(), 2026);
    assert.strictEqual(parsedSlash.expiryDate.getMonth(), 11);
    assert.strictEqual(parsedSlash.expiryDate.getDate(), 25);
    assert.strictEqual(parsedSlash.customerName, 'Bu Siti');
  });
});

describe('Expiry Status Classification (Aktif, Segera Habis, Kadaluarsa)', () => {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  function formatDate(d) {
    const yyyy = d.getFullYear();
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    const dd = String(d.getDate()).padStart(2, '0');
    return `${yyyy}-${mm}-${dd}`;
  }

  test('identifies status as active when > 7 days remaining', () => {
    const futureDate = new Date(today);
    futureDate.setDate(today.getDate() + 15);

    const comment = `exp: ${formatDate(futureDate)} | Pelanggan Aktif`;
    const parsed = parseExpiryFromComment(comment);

    assert.strictEqual(parsed.status, 'active');
    assert.strictEqual(parsed.daysRemaining, 15);

    // Exact boundary test: Day 8 is active
    const day8 = new Date(today);
    day8.setDate(today.getDate() + 8);
    const parsed8 = parseExpiryFromComment(`exp: ${formatDate(day8)}`);
    assert.strictEqual(parsed8.status, 'active');
    assert.strictEqual(parsed8.daysRemaining, 8);
  });

  test('identifies status as expiring-soon when <= 7 days remaining', () => {
    const nearDate = new Date(today);
    nearDate.setDate(today.getDate() + 5);

    const comment = `exp: ${formatDate(nearDate)} | H-5`;
    const parsed = parseExpiryFromComment(comment);

    assert.strictEqual(parsed.status, 'expiring-soon');
    assert.strictEqual(parsed.daysRemaining, 5);

    // Test exactly 7 days
    const day7 = new Date(today);
    day7.setDate(today.getDate() + 7);
    const parsed7 = parseExpiryFromComment(`exp: ${formatDate(day7)}`);
    assert.strictEqual(parsed7.status, 'expiring-soon');
    assert.strictEqual(parsed7.daysRemaining, 7);

    // Test Day 1
    const day1 = new Date(today);
    day1.setDate(today.getDate() + 1);
    const parsed1 = parseExpiryFromComment(`exp: ${formatDate(day1)}`);
    assert.strictEqual(parsed1.status, 'expiring-soon');
    assert.strictEqual(parsed1.daysRemaining, 1);

    // Test today (0 days)
    const day0 = new Date(today);
    const parsed0 = parseExpiryFromComment(`exp: ${formatDate(day0)}`);
    assert.strictEqual(parsed0.status, 'expiring-soon');
    assert.strictEqual(parsed0.daysRemaining, 0);
  });

  test('identifies status as expired when date is in the past', () => {
    const pastDate = new Date(today);
    pastDate.setDate(today.getDate() - 3);

    const comment = `exp: ${formatDate(pastDate)} | Terlambat`;
    const parsed = parseExpiryFromComment(comment);

    assert.strictEqual(parsed.status, 'expired');
    assert.strictEqual(parsed.daysRemaining, -3);

    // Exact boundary test: Yesterday (-1 day)
    const yesterday = new Date(today);
    yesterday.setDate(today.getDate() - 1);
    const parsedYest = parseExpiryFromComment(`exp: ${formatDate(yesterday)}`);
    assert.strictEqual(parsedYest.status, 'expired');
    assert.strictEqual(parsedYest.daysRemaining, -1);
  });
});

describe('Comment Generation & Extension (+30, +60, +7 Hari)', () => {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  function formatDate(d) {
    const yyyy = d.getFullYear();
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    const dd = String(d.getDate()).padStart(2, '0');
    return `${yyyy}-${mm}-${dd}`;
  }

  test('buildExpiryComment formats correctly with and without note', () => {
    const withNote = buildExpiryComment('2026-11-30', 'Bpk Budi');
    assert.strictEqual(withNote, '2026-11-30 23:59:59 | Bpk Budi');

    const withoutNote = buildExpiryComment('2026-11-30');
    assert.strictEqual(withoutNote, '2026-11-30 23:59:59');

    const empty = buildExpiryComment('', 'Catatan saja');
    assert.strictEqual(empty, 'Catatan saja');
  });

  test('extendExpiryDate adds 30 days to future expiry and preserves customer note', () => {
    const initialExpiry = new Date(today);
    initialExpiry.setDate(today.getDate() + 10);
    const comment = `${formatDate(initialExpiry)} 23:59:59 | Pelanggan Setia`;

    const extendedComment = extendExpiryDate(comment, 30);
    const parsed = parseExpiryFromComment(extendedComment);

    const expectedDate = new Date(initialExpiry);
    expectedDate.setDate(expectedDate.getDate() + 30);

    assert.strictEqual(formatDate(parsed.expiryDate), formatDate(expectedDate));
    assert.strictEqual(parsed.customerName, 'Pelanggan Setia');
    assert.ok(extendedComment.includes('23:59:59'));
  });

  test('extendExpiryDate supports +60 and +7 presets', () => {
    const initialExpiry = new Date(today);
    initialExpiry.setDate(today.getDate() + 5);
    const comment = `exp: ${formatDate(initialExpiry)} | Paket 2 Bulan`;

    // 60 days
    const extended60 = extendExpiryDate(comment, 60);
    const parsed60 = parseExpiryFromComment(extended60);
    const exp60 = new Date(initialExpiry);
    exp60.setDate(exp60.getDate() + 60);
    assert.strictEqual(formatDate(parsed60.expiryDate), formatDate(exp60));

    // 7 days
    const extended7 = extendExpiryDate(comment, 7);
    const parsed7 = parseExpiryFromComment(extended7);
    const exp7 = new Date(initialExpiry);
    exp7.setDate(exp7.getDate() + 7);
    assert.strictEqual(formatDate(parsed7.expiryDate), formatDate(exp7));
  });

  test('extendExpiryDate adds 30 days from today if already expired', () => {
    const pastExpiry = new Date(today);
    pastExpiry.setDate(today.getDate() - 15);
    const comment = `exp: ${formatDate(pastExpiry)} | Pelanggan Nunggak`;

    const extendedComment = extendExpiryDate(comment, 30);
    const parsed = parseExpiryFromComment(extendedComment);

    const expectedDate = new Date(today);
    expectedDate.setDate(expectedDate.getDate() + 30);

    assert.strictEqual(formatDate(parsed.expiryDate), formatDate(expectedDate));
    assert.strictEqual(parsed.customerName, 'Pelanggan Nunggak');
  });

  test('extendExpiryDate adds 30 days from today if comment has no date', () => {
    const comment = 'Catatan Biasa Tanpa Tanggal';
    const extendedComment = extendExpiryDate(comment, 30);
    const parsed = parseExpiryFromComment(extendedComment);

    const expectedDate = new Date(today);
    expectedDate.setDate(expectedDate.getDate() + 30);

    assert.strictEqual(formatDate(parsed.expiryDate), formatDate(expectedDate));
    assert.strictEqual(parsed.customerName, 'Catatan Biasa Tanpa Tanggal');
  });

  test('handles year boundary rollover (Dec to Jan)', () => {
    const decComment = 'exp: 2026-12-25 | Akhir Tahun';
    const extended = extendExpiryDate(decComment, 30);
    const parsed = parseExpiryFromComment(extended);

    assert.strictEqual(parsed.expiryDate.getFullYear(), 2027);
    assert.strictEqual(parsed.expiryDate.getMonth(), 0); // Jan = 0
    assert.strictEqual(parsed.expiryDate.getDate(), 24);
  });

  test('extendExpiryDate handles bare prefix exp: without appending | exp:', () => {
    const extended = extendExpiryDate('exp: ', 30);
    assert.strictEqual(extended.includes('| exp:'), false);
    assert.ok(extended.includes('23:59:59'));

    const extendedPipe = extendExpiryDate('exp: | Bpk Budi', 30);
    const parsed = parseExpiryFromComment(extendedPipe);
    assert.strictEqual(parsed.customerName, 'Bpk Budi');
    assert.strictEqual(extendedPipe.includes('exp: | exp:'), false);
  });

  test('buildExpiryComment sanitizes accidentally pasted exp: prefixes in customer note', () => {
    const sanitized = buildExpiryComment('2026-11-19', 'exp: 2026-11-19 | Bpk Budi');
    assert.strictEqual(sanitized, '2026-11-19 23:59:59 | Bpk Budi');

    const sanitizedBareExp = buildExpiryComment('2026-11-19', 'exp: | Pelanggan Baru');
    assert.strictEqual(sanitizedBareExp, '2026-11-19 23:59:59 | Pelanggan Baru');
  });

  test('extendExpiryDate normalizes dot dates, dates with timestamps, and named months to standard YYYY-MM-DD 23:59:59', () => {
    // Dot date normalized
    const extDot = extendExpiryDate('exp: 19.11.2026 | Pak Budi', 30);
    assert.ok(extDot.startsWith('2026-12-19 23:59:59'));
    assert.strictEqual(extDot, '2026-12-19 23:59:59 | Pak Budi');

    // Date with timestamp normalized without leftover time in customer note
    const extTime = extendExpiryDate('exp: 2026-11-19 14:30:00 | Pak Joko', 30);
    assert.strictEqual(extTime, '2026-12-19 23:59:59 | Pak Joko');

    // Indonesian named month normalized
    const extNamed = extendExpiryDate('exp: 19 November 2026 | Bu Siti', 30);
    assert.strictEqual(extNamed, '2026-12-19 23:59:59 | Bu Siti');
  });

  test('extendExpiryDate preserves note with earlier date and extends from explicit exp date', () => {
    const ext = extendExpiryDate('Pak Joko pasang 2024-01-01 | exp: 2026-11-19', 30);
    assert.strictEqual(ext, '2026-12-19 23:59:59 | Pak Joko pasang 2024-01-01');
  });

  test('buildExpiryComment cleans named-month and parenthesized dates from customerNote', () => {
    const sanitizedNamed = buildExpiryComment('2026-11-19', 'exp: 19 Oktober 2026 | Pak Budi');
    assert.strictEqual(sanitizedNamed, '2026-11-19 23:59:59 | Pak Budi');

    const sanitizedParens = buildExpiryComment('2026-11-19', 'Pak Budi (exp: 2026-10-19)');
    assert.strictEqual(sanitizedParens, '2026-11-19 23:59:59 | Pak Budi');

    const sanitizedBareDate = buildExpiryComment('2026-11-19', 'exp: 2026-10-19');
    assert.strictEqual(sanitizedBareDate, '2026-11-19 23:59:59');
  });
});

describe('DHCP Lease to PPPoE Form Pre-fill (R1)', () => {
  test('extracts caller ID MAC, IP remote address, and username from DHCP Lease', () => {
    const sampleLease = {
      '.id': '*5',
      address: '192.168.88.150',
      'mac-address': '48:8A:D2:AA:BB:CC',
      'host-name': 'ZTE-F609-User',
      status: 'bound',
      'expires-after': '9m45s',
    };

    // Emulate pre-fill logic from PppoeView
    const hostClean = (sampleLease['host-name'] || '')
      .toLowerCase()
      .replace(/[^a-z0-9]/g, '-')
      .replace(/^-+|-+$/g, '');
    const ipSuffix = (sampleLease.address || '').split('.').pop() || 'client';
    const suggestedUser = hostClean && hostClean !== 'unknown' ? hostClean : `ont-${ipSuffix}`;

    assert.strictEqual(suggestedUser, 'zte-f609-user');
    assert.strictEqual(sampleLease['mac-address'], '48:8A:D2:AA:BB:CC');
    assert.strictEqual(sampleLease.address, '192.168.88.150');

    // Emulate creation payload
    const payload = {
      name: suggestedUser,
      password: 'random-password-123',
      profile: 'paket-10mbps',
      comment: buildExpiryComment('2026-11-19', `ONT: ${sampleLease['host-name']}`),
      'caller-id': sampleLease['mac-address'],
      'remote-address': sampleLease.address,
    };

    assert.strictEqual(payload['caller-id'], '48:8A:D2:AA:BB:CC');
    assert.strictEqual(payload['remote-address'], '192.168.88.150');
    assert.strictEqual(payload.comment, '2026-11-19 23:59:59 | ONT: ZTE-F609-User');
  });

  test('fallback suggested username when lease host-name is empty or generic', () => {
    const leaseNoHost = {
      '.id': '*6',
      address: '192.168.88.204',
      'mac-address': '00:11:22:33:44:55',
      status: 'bound',
    };

    const hostClean = (leaseNoHost['host-name'] || '')
      .toLowerCase()
      .replace(/[^a-z0-9]/g, '-')
      .replace(/^-+|-+$/g, '');
    const ipSuffix = (leaseNoHost.address || '').split('.').pop() || 'client';
    const suggestedUser = hostClean && hostClean !== 'unknown' ? hostClean : `ont-${ipSuffix}`;

    assert.strictEqual(suggestedUser, 'ont-204');
  });

  test('supports active-address and active-mac-address fallbacks when primary fields are absent', () => {
    const dynamicLease = {
      '.id': '*7',
      'active-address': '192.168.88.220',
      'active-mac-address': 'AA:BB:CC:DD:EE:FF',
      status: 'bound',
    };

    const leaseIp = dynamicLease.address || dynamicLease['active-address'] || '';
    const leaseMac = dynamicLease['mac-address'] || dynamicLease['active-mac-address'] || '';
    const ipSuffix = leaseIp.split('.').pop() || 'client';
    const suggestedUser = `ont-${ipSuffix}`;

    assert.strictEqual(leaseIp, '192.168.88.220');
    assert.strictEqual(leaseMac, 'AA:BB:CC:DD:EE:FF');
    assert.strictEqual(suggestedUser, 'ont-220');
  });
});

describe('Isolir & Active Session Termination Logic (R2)', () => {
  test('disabling secret identifies and kicks all matching active sessions', async () => {
    const pppSecrets = [
      { '.id': '*1', name: 'user-budi', disabled: 'false', comment: 'exp: 2026-10-10' },
      { '.id': '*2', name: 'user-siti', disabled: 'false', comment: 'exp: 2026-11-20' },
    ];

    const pppActive = [
      { '.id': '*A', name: 'user-budi', address: '10.10.10.2', uptime: '2d1h' },
      { '.id': '*B', name: 'user-budi', address: '10.10.10.3', uptime: '10m' }, // multi session test
      { '.id': '*C', name: 'user-siti', address: '10.10.10.4', uptime: '5h' },
    ];

    const kickedSessionIds = [];
    const mockDisconnectPppActive = async (profile, id) => {
      kickedSessionIds.push(id);
      return {};
    };

    // Simulate handleUpdatePppSecret isolir behavior
    const targetId = '*1';
    const updates = { disabled: 'true' };

    const targetSecret = pppSecrets.find((s) => s['.id'] === targetId || s.name === targetId);
    assert.ok(targetSecret);
    assert.strictEqual(targetSecret.name, 'user-budi');

    if (updates.disabled === 'true' || updates.disabled === true) {
      const matchingActive = pppActive.filter((a) => a.name === targetSecret.name);
      await Promise.allSettled(
        matchingActive.map((a) => mockDisconnectPppActive({}, a['.id']))
      );
    }

    assert.deepStrictEqual(kickedSessionIds, ['*A', '*B']);
    assert.strictEqual(kickedSessionIds.includes('*C'), false);
  });

  test('matches active sessions case-insensitively when kicking', async () => {
    const pppSecrets = [
      { '.id': '*1', name: 'User-Budi', disabled: 'false' },
    ];
    const pppActive = [
      { '.id': '*A', name: 'user-budi', address: '10.10.10.2' },
      { '.id': '*B', name: 'USER-BUDI', address: '10.10.10.3' },
      { '.id': '*C', name: 'user-other', address: '10.10.10.4' },
    ];

    const targetSecret = pppSecrets[0];
    const targetName = targetSecret.name.toLowerCase();
    const matchingActive = pppActive.filter(
      (a) => a.name && a.name.toLowerCase() === targetName
    );

    assert.strictEqual(matchingActive.length, 2);
    assert.deepStrictEqual(matchingActive.map((a) => a['.id']), ['*A', '*B']);
  });

  test('deleting a secret kicks any active session for that customer', async () => {
    const pppActive = [
      { '.id': '*X', name: 'user-to-delete', address: '10.10.10.99' },
      { '.id': '*Y', name: 'user-keep', address: '10.10.10.100' },
    ];

    const targetName = 'user-to-delete';
    const kicked = [];
    const mockDisconnect = async (id) => { kicked.push(id); };

    const matchingActive = pppActive.filter(
      (a) => a.name && a.name.toLowerCase() === targetName.toLowerCase()
    );
    await Promise.allSettled(matchingActive.map((a) => mockDisconnect(a['.id'])));

    assert.deepStrictEqual(kicked, ['*X']);
  });

  test('explicit updates.name ensures correct active session kick even if targetSecret lookup is desynced', async () => {
    const pppActive = [
      { '.id': '*M1', name: 'user-agus', address: '10.10.10.50' },
      { '.id': '*M2', name: 'user-budi', address: '10.10.10.51' },
    ];

    // Simulated payload with id='*99' where local state lookup might fail
    const id = '*99';
    const updates = { name: 'user-agus', disabled: 'true' };
    const targetSecret = null; // desynced local state

    const targetName = (updates.name || targetSecret?.name || id).toLowerCase();
    assert.strictEqual(targetName, 'user-agus');

    const matchingActive = pppActive.filter(
      (a) => a.name && a.name.toLowerCase() === targetName
    );
    assert.strictEqual(matchingActive.length, 1);
    assert.strictEqual(matchingActive[0]['.id'], '*M1');
  });

  test('deletion cancellation state un-arms confirmation without deleting', () => {
    let deletingId = '*secret-1';
    // User clicks cancel ('X') button:
    const handleCancelDelete = () => { deletingId = null; };
    handleCancelDelete();
    assert.strictEqual(deletingId, null);
  });

  test('activeMap matches sessions case-insensitively and provides accurate online count', () => {
    const secrets = [
      { '.id': '*1', name: 'User-Budi' },
      { '.id': '*2', name: 'User-Siti' },
      { '.id': '*3', name: 'User-Agus' },
    ];
    const activeSessions = [
      { '.id': '*A', name: 'user-budi', address: '10.10.10.2' },
      { '.id': '*B', name: 'USER-SITI', address: '10.10.10.3' },
    ];

    // Emulate PppoeView activeMap
    const map = new Map();
    for (const session of activeSessions) {
      if (session.name) {
        map.set(session.name.toLowerCase(), session);
      }
    }

    assert.strictEqual(map.has('User-Budi'.toLowerCase()), true);
    assert.strictEqual(map.has('User-Siti'.toLowerCase()), true);
    assert.strictEqual(map.has('User-Agus'.toLowerCase()), false);

    const onlineSecretsCount = secrets.filter((s) => map.has((s.name || '').toLowerCase())).length;
    assert.strictEqual(onlineSecretsCount, 2);
  });

  test('disconnect session falls back to session-id or name when .id is absent', async () => {
    const sessions = [
      { '.id': '*A', name: 'user-one' },
      { 'session-id': 'sess-2', name: 'user-two' },
      { name: 'user-three' },
    ];

    const disconnectedIds = [];
    for (const a of sessions) {
      const kickId = a['.id'] || a['session-id'] || a.name;
      if (kickId) disconnectedIds.push(kickId);
    }

    assert.deepStrictEqual(disconnectedIds, ['*A', 'sess-2', 'user-three']);
  });
});

describe('MikroTik API Client & RouterOS v7 Endpoints', () => {
  const profile = {
    id: 'test-profile-1',
    name: 'Main Router',
    host: '192.168.88.1',
    port: 80,
    useHttps: false,
    username: 'admin',
    password: 'securepassword123',
  };

  test('buildBaseUrl handles IPv4 and default ports correctly', () => {
    const url = mikrotikApiService.buildBaseUrl(profile);
    assert.strictEqual(url, 'http://192.168.88.1:80');

    const httpsProfile = { ...profile, useHttps: true, port: 443 };
    const httpsUrl = mikrotikApiService.buildBaseUrl(httpsProfile);
    assert.strictEqual(httpsUrl, 'https://192.168.88.1:443');

    // IPv6 host
    const ipv6Profile = { ...profile, host: '2001:db8::1', port: 80 };
    const ipv6Url = mikrotikApiService.buildBaseUrl(ipv6Profile);
    assert.strictEqual(ipv6Url, 'http://[2001:db8::1]:80');
  });

  test('getAuthHeader generates valid Basic authentication credentials', () => {
    const authHeader = mikrotikApiService.getAuthHeader(profile);
    assert.ok(authHeader.startsWith('Basic '));

    const token = authHeader.replace('Basic ', '');
    const decoded = Buffer.from(token, 'base64').toString('utf-8');
    assert.strictEqual(decoded, 'admin:securepassword123');
  });

  test('read-only helper methods exist on mikrotikApiService', () => {
    assert.strictEqual(typeof mikrotikApiService.getSystemResource, 'function');
    assert.strictEqual(typeof mikrotikApiService.getSystemIdentity, 'function');
    assert.strictEqual(typeof mikrotikApiService.getSystemClock, 'function');
    assert.strictEqual(typeof mikrotikApiService.getSystemHealth, 'function');
    assert.strictEqual(typeof mikrotikApiService.getHotspotActive, 'function');
    assert.strictEqual(typeof mikrotikApiService.getHotspotUsers, 'function');
    assert.strictEqual(typeof mikrotikApiService.getHotspotProfiles, 'function');
    assert.strictEqual(typeof mikrotikApiService.createHotspotProfile, 'function');
    assert.strictEqual(typeof mikrotikApiService.updateHotspotProfile, 'function');
    assert.strictEqual(typeof mikrotikApiService.deleteHotspotProfile, 'function');
    assert.strictEqual(typeof mikrotikApiService.createHotspotUser, 'function');
    assert.strictEqual(typeof mikrotikApiService.updateHotspotUser, 'function');
    assert.strictEqual(typeof mikrotikApiService.deleteHotspotUser, 'function');
    assert.strictEqual(typeof mikrotikApiService.clearHotspotUserMac, 'function');
    assert.strictEqual(typeof mikrotikApiService.clearHotspotUserMacByName, 'function');
    assert.strictEqual(typeof mikrotikApiService.disconnectHotspotActive, 'function');
    assert.strictEqual(typeof mikrotikApiService.getInterfaces, 'function');
    assert.strictEqual(typeof mikrotikApiService.getDhcpLeases, 'function');
    assert.strictEqual(typeof mikrotikApiService.makeDhcpLeaseStatic, 'function');
    assert.strictEqual(typeof mikrotikApiService.releaseDhcpLeaseStatic, 'function');
    assert.strictEqual(typeof mikrotikApiService.deleteDhcpLease, 'function');
    assert.strictEqual(typeof mikrotikApiService.getPppActive, 'function');
    assert.strictEqual(typeof mikrotikApiService.getPppSecrets, 'function');
  });
});
