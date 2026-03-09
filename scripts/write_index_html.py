#!/usr/bin/env python3
"""Write the new minimal index.html for Origna GTA."""

INDEX_HTML = r'''<!DOCTYPE html><html><head>
  <base href="$FLUTTER_BASE_HREF">

  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="Origna GTA &ndash; Your marketplace for buying and selling across the Greater Toronto Area and all of Canada. Discover products, connect with sellers, and shop securely.">

  <!-- iOS meta tags & icons -->
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="Origna GTA">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">

  <!-- Favicon -->
  <link rel="icon" type="image/png" href="favicon.png">

  <!-- Stripe JS (defer to not block initial paint) -->
  <script src="https://js.stripe.com/v3/" defer></script>

  <title>Origna GTA</title>
  <link rel="manifest" href="manifest.json">

  <style>
    html, body {
      margin: 0;
      padding: 0;
      height: 100%;
      overflow: hidden;
      background: #FFFFFF;
    }

    /* Simple centered splash */
    #splash {
      position: fixed;
      inset: 0;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      background: #FFFFFF;
      z-index: 100;
      transition: opacity 0.3s ease-out;
    }

    #splash.removing {
      opacity: 0;
      pointer-events: none;
    }

    #splash img {
      width: 120px;
      height: 120px;
      object-fit: contain;
    }

    /* Minimal loading bar */
    #splash-loader {
      margin-top: 32px;
      width: 160px;
      height: 3px;
      background: #E8E8E8;
      border-radius: 3px;
      overflow: hidden;
    }

    #splash-loader::after {
      content: '';
      display: block;
      height: 100%;
      width: 40%;
      background: #1a1a2e;
      border-radius: 3px;
      animation: load 1s ease-in-out infinite;
    }

    @keyframes load {
      0% { transform: translateX(-100%); }
      100% { transform: translateX(400%); }
    }

    /* If Flutter build injects splash-branding, keep it centered */
    #splash-branding {
      position: absolute !important;
      top: 50% !important;
      left: 50% !important;
      right: auto !important;
      bottom: auto !important;
      transform: translate(-50%, -50%) !important;
      z-index: 100;
    }
  </style>

  <script>
    // Minimal splash removal — no heavy JS, no canvas, no animations
    var _splashRemoved = false;
    function removeSplashFromWeb() {
      if (_splashRemoved) return;
      _splashRemoved = true;
      var s = document.getElementById('splash');
      if (s) {
        s.classList.add('removing');
        setTimeout(function() { s.remove(); }, 300);
      }
      var b = document.getElementById('splash-branding');
      if (b) b.remove();
      // Hide the HTML footer once Flutter takes over
      var f = document.getElementById('site-footer');
      if (f) f.style.display = 'none';
    }

    // Remove splash on Flutter first frame (fastest path)
    window.addEventListener('flutter-first-frame', function() {
      requestAnimationFrame(removeSplashFromWeb);
    });

    // Fallback: 5s safety net
    window.addEventListener('load', function() {
      if (!_splashRemoved) {
        setTimeout(removeSplashFromWeb, 5000);
      }
    });
  </script>
</head>
<body>
  <!-- Simple splash: white bg + logo + thin loader -->
  <div id="splash">
    <img src="splash/img/light-1x.png"
         srcset="splash/img/light-1x.png 1x, splash/img/light-2x.png 2x, splash/img/light-3x.png 3x"
         alt="Origna GTA" width="120" height="120">
    <div id="splash-loader"></div>
  </div>

  <!-- Footer with legal links (visible to crawlers before Flutter loads) -->
  <footer id="site-footer" style="position:fixed;bottom:0;left:0;right:0;z-index:9999;text-align:center;padding:12px 16px;background:rgba(15,15,40,0.85);backdrop-filter:blur(8px);border-top:1px solid rgba(92,225,230,0.2);font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
    <a href="/privacy-policy" style="color:rgba(92,225,230,0.9);text-decoration:none;font-size:13px;margin:0 12px;">Privacy Policy</a>
    <span style="color:rgba(255,255,255,0.3);font-size:13px;">|</span>
    <a href="/terms-of-service" style="color:rgba(92,225,230,0.9);text-decoration:none;font-size:13px;margin:0 12px;">Terms of Service</a>
    <span style="color:rgba(255,255,255,0.3);font-size:13px;">|</span>
    <span style="color:rgba(255,255,255,0.5);font-size:12px;margin:0 12px;">&copy; 2026 Origna GTA</span>
  </footer>

  <script src="flutter_bootstrap.js" async></script>
</body></html>'''

target = '/Users/yuniorrodriguezosorio/Documents/GitHub/origna_gta/origna_gta/web/index.html'
with open(target, 'w') as f:
    f.write(INDEX_HTML)
print(f'Written {len(INDEX_HTML)} bytes to {target}')
