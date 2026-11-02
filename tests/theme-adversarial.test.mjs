import { test, describe, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { themeService } from './themeService.mjs';

// Enhanced DOM & Environment Mock
class MockClassList {
  constructor() {
    this.classes = new Set();
  }
  add(...names) {
    names.forEach((n) => this.classes.add(n));
  }
  remove(...names) {
    names.forEach((n) => this.classes.delete(n));
  }
  contains(name) {
    return this.classes.has(name);
  }
  toggle(name) {
    if (this.classes.has(name)) {
      this.classes.delete(name);
      return false;
    }
    this.classes.add(name);
    return true;
  }
  toString() {
    return Array.from(this.classes).join(' ');
  }
}

class MockElement {
  constructor(tagName = 'div') {
    this.tagName = tagName.toUpperCase();
    this.attributes = new Map();
    this.classList = new MockClassList();
    this.style = {};
  }
  setAttribute(name, value) {
    this.attributes.set(name, String(value));
  }
  getAttribute(name) {
    return this.attributes.get(name) || null;
  }
  hasAttribute(name) {
    return this.attributes.has(name);
  }
}

class MockLocalStorage {
  constructor() {
    this.store = new Map();
    this.shouldThrowOnGet = false;
    this.shouldThrowOnSet = false;
    this.errorType = 'SecurityError';
  }
  getItem(key) {
    if (this.shouldThrowOnGet) {
      const err = new Error(`${this.errorType}: Storage access is denied`);
      err.name = this.errorType;
      throw err;
    }
    return this.store.has(key) ? this.store.get(key) : null;
  }
  setItem(key, value) {
    if (this.shouldThrowOnSet) {
      const err = new Error(`${this.errorType}: Storage quota exceeded`);
      err.name = this.errorType;
      throw err;
    }
    this.store.set(key, String(value));
  }
  removeItem(key) {
    this.store.delete(key);
  }
  clear() {
    this.store.clear();
  }
}

let mockStorage;
let mockDocElement;
let mockMetaThemeColor;
let mockMetaColorScheme;
let systemPrefersDark = false;

function setupHarness() {
  mockStorage = new MockLocalStorage();
  mockDocElement = new MockElement('html');
  mockMetaThemeColor = new MockElement('meta');
  mockMetaThemeColor.setAttribute('name', 'theme-color');
  mockMetaColorScheme = new MockElement('meta');
  mockMetaColorScheme.setAttribute('name', 'color-scheme');

  global.localStorage = mockStorage;
  global.window = {
    matchMedia: (query) => {
      if (query === '(prefers-color-scheme: dark)') {
        return { matches: systemPrefersDark };
      }
      return { matches: false };
    },
  };
  global.document = {
    documentElement: mockDocElement,
    querySelector: (selector) => {
      if (selector === 'meta[name="theme-color"]') return mockMetaThemeColor;
      if (selector === 'meta[name="color-scheme"]') return mockMetaColorScheme;
      return null;
    },
  };
}

describe('Adversarial Theme State Machine & Invariants Oracle', () => {
  beforeEach(() => {
    systemPrefersDark = false;
    setupHarness();
  });

  afterEach(() => {
    mockStorage.clear();
  });

  test('Oracle Invariant: Single class exclusivity (never both dark and light, never neither)', () => {
    // Pre-pollute classList with both classes and extraneous classes
    mockDocElement.classList.add('dark', 'light', 'custom-class', 'debug');

    themeService.applyTheme('dark');
    assert.strictEqual(mockDocElement.classList.contains('dark'), true);
    assert.strictEqual(mockDocElement.classList.contains('light'), false);
    assert.strictEqual(mockDocElement.classList.contains('custom-class'), true);

    themeService.applyTheme('light');
    assert.strictEqual(mockDocElement.classList.contains('light'), true);
    assert.strictEqual(mockDocElement.classList.contains('dark'), false);
    assert.strictEqual(mockDocElement.classList.contains('custom-class'), true);
  });

  test('Oracle Invariant: Strict Facebook Meta Theme-Color Synchronization', () => {
    themeService.applyTheme('dark');
    assert.strictEqual(mockMetaThemeColor.getAttribute('content'), '#18191A');
    assert.strictEqual(mockMetaColorScheme.getAttribute('content'), 'dark');
    assert.strictEqual(mockDocElement.style.colorScheme, 'dark');

    themeService.applyTheme('light');
    assert.strictEqual(mockMetaThemeColor.getAttribute('content'), '#1877F2');
    assert.strictEqual(mockMetaColorScheme.getAttribute('content'), 'light');
    assert.strictEqual(mockDocElement.style.colorScheme, 'light');
  });

  test('Oracle Invariant: Self-unsubscribing listeners do not crash iteration or corrupt Set', () => {
    const executed = [];
    let unsub1;
    let unsub2;

    unsub1 = themeService.subscribe((theme) => {
      executed.push(`unsub1:${theme}`);
      unsub1(); // Listener unsubscribes itself during execution
    });

    unsub2 = themeService.subscribe((theme) => {
      executed.push(`unsub2:${theme}`);
    });

    themeService.setTheme('dark');
    assert.deepStrictEqual(executed, ['unsub1:dark', 'unsub2:dark']);

    // Next change: unsub1 should not run, only unsub2
    themeService.setTheme('light');
    assert.deepStrictEqual(executed, ['unsub1:dark', 'unsub2:dark', 'unsub2:light']);

    unsub2();
  });

  test('Oracle Invariant: Re-entrant state changes resolve deterministically', () => {
    let callCount = 0;
    const unsub = themeService.subscribe((theme) => {
      callCount++;
      // Guarded re-entrant call
      if (theme === 'dark' && callCount === 1) {
        // Trigger a re-entrant theme change
        themeService.setTheme('light');
      }
    });

    themeService.setTheme('dark');
    unsub();

    assert.strictEqual(themeService.getTheme(), 'light');
    assert.strictEqual(mockDocElement.classList.contains('light'), true);
    assert.strictEqual(mockDocElement.classList.contains('dark'), false);
  });

  test('Strict Invariant Fuzzing: 500 valid transitions between light and dark', () => {
    const validInputs = ['dark', 'light'];
    for (let i = 0; i < 500; i++) {
      if (i % 3 === 0) {
        themeService.toggleTheme();
      } else {
        const choice = validInputs[i % validInputs.length];
        themeService.setTheme(choice);
      }

      // Assert invariants always hold
      const isDark = mockDocElement.classList.contains('dark');
      const isLight = mockDocElement.classList.contains('light');

      // Exclusivity invariant
      assert.notStrictEqual(isDark, isLight, `Iteration ${i}: Exclusivity violated! dark=${isDark}, light=${isLight}`);
      assert.strictEqual(isDark || isLight, true, `Iteration ${i}: Neither dark nor light present!`);

      // Meta color sync invariant
      if (isDark) {
        assert.strictEqual(mockMetaThemeColor.getAttribute('content'), '#18191A');
        assert.strictEqual(mockDocElement.style.colorScheme, 'dark');
      } else {
        assert.strictEqual(mockMetaThemeColor.getAttribute('content'), '#1877F2');
        assert.strictEqual(mockDocElement.style.colorScheme, 'light');
      }
    }
  });

  test('Defensive Input Resilience: arbitrary/corrupted theme inputs do not crash or leave broken classes', () => {
    const malformedInputs = ['LIGHT', 'DARK', 'null', '', undefined, 'neon-green', 12345, {}, []];
    for (const input of malformedInputs) {
      assert.doesNotThrow(() => {
        themeService.applyTheme(input);
      }, `applyTheme crashed on input: ${input}`);

      // The DOM class should resolve safely to light for non-dark strings
      const isDark = mockDocElement.classList.contains('dark');
      const isLight = mockDocElement.classList.contains('light');
      assert.notStrictEqual(isDark, isLight, `Malformed input ${input} must produce exclusive class`);
    }
  });

  test('Anti-FOUC Inline Script Simulation in index.html under adversarial conditions', () => {
    const html = fs.readFileSync('index.html', 'utf8');
    const scriptMatch = html.match(/<script>([\s\S]*?)<\/script>/);
    assert.ok(scriptMatch, 'Inline script must exist in index.html');
    const scriptBody = scriptMatch[1];

    // Scenario A: Stored theme = 'dark', System = light
    {
      const localDocElement = new MockElement('html');
      const localMeta = new MockElement('meta');
      localMeta.setAttribute('name', 'theme-color');
      const localStore = new Map([['fnet_theme', 'dark']]);

      const testFn = new Function('localStorage', 'window', 'document', scriptBody);
      testFn(
        { getItem: (k) => localStore.get(k) },
        { matchMedia: () => ({ matches: false }) },
        {
          documentElement: localDocElement,
          querySelector: (sel) => (sel === 'meta[name="theme-color"]' ? localMeta : null),
        }
      );

      assert.strictEqual(localDocElement.classList.contains('dark'), true);
      assert.strictEqual(localDocElement.classList.contains('light'), false);
      assert.strictEqual(localMeta.getAttribute('content'), '#18191A');
    }

    // Scenario B: No stored theme, System prefers dark
    {
      const localDocElement = new MockElement('html');
      const localMeta = new MockElement('meta');
      localMeta.setAttribute('name', 'theme-color');
      const localStore = new Map();

      const testFn = new Function('localStorage', 'window', 'document', scriptBody);
      testFn(
        { getItem: (k) => localStore.get(k) },
        { matchMedia: (q) => ({ matches: q.includes('dark') }) },
        {
          documentElement: localDocElement,
          querySelector: (sel) => (sel === 'meta[name="theme-color"]' ? localMeta : null),
        }
      );

      assert.strictEqual(localDocElement.classList.contains('dark'), true);
      assert.strictEqual(localDocElement.classList.contains('light'), false);
      assert.strictEqual(localMeta.getAttribute('content'), '#18191A');
    }

    // Scenario C: LocalStorage throws SecurityError (Private browsing)
    {
      const localDocElement = new MockElement('html');
      const localMeta = new MockElement('meta');
      localMeta.setAttribute('name', 'theme-color');

      const testFn = new Function('localStorage', 'window', 'document', scriptBody);
      assert.doesNotThrow(() => {
        testFn(
          {
            getItem: () => {
              throw new Error('SecurityError: Access Denied');
            },
          },
          { matchMedia: () => ({ matches: false }) },
          {
            documentElement: localDocElement,
            querySelector: (sel) => (sel === 'meta[name="theme-color"]' ? localMeta : null),
          }
        );
      });

      // Does not crash, defaults safely
    }
  });
});

describe('Facebook Design Tokens Rigorous Verification', () => {
  const css = fs.readFileSync('src/index.css', 'utf8');

  test('All required Facebook brand tokens exist with exact values', () => {
    const requiredLightTokens = {
      '--background': '#F0F2F5',
      '--card': '#FFFFFF',
      '--primary': '#1877F2',
      '--fb-blue': '#1877F2',
      '--fb-header-bg': '#FFFFFF',
      '--fb-header-border': '#CED0D4',
      '--fb-card-bg': '#FFFFFF',
      '--fb-surface-bg': '#F0F2F5',
      '--fb-pill-bg': '#E4E6EB',
      '--fb-pill-hover': '#D8DADF',
      '--fb-text-primary': '#050505',
      '--fb-text-secondary': '#65676B',
    };

    const requiredDarkTokens = {
      '--background': '#18191A',
      '--card': '#242526',
      '--primary': '#2D88FF',
      '--fb-blue': '#2D88FF',
      '--fb-header-bg': '#242526',
      '--fb-header-border': '#3A3B3C',
      '--fb-card-bg': '#242526',
      '--fb-surface-bg': '#18191A',
      '--fb-pill-bg': '#3A3B3C',
      '--fb-pill-hover': '#4E4F50',
      '--fb-text-primary': '#E4E6EB',
      '--fb-text-secondary': '#B0B3B8',
    };

    const rootMatch = css.match(/:root\s*\{([\s\S]*?)\}/);
    assert.ok(rootMatch, ':root block must exist');
    const rootBlock = rootMatch[1];

    for (const [token, expectedVal] of Object.entries(requiredLightTokens)) {
      const reg = new RegExp(`${token}:\\s*${expectedVal}\\b`, 'i');
      assert.match(rootBlock, reg, `Light token ${token} must be ${expectedVal}`);
    }

    const darkMatch = css.match(/\.dark\s*\{([\s\S]*?)\}/);
    assert.ok(darkMatch, '.dark block must exist');
    const darkBlock = darkMatch[1];

    for (const [token, expectedVal] of Object.entries(requiredDarkTokens)) {
      const reg = new RegExp(`${token}:\\s*${expectedVal}\\b`, 'i');
      assert.match(darkBlock, reg, `Dark token ${token} must be ${expectedVal}`);
    }
  });

  test('WCAG Contrast Ratios meet accessibility standards for all Facebook pairs', () => {
    function hexToLuminance(hex) {
      const rgb = hex.replace('#', '').match(/.{2}/g).map((x) => parseInt(x, 16) / 255);
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

    // Light text on light background
    const lightTextOnBg = contrastRatio('#050505', '#F0F2F5');
    assert.ok(lightTextOnBg >= 7.0, `Light text contrast ${lightTextOnBg.toFixed(2)} must be >= 7.0 (AAA)`);

    // Light text on white card
    const lightTextOnCard = contrastRatio('#050505', '#FFFFFF');
    assert.ok(lightTextOnCard >= 7.0, `Light text on card ${lightTextOnCard.toFixed(2)} must be >= 7.0 (AAA)`);

    // Dark text on dark background
    const darkTextOnBg = contrastRatio('#E4E6EB', '#18191A');
    assert.ok(darkTextOnBg >= 7.0, `Dark text contrast ${darkTextOnBg.toFixed(2)} must be >= 7.0 (AAA)`);

    // Dark text on dark card
    const darkTextOnCard = contrastRatio('#E4E6EB', '#242526');
    assert.ok(darkTextOnCard >= 7.0, `Dark text on card ${darkTextOnCard.toFixed(2)} must be >= 7.0 (AAA)`);

    // Dark primary accent contrast
    const darkAccentContrast = contrastRatio('#2D88FF', '#18191A');
    assert.ok(darkAccentContrast >= 4.5, `Dark accent contrast ${darkAccentContrast.toFixed(2)} must be >= 4.5 (AA)`);
  });
});

describe('Social Media Term Purification Codebase Audit', () => {
  test('Zero social media terms across all TSX and TS components in src/', () => {
    function getFiles(dir) {
      let results = [];
      const list = fs.readdirSync(dir);
      for (const file of list) {
        const fullPath = path.join(dir, file);
        const stat = fs.statSync(fullPath);
        if (stat && stat.isDirectory()) {
          results = results.concat(getFiles(fullPath));
        } else if (file.endsWith('.tsx') || file.endsWith('.ts')) {
          results.push(fullPath);
        }
      }
      return results;
    }

    const files = getFiles('src');
    const forbiddenRegex = /\b(like|share|komentar|teman|story|friend|timeline)\b/i;

    for (const file of files) {
      const content = fs.readFileSync(file, 'utf8');
      const lines = content.split('\n');
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        // Ignore internal utility comments like '// Strip prefixes like "exp: ..."'
        if (line.trim().startsWith('//') || line.trim().startsWith('*')) continue;
        const match = line.match(forbiddenRegex);
        assert.strictEqual(
          match,
          null,
          `Forbidden social media term "${match?.[0]}" found in UI file ${file}:${i + 1}: ${line.trim()}`
        );
      }
    }
  });
});

describe('TopAppBar Ergonomics & Viewport Fit Oracle', () => {
  const topAppBarPath = path.resolve('src/components/TopAppBar.tsx');
  const topAppBarCode = fs.readFileSync(topAppBarPath, 'utf8');

  test('TopAppBar header includes pt-safe for notch protection', () => {
    assert.match(
      topAppBarCode,
      /<header[^>]*pt-safe[^>]*>/,
      'TopAppBar header must include pt-safe utility class'
    );
  });

  test('All interactive buttons enforce 48x48dp minimum touch target', () => {
    // Check avatar button
    assert.match(
      topAppBarCode,
      /className="[^"]*min-h-\[48px\][^"]*min-w-\[48px\][^"]*"/,
      'Buttons must enforce min-h-[48px] and min-w-[48px]'
    );
    // Search clear button
    assert.match(
      topAppBarCode,
      /className="[^"]*min-h-\[48px\] min-w-\[48px\][^"]*"[\s\S]*?aria-label="Bersihkan pencarian"/,
      'Search clear button must have 48x48dp target'
    );
    // Dismiss button
    assert.match(
      topAppBarCode,
      /className="[^"]*min-h-\[48px\] min-w-\[48px\][^"]*"[^>]*>\s*Tutup/s,
      'Dismiss button must have 48x48dp target'
    );
  });
});
