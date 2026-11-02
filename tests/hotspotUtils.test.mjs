import test from 'node:test';
import assert from 'node:assert/strict';
import {
  parseHotspotDate,
  parseHotspotDuration,
  calculateHotspotUserExpiry,
} from './hotspotUtils.mjs';

test('Hotspot Date & Time Parsing', async (t) => {
  await t.test('parses ISO date and time: 2026-11-07 11:23:28', () => {
    const d = parseHotspotDate('2026-11-07 11:23:28');
    assert.ok(d !== null);
    assert.equal(d.getFullYear(), 2026);
    assert.equal(d.getMonth(), 10); // Nov is 10
    assert.equal(d.getDate(), 7);
    assert.equal(d.getHours(), 11);
    assert.equal(d.getMinutes(), 23);
    assert.equal(d.getSeconds(), 28);
  });

  await t.test('parses Mikhmon standard: nov/07/2026 11:23:28', () => {
    const d = parseHotspotDate('nov/07/2026 11:23:28');
    assert.ok(d !== null);
    assert.equal(d.getFullYear(), 2026);
    assert.equal(d.getMonth(), 10);
    assert.equal(d.getDate(), 7);
    assert.equal(d.getHours(), 11);
    assert.equal(d.getMinutes(), 23);
  });

  await t.test('parses Mikhmon reversed: 11:23:28 nov/07/2026', () => {
    const d = parseHotspotDate('11:23:28 nov/07/2026');
    assert.ok(d !== null);
    assert.equal(d.getFullYear(), 2026);
    assert.equal(d.getMonth(), 10);
    assert.equal(d.getDate(), 7);
    assert.equal(d.getHours(), 11);
  });

  await t.test('parses date with batch or mode suffix: 2026-11-07 11:23:28,vc-kasir1', () => {
    const d = parseHotspotDate('2026-11-07 11:23:28,vc-kasir1');
    assert.ok(d !== null);
    assert.equal(d.getFullYear(), 2026);
    assert.equal(d.getMonth(), 10);
    assert.equal(d.getDate(), 7);
  });
});

test('Hotspot Duration & Validity Parsing', async (t) => {
  await t.test('parses MikroTik duration notations: 30d, 7d, 3h, 30m', () => {
    assert.equal(parseHotspotDuration('1d'), 24 * 3600 * 1000);
    assert.equal(parseHotspotDuration('3h'), 3 * 3600 * 1000);
    assert.equal(parseHotspotDuration('30m'), 30 * 60 * 1000);
    assert.equal(parseHotspotDuration('7d'), 7 * 24 * 3600 * 1000);
  });

  await t.test('parses Indonesian unit text: 3Jam, 1Hari, 7Hari, 30Hari', () => {
    assert.equal(parseHotspotDuration('3Jam'), 3 * 3600 * 1000);
    assert.equal(parseHotspotDuration('1Hari'), 24 * 3600 * 1000);
    assert.equal(parseHotspotDuration('7Hari'), 7 * 24 * 3600 * 1000);
    assert.equal(parseHotspotDuration('1Bulan'), 30 * 24 * 3600 * 1000);
  });

  await t.test('extracts duration from profile name: Voucher-3Jam, Voucher-1Hari', () => {
    assert.equal(parseHotspotDuration('Voucher-3Jam'), 3 * 3600 * 1000);
    assert.equal(parseHotspotDuration('Voucher-1Hari'), 24 * 3600 * 1000);
    assert.equal(parseHotspotDuration('VIP-30Hari'), 30 * 24 * 3600 * 1000);
  });
});

test('Hotspot User Expiry & Usage Calculation (User udh kepake vs Profile)', async (t) => {
  const fixedNow = new Date(2026, 10, 2, 14, 22, 25); // 2026-11-02 14:22:25

  await t.test('identifies user with "2026-11-07 11:23:28" as TERPAKAI with 5 days remaining', () => {
    const user = {
      '.id': '*H1',
      name: 'tasya-voucher',
      profile: 'Voucher-5M',
      comment: '2026-11-07 11:23:28',
    };
    const profile = {
      '.id': '*HP1',
      name: 'Voucher-5M',
    };

    const res = calculateHotspotUserExpiry(user, profile, fixedNow);
    assert.equal(res.isUsed, true);
    assert.equal(res.hasTimestamp, true);
    assert.ok(res.daysRemaining >= 4 && res.daysRemaining <= 5);
    assert.match(res.sisaText, /Sisa 5 hari/);
    assert.equal(res.status, 'active');
  });

  await t.test('calculates first login timestamp + profile validity', () => {
    // User logged in 2 hours ago at 12:22:25 on 2026-11-02 with 3Jam profile
    const user = {
      '.id': '*H2',
      name: 'user-3jam',
      profile: 'Voucher-3Jam',
      comment: '2026-11-02 12:22:25',
    };
    const profile = {
      '.id': '*HP2',
      name: 'Voucher-3Jam',
    };

    const res = calculateHotspotUserExpiry(user, profile, fixedNow);
    assert.equal(res.isUsed, true);
    assert.equal(res.status, 'expiring-soon');
    // 3 hours from 12:22:25 is 15:22:25, which is 1 hour from 14:22:25
    assert.match(res.sisaText, /Sisa 1 jam/);
  });

  await t.test('marks fresh voucher without timestamp or uptime as Belum Dipakai', () => {
    const user = {
      '.id': '*H3',
      name: 'fresh-voucher-99',
      profile: 'Voucher-3M',
      uptime: '0s',
      comment: 'Voucher Kasir 1',
    };
    const res = calculateHotspotUserExpiry(user, undefined, fixedNow);
    assert.equal(res.isUsed, false);
    assert.equal(res.status, 'unused');
    assert.equal(res.sisaText, 'Belum Dipakai');
  });

  await t.test('identifies expired voucher when timestamp + validity has passed', () => {
    // User logged in yesterday with 3-hour voucher
    const user = {
      '.id': '*H4',
      name: 'old-user',
      profile: 'Voucher-3Jam',
      comment: '2026-11-01 10:00:00',
    };
    const profile = {
      '.id': '*HP2',
      name: 'Voucher-3Jam',
    };

    const res = calculateHotspotUserExpiry(user, profile, fixedNow);
    assert.equal(res.isUsed, true);
    assert.equal(res.status, 'expired');
    assert.match(res.sisaText, /Habis/);
  });

  await t.test('calculates sisa for online active session with comment date', () => {
    const user = {
      '.id': '*H1',
      name: 'tasyauser',
      profile: 'Voucher-8M',
      comment: '2026-11-07 11:23:28',
    };
    const profile = {
      '.id': '*HP3',
      name: 'Voucher-8M',
    };

    const res = calculateHotspotUserExpiry(user, profile, fixedNow, true);
    assert.equal(res.isUsed, true);
    assert.equal(res.badgeText, 'Online');
    assert.match(res.sisaText, /Sisa 5 hari/);
  });
});
