const { chromium } = require('@playwright/test');

(async () => {
  const browser = await chromium.launch({ 
    channel: 'chrome',
    headless: false, 
    args: [
      '--enable-unsafe-swiftshader',
      '--enable-webgl',
      '--ignore-gpu-blocklist',
    ] 
  });
  const context = await browser.newContext({ 
    serviceWorkers: 'block',
    viewport: { width: 1280, height: 720 },
  });
  const page = await context.newPage();

  // Capture console messages and errors  
  var consoleMessages = [];
  page.on('console', function(msg) {
    consoleMessages.push(msg.type() + ': ' + msg.text());
  });
  page.on('pageerror', function(err) {
    consoleMessages.push('PAGE_ERROR: ' + err.message);
  });

  // Capture network requests
  var requests = [];
  page.on('request', function(req) {
    requests.push('REQ: ' + req.method() + ' ' + req.url().substring(0, 100));
  });
  page.on('response', function(res) {
    requests.push('RES: ' + res.status() + ' ' + res.url().substring(0, 100));
  });
  page.on('requestfailed', function(req) {
    requests.push('FAIL: ' + req.url().substring(0, 100) + ' err=' + (req.failure() ? req.failure().errorText : 'unknown'));
  });

  await page.goto('http://localhost:5005/#/login', {
    waitUntil: 'domcontentloaded',
    timeout: 60000,
  });

  console.log('Loaded. Waiting for flutter...');
  try { await page.waitForSelector('flutter-view', { timeout: 60000 }); console.log('flutter-view found'); } catch(e) { console.log('flutter-view NOT found'); }

  // Deep DOM inspection including shadow roots
  console.log('Waiting 60s for app to fully initialize...');
  await page.waitForTimeout(60000);
  
  var deepInspect = await page.evaluate(function() {
    var lines = [];
    function inspectNode(node, depth) {
      if (depth > 8) return;
      var prefix = '  '.repeat(depth);
      if (node.nodeType === 1) {
        var tag = node.tagName.toLowerCase();
        var role = node.getAttribute('role') || '';
        var label = node.getAttribute('aria-label') || '';
        var id = node.id || '';
        var line = prefix + '<' + tag;
        if (id) line += ' id="' + id + '"';
        if (role) line += ' role="' + role + '"';
        if (label) line += ' aria-label="' + label + '"';
        line += '>';
        lines.push(line);
        
        // Check shadow root
        if (node.shadowRoot) {
          lines.push(prefix + '  [SHADOW ROOT] mode=' + node.shadowRoot.mode + ' children=' + node.shadowRoot.children.length);
          Array.from(node.shadowRoot.children).forEach(function(c) { inspectNode(c, depth + 2); });
        }
        
        // Check children
        Array.from(node.children).forEach(function(c) { inspectNode(c, depth + 1); });
      }
    }
    
    var fv = document.querySelector('flutter-view');
    if (fv) {
      lines.push('=== FLUTTER-VIEW TREE ===');
      inspectNode(fv, 0);
    } else {
      lines.push('NO FLUTTER-VIEW FOUND');
    }
    
    // Check for canvas anywhere in the document including shadow
    var allCanvases = document.querySelectorAll('canvas');
    lines.push('\ncanvas in light DOM: ' + allCanvases.length);
    
    // Check inside flutter-view shadow
    if (fv && fv.shadowRoot) {
      var shadowCanvases = fv.shadowRoot.querySelectorAll('canvas');
      lines.push('canvas in flutter-view shadow: ' + shadowCanvases.length);
    }
    
    // Check flt-glass-pane shadow
    var gp = document.querySelector('flt-glass-pane');
    if (gp) {
      lines.push('flt-glass-pane has shadow: ' + !!gp.shadowRoot);
      if (gp.shadowRoot) {
        var gpCanvases = gp.shadowRoot.querySelectorAll('canvas');
        lines.push('canvas in glass-pane shadow: ' + gpCanvases.length);
        lines.push('glass-pane shadow children: ' + gp.shadowRoot.children.length);
        Array.from(gp.shadowRoot.children).forEach(function(c) { inspectNode(c, 1); });
      }
      lines.push('flt-glass-pane light children: ' + gp.children.length);
    }
    
    return lines.join('\n');
  });
  console.log(deepInspect);
  // Skip disabled checks since we already deep-inspected above
  console.log('--- POST DEEP INSPECT ---');

  // Try clicking "Enable accessibility" button
  try {
    var enableBtn = page.locator('flt-semantics-placeholder[aria-label="Enable accessibility"]');
    var btnCount = await enableBtn.count();
    console.log('Enable accessibility btn found: ' + btnCount);
    if (btnCount > 0) {
      await enableBtn.click({ timeout: 5000 });
      console.log('Clicked Enable accessibility!');
    }
  } catch(e) { console.log('Enable accessibility click failed: ' + e.message); }

  console.log('Waiting 15s for semantics to populate...');
  await page.waitForTimeout(15000);

  const c1 = await page.getByRole('textbox').count();
  const c2 = await page.locator('input').count();
  const c3 = await page.locator('flt-semantics').count();
  const c4 = await page.locator('[role=textbox]').count();
  const c5 = await page.locator('textarea').count();
  const c6 = await page.locator('[contenteditable]').count();
  console.log(
    'textbox=' + c1 +
    ' input=' + c2 +
    ' flt-semantics=' + c3 +
    ' [role=textbox]=' + c4 +
    ' textarea=' + c5 +
    ' contenteditable=' + c6
  );

  var labels = await page.evaluate(function () {
    var els = document.querySelectorAll('[aria-label]');
    var out = [];
    els.forEach(function (e) {
      out.push(
        e.tagName + ' role=' + e.getAttribute('role') + ' label=' + e.getAttribute('aria-label')
      );
    });
    return out.join('\n');
  });
  console.log('LABELED:\n' + labels);

  var semRoles = await page.evaluate(function () {
    var els = document.querySelectorAll('flt-semantics[role]');
    var out = [];
    els.forEach(function (e) {
      out.push('role=' + e.getAttribute('role') + ' label=' + e.getAttribute('aria-label'));
    });
    return out.join('\n');
  });
  console.log('SEM_ROLES:\n' + semRoles);

  var inputInfo = await page.evaluate(function () {
    var els = document.querySelectorAll('input');
    var out = [];
    els.forEach(function (e) {
      out.push(
        'type=' + e.type +
        ' role=' + e.getAttribute('role') +
        ' label=' + e.getAttribute('aria-label') +
        ' parent=' + (e.parentElement ? e.parentElement.tagName : 'none')
      );
    });
    return out.join('\n');
  });
  console.log('INPUTS:\n' + inputInfo);

  console.log('\nNETWORK REQUESTS (' + requests.length + '):');
  requests.forEach(function(r, i) {
    if (i < 60) console.log('  ' + r);
  });

  console.log('\nCONSOLE MESSAGES (' + consoleMessages.length + '):');
  consoleMessages.forEach(function(m, i) {
    if (i < 50) console.log('  ' + m);
  });

  await browser.close();
  console.log('DONE');
})();
