import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import ts from 'typescript';

describe('Milestone 2 Empirical Verifier: Touch Targets, Layout & Viewport Ergonomics', () => {
  const views = [
    { name: 'SetupConnection', file: 'src/components/SetupConnection.tsx' },
    { name: 'InterfacesView', file: 'src/components/InterfacesView.tsx' },
    { name: 'DhcpView', file: 'src/components/DhcpView.tsx' },
    { name: 'PppoeView', file: 'src/components/PppoeView.tsx' },
    { name: 'VitalsView', file: 'src/components/VitalsView.tsx' },
  ];

  // Helper to extract all interactive elements using TypeScript AST
  function getInteractiveElements(filePath) {
    const content = fs.readFileSync(filePath, 'utf8');
    const sourceFile = ts.createSourceFile(
      filePath,
      content,
      ts.ScriptTarget.Latest,
      true,
      ts.ScriptKind.TSX
    );

    const elements = [];

    function visit(node) {
      if (ts.isJsxOpeningElement(node) || ts.isJsxSelfClosingElement(node)) {
        const tagName = node.tagName.getText(sourceFile);
        const hasOnClick = node.attributes.properties.some(
          (p) => p.name && p.name.getText(sourceFile) === 'onClick'
        );
        const isInteractiveTag = [
          'button',
          'Button',
          'input',
          'Input',
          'InputGroupInput',
          'select',
          'TabsTrigger',
        ].includes(tagName);

        if (isInteractiveTag || hasOnClick) {
          const line =
            sourceFile.getLineAndCharacterOfPosition(node.getStart(sourceFile)).line + 1;
          const classAttr = node.attributes.properties.find(
            (p) => p.name && p.name.getText(sourceFile) === 'className'
          );
          let classValue = '';
          if (classAttr && classAttr.initializer) {
            classValue = classAttr.initializer.getText(sourceFile);
          }

          const isInputGroupInput = tagName === 'InputGroupInput';

          elements.push({
            tagName,
            line,
            className: classValue,
            hasOnClick,
            isInputGroupInput,
            raw: node.getText(sourceFile),
          });
        }
      }
      ts.forEachChild(node, visit);
    }

    visit(sourceFile);
    return elements;
  }

  describe('1. Touch Target Height Standard (>= 48dp / min-h-[48px])', () => {
    for (const view of views) {
      test(`all interactive buttons and tabs in ${view.name} meet or exceed min-h-[48px]`, () => {
        const elements = getInteractiveElements(view.file);
        const violations = [];

        for (const el of elements) {
          const hasMinH48 =
            el.className.includes('min-h-[48px]') ||
            el.className.includes('min-h-[52px]') ||
            el.className.includes('h-12');

          if (!hasMinH48 && !el.isInputGroupInput) {
            violations.push({
              file: view.file,
              line: el.line,
              tag: el.tagName,
              reason: 'Touch target height is below 48dp minimum',
              className: el.className,
            });
          }
        }

        if (violations.length > 0) {
          const msg = violations
            .map(
              (v) =>
                `  - [${v.file}:${v.line}] <${v.tag}> ${v.reason}. className: ${v.className}`
            )
            .join('\n');
          assert.fail(`Found ${violations.length} touch target height violations in ${view.name}:\n${msg}`);
        }
      });
    }
  });

  describe('2. Standalone Icon Buttons Touch Target Width (>= 48dp / min-w-[48px])', () => {
    test('all icon-only buttons across 5 views enforce min-w-[48px]', () => {
      // Find all icon-only buttons (buttons with size="icon" or icon children with no text)
      for (const view of views) {
        const elements = getInteractiveElements(view.file);
        for (const el of elements) {
          // If button has size="icon" or p-0 / w-12, check min-w-[48px]
          if (
            el.raw.includes('size="icon"') ||
            (el.className.includes('p-0') && (el.tagName === 'Button' || el.tagName === 'button'))
          ) {
            const hasMinW48 =
              el.className.includes('min-w-[48px]') || el.className.includes('w-12');
            assert.ok(
              hasMinW48,
              `Icon button in ${view.file}:${el.line} must enforce min-w-[48px]. Found: ${el.className}`
            );
          }
        }
      }
    });
  });

  describe('3. Mobile Viewport Layout & Horizontal Overflow Resilience', () => {
    test('PppoeView action buttons container must prevent horizontal overflow via flex-wrap', () => {
      const pppoeCode = fs.readFileSync('src/components/PppoeView.tsx', 'utf8');
      // Line 723: action buttons container for Extend +30 Hari, Isolir, Trash
      const actionRowMatch = pppoeCode.match(/<div className="([^"]*justify-between[^"]*)">\s*\{\/\* Extend \+30 Hari Button \*\/\}/);
      assert.ok(actionRowMatch, 'Action buttons container exists in PppoeView');
      const classes = actionRowMatch[1];
      const hasWrap = classes.includes('flex-wrap') || classes.includes('flex-col');
      assert.strictEqual(
        hasWrap,
        true,
        `PppoeView action row at line 723 lacks "flex-wrap", risking horizontal overflow on 320px/360px screens (found: "${classes}")`
      );
    });

    test('All views root container must avoid hardcoded fixed widths exceeding 320px', () => {
      for (const view of views) {
        const code = fs.readFileSync(view.file, 'utf8');
        // Look for fixed pixel widths like w-[350px], min-w-[400px], etc.
        const fixedWidthMatch = code.match(/(?:w|min-w)-\[(\d+)px\]/g);
        if (fixedWidthMatch) {
          for (const m of fixedWidthMatch) {
            const num = parseInt(m.replace(/\D/g, ''), 10);
            assert.ok(
              num <= 320,
              `Fixed width ${m} in ${view.file} exceeds 320px mobile viewport limit`
            );
          }
        }
      }
    });
  });

  describe('4. Social Media Term Purification', () => {
    test('zero social media terms in all 5 views and card UI component', () => {
      const files = [
        ...views.map((v) => v.file),
        'src/components/ui/card.tsx',
      ];
      const forbiddenRegex = /\b(like|share|posting|komentar|teman|timeline|story|friend)\b/i;

      for (const file of files) {
        const content = fs.readFileSync(file, 'utf8');
        const lines = content.split('\n');
        for (let i = 0; i < lines.length; i++) {
          const line = lines[i];
          // Skip comments
          if (line.trim().startsWith('//') || line.trim().startsWith('*')) continue;
          const match = line.match(forbiddenRegex);
          assert.strictEqual(
            match,
            null,
            `Forbidden social media term "${match?.[0]}" found in ${file}:${i + 1}: ${line.trim()}`
          );
        }
      }
    });
  });

  describe('5. Dual-Theme Compliance (Zero hardcoded dark zinc classes in views)', () => {
    test('all 5 views are purged of hardcoded dark zinc classes', () => {
      const darkZincRegex = /\b(bg-zinc-950|bg-zinc-900|bg-zinc-800|border-zinc-800|border-zinc-700|text-zinc-400|text-zinc-500|text-zinc-200|text-zinc-100)\b/;

      for (const view of views) {
        const content = fs.readFileSync(view.file, 'utf8');
        const lines = content.split('\n');
        for (let i = 0; i < lines.length; i++) {
          const line = lines[i];
          if (line.trim().startsWith('//')) continue;
          const match = line.match(darkZincRegex);
          assert.strictEqual(
            match,
            null,
            `Hardcoded dark zinc class "${match?.[0]}" found in ${view.file}:${i + 1}: ${line.trim()}`
          );
        }
      }
    });
  });
});
