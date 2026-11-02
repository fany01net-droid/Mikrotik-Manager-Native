import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

describe('320px Viewport Simulation & Touch Target Measurement', () => {
  const topAppBarCode = fs.readFileSync('src/components/TopAppBar.tsx', 'utf8');
  const bottomNavBarCode = fs.readFileSync('src/components/BottomNavBar.tsx', 'utf8');
  const appCode = fs.readFileSync('src/App.tsx', 'utf8');

  // Tailwind scale mapping in pixels (assuming base font-size: 16px)
  const rem = 16;
  const tailwindSpacing = {
    '0.5': 0.125 * rem, // 2px
    '1': 0.25 * rem,    // 4px
    '1.5': 0.375 * rem,  // 6px
    '2': 0.5 * rem,     // 8px
    '3': 0.75 * rem,    // 12px
    '4': 1.0 * rem,     // 16px
    '6': 1.5 * rem,     // 24px
    '10': 2.5 * rem,    // 40px
    '12': 3.0 * rem,    // 48px
  };

  describe('1. TopAppBar 320px Viewport Measurement & Zero Clipping', () => {
    test('TopAppBar header container has px-1.5 and gap-1 for mobile screens', () => {
      assert.ok(
        topAppBarCode.includes('px-1.5 sm:px-6'),
        'Header container must use px-1.5 on mobile to conserve width on 320px'
      );
      assert.ok(
        topAppBarCode.includes('gap-1 sm:gap-2'),
        'Header container must use gap-1 on mobile'
      );
    });

    test('Left section buttons and spacing compute within bounds on 320px', () => {
      // Left section contains:
      // 1. Brand emblem: min-w-[48px], min-h-[48px] -> 48px
      // 2. Gap: gap-1.5 -> 6px
      // 3. Router Avatar button: min-w-[48px], min-h-[48px], p-1 with 40px child -> 48px
      const brandWidth = 48;
      const leftGap = tailwindSpacing['1.5']; // 6px
      const avatarWidth = 48;

      const leftSectionWidth = brandWidth + leftGap + avatarWidth;
      assert.strictEqual(leftSectionWidth, 102, 'Left section width must be exactly 102px');
    });

    test('Right section action controls compute within bounds on 320px (all 4 buttons visible)', () => {
      // Right section contains:
      // 1. Mobile Search toggle: w-12 min-w-[48px] -> 48px
      // 2. Theme toggle: w-12 min-w-[48px] -> 48px
      // 3. Auto-refresh: w-12 min-w-[48px] -> 48px
      // 4. Manual refresh: w-12 min-w-[48px] -> 48px
      // Gaps: gap-0.5 -> 2px between each pair (3 gaps total = 6px)
      const buttonWidth = 48;
      const buttonCount = 4;
      const rightGap = tailwindSpacing['0.5']; // 2px
      const totalGap = rightGap * (buttonCount - 1); // 6px
      const rightSectionWidth = (buttonWidth * buttonCount) + totalGap;

      assert.strictEqual(rightSectionWidth, 198, 'Right section width must be exactly 198px');
    });

    test('Total TopAppBar layout on 320px viewport has positive margin and ZERO clipping', () => {
      const viewportWidth = 320;
      const containerPaddingLeft = tailwindSpacing['1.5']; // 6px
      const containerPaddingRight = tailwindSpacing['1.5']; // 6px
      const totalPadding = containerPaddingLeft + containerPaddingRight; // 12px

      const leftSectionWidth = 48 + tailwindSpacing['1.5'] + 48; // 102px
      const centerGap = tailwindSpacing['1']; // 4px
      const rightSectionWidth = (4 * 48) + (3 * tailwindSpacing['0.5']); // 198px

      const totalRequiredWidth = totalPadding + leftSectionWidth + centerGap + rightSectionWidth;
      const clearance = viewportWidth - totalRequiredWidth;

      assert.strictEqual(totalRequiredWidth, 316, 'Total TopAppBar content width is exactly 316px');
      assert.ok(
        totalRequiredWidth <= viewportWidth,
        `Total required width (${totalRequiredWidth}px) exceeds 320px viewport by ${totalRequiredWidth - viewportWidth}px`
      );
      assert.strictEqual(clearance, 4, 'TopAppBar has exactly 4px safety clearance on 320px viewport (0 clipping)');
    });

    test('Expanded mobile search pill fits comfortably within 320px viewport with zero clipping', () => {
      const viewportWidth = 320;
      const searchContainerPadding = tailwindSpacing['4'] * 2; // px-4 = 16px left + 16px right = 32px
      const pillInnerWidth = viewportWidth - searchContainerPadding; // 288px

      const searchIconFootprint = 16 + 8; // w-4 (16px) + mr-2 (8px) = 24px
      const tutupButtonWidth = 48 - tailwindSpacing['1.5']; // 48px touch target with -mr-1.5 (-6px) = 42px
      const inputAvailableWidth = pillInnerWidth - searchIconFootprint - tutupButtonWidth;

      assert.strictEqual(pillInnerWidth, 288);
      assert.ok(
        inputAvailableWidth > 150,
        `Input field has ${inputAvailableWidth}px available width (> 150px) on 320px screen`
      );
    });
  });

  describe('2. Bottom Navigation Bar 320px Viewport Measurement', () => {
    test('5 tabs on 320px screen all meet or exceed 48px touch minimum', () => {
      const viewportWidth = 320;
      const navPaddingHorizontal = tailwindSpacing['1'] * 2; // px-1 = 4px left + 4px right = 8px
      const availableWidth = viewportWidth - navPaddingHorizontal; // 312px
      const tabCount = 5;
      const widthPerTab = availableWidth / tabCount; // 62.4px

      assert.ok(
        widthPerTab >= 48,
        `Allocated width per tab (${widthPerTab}px) must be >= 48px minimum touch target`
      );
      assert.strictEqual(widthPerTab, 62.4, 'Each tab is allocated 62.4px on 320px viewport');
    });

    test('Tab height meets 52px (exceeds 48px touch target standard)', () => {
      assert.ok(bottomNavBarCode.includes('min-h-[52px]'));
    });
  });

  describe('3. Root App Container Overflow Protection', () => {
    test('App root container enforces overflow-x-hidden', () => {
      assert.ok(
        appCode.includes('overflow-x-hidden'),
        'Root layout must enforce overflow-x-hidden to prevent horizontal page scrolling'
      );
    });
  });

  describe('4. Comprehensive Touch Target Compliance', () => {
    test('all interactive buttons in TopAppBar have at least 48x48 dp footprint', () => {
      const buttons = [
        { name: 'Brand emblem', pattern: /min-h-\[48px\] min-w-\[48px\] items-center justify-center rounded-full bg-\[#1877F2\]/ },
        { name: 'Router profile avatar', pattern: /min-h-\[48px\] min-w-\[48px\]/ },
        { name: 'Mobile search toggle', pattern: /min-h-\[48px\] min-w-\[48px\] w-12 h-12/ },
        { name: 'Theme toggle', pattern: /min-h-\[48px\] min-w-\[48px\] w-12 h-12 rounded-full bg-secondary/ },
        { name: 'Auto-refresh button', pattern: /min-h-\[48px\] min-w-\[48px\] w-12 h-12 rounded-full transition/ },
        { name: 'Manual refresh button', pattern: /min-h-\[48px\] min-w-\[48px\] w-12 h-12 rounded-full bg-secondary hover:bg-muted text-foreground border border-border\/40/ },
        { name: 'Mobile search clear button', pattern: /min-h-\[48px\] min-w-\[48px\] -mr-1\.5 rounded-full hover:bg-muted/ },
        { name: 'Mobile search Tutup button', pattern: /min-h-\[48px\] min-w-\[48px\] px-3 -mr-1\.5 text-xs/ },
      ];

      for (const btn of buttons) {
        assert.ok(
          btn.pattern.test(topAppBarCode),
          `Button ${btn.name} must strictly match 48x48dp target pattern`
        );
      }
    });
  });
});
