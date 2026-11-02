import { test, describe, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { themeService } from './themeService.mjs';

// DOM & Web API Mock Harness
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
    } else {
      this.classes.add(name);
      return true;
    }
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
  }
  getItem(key) {
    if (this.shouldThrowOnGet) throw new Error('SecurityError: Access denied');
    return this.store.has(key) ? this.store.get(key) : null;
  }
  setItem(key, value) {
    if (this.shouldThrowOnSet) throw new Error('QuotaExceededError: Storage quota exceeded');
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

function setupMockEnvironment() {
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

describe('Theme Service & State Verifier', () => {
  beforeEach(() => {
    systemPrefersDark = false;
    setupMockEnvironment();
  });

  afterEach(() => {
    mockStorage.clear();
  });

  describe('Theme Detection & Preference Resolution', () => {
    test('defaults to light mode when no preference stored and system prefers light', () => {
      systemPrefersDark = false;
      assert.strictEqual(themeService.getTheme(), 'light');
    });

    test('defaults to dark mode when no preference stored and system prefers dark', () => {
      systemPrefersDark = true;
      assert.strictEqual(themeService.getTheme(), 'dark');
    });

    test('stored preference "light" overrides system dark preference', () => {
      systemPrefersDark = true;
      mockStorage.setItem('fnet_theme', 'light');
      assert.strictEqual(themeService.getTheme(), 'light');
    });

    test('stored preference "dark" overrides system light preference', () => {
      systemPrefersDark = false;
      mockStorage.setItem('fnet_theme', 'dark');
      assert.strictEqual(themeService.getTheme(), 'dark');
    });

    test('corrupted or invalid stored values safely fall back to system preference', () => {
      systemPrefersDark = true;
      mockStorage.setItem('fnet_theme', 'neon-cyber');
      assert.strictEqual(themeService.getTheme(), 'dark');

      systemPrefersDark = false;
      mockStorage.setItem('fnet_theme', '12345');
      assert.strictEqual(themeService.getTheme(), 'light');
    });

    test('recovers safely when localStorage throws SecurityError', () => {
      mockStorage.shouldThrowOnGet = true;
      assert.doesNotThrow(() => {
        const theme = themeService.getTheme();
        assert.strictEqual(theme, 'light');
      });
    });
  });

  describe('Theme Application & DOM Synchronization', () => {
    test('applyTheme("dark") updates classList, colorScheme, and meta tags with Facebook dark tokens', () => {
      themeService.applyTheme('dark');

      assert.strictEqual(mockDocElement.classList.contains('dark'), true);
      assert.strictEqual(mockDocElement.classList.contains('light'), false);
      assert.strictEqual(mockDocElement.style.colorScheme, 'dark');
      assert.strictEqual(mockMetaThemeColor.getAttribute('content'), '#18191A');
      assert.strictEqual(mockMetaColorScheme.getAttribute('content'), 'dark');
    });

    test('applyTheme("light") updates classList, colorScheme, and meta tags with Facebook light tokens', () => {
      // First set dark
      themeService.applyTheme('dark');
      assert.strictEqual(mockDocElement.classList.contains('dark'), true);

      // Now switch to light
      themeService.applyTheme('light');
      assert.strictEqual(mockDocElement.classList.contains('light'), true);
      assert.strictEqual(mockDocElement.classList.contains('dark'), false);
      assert.strictEqual(mockDocElement.style.colorScheme, 'light');
      assert.strictEqual(mockMetaThemeColor.getAttribute('content'), '#1877F2');
      assert.strictEqual(mockMetaColorScheme.getAttribute('content'), 'light');
    });

    test('applyTheme handles missing meta tags gracefully without throwing', () => {
      global.document.querySelector = () => null;

      assert.doesNotThrow(() => {
        themeService.applyTheme('dark');
      });
      assert.strictEqual(mockDocElement.classList.contains('dark'), true);
    });

    test('applyTheme handles undefined document (SSR / Headless) gracefully', () => {
      const origDoc = global.document;
      delete global.document;

      assert.doesNotThrow(() => {
        themeService.applyTheme('dark');
      });

      global.document = origDoc;
    });
  });

  describe('setTheme, toggleTheme, and Persistence', () => {
    test('setTheme("dark") persists to localStorage and updates DOM', () => {
      themeService.setTheme('dark');

      assert.strictEqual(mockStorage.getItem('fnet_theme'), 'dark');
      assert.strictEqual(mockDocElement.classList.contains('dark'), true);
      assert.strictEqual(mockMetaThemeColor.getAttribute('content'), '#18191A');
    });

    test('setTheme("light") persists to localStorage and updates DOM', () => {
      themeService.setTheme('light');

      assert.strictEqual(mockStorage.getItem('fnet_theme'), 'light');
      assert.strictEqual(mockDocElement.classList.contains('light'), true);
      assert.strictEqual(mockMetaThemeColor.getAttribute('content'), '#1877F2');
    });

    test('setTheme still applies theme even if localStorage.setItem fails (quota exceeded)', () => {
      mockStorage.shouldThrowOnSet = true;

      assert.doesNotThrow(() => {
        themeService.setTheme('dark');
      });
      assert.strictEqual(mockDocElement.classList.contains('dark'), true);
    });

    test('toggleTheme toggles back and forth between light and dark across multiple invocations', () => {
      mockStorage.setItem('fnet_theme', 'light');

      const next1 = themeService.toggleTheme();
      assert.strictEqual(next1, 'dark');
      assert.strictEqual(mockStorage.getItem('fnet_theme'), 'dark');
      assert.strictEqual(mockDocElement.classList.contains('dark'), true);

      const next2 = themeService.toggleTheme();
      assert.strictEqual(next2, 'light');
      assert.strictEqual(mockStorage.getItem('fnet_theme'), 'light');
      assert.strictEqual(mockDocElement.classList.contains('light'), true);

      const next3 = themeService.toggleTheme();
      assert.strictEqual(next3, 'dark');
      assert.strictEqual(mockStorage.getItem('fnet_theme'), 'dark');
    });

    test('initTheme initializes DOM from storage and returns current theme', () => {
      mockStorage.setItem('fnet_theme', 'dark');
      const active = themeService.initTheme();

      assert.strictEqual(active, 'dark');
      assert.strictEqual(mockDocElement.classList.contains('dark'), true);
      assert.strictEqual(mockMetaThemeColor.getAttribute('content'), '#18191A');
    });
  });

  describe('Event Subscription & Listener Resilience', () => {
    test('listeners receive theme change notifications on setTheme and toggleTheme', () => {
      const received = [];
      const unsub = themeService.subscribe((theme) => {
        received.push(theme);
      });

      themeService.setTheme('dark');
      themeService.toggleTheme();
      themeService.setTheme('dark');

      assert.deepStrictEqual(received, ['dark', 'light', 'dark']);
      unsub();

      themeService.setTheme('light');
      // No more events after unsubscribe
      assert.deepStrictEqual(received, ['dark', 'light', 'dark']);
    });

    test('throwing listener does not prevent other listeners from executing', () => {
      const goodListenerReceived = [];

      const unsubBad = themeService.subscribe(() => {
        throw new Error('Exploding listener');
      });

      const unsubGood = themeService.subscribe((theme) => {
        goodListenerReceived.push(theme);
      });

      assert.doesNotThrow(() => {
        themeService.setTheme('dark');
      });

      assert.strictEqual(goodListenerReceived.length, 1);
      assert.strictEqual(goodListenerReceived[0], 'dark');

      unsubBad();
      unsubGood();
    });
  });

  describe('Adversarial Stress Testing & Fuzzing', () => {
    test('rapid alternating toggles (100 iterations) maintain strict consistency', () => {
      themeService.setTheme('light');
      let current = 'light';

      for (let i = 0; i < 100; i++) {
        const next = themeService.toggleTheme();
        const expected = current === 'light' ? 'dark' : 'light';
        assert.strictEqual(next, expected, `Toggle iteration ${i} mismatch`);
        assert.strictEqual(mockStorage.getItem('fnet_theme'), expected);
        assert.strictEqual(mockDocElement.classList.contains(expected), true);
        assert.strictEqual(mockDocElement.classList.contains(current), false);
        current = expected;
      }
    });

    test('fuzzing setTheme with arbitrary strings or nullish values behaves deterministically', () => {
      // Non-dark values resolve to isDark = false in applyTheme
      themeService.applyTheme('neon-green');
      assert.strictEqual(mockDocElement.classList.contains('light'), true);
      assert.strictEqual(mockDocElement.classList.contains('dark'), false);
      assert.strictEqual(mockMetaThemeColor.getAttribute('content'), '#1877F2');

      themeService.applyTheme(null);
      assert.strictEqual(mockDocElement.classList.contains('light'), true);
      assert.strictEqual(mockDocElement.classList.contains('dark'), false);

      themeService.applyTheme(undefined);
      assert.strictEqual(mockDocElement.classList.contains('light'), true);
      assert.strictEqual(mockDocElement.classList.contains('dark'), false);
    });

    test('subscriber scale test: 50 concurrent listeners all receive updates and clean up without leak', () => {
      const results = new Array(50).fill(null).map(() => []);
      const unsubs = [];

      for (let i = 0; i < 50; i++) {
        const idx = i;
        unsubs.push(themeService.subscribe((t) => results[idx].push(t)));
      }

      themeService.setTheme('dark');
      themeService.setTheme('light');

      results.forEach((arr, i) => {
        assert.deepStrictEqual(arr, ['dark', 'light'], `Listener ${i} failed to receive updates`);
      });

      // Cleanup
      unsubs.forEach((unsub) => unsub());

      themeService.setTheme('dark');
      results.forEach((arr, i) => {
        assert.strictEqual(arr.length, 2, `Listener ${i} received unexpected update after unsub`);
      });
    });
  });
});

describe('Facebook Light & Dark CSS Tokens Specification', () => {
  const cssPath = path.resolve('src/index.css');
  const cssContent = fs.readFileSync(cssPath, 'utf8');

  test('src/index.css defines exact Facebook Light mode tokens in :root', () => {
    // Extract :root block
    const rootMatch = cssContent.match(/:root\s*\{([\s\S]*?)\}/);
    assert.ok(rootMatch, ':root block must exist in index.css');
    const rootBlock = rootMatch[1];

    // Facebook specification: Light mode
    // Background: #F0F2F5
    assert.match(rootBlock, /--background:\s*#F0F2F5/i, 'Light background must be #F0F2F5');
    // Card: #FFFFFF
    assert.match(rootBlock, /--card:\s*#FFFFFF/i, 'Light card must be #FFFFFF');
    // Primary: #1877F2
    assert.match(rootBlock, /--primary:\s*#1877F2/i, 'Light primary must be #1877F2');
    // Facebook specific token: --fb-blue: #1877F2
    assert.match(rootBlock, /--fb-blue:\s*#1877F2/i, '--fb-blue must be #1877F2');
    // Facebook surface bg: #F0F2F5
    assert.match(rootBlock, /--fb-surface-bg:\s*#F0F2F5/i, '--fb-surface-bg must be #F0F2F5');
    // Facebook card bg: #FFFFFF
    assert.match(rootBlock, /--fb-card-bg:\s*#FFFFFF/i, '--fb-card-bg must be #FFFFFF');
  });

  test('src/index.css defines exact Facebook Dark mode tokens in .dark', () => {
    // Extract .dark block
    const darkMatch = cssContent.match(/\.dark\s*\{([\s\S]*?)\}/);
    assert.ok(darkMatch, '.dark block must exist in index.css');
    const darkBlock = darkMatch[1];

    // Facebook specification: Dark mode
    // Background: #18191A
    assert.match(darkBlock, /--background:\s*#18191A/i, 'Dark background must be #18191A');
    // Card: #242526
    assert.match(darkBlock, /--card:\s*#242526/i, 'Dark card must be #242526');
    // Primary: #2D88FF
    assert.match(darkBlock, /--primary:\s*#2D88FF/i, 'Dark primary must be #2D88FF');
    // Facebook specific token: --fb-blue: #2D88FF
    assert.match(darkBlock, /--fb-blue:\s*#2D88FF/i, '--fb-blue must be #2D88FF');
    // Facebook surface bg: #18191A
    assert.match(darkBlock, /--fb-surface-bg:\s*#18191A/i, '--fb-surface-bg must be #18191A');
    // Facebook card bg: #242526
    assert.match(darkBlock, /--fb-card-bg:\s*#242526/i, '--fb-card-bg must be #242526');
  });

  test('index.html inline script synchronizes theme without flashing', () => {
    const htmlPath = path.resolve('index.html');
    const htmlContent = fs.readFileSync(htmlPath, 'utf8');

    // Must check fnet_theme localStorage key
    assert.match(htmlContent, /localStorage\.getItem\(['"]fnet_theme['"]\)/, 'Must read fnet_theme');
    // Must handle meta theme-color #18191A for dark and #1877F2 for light
    assert.match(htmlContent, /#18191A/, 'Must set #18191A meta theme-color for dark');
    assert.match(htmlContent, /#1877F2/, 'Must set #1877F2 meta theme-color for light');
    // Must add/remove dark/light class
    assert.match(htmlContent, /classList\.add\(['"]dark['"]\)/);
    assert.match(htmlContent, /classList\.remove\(['"]light['"]\)/);
  });
});
