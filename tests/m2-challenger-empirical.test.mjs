import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {
  parseExpiryFromComment,
  extendExpiryDate,
  buildExpiryComment,
} from './pppoeUtils.mjs';
import { mikrotikApiService } from './mikrotikApi.mjs';

// --- HELPER: WCAG Luminance & Contrast Calculation ---
function hexToLuminance(hex) {
  const cleanHex = hex.replace('#', '').trim();
  const rgb = cleanHex.match(/.{2}/g).map((x) => parseInt(x, 16) / 255);
  const a = rgb.map((v) => (v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)));
  return a[0] * 0.2126 + a[1] * 0.7152 + a[2] * 0.0722;
}

function contrastRatio(hex1, hex2) {
  const l1 = hexToLuminance(hex1);
  const l2 = hexToLuminance(hex2);
  const brighter = Math.max(l1, l2);
  const darker = Math.min(l1, l2);
  return (brighter + 0.05) / (darker + 0.05);
}

describe('Challenger M2: Card Elements & Semantic Dual-Theming Adaptation', () => {
  const css = fs.readFileSync(path.resolve('src/index.css'), 'utf8');
  const cardPath = path.resolve('src/components/ui/card.tsx');
  const cardCode = fs.readFileSync(cardPath, 'utf8');

  test('Card component uses semantic tokens: bg-card, text-card-foreground, border-border', () => {
    assert.match(
      cardCode,
      /bg-card/,
      'Card component must use bg-card semantic token'
    );
    assert.match(
      cardCode,
      /text-card-foreground/,
      'Card component must use text-card-foreground'
    );
    assert.match(
      cardCode,
      /border-border/,
      'Card component must use border-border'
    );
    // Ensure no hardcoded dark background in card.tsx
    assert.doesNotMatch(
      cardCode,
      /bg-zinc-|bg-slate-|bg-black|bg-\[#/,
      'Card component must not contain hardcoded dark colors'
    );
  });

  test('CSS tokens strictly define Light Mode (#FFFFFF card on #F0F2F5 background)', () => {
    const rootMatch = css.match(/:root\s*\{([\s\S]*?)\}/);
    assert.ok(rootMatch, ':root selector must be present in index.css');
    const rootBlock = rootMatch[1];

    assert.match(rootBlock, /--background:\s*#F0F2F5/i, '--background must be #F0F2F5 in :root');
    assert.match(rootBlock, /--card:\s*#FFFFFF/i, '--card must be #FFFFFF in :root');
    assert.match(rootBlock, /--card-foreground:\s*#050505/i, '--card-foreground must be #050505 in :root');
    assert.match(rootBlock, /--border:\s*#CED0D4/i, '--border must be #CED0D4 in :root');
  });

  test('CSS tokens strictly define Dark Mode (#242526 card on #18191A background)', () => {
    const darkMatch = css.match(/\.dark\s*\{([\s\S]*?)\}/);
    assert.ok(darkMatch, '.dark selector must be present in index.css');
    const darkBlock = darkMatch[1];

    assert.match(darkBlock, /--background:\s*#18191A/i, '--background must be #18191A in .dark');
    assert.match(darkBlock, /--card:\s*#242526/i, '--card must be #242526 in .dark');
    assert.match(darkBlock, /--card-foreground:\s*#E4E6EB/i, '--card-foreground must be #E4E6EB in .dark');
    assert.match(darkBlock, /--border:\s*#3A3B3C/i, '--border must be #3A3B3C in .dark');
  });

  test('WCAG Accessibility: High contrast in both Light & Dark modes for card contents', () => {
    // Light Mode Contrast Ratios
    const lightCardBg = '#FFFFFF';
    const lightSurfaceBg = '#F0F2F5';
    const lightCardFg = '#050505';
    const lightMutedFg = '#65676B';

    const lightCardTextContrast = contrastRatio(lightCardFg, lightCardBg);
    assert.ok(
      lightCardTextContrast >= 7.0,
      `Light mode text on card contrast ${lightCardTextContrast.toFixed(2)} must exceed WCAG AAA 7.0`
    );

    const lightMutedTextContrast = contrastRatio(lightMutedFg, lightCardBg);
    assert.ok(
      lightMutedTextContrast >= 4.5,
      `Light mode muted text contrast ${lightMutedTextContrast.toFixed(2)} must exceed WCAG AA 4.5`
    );

    // Dark Mode Contrast Ratios
    const darkCardBg = '#242526';
    const darkSurfaceBg = '#18191A';
    const darkCardFg = '#E4E6EB';
    const darkMutedFg = '#B0B3B8';

    const darkCardTextContrast = contrastRatio(darkCardFg, darkCardBg);
    assert.ok(
      darkCardTextContrast >= 7.0,
      `Dark mode text on card contrast ${darkCardTextContrast.toFixed(2)} must exceed WCAG AAA 7.0`
    );

    const darkMutedTextContrast = contrastRatio(darkMutedFg, darkCardBg);
    assert.ok(
      darkMutedTextContrast >= 4.5,
      `Dark mode muted text contrast ${darkMutedTextContrast.toFixed(2)} must exceed WCAG AA 4.5`
    );

    // Subtle Elevation Differentiation between card and canvas background
    const lightElevationContrast = contrastRatio(lightCardBg, lightSurfaceBg);
    assert.ok(
      lightElevationContrast >= 1.05 && lightElevationContrast <= 1.3,
      `Light mode card elevation contrast ${lightElevationContrast.toFixed(2)} should be subtle Facebook card feel (1.05-1.3)`
    );

    const darkElevationContrast = contrastRatio(darkCardBg, darkSurfaceBg);
    assert.ok(
      darkElevationContrast >= 1.05 && darkElevationContrast <= 1.4,
      `Dark mode card elevation contrast ${darkElevationContrast.toFixed(2)} should be subtle Facebook dark card feel (1.05-1.4)`
    );
  });
});

describe('Challenger M2: All 5 Views Card Theming & Zero Hardcoded Classes', () => {
  const views = [
    'src/components/VitalsView.tsx',
    'src/components/InterfacesView.tsx',
    'src/components/DhcpView.tsx',
    'src/components/PppoeView.tsx',
    'src/components/SetupConnection.tsx',
  ];

  for (const viewPath of views) {
    const filename = path.basename(viewPath);
    const content = fs.readFileSync(path.resolve(viewPath), 'utf8');

    test(`${filename} uses <Card> primitives and contains ZERO hardcoded zinc classes`, () => {
      // Must import or use Card
      assert.match(content, /<Card\b/, `${filename} must render at least one <Card> element`);

      // Must not contain hardcoded zinc classes
      assert.doesNotMatch(
        content,
        /\bzinc-\d+\b/,
        `${filename} must not contain any hardcoded zinc classes`
      );
    });

    test(`${filename} does not contain hardcoded dark card backgrounds`, () => {
      // Must not have hardcoded bg-slate-900, bg-zinc-900, bg-gray-900, bg-black on cards
      assert.doesNotMatch(
        content,
        /\b(bg-slate-900|bg-zinc-900|bg-gray-900|bg-black)\b/,
        `${filename} must not contain hardcoded dark card backgrounds`
      );
    });
  }

  test('All interactive touch targets in views satisfy >= 48px minimum', () => {
    // Audit search clear buttons, action buttons, filter buttons
    const dhcpContent = fs.readFileSync(path.resolve('src/components/DhcpView.tsx'), 'utf8');
    assert.match(dhcpContent, /aria-label="Hapus pencarian"[\s\S]*?min-h-\[48px\] min-w-\[48px\]/);
    assert.match(dhcpContent, /min-h-\[48px\] min-w-\[48px\][\s\S]*?title="Salin MAC Address"/);
    assert.match(dhcpContent, /min-h-\[48px\][\s\S]*?Buat PPPoE/);

    const intfContent = fs.readFileSync(path.resolve('src/components/InterfacesView.tsx'), 'utf8');
    assert.match(intfContent, /aria-label="Hapus kata kunci pencarian"[\s\S]*?min-h-\[48px\] min-w-\[48px\]/);

    const setupContent = fs.readFileSync(path.resolve('src/components/SetupConnection.tsx'), 'utf8');
    assert.match(setupContent, /min-h-\[48px\] min-w-\[48px\][\s\S]*?Tambah Profil/);
    assert.match(setupContent, /min-h-\[48px\] min-w-\[48px\][\s\S]*?aria-label={`Hapus profil/);
    assert.match(setupContent, /min-h-\[48px\] min-w-\[48px\][\s\S]*?Tampilkan password/);
  });
});

describe('Challenger M2: PPPoE Domain Logic Stress Testing & Fuzzing Oracle', () => {
  test('Leap year edge cases in parseExpiryFromComment', () => {
    // 2028 is a leap year -> Feb 29, 2028 is valid
    const validLeap = parseExpiryFromComment('exp: 2028-02-29 | Pelanggan Leap');
    assert.ok(validLeap.expiryDate, '2028-02-29 must parse successfully');
    assert.strictEqual(validLeap.expiryDate.getFullYear(), 2028);
    assert.strictEqual(validLeap.expiryDate.getMonth(), 1); // 1 = Feb
    assert.strictEqual(validLeap.expiryDate.getDate(), 29);
    assert.strictEqual(validLeap.customerName, 'Pelanggan Leap');

    // 2026 is NOT a leap year -> 2026-02-29 must be rejected and not roll over to March 1
    const invalidLeap = parseExpiryFromComment('exp: 2026-02-29 | Pelanggan Non-Leap');
    assert.strictEqual(invalidLeap.expiryDate, null, '2026-02-29 must be rejected');
    assert.strictEqual(invalidLeap.status, 'no-expiry');
  });

  test('All Indonesian month names and abbreviations parsed correctly', () => {
    const idMonths = [
      { name: 'Januari', m: 0 },
      { name: 'Februari', m: 1 },
      { name: 'Maret', m: 2 },
      { name: 'April', m: 3 },
      { name: 'Mei', m: 4 },
      { name: 'Juni', m: 5 },
      { name: 'Juli', m: 6 },
      { name: 'Agustus', m: 7 },
      { name: 'Agu', m: 7 },
      { name: 'Ags', m: 7 },
      { name: 'September', m: 8 },
      { name: 'Sep', m: 8 },
      { name: 'Oktober', m: 9 },
      { name: 'Okt', m: 9 },
      { name: 'November', m: 10 },
      { name: 'Nov', m: 10 },
      { name: 'Desember', m: 11 },
      { name: 'Des', m: 11 },
    ];

    for (const item of idMonths) {
      const comment = `exp: 15 ${item.name} 2027 | User ${item.name}`;
      const res = parseExpiryFromComment(comment);
      assert.ok(res.expiryDate, `Failed parsing Indonesian month: ${item.name}`);
      assert.strictEqual(res.expiryDate.getMonth(), item.m, `Month index mismatch for ${item.name}`);
      assert.strictEqual(res.expiryDate.getDate(), 15);
      assert.strictEqual(res.expiryDate.getFullYear(), 2027);
      assert.strictEqual(res.customerName, `User ${item.name}`);
    }
  });

  test('Adversarial dirty strings: multiple delimiters, nested dates, timestamps', () => {
    // Multiple pipes
    const multiPipe = parseExpiryFromComment('exp: 2027-05-20 | Pak Budi | RT 04 / RW 02 | Paket 20 Mbps');
    assert.ok(multiPipe.expiryDate);
    assert.strictEqual(multiPipe.customerName, 'Pak Budi | RT 04 / RW 02 | Paket 20 Mbps');

    // Date with timestamp inside brackets
    const timestampInBrackets = parseExpiryFromComment('(exp: 2027-06-10 18:45:00) Budi Santoso (0812-3456-7890)');
    assert.ok(timestampInBrackets.expiryDate);
    assert.strictEqual(timestampInBrackets.expiryDate.getDate(), 10);
    assert.strictEqual(timestampInBrackets.customerName, 'Budi Santoso (0812-3456-7890)');

    // Inverted format
    const inverted = parseExpiryFromComment('Pak Joko (Blok C1) | exp: 2027-07-22');
    assert.ok(inverted.expiryDate);
    assert.strictEqual(inverted.expiryDate.getDate(), 22);
    assert.strictEqual(inverted.customerName, 'Pak Joko (Blok C1)');
  });

  test('Fuzzing parseExpiryFromComment with 200 random noisy inputs does not throw', () => {
    const junkTokens = [
      'exp:', 'expired:', '|', '---', '2026/02/31', 'null', 'undefined',
      'NaN', '::1', '0812999999', 'paket-cepat', '$$$$', '&&&', '<script>',
    ];

    for (let i = 0; i < 200; i++) {
      const noisy = junkTokens.sort(() => 0.5 - Math.random()).slice(0, 5).join(' ');
      assert.doesNotThrow(() => {
        const res = parseExpiryFromComment(noisy);
        assert.ok(res !== null && typeof res === 'object');
        assert.ok(['active', 'expiring-soon', 'expired', 'no-expiry'].includes(res.status));
      }, `Crashed on noisy string: ${noisy}`);
    }
  });

  test('extendExpiryDate handles rollover across leap years and year boundaries', () => {
    // Dec 15 to Jan 14
    const decComment = 'exp: 2026-12-15 | User Akhir Tahun';
    const extendedDec = extendExpiryDate(decComment, 30);
    assert.strictEqual(extendedDec, 'exp: 2027-01-14 | User Akhir Tahun');

    // Leap year extension: 2028-02-10 + 30 days -> 2028-03-11 (since 2028 has 29 days in Feb)
    const leapComment = 'exp: 2028-02-10 | User Leap';
    const extendedLeap = extendExpiryDate(leapComment, 30);
    assert.strictEqual(extendedLeap, 'exp: 2028-03-11 | User Leap');

    // Extension from bare exp
    const bareComment = 'exp:';
    const extendedBare = extendExpiryDate(bareComment, 30);
    assert.match(extendedBare, /^exp: \d{4}-\d{2}-\d{2}$/);
  });

  test('buildExpiryComment strips redundant prefixes cleanly', () => {
    assert.strictEqual(
      buildExpiryComment('2026-11-20', 'exp: Pak Rudi'),
      'exp: 2026-11-20 | Pak Rudi'
    );
    assert.strictEqual(
      buildExpiryComment('2026-11-20', 'expired: Pak Rudi'),
      'exp: 2026-11-20 | Pak Rudi'
    );
    assert.strictEqual(
      buildExpiryComment('2026-11-20', 'Pak Rudi | exp: 2026-10-20'),
      'exp: 2026-11-20 | Pak Rudi'
    );
  });
});

describe('Challenger M2: MikroTik API Service Stress Testing', () => {
  test('buildBaseUrl handles diverse URLs, hosts, ports, and protocols', () => {
    // Standard host with default HTTP
    const u1 = mikrotikApiService.buildBaseUrl({ host: '192.168.88.1', port: 80, useHttps: false });
    assert.strictEqual(u1, 'http://192.168.88.1:80');

    // HTTPS with default 443
    const u2 = mikrotikApiService.buildBaseUrl({ host: '192.168.88.1', port: 443, useHttps: true });
    assert.strictEqual(u2, 'https://192.168.88.1:443');

    // User entered full URL with http:// and trailing path
    const u3 = mikrotikApiService.buildBaseUrl({ host: 'http://192.168.1.1/rest/system/resource', port: 80, useHttps: false });
    assert.strictEqual(u3, 'http://192.168.1.1:80');

    // User embedded port in host string
    const u4 = mikrotikApiService.buildBaseUrl({ host: '10.0.0.1:8080', port: 80, useHttps: false });
    assert.strictEqual(u4, 'http://10.0.0.1:8080');

    // IPv6 bracketed address
    const u5 = mikrotikApiService.buildBaseUrl({ host: '[2001:db8::1]', port: 80, useHttps: false });
    assert.strictEqual(u5, 'http://[2001:db8::1]:80');

    // IPv6 bracketed address with custom port
    const u6 = mikrotikApiService.buildBaseUrl({ host: '[2001:db8::1]:8443', port: 80, useHttps: true });
    assert.strictEqual(u6, 'https://[2001:db8::1]:8443');
  });

  test('getAuthHeader encodes standard and special characters safely', () => {
    // Basic standard credentials
    const h1 = mikrotikApiService.getAuthHeader({ username: 'admin', password: 'password123' });
    const decoded1 = Buffer.from(h1.replace('Basic ', ''), 'base64').toString('utf8');
    assert.strictEqual(decoded1, 'admin:password123');

    // Empty password
    const h2 = mikrotikApiService.getAuthHeader({ username: 'admin', password: '' });
    const decoded2 = Buffer.from(h2.replace('Basic ', ''), 'base64').toString('utf8');
    assert.strictEqual(decoded2, 'admin:');

    // Special UTF-8 characters in password
    const h3 = mikrotikApiService.getAuthHeader({ username: 'admin', password: 'p@sswørd!#123' });
    const decoded3 = Buffer.from(h3.replace('Basic ', ''), 'base64').toString('utf8');
    assert.strictEqual(decoded3, 'admin:p@sswørd!#123');
  });
});

describe('Challenger M2: Comprehensive Social Media Term Purification Audit', () => {
  test('Zero social media terms in UI labels, placeholders, titles, and text across src/', () => {
    function getAllSrcFiles(dir) {
      let files = [];
      const entries = fs.readdirSync(dir, { withFileTypes: true });
      for (const entry of entries) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) {
          files = files.concat(getAllSrcFiles(full));
        } else if (/\.(tsx|ts|html)$/.test(entry.name)) {
          files.push(full);
        }
      }
      return files;
    }

    const allFiles = getAllSrcFiles('src');
    allFiles.push('index.html');

    // Strict forbidden social media regex for user-facing words
    // Note: Exclude comments or backend schema keys like `secret.comment` or `lease.comment`
    const forbiddenSocialTerms = /\b(like|likes|dislike|share|shares|posting|postingan|komentar|teman|temanku|timeline|story|stories|beranda sosial|apa yang anda pikirkan)\b/i;

    const violations = [];

    for (const filePath of allFiles) {
      const content = fs.readFileSync(filePath, 'utf8');
      const lines = content.split('\n');
      for (let lineNum = 0; lineNum < lines.length; lineNum++) {
        const line = lines[lineNum];
        const trimmed = line.trim();

        // Skip code comments
        if (trimmed.startsWith('//') || trimmed.startsWith('/*') || trimmed.startsWith('*')) continue;

        // Skip data model / schema properties e.g. "comment?: string;" or "secret.comment"
        if (/comment\??:|\.comment\b|'comment'|"comment"/.test(line)) continue;

        const match = line.match(forbiddenSocialTerms);
        if (match) {
          violations.push({
            file: filePath,
            line: lineNum + 1,
            matched: match[0],
            snippet: trimmed,
          });
        }
      }
    }

    assert.strictEqual(
      violations.length,
      0,
      `Detected ${violations.length} forbidden social media terms:\n` +
        violations.map((v) => `  ${v.file}:${v.line} -> "${v.matched}" in "${v.snippet}"`).join('\n')
    );
  });
});
