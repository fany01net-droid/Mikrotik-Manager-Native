import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import ts from 'typescript';

describe('Milestone 2 Iteration 2 Challenger: Deep Ergonomics & Layout Stress Harness', () => {
  const componentFiles = [
    { name: 'SetupConnection', file: 'src/components/SetupConnection.tsx' },
    { name: 'InterfacesView', file: 'src/components/InterfacesView.tsx' },
    { name: 'DhcpView', file: 'src/components/DhcpView.tsx' },
    { name: 'PppoeView', file: 'src/components/PppoeView.tsx' },
    { name: 'VitalsView', file: 'src/components/VitalsView.tsx' },
    { name: 'TopAppBar', file: 'src/components/TopAppBar.tsx' },
    { name: 'BottomNavBar', file: 'src/components/BottomNavBar.tsx' },
  ];

  // Helper to extract JSX elements
  function extractInteractiveElements(filePath) {
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

          // Check if parent node or container enforces min-h
          let parentHasMinH = false;
          let parentNode = node.parent;
          while (parentNode && !parentHasMinH) {
            if (ts.isJsxElement(parentNode) || ts.isJsxOpeningElement(parentNode)) {
              const opening = ts.isJsxElement(parentNode) ? parentNode.openingElement : parentNode;
              const pClassAttr = opening.attributes?.properties?.find(
                (p) => p.name && p.name.getText(sourceFile) === 'className'
              );
              if (pClassAttr && pClassAttr.initializer) {
                const pClass = pClassAttr.initializer.getText(sourceFile);
                if (pClass.includes('min-h-[48px]') || pClass.includes('min-h-[52px]') || pClass.includes('h-12')) {
                  parentHasMinH = true;
                  break;
                }
              }
            }
            parentNode = parentNode.parent;
          }

          elements.push({
            tagName,
            line,
            className: classValue,
            hasOnClick,
            parentHasMinH,
            raw: node.getText(sourceFile),
          });
        }
      }
      ts.forEachChild(node, visit);
    }

    visit(sourceFile);
    return elements;
  }

  describe('1. 100% Interactive Element Height Verification (>= 48dp)', () => {
    for (const comp of componentFiles) {
      test(`${comp.name}: all interactive elements satisfy min-h-[48px] / min-h-[52px] / h-12`, () => {
        const elements = extractInteractiveElements(comp.file);
        const failures = [];

        for (const el of elements) {
          const hasValidHeight =
            el.className.includes('min-h-[48px]') ||
            el.className.includes('min-h-[52px]') ||
            el.className.includes('min-h-[56px]') ||
            el.className.includes('h-12') ||
            el.className.includes('h-14') ||
            el.parentHasMinH;

          if (!hasValidHeight) {
            failures.push(`line ${el.line}: <${el.tagName}> className: ${el.className}`);
          }
        }

        assert.strictEqual(
          failures.length,
          0,
          `Found touch height violations in ${comp.name}:\n` + failures.join('\n')
        );
      });
    }
  });

  describe('2. Standalone Icon Buttons & Square Elements Width Verification (>= 48dp)', () => {
    test('all icon buttons across all components enforce min-w-[48px] / w-12', () => {
      for (const comp of componentFiles) {
        const elements = extractInteractiveElements(comp.file);
        for (const el of elements) {
          const isIconOnly =
            el.raw.includes('size="icon"') ||
            (el.className.includes('p-0') && (el.tagName === 'Button' || el.tagName === 'button'));

          if (isIconOnly) {
            const hasValidWidth =
              el.className.includes('min-w-[48px]') ||
              el.className.includes('min-w-[52px]') ||
              el.className.includes('w-12');

            assert.ok(
              hasValidWidth,
              `Icon button in ${comp.file}:${el.line} must enforce min-w-[48px]. Found: ${el.className}`
            );
          }
        }
      }
    });
  });

  describe('3. 320px Screen Horizontal Overflow Stress Tests', () => {
    test('App.tsx root wrapper enforces overflow-x-hidden', () => {
      const appCode = fs.readFileSync('src/App.tsx', 'utf8');
      assert.ok(
        appCode.includes('overflow-x-hidden'),
        'App container must enforce overflow-x-hidden'
      );
    });

    test('All component files avoid rigid fixed widths greater than 320px', () => {
      for (const comp of componentFiles) {
        const code = fs.readFileSync(comp.file, 'utf8');
        const matches = code.match(/(?:w|min-w)-\[(\d+)px\]/g) || [];
        for (const m of matches) {
          const px = parseInt(m.replace(/\D/g, ''), 10);
          assert.ok(
            px <= 320,
            `Component ${comp.file} contains rigid fixed width ${m} exceeding 320px`
          );
        }
      }
    });

    test('Data tables or dense lists are wrapped in overflow-x-auto or flex-wrap', () => {
      // In InterfacesView, DHCPView, PppoeView
      const pppoeCode = fs.readFileSync('src/components/PppoeView.tsx', 'utf8');
      assert.ok(
        pppoeCode.includes('flex flex-wrap items-center justify-between gap-2 pt-2 border-t border-border'),
        'PPPoE quick admin action row must have flex-wrap'
      );

      const interfacesCode = fs.readFileSync('src/components/InterfacesView.tsx', 'utf8');
      assert.ok(
        interfacesCode.includes('min-h-[56px]'),
        'InterfacesView TabsList must have min-h-[56px] to accommodate 48dp triggers'
      );
    });

    test('SetupConnection IP preset buttons padding on 320px viewport', () => {
      const setupCode = fs.readFileSync('src/components/SetupConnection.tsx', 'utf8');
      assert.ok(
        setupCode.includes('px-1.5 sm:px-3.5'),
        'SetupConnection IP preset buttons must use compact mobile padding px-1.5'
      );
    });
  });

  describe('4. Theme & Token Purity Checks', () => {
    test('src/components/ui/input.tsx contains zero hardcoded zinc or slate classes', () => {
      const inputCode = fs.readFileSync('src/components/ui/input.tsx', 'utf8');
      const zincMatch = inputCode.match(/\b(zinc|slate)-[0-9]/);
      assert.strictEqual(
        zincMatch,
        null,
        `Found hardcoded zinc/slate in input.tsx: ${zincMatch?.[0]}`
      );
    });

    test('Card UI primitive uses semantic design tokens', () => {
      const cardCode = fs.readFileSync('src/components/ui/card.tsx', 'utf8');
      assert.ok(cardCode.includes('bg-card'), 'Card must use bg-card');
      assert.ok(cardCode.includes('text-card-foreground'), 'Card must use text-card-foreground');
      assert.ok(cardCode.includes('border-border'), 'Card must use border-border');
    });
  });

  describe('5. Complete Social Media Term Purification Audit', () => {
    test('Zero social media terms in all source files', () => {
      const forbidden = /\b(like|likes|likers|share|shares|sharing|posting|komentar|teman|timeline|story|stories|friend|friends)\b/i;

      function checkFile(filePath) {
        const content = fs.readFileSync(filePath, 'utf8');
        const lines = content.split('\n');
        for (let i = 0; i < lines.length; i++) {
          const line = lines[i];
          if (line.trim().startsWith('//') || line.trim().startsWith('*')) continue;
          const match = line.match(forbidden);
          assert.strictEqual(
            match,
            null,
            `Forbidden social media term "${match?.[0]}" in ${filePath}:${i + 1}: ${line.trim()}`
          );
        }
      }

      function scanDir(dir) {
        const entries = fs.readdirSync(dir, { withFileTypes: true });
        for (const entry of entries) {
          const fullPath = path.join(dir, entry.name);
          if (entry.isDirectory()) {
            if (entry.name !== 'node_modules' && entry.name !== 'dist' && entry.name !== '.git') {
              scanDir(fullPath);
            }
          } else if (/\.(tsx?|html|css)$/.test(entry.name)) {
            checkFile(fullPath);
          }
        }
      }

      scanDir('src');
      checkFile('index.html');
    });
  });
});
