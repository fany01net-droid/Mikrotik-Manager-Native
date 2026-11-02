import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

describe('Milestone 1 Layout & Touch Ergonomics Challenge', () => {
  const topAppBarCode = fs.readFileSync('src/components/TopAppBar.tsx', 'utf8');
  const bottomNavBarCode = fs.readFileSync('src/components/BottomNavBar.tsx', 'utf8');
  const appCode = fs.readFileSync('src/App.tsx', 'utf8');
  const indexCss = fs.readFileSync('src/index.css', 'utf8');
  const indexHtml = fs.readFileSync('index.html', 'utf8');

  describe('R1. Bottom Navigation Bar Ergonomics & Touch Targets', () => {
    test('all tabs enforce min-h-[52px] and min-w-[48px]', () => {
      assert.ok(bottomNavBarCode.includes('min-h-[52px]'), 'BottomNavBar should have min-h-[52px]');
      assert.ok(bottomNavBarCode.includes('min-w-[48px]'), 'BottomNavBar should have min-w-[48px]');
    });

    test('bottom navigation includes safe area inset bottom padding', () => {
      assert.ok(
        bottomNavBarCode.includes('safe-area-inset-bottom'),
        'BottomNavBar must include env(safe-area-inset-bottom)'
      );
    });

    test('bottom navigation hides automatically when virtual keyboard is open', () => {
      assert.ok(
        bottomNavBarCode.includes("isKeyboardOpen ? 'translate-y-full pointer-events-none' : 'translate-y-0'"),
        'BottomNavBar must translate offscreen when keyboard is open'
      );
    });
  });

  describe('R2. Top App Bar Touch Targets (48x48 dp)', () => {
    test('brand emblem enforces min-h-[48px] and min-w-[48px]', () => {
      assert.ok(topAppBarCode.includes('min-h-[48px] min-w-[48px] items-center justify-center rounded-full bg-[#1877F2]'));
    });

    test('theme toggle button enforces min-h-[48px] and min-w-[48px]', () => {
      assert.ok(topAppBarCode.includes('min-h-[48px] min-w-[48px] w-12 h-12 rounded-full bg-secondary hover:bg-muted text-foreground transition active:scale-95 cursor-pointer border border-border/40 focus:outline-none focus:ring-2 focus:ring-[#1877F2]'));
    });

    test('auto-refresh button enforces min-h-[48px] and min-w-[48px]', () => {
      assert.ok(topAppBarCode.includes('min-h-[48px] min-w-[48px] w-12 h-12 rounded-full transition active:scale-95 cursor-pointer border focus:outline-none'));
    });

    test('manual refresh button enforces min-h-[48px] and min-w-[48px]', () => {
      assert.ok(topAppBarCode.includes('min-h-[48px] min-w-[48px] w-12 h-12 rounded-full bg-secondary hover:bg-muted text-foreground border border-border/40 transition active:scale-95 cursor-pointer disabled:opacity-50'));
    });

    test('mobile search toggle button enforces min-h-[48px] and min-w-[48px]', () => {
      assert.ok(topAppBarCode.includes('md:hidden flex items-center justify-center min-h-[48px] min-w-[48px] w-12 h-12'));
    });

    test('DEFECT CHECK: router profile avatar button enforces explicit min-w-[48px]', () => {
      // Line 150 to 156
      const lines = topAppBarCode.split('\n');
      const avatarBtnTag = lines.slice(149, 157).join(' ');
      assert.ok(avatarBtnTag.includes('min-h-[48px]'), 'Has min-h-[48px]');
      assert.strictEqual(
        avatarBtnTag.includes('min-w-[48px]'),
        true,
        'Router avatar button at line 150 lacks explicit min-w-[48px] class: ' + avatarBtnTag.trim()
      );
    });

    test('DEFECT CHECK: search clear button has 48x48 dp touch target', () => {
      // Find clear search button on line 325 (mobile)
      const lines = topAppBarCode.split('\n');
      const mobileClearBtn = lines.slice(324, 331).join(' ');
      const has48 = mobileClearBtn.includes('min-h-[48px]') || mobileClearBtn.includes('h-12');
      assert.strictEqual(
        has48,
        true,
        'Mobile search clear button at line 325 lacks 48x48dp target (found: ' + mobileClearBtn.trim() + ')'
      );
    });

    test('DEFECT CHECK: mobile search Tutup button has 48x48 dp touch target', () => {
      const lines = topAppBarCode.split('\n');
      const tutupBtn = lines.slice(333, 339).join(' ');
      const has48 = tutupBtn.includes('min-h-[48px]') || tutupBtn.includes('h-12');
      assert.strictEqual(
        has48,
        true,
        'Mobile search Tutup button at line 334 lacks 48x48dp target: ' + tutupBtn.trim()
      );
    });

    test('DEFECT CHECK: TopAppBar header supports safe area inset top (notch protection)', () => {
      const match = topAppBarCode.match(/<header\b([\s\S]*?)>/);
      assert.ok(match, 'TopAppBar header exists');
      const hasPtSafe = match[1].includes('pt-safe') || match[1].includes('safe-area-inset-top');
      assert.strictEqual(
        hasPtSafe,
        true,
        'TopAppBar header missing pt-safe or env(safe-area-inset-top) while viewport-fit=cover is configured in index.html'
      );
    });
  });

  describe('R3. Social Media Term Purification', () => {
    test('zero social media terms in UI markup and labels', () => {
      const filesToCheck = [
        'src/components/TopAppBar.tsx',
        'src/components/BottomNavBar.tsx',
        'src/App.tsx',
        'src/main.tsx',
        'index.html',
      ];
      const forbiddenRegex = /\b(like|share|post|komentar|teman|story|friend)\b/i;
      for (const f of filesToCheck) {
        const content = fs.readFileSync(f, 'utf8');
        const lines = content.split('\n');
        for (let i = 0; i < lines.length; i++) {
          const m = lines[i].match(forbiddenRegex);
          assert.strictEqual(
            m,
            null,
            `Forbidden social media term "${m?.[0]}" found in ${f}:${i + 1}: ${lines[i].trim()}`
          );
        }
      }
    });
  });
});
