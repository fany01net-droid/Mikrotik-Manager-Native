import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

// Helper to load files
function readProjectFile(relPath) {
  const absPath = path.resolve(relPath);
  assert.ok(fs.existsSync(absPath), `File does not exist: ${relPath}`);
  return fs.readFileSync(absPath, 'utf8');
}

// Relative luminance and contrast ratio calculator (WCAG 2.1)
function hexToRgb(hex) {
  const cleanHex = hex.replace('#', '').trim();
  const bigint = parseInt(cleanHex, 16);
  const r = (bigint >> 16) & 255;
  const g = (bigint >> 8) & 255;
  const b = bigint & 255;
  return [r, g, b];
}

function relativeLuminance([r, g, b]) {
  const [rs, gs, bs] = [r, g, b].map((c) => {
    const s = c / 255;
    return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
  });
  return 0.2126 * rs + 0.7152 * gs + 0.0722 * bs;
}

function contrastRatio(hex1, hex2) {
  const lum1 = relativeLuminance(hexToRgb(hex1));
  const lum2 = relativeLuminance(hexToRgb(hex2));
  const lighter = Math.max(lum1, lum2);
  const darker = Math.min(lum1, lum2);
  return (lighter + 0.05) / (darker + 0.05);
}

describe('Challenger M2-R2-1: Input & View Card Dual-Theming Adaptation', () => {
  const inputTsx = readProjectFile('src/components/ui/input.tsx');
  const cardTsx = readProjectFile('src/components/ui/card.tsx');

  test('Input component (src/components/ui/input.tsx) contains ZERO hardcoded zinc, slate, gray, or neutral classes', () => {
    const hardcodedPaletteRegex = /\b(zinc|slate|gray|neutral|stone)-[0-9]{2,3}\b/g;
    const matches = inputTsx.match(hardcodedPaletteRegex);
    assert.strictEqual(
      matches,
      null,
      `Found hardcoded color palette classes in input.tsx: ${JSON.stringify(matches)}`
    );
  });

  test('Input component strictly employs semantic tokens for both Light and Dark mode', () => {
    // Must use border-border, bg-background, text-foreground, placeholder:text-muted-foreground, ring-offset-background
    assert.match(inputTsx, /\bborder-border\b/, 'Input must use border-border');
    assert.match(inputTsx, /\bbg-background\b/, 'Input must use bg-background');
    assert.match(inputTsx, /\btext-foreground\b/, 'Input must use text-foreground');
    assert.match(inputTsx, /\bplaceholder:text-muted-foreground\b/, 'Input must use placeholder:text-muted-foreground');
    assert.match(inputTsx, /\bring-offset-background\b/, 'Input must use ring-offset-background');
    assert.match(inputTsx, /\bfocus-visible:border-primary\b/, 'Input must use focus-visible:border-primary');
    assert.match(inputTsx, /\bfocus-visible:ring-ring\b/, 'Input must use focus-visible:ring-ring');
  });

  test('InputGroup components in input.tsx use semantic tokens with zero hardcoded colors', () => {
    // InputGroup
    assert.match(inputTsx, /InputGroup\s*=\s*React\.forwardRef/, 'InputGroup must be defined');
    assert.match(inputTsx, /InputGroupPrefix\s*=\s*React\.forwardRef/, 'InputGroupPrefix must be defined');
    assert.match(inputTsx, /InputGroupInput\s*=\s*React\.forwardRef/, 'InputGroupInput must be defined');

    // InputGroupPrefix should use text-muted-foreground
    assert.match(inputTsx, /text-muted-foreground/, 'InputGroupPrefix must use text-muted-foreground');

    // InputGroupInput should use bg-transparent and text-foreground
    assert.match(inputTsx, /bg-transparent/, 'InputGroupInput must use bg-transparent');
    assert.match(inputTsx, /text-foreground/, 'InputGroupInput must use text-foreground');
  });

  test('Card component (src/components/ui/card.tsx) contains ZERO hardcoded zinc, slate, gray, or neutral classes', () => {
    const hardcodedPaletteRegex = /\b(zinc|slate|gray|neutral|stone)-[0-9]{2,3}\b/g;
    const matches = cardTsx.match(hardcodedPaletteRegex);
    assert.strictEqual(
      matches,
      null,
      `Found hardcoded color palette classes in card.tsx: ${JSON.stringify(matches)}`
    );
  });

  test('Card component uses bg-card, text-card-foreground, and border-border', () => {
    assert.match(cardTsx, /\bbg-card\b/, 'Card must use bg-card');
    assert.match(cardTsx, /\btext-card-foreground\b/, 'Card must use text-card-foreground');
    assert.match(cardTsx, /\bborder-border\b/, 'Card must use border-border');
  });
});

describe('Challenger M2-R2-1: CSS Variable Specifications (Light vs Dark)', () => {
  const css = readProjectFile('src/index.css');

  test('Light Mode CSS variables strictly adhere to Facebook specifications (#FFFFFF card on #F0F2F5 background)', () => {
    const rootBlock = css.match(/:root\s*\{([\s\S]*?)\}/)?.[1];
    assert.ok(rootBlock, ':root block missing in src/index.css');

    // Specifications:
    // Light Mode: Background #F0F2F5, Card #FFFFFF, Primary #1877F2, Border #CED0D4
    assert.match(rootBlock, /--background:\s*#F0F2F5/i, 'Light background must be #F0F2F5');
    assert.match(rootBlock, /--card:\s*#FFFFFF/i, 'Light card must be #FFFFFF');
    assert.match(rootBlock, /--card-foreground:\s*#050505/i, 'Light card-foreground must be #050505');
    assert.match(rootBlock, /--border:\s*#CED0D4/i, 'Light border must be #CED0D4');
    assert.match(rootBlock, /--primary:\s*#1877F2/i, 'Light primary must be Facebook blue #1877F2');
    assert.match(rootBlock, /--fb-card-bg:\s*#FFFFFF/i, 'Light --fb-card-bg must be #FFFFFF');
    assert.match(rootBlock, /--fb-surface-bg:\s*#F0F2F5/i, 'Light --fb-surface-bg must be #F0F2F5');
  });

  test('Dark Mode CSS variables strictly adhere to Facebook specifications (#242526 card on #18191A background)', () => {
    const darkBlock = css.match(/\.dark\s*\{([\s\S]*?)\}/)?.[1];
    assert.ok(darkBlock, '.dark block missing in src/index.css');

    // Specifications:
    // Dark Mode: Background #18191A, Card #242526, Primary #2D88FF, Border #3A3B3C
    assert.match(darkBlock, /--background:\s*#18191A/i, 'Dark background must be #18191A');
    assert.match(darkBlock, /--card:\s*#242526/i, 'Dark card must be #242526');
    assert.match(darkBlock, /--card-foreground:\s*#E4E6EB/i, 'Dark card-foreground must be #E4E6EB');
    assert.match(darkBlock, /--border:\s*#3A3B3C/i, 'Dark border must be #3A3B3C');
    assert.match(darkBlock, /--primary:\s*#2D88FF/i, 'Dark primary must be Facebook dark blue #2D88FF');
    assert.match(darkBlock, /--fb-card-bg:\s*#242526/i, 'Dark --fb-card-bg must be #242526');
    assert.match(darkBlock, /--fb-surface-bg:\s*#18191A/i, 'Dark --fb-surface-bg must be #18191A');
  });

  test('WCAG Accessibility Contrast Ratios meet standard guidelines in both modes', () => {
    // Light Mode: text #050505 on card #FFFFFF
    const lightCardContrast = contrastRatio('#050505', '#FFFFFF');
    assert.ok(lightCardContrast >= 7.0, `Light card contrast (${lightCardContrast.toFixed(2)}) must exceed AAA 7.0:1`);

    // Light Mode: text #050505 on background #F0F2F5
    const lightBgContrast = contrastRatio('#050505', '#F0F2F5');
    assert.ok(lightBgContrast >= 7.0, `Light background contrast (${lightBgContrast.toFixed(2)}) must exceed AAA 7.0:1`);

    // Dark Mode: text #E4E6EB on card #242526
    const darkCardContrast = contrastRatio('#E4E6EB', '#242526');
    assert.ok(darkCardContrast >= 7.0, `Dark card contrast (${darkCardContrast.toFixed(2)}) must exceed AAA 7.0:1`);

    // Dark Mode: text #E4E6EB on background #18191A
    const darkBgContrast = contrastRatio('#E4E6EB', '#18191A');
    assert.ok(darkBgContrast >= 7.0, `Dark background contrast (${darkBgContrast.toFixed(2)}) must exceed AAA 7.0:1`);

    // Primary Buttons & Graphical Components: (WCAG 2.1 Non-text / large UI components require >= 3.0:1)
    const lightPrimaryContrast = contrastRatio('#FFFFFF', '#1877F2');
    assert.ok(lightPrimaryContrast >= 3.0, `Light primary contrast (${lightPrimaryContrast.toFixed(2)}) must exceed UI Component standard 3.0:1`);

    const darkPrimaryContrast = contrastRatio('#FFFFFF', '#2D88FF');
    assert.ok(darkPrimaryContrast >= 3.0, `Dark primary contrast (${darkPrimaryContrast.toFixed(2)}) must exceed UI Component standard 3.0:1`);

    // Dark primary accent against dark page background
    const darkAccentContrast = contrastRatio('#2D88FF', '#18191A');
    assert.ok(darkAccentContrast >= 4.5, `Dark accent contrast (${darkAccentContrast.toFixed(2)}) must exceed AA 4.5:1`);
  });
});

describe('Challenger M2-R2-1: All 5 Views Card Theming & Zero Hardcoded Classes', () => {
  const views = [
    { name: 'VitalsView', path: 'src/components/VitalsView.tsx' },
    { name: 'InterfacesView', path: 'src/components/InterfacesView.tsx' },
    { name: 'DhcpView', path: 'src/components/DhcpView.tsx' },
    { name: 'PppoeView', path: 'src/components/PppoeView.tsx' },
    { name: 'SetupConnection', path: 'src/components/SetupConnection.tsx' },
  ];

  for (const view of views) {
    test(`${view.name} contains ZERO hardcoded zinc, slate, gray, or neutral palette classes`, () => {
      const content = readProjectFile(view.path);
      const hardcodedPaletteRegex = /\b(zinc|slate|gray|neutral|stone)-[0-9]{2,3}\b/g;
      const matches = content.match(hardcodedPaletteRegex);
      assert.strictEqual(
        matches,
        null,
        `${view.name} contains hardcoded palette classes: ${JSON.stringify(matches)}`
      );
    });

    test(`${view.name} does not use hardcoded dark hex backgrounds (e.g. #020617, #0f172a, #1e293b)`, () => {
      const content = readProjectFile(view.path);
      const hardcodedHexBg = /bg-\[#(020617|0f172a|1e293b|18191a|242526)\]/i;
      assert.strictEqual(
        hardcodedHexBg.test(content),
        false,
        `${view.name} has hardcoded dark hex backgrounds that prevent light mode adaptation`
      );
    });

    test(`${view.name} uses <Card> or semantic container styling`, () => {
      const content = readProjectFile(view.path);
      assert.ok(
        content.includes('<Card') || content.includes('bg-card') || content.includes('rounded-xl'),
        `${view.name} should use Card primitives or semantic card containers`
      );
    });
  }
});

describe('Challenger M2-R2-1: Remediation Regressions Stress Test', () => {
  test('InterfacesView TabsTrigger elements strictly enforce min-h-[48px] with responsive padding', () => {
    const interfacesTsx = readProjectFile('src/components/InterfacesView.tsx');
    
    // Check TabsList height
    assert.match(
      interfacesTsx,
      /<TabsList[^>]*min-h-\[56px\]/s,
      'InterfacesView TabsList must have min-h-[56px] to accommodate 48dp triggers'
    );

    // Ensure NO min-h-[40px] triggers exist
    const has40pxTrigger = /<TabsTrigger[^>]*min-h-\[40px\]/s.test(interfacesTsx);
    assert.strictEqual(has40pxTrigger, false, 'InterfacesView must NOT have min-h-[40px] TabsTrigger');

    // Ensure all TabsTrigger have min-h-[48px]
    const triggers = interfacesTsx.match(/<TabsTrigger[\s\S]*?>/g) || [];
    assert.ok(triggers.length >= 3, 'Must have at least 3 TabsTrigger elements');
    for (const trigger of triggers) {
      assert.match(trigger, /min-h-\[48px\]/, `TabsTrigger missing min-h-[48px]: ${trigger}`);
      assert.match(trigger, /px-2/, `TabsTrigger must use px-2 on mobile for 320px viewport fit: ${trigger}`);
    }
  });

  test('PppoeView action row strictly enforces flex-wrap to prevent horizontal overflow', () => {
    const pppoeTsx = readProjectFile('src/components/PppoeView.tsx');
    // Find the action row containing Extend +30 Hari and Isolir buttons at line 723
    const actionRowMatch = pppoeTsx.match(/<div className="([^"]*justify-between[^"]*)">\s*\{\/\* Extend \+30 Hari Button \*\/\}/);
    assert.ok(actionRowMatch, 'Action buttons container exists in PppoeView');
    const classes = actionRowMatch[1];
    const hasWrap = classes.includes('flex-wrap') || classes.includes('flex-col');
    assert.strictEqual(
      hasWrap,
      true,
      `PppoeView action row at line 723 lacks "flex-wrap", risking horizontal overflow on 320px/360px screens (found: "${classes}")`
    );
  });

  test('SetupConnection IP preset buttons maintain 48dp bounds while preserving 320px fit', () => {
    const setupTsx = readProjectFile('src/components/SetupConnection.tsx');
    // Presets button map
    assert.match(
      setupTsx,
      /px-1\.5\s+sm:px-3\.5/,
      'SetupConnection presets must use px-1.5 on mobile to avoid overflow on 320px'
    );
    assert.match(
      setupTsx,
      /min-h-\[48px\]/,
      'SetupConnection presets must enforce min-h-[48px]'
    );
    assert.match(
      setupTsx,
      /min-w-\[48px\]/,
      'SetupConnection presets must enforce min-w-[48px]'
    );
  });
});

describe('Challenger M2-R2-1: Content Purification & Forbidden Social Media Terms', () => {
  function getAllSourceFiles(dir) {
    let files = [];
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        files = files.concat(getAllSourceFiles(full));
      } else if (/\.(tsx|ts|html)$/.test(entry.name)) {
        files.push(full);
      }
    }
    return files;
  }

  test('Zero forbidden social media words exist in UI labels, placeholders, or buttons across all source files', () => {
    const files = getAllSourceFiles('src');
    files.push('index.html');

    // Forbidden social media terms (case insensitive)
    const forbiddenPattern = /\b(like|likes|dislike|share|shares|posting|postingan|komentar|teman|temanku|timeline|story|stories|beranda sosial|apa yang anda pikirkan)\b/i;

    const detected = [];

    for (const file of files) {
      const content = fs.readFileSync(file, 'utf8');
      const lines = content.split('\n');

      lines.forEach((line, idx) => {
        const trimmed = line.trim();
        // Ignore code comments
        if (trimmed.startsWith('//') || trimmed.startsWith('/*') || trimmed.startsWith('*')) return;
        // Ignore schema/data fields like `comment?: string;` or `.comment` or `'comment'`
        if (/comment\??:|\.comment\b|'comment'|"comment"/.test(line)) return;

        const match = line.match(forbiddenPattern);
        if (match) {
          detected.push({
            file,
            line: idx + 1,
            word: match[0],
            snippet: trimmed,
          });
        }
      });
    }

    assert.strictEqual(
      detected.length,
      0,
      `Detected forbidden social media terms in UI:\n` +
        detected.map((d) => `  ${d.file}:${d.line} -> "${d.word}" in: ${d.snippet}`).join('\n')
    );
  });
});
