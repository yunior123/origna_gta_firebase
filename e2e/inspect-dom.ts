import { chromium } from '@playwright/test';

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const page = await context.newPage();
  page.setDefaultTimeout(180000);
  await page.goto('https://orignagta-dev.web.app/', { timeout: 180000 });

  // Wait 30s then dump whatever HTML is on the page
  console.log('Waiting 30s for initial page load...');
  await page.waitForTimeout(30000);

  const initialHtml = await page.evaluate(() => {
    return {
      title: document.title,
      bodyChildTags: Array.from(document.body.children).map(c => c.tagName.toLowerCase() + '#' + c.id),
      bodyHtml: document.body.innerHTML.substring(0, 2000),
    };
  });
  console.log('Page title:', initialHtml.title);
  console.log('Body children:', initialHtml.bodyChildTags);
  console.log('Body HTML (2000 chars):', initialHtml.bodyHtml);

  console.log('\nWaiting for Flutter host element (180s)...');
  try {
    await page.waitForFunction(() => {
      const gp = document.querySelector('flt-glass-pane');
      const fv = document.querySelector('flutter-view');
      const canvas = document.querySelector('canvas');
      return gp !== null || fv !== null || (canvas instanceof HTMLCanvasElement && canvas.getBoundingClientRect().width > 0);
    }, { timeout: 180000 });
    console.log('Flutter host found!');
  } catch (e) {
    console.log('Flutter host NOT found after 180s. Dumping final HTML...');
    const finalHtml = await page.evaluate(() => document.body.innerHTML.substring(0, 3000));
    console.log(finalHtml);
    await browser.close();
    process.exit(1);
  }
  console.log('Canvas found. Clicking placeholder + Tab...');

  // Try to activate semantics
  const placeholder = page.locator('flt-semantics-placeholder');
  const pCount = await placeholder.count();
  console.log('flt-semantics-placeholder count:', pCount);
  if (pCount > 0) {
    await placeholder.first().click({ force: true });
    console.log('Clicked placeholder');
  }
  await page.keyboard.press('Tab');
  console.log('Pressed Tab. Waiting 15s...');
  await page.waitForTimeout(15000);

  const info = await page.evaluate(() => {
    const lines: string[] = [];
    const sems = document.querySelectorAll('flt-semantics');
    lines.push('flt-semantics count: ' + sems.length);

    const inputs = document.querySelectorAll('input');
    lines.push('input count: ' + inputs.length);
    inputs.forEach((inp, i) => {
      lines.push('  input[' + i + ']: type=' + inp.type + ' role=' + inp.getAttribute('role') + ' aria-label=' + inp.getAttribute('aria-label') + ' parent=' + (inp.parentElement?.tagName || ''));
    });

    const tas = document.querySelectorAll('textarea');
    lines.push('textarea count: ' + tas.length);

    const edits = document.querySelectorAll('[contenteditable]');
    lines.push('contenteditable count: ' + edits.length);

    const tbx = document.querySelectorAll('[role="textbox"]');
    lines.push('role=textbox count: ' + tbx.length);
    tbx.forEach((t, i) => {
      lines.push('  tb[' + i + ']: tag=' + t.tagName + ' label=' + t.getAttribute('aria-label'));
    });

    const cbx = document.querySelectorAll('[role="combobox"]');
    lines.push('role=combobox count: ' + cbx.length);

    const labeled = document.querySelectorAll('[aria-label]');
    lines.push('aria-label elements: ' + labeled.length);
    labeled.forEach((el, i) => {
      if (i < 80) {
        lines.push('  [' + i + '] <' + el.tagName.toLowerCase() + '> role=' + el.getAttribute('role') + ' label="' + el.getAttribute('aria-label') + '"');
      }
    });

    const semRoles = document.querySelectorAll('flt-semantics[role]');
    lines.push('flt-semantics with role: ' + semRoles.length);
    semRoles.forEach((el, i) => {
      if (i < 40) {
        lines.push('  sem[' + i + ']: role=' + el.getAttribute('role') + ' label=' + el.getAttribute('aria-label'));
      }
    });

    // Check shadow DOMs
    lines.push('\n--- Shadow DOM inspection ---');
    const allElements = document.querySelectorAll('*');
    for (const el of allElements) {
      if (el.shadowRoot) {
        const tag = el.tagName.toLowerCase();
        const shadowChildren = el.shadowRoot.querySelectorAll('*');
        const shadowFlt = el.shadowRoot.querySelectorAll('[class*="semantics"], flt-semantics, [role]');
        lines.push('Shadow host: <' + tag + '> children=' + shadowChildren.length + ' semantic-like=' + shadowFlt.length);
        // Show first few children tags
        const childTags = new Set<string>();
        shadowChildren.forEach(c => childTags.add(c.tagName.toLowerCase()));
        lines.push('  Child tags: ' + Array.from(childTags).join(', '));
        // Show aria labels in shadow
        const shadowAria = el.shadowRoot.querySelectorAll('[aria-label]');
        lines.push('  aria-label count: ' + shadowAria.length);
        shadowAria.forEach((sa, i) => {
          if (i < 10) {
            lines.push('    [' + i + '] <' + sa.tagName.toLowerCase() + '> role=' + sa.getAttribute('role') + ' label="' + sa.getAttribute('aria-label') + '"');
          }
        });
      }
    }

    // Show body direct children
    lines.push('\n--- Body structure ---');
    for (const child of document.body.children) {
      lines.push('<' + child.tagName.toLowerCase() + ' id="' + child.id + '" class="' + child.className + '">');
    }

    return lines.join('\n');
  });

  console.log('\n=== FLUTTER DOM INSPECTION ===');
  console.log(info);

  console.log('\n=== PLAYWRIGHT LOCATOR COUNTS ===');
  const tbCount = await page.getByRole('textbox').count();
  console.log('getByRole textbox: ' + tbCount);
  const cbCount = await page.getByRole('combobox').count();
  console.log('getByRole combobox: ' + cbCount);
  const inpCount = await page.locator('input').count();
  console.log('locator input: ' + inpCount);
  const taCount = await page.locator('textarea').count();
  console.log('locator textarea: ' + taCount);
  const ceCount = await page.locator('[contenteditable]').count();
  console.log('locator contenteditable: ' + ceCount);
  const semCount = await page.locator('flt-semantics').count();
  console.log('locator flt-semantics: ' + semCount);

  await browser.close();
  console.log('\nDone.');
})();
