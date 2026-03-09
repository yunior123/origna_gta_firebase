/**
 * Inspect the Flutter widget previewer DOM to find navigation structure.
 */
import { chromium } from 'playwright';

const CDP_PORT = process.env.CDP_PORT ?? '52724';
const browser = await chromium.connectOverCDP(`http://localhost:${CDP_PORT}`);
const page = (browser.contexts()[0]).pages().find(p => p.url().includes('localhost'));
console.log('Page URL:', page.url());

// Dump all semantics nodes with roles and labels
const nodes = await page.evaluate(() => {
  const all = document.querySelectorAll('flt-semantics');
  return Array.from(all).map((el, i) => ({
    i,
    role: el.getAttribute('role'),
    label: el.getAttribute('aria-label'),
    tag: el.tagName,
    id: el.getAttribute('id'),
    style: el.getAttribute('style')?.slice(0, 80),
  }));
});

console.log(`\nTotal flt-semantics: ${nodes.length}`);
console.log('\n--- All nodes with roles/labels ---');
nodes.filter(n => n.role || n.label).forEach(n => {
  console.log(`[${n.i}] role=${n.role} label=${JSON.stringify(n.label)?.slice(0, 60)}`);
});

// Also check flt-semantics-container
const containers = await page.evaluate(() => {
  const all = document.querySelectorAll('flt-semantics-container');
  return all.length;
});
console.log(`\nflt-semantics-container count: ${containers}`);

// Check if there's any non-flutter sidebar DOM
const nonFlutter = await page.evaluate(() => {
  const body = document.body;
  const flutterElements = document.querySelectorAll('flutter-view, flt-glass-pane, flt-scene');
  const divs = document.querySelectorAll('div[class], nav, aside, ul, li');
  return {
    flutterCount: flutterElements.length,
    regularCount: divs.length,
    bodyChildren: body.children.length,
    bodyHTML: body.innerHTML.slice(0, 500),
  };
});
console.log('\nDOM structure:', JSON.stringify(nonFlutter, null, 2));

// Try to read the previewer state via JS
const previewState = await page.evaluate(() => {
  // Check for any global Flutter/preview state
  const keys = Object.keys(window).filter(k =>
    k.toLowerCase().includes('preview') ||
    k.toLowerCase().includes('flutter') ||
    k.toLowerCase().includes('dart')
  );
  return keys;
});
console.log('\nGlobal window keys related to preview/flutter:', previewState);

await browser.close();
