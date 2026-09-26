#!/usr/bin/env python3
import json
import sys
from pathlib import Path

from PIL import Image

if len(sys.argv) != 3:
    raise SystemExit("usage: pwa_patch.py <build_web_dir> <base_path>")

build = Path(sys.argv[1])
base_path = sys.argv[2]
if not base_path.startswith("/") or not base_path.endswith("/"):
    raise SystemExit("base_path must start and end with /")

index = build / "index.html"
if not index.exists():
    raise SystemExit(f"missing {index}")

source_icon = Path("assets/app_icons/cepqar_icon.png")
if not source_icon.exists():
    raise SystemExit(f"missing {source_icon}")

icons_dir = build / "icons"
icons_dir.mkdir(parents=True, exist_ok=True)
source = Image.open(source_icon).convert("RGBA")
for size in (192, 512):
    out = source.resize((size, size), Image.Resampling.LANCZOS)
    out.save(icons_dir / f"cepqar-{size}.png", optimize=True)
    out.save(icons_dir / f"cepqar-maskable-{size}.png", optimize=True)

manifest = {
    "name": "Cepqar",
    "short_name": "Cepqar",
    "description": "QR tabanlı anonim araç iletişim uygulaması",
    "id": base_path,
    "start_url": base_path,
    "scope": base_path,
    "display": "standalone",
    "orientation": "portrait-primary",
    "background_color": "#07101F",
    "theme_color": "#6E22D9",
    "lang": "tr",
    "categories": ["utilities", "navigation"],
    "icons": [
        {
            "src": "icons/cepqar-192.png",
            "sizes": "192x192",
            "type": "image/png",
            "purpose": "any"
        },
        {
            "src": "icons/cepqar-512.png",
            "sizes": "512x512",
            "type": "image/png",
            "purpose": "any"
        },
        {
            "src": "icons/cepqar-maskable-192.png",
            "sizes": "192x192",
            "type": "image/png",
            "purpose": "maskable"
        },
        {
            "src": "icons/cepqar-maskable-512.png",
            "sizes": "512x512",
            "type": "image/png",
            "purpose": "maskable"
        }
    ]
}
(build / "manifest.json").write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8"
)

html = index.read_text(encoding="utf-8")
meta = f"""
  <meta name="theme-color" content="#6E22D9">
  <meta name="application-name" content="Cepqar">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="apple-mobile-web-app-title" content="Cepqar">
  <meta name="format-detection" content="telephone=no">
  <link rel="manifest" href="manifest.json">
  <link rel="apple-touch-icon" sizes="192x192" href="icons/cepqar-192.png">
"""
if 'name="apple-mobile-web-app-capable"' not in html:
    html = html.replace("</head>", meta + "</head>", 1)

# Ensure iOS safe-area support without disturbing Flutter's existing viewport.
html = html.replace(
    'content="width=device-width, initial-scale=1.0"',
    'content="width=device-width, initial-scale=1.0, viewport-fit=cover"',
    1,
)

install_ui = r"""
<style>
  #cepqar-install-banner {
    position: fixed;
    z-index: 2147483646;
    top: max(10px, env(safe-area-inset-top));
    left: 12px;
    right: 12px;
    display: none;
    align-items: center;
    gap: 10px;
    padding: 10px 10px 10px 12px;
    border-radius: 16px;
    background: rgba(7,16,31,.96);
    border: 1px solid rgba(124,77,255,.45);
    box-shadow: 0 10px 30px rgba(0,0,0,.28);
    color: #fff;
    font-family: -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;
    -webkit-backdrop-filter: blur(12px);
    backdrop-filter: blur(12px);
  }
  #cepqar-install-banner .cepqar-install-icon {
    width: 42px; height: 42px; border-radius: 11px; flex: 0 0 auto;
  }
  #cepqar-install-banner .cepqar-install-copy { min-width: 0; flex: 1 1 auto; }
  #cepqar-install-banner .cepqar-install-title {
    font-size: 14px; line-height: 1.1; font-weight: 800; margin-bottom: 3px;
  }
  #cepqar-install-banner .cepqar-install-subtitle {
    font-size: 11.5px; line-height: 1.2; color: #b8c0d4;
  }
  #cepqar-install-button {
    border: 0; border-radius: 11px; padding: 10px 13px;
    background: #6E22D9; color: #fff; font-weight: 800; font-size: 13px;
    white-space: nowrap;
  }
  #cepqar-install-close {
    border: 0; background: transparent; color: #8e98ad;
    width: 28px; height: 28px; font-size: 22px; line-height: 24px;
    padding: 0; flex: 0 0 auto;
  }
  #cepqar-ios-sheet {
    position: fixed; z-index: 2147483647; inset: 0; display: none;
    align-items: flex-end; justify-content: center;
    background: rgba(0,0,0,.48);
    font-family: -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;
  }
  #cepqar-ios-sheet .sheet {
    width: min(100% - 20px, 520px);
    margin: 10px 10px max(10px, env(safe-area-inset-bottom));
    border-radius: 22px; padding: 18px;
    background: #07101F; color: #fff;
    border: 1px solid rgba(124,77,255,.40);
  }
  #cepqar-ios-sheet .sheet h3 { margin: 0 0 8px; font-size: 20px; }
  #cepqar-ios-sheet .sheet p { margin: 7px 0; color: #c7cede; line-height: 1.4; font-size: 14px; }
  #cepqar-ios-sheet .sheet b { color: #fff; }
  #cepqar-ios-sheet .sheet button {
    width: 100%; margin-top: 12px; padding: 13px; border: 0;
    border-radius: 13px; background: #6E22D9; color: #fff; font-weight: 800;
  }
</style>
<div id="cepqar-install-banner" role="region" aria-label="Cepqar yükleme">
  <img class="cepqar-install-icon" src="icons/cepqar-192.png" alt="">
  <div class="cepqar-install-copy">
    <div class="cepqar-install-title">Cepqar'ı yükle</div>
    <div class="cepqar-install-subtitle" id="cepqar-install-subtitle">Uygulama gibi ana ekrandan aç.</div>
  </div>
  <button id="cepqar-install-button" type="button">Yükle</button>
  <button id="cepqar-install-close" type="button" aria-label="Kapat">×</button>
</div>
<div id="cepqar-ios-sheet" role="dialog" aria-modal="true" aria-label="iPhone'a Cepqar yükleme">
  <div class="sheet">
    <h3>Cepqar'ı iPhone'a ekle</h3>
    <p>Safari'de alttaki <b>Paylaş</b> simgesine dokun.</p>
    <p>Ardından <b>Ana Ekrana Ekle</b> → <b>Ekle</b> seç.</p>
    <p>Sonrasında Cepqar adres çubuğu olmadan uygulama gibi açılır.</p>
    <button id="cepqar-ios-sheet-close" type="button">Tamam</button>
  </div>
</div>
<script>
(function () {
  var banner = document.getElementById('cepqar-install-banner');
  var button = document.getElementById('cepqar-install-button');
  var close = document.getElementById('cepqar-install-close');
  var subtitle = document.getElementById('cepqar-install-subtitle');
  var iosSheet = document.getElementById('cepqar-ios-sheet');
  var iosSheetClose = document.getElementById('cepqar-ios-sheet-close');
  var deferredPrompt = null;

  var standalone = window.matchMedia('(display-mode: standalone)').matches ||
                   window.navigator.standalone === true;
  if (standalone) return;

  var ua = navigator.userAgent || '';
  var isIOS = /iPhone|iPad|iPod/i.test(ua) ||
              (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  var isSafari = isIOS && /Safari/i.test(ua) && !/CriOS|FxiOS|EdgiOS/i.test(ua);

  try {
    var dismissedUntil = Number(localStorage.getItem('cepqar_install_dismissed_until') || '0');
    if (Date.now() < dismissedUntil) return;
  } catch (_) {}

  function showBanner() {
    banner.style.display = 'flex';
  }

  window.addEventListener('beforeinstallprompt', function (event) {
    event.preventDefault();
    deferredPrompt = event;
    subtitle.textContent = 'Tek dokunuşla ana ekrana ekle.';
    button.textContent = 'Yükle';
    showBanner();
  });

  if (isSafari) {
    subtitle.textContent = 'iPhone’a ana ekran uygulaması olarak ekle.';
    button.textContent = 'Nasıl?';
    window.setTimeout(showBanner, 900);
  }

  button.addEventListener('click', async function () {
    if (deferredPrompt) {
      deferredPrompt.prompt();
      try {
        await deferredPrompt.userChoice;
      } catch (_) {}
      deferredPrompt = null;
      banner.style.display = 'none';
      return;
    }
    if (isSafari) {
      iosSheet.style.display = 'flex';
    }
  });

  close.addEventListener('click', function () {
    banner.style.display = 'none';
    try {
      localStorage.setItem(
        'cepqar_install_dismissed_until',
        String(Date.now() + 7 * 24 * 60 * 60 * 1000)
      );
    } catch (_) {}
  });

  iosSheetClose.addEventListener('click', function () {
    iosSheet.style.display = 'none';
  });
  iosSheet.addEventListener('click', function (event) {
    if (event.target === iosSheet) iosSheet.style.display = 'none';
  });

  window.addEventListener('appinstalled', function () {
    banner.style.display = 'none';
  });
})();
</script>
"""

push_ui = r"""
<style>
  #cepqar-push-banner {
    position: fixed; z-index: 2147483645;
    top: max(10px, env(safe-area-inset-top)); left: 12px; right: 12px;
    display: none; align-items: center; gap: 10px;
    padding: 10px 10px 10px 12px; border-radius: 16px;
    background: rgba(7,16,31,.97); border: 1px solid rgba(124,77,255,.45);
    box-shadow: 0 10px 30px rgba(0,0,0,.28); color: #fff;
    font-family: -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;
  }
  #cepqar-push-banner img { width: 42px; height: 42px; border-radius: 11px; flex: 0 0 auto; }
  #cepqar-push-banner .copy { min-width: 0; flex: 1 1 auto; }
  #cepqar-push-banner .title { font-size: 14px; font-weight: 800; margin-bottom: 3px; }
  #cepqar-push-banner .sub { font-size: 11.5px; line-height: 1.2; color: #b8c0d4; }
  #cepqar-push-enable {
    border: 0; border-radius: 11px; padding: 10px 13px;
    background: #6E22D9; color: #fff; font-weight: 800; font-size: 13px; white-space: nowrap;
  }
  #cepqar-push-close {
    border: 0; background: transparent; color: #8e98ad;
    width: 28px; height: 28px; font-size: 22px; line-height: 24px; padding: 0;
  }
</style>
<div id="cepqar-push-banner" role="region" aria-label="Cepqar bildirimleri">
  <img src="icons/cepqar-192.png" alt="">
  <div class="copy">
    <div class="title">Cepqar bildirimlerini aç</div>
    <div class="sub" id="cepqar-push-subtitle">QR mesajları ve araç bildirimleri anında gelsin.</div>
  </div>
  <button id="cepqar-push-enable" type="button">Aç</button>
  <button id="cepqar-push-close" type="button" aria-label="Kapat">×</button>
</div>
<script>
(function () {
  var api = 'https://heycar-api-185-165-46-213.nip.io';
  var authToken = '';
  var authRole = 'owner';
  var banner = document.getElementById('cepqar-push-banner');
  var enableButton = document.getElementById('cepqar-push-enable');
  var closeButton = document.getElementById('cepqar-push-close');
  var subtitle = document.getElementById('cepqar-push-subtitle');

  function standalone() {
    return window.matchMedia('(display-mode: standalone)').matches ||
           window.navigator.standalone === true;
  }

  function base64UrlToUint8Array(value) {
    var padding = '='.repeat((4 - value.length % 4) % 4);
    var base64 = (value + padding).replace(/-/g, '+').replace(/_/g, '/');
    var raw = window.atob(base64);
    var output = new Uint8Array(raw.length);
    for (var i = 0; i < raw.length; ++i) output[i] = raw.charCodeAt(i);
    return output;
  }

  async function subscribeNow() {
    if (!authToken || !('serviceWorker' in navigator) || !('PushManager' in window)) return false;

    // Mobile browsers require the permission prompt to stay inside the direct
    // user gesture. Ask before any network await so the click is not lost.
    var permission = Notification.permission;
    if (permission !== 'granted') permission = await Notification.requestPermission();
    if (permission !== 'granted') return false;

    var configResponse = await fetch(api + '/api/push/web/config', { cache: 'no-store' });
    if (!configResponse.ok) throw new Error('WEB_PUSH_CONFIG_' + configResponse.status);
    var config = await configResponse.json();
    if (!config.enabled || !config.publicKey) throw new Error('WEB_PUSH_NOT_CONFIGURED');

    var registration = await navigator.serviceWorker.getRegistration('./');
    if (!registration) {
      registration = await navigator.serviceWorker.register('cepqar-sw.js', { scope: './' });
    }
    if (registration.waiting) registration.waiting.postMessage({ type: 'SKIP_WAITING' });

    // Always use the active registration returned by ready. A registration
    // object captured while the worker is installing/waiting can make
    // PushManager.subscribe() fail with AbortError on Chromium Android.
    registration = await navigator.serviceWorker.ready;
    if (!registration.active) {
      await new Promise(function (resolve) { setTimeout(resolve, 500); });
      registration = await navigator.serviceWorker.ready;
    }

    var subscription = await registration.pushManager.getSubscription();
    if (!subscription) {
      var options = {
        userVisibleOnly: true,
        applicationServerKey: base64UrlToUint8Array(config.publicKey)
      };
      try {
        subscription = await registration.pushManager.subscribe(options);
      } catch (firstError) {
        console.warn('Cepqar push subscribe first attempt:', firstError);
        await registration.update().catch(function () {});
        await new Promise(function (resolve) { setTimeout(resolve, 1200); });
        registration = await navigator.serviceWorker.ready;
        if (!registration.active) {
          await new Promise(function (resolve) { setTimeout(resolve, 600); });
          registration = await navigator.serviceWorker.ready;
        }
        subscription = await registration.pushManager.getSubscription();
        if (!subscription) subscription = await registration.pushManager.subscribe(options);
      }
    }

    var endpoint = authRole === 'driver'
      ? '/api/driver/web-push-subscription'
      : '/api/owner/web-push-subscription';
    var save = await fetch(api + endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + authToken
      },
      body: JSON.stringify(subscription.toJSON())
    });
    if (!save.ok) throw new Error('WEB_PUSH_SAVE_' + save.status);
    localStorage.setItem('cepqar_web_push_enabled', '1');
    banner.style.display = 'none';
    return true;
  }

  window.cepqarEnableWebPush = async function (token, role) {
    authToken = String(token || '');
    authRole = role === 'driver' ? 'driver' : 'owner';
    if (!authToken) return false;
    if (!('Notification' in window) || !('PushManager' in window) || !('serviceWorker' in navigator)) return false;

    if (Notification.permission === 'granted') {
      try { return await subscribeNow(); }
      catch (error) { console.warn('Cepqar web push refresh:', error); }
    }

    if (!standalone()) return false;
    if (Notification.permission === 'denied') {
      subtitle.textContent = 'Bildirim izni tarayıcı ayarlarından kapalı.';
      enableButton.style.display = 'none';
    } else {
      subtitle.textContent = 'QR mesajları ve araç bildirimleri anında gelsin.';
      enableButton.style.display = '';
    }
    banner.style.display = 'flex';
    return false;
  };

  enableButton.addEventListener('click', async function () {
    enableButton.disabled = true;
    subtitle.textContent = 'Bildirim izni hazırlanıyor…';
    try {
      var ok = await subscribeNow();
      if (!ok) subtitle.textContent = 'Bildirim izni verilmedi.';
    } catch (error) {
      console.warn('Cepqar web push:', error);
      var code = String(error && (error.message || error.name) || '');
      if (code.indexOf('WEB_PUSH_SAVE_401') >= 0) {
        subtitle.textContent = 'Oturum yenileniyor. Cepqar’ı kapatıp tekrar açın.';
      } else if (code.indexOf('WEB_PUSH_SAVE_') >= 0) {
        subtitle.textContent = 'Sunucu aboneliği kaydedemedi. Tekrar deneyin.';
      } else if (code.indexOf('NotAllowed') >= 0 || Notification.permission === 'denied') {
        subtitle.textContent = 'Bildirim izni cihaz ayarlarından kapalı.';
      } else {
        var detail = String((error && (error.name || error.message)) || 'UNKNOWN').replace(/[^A-Za-z0-9_ .:-]/g, '').slice(0,80);
        subtitle.textContent = 'Bildirim servisi hatası: ' + detail;
      }
    } finally {
      enableButton.disabled = false;
    }
  });

  closeButton.addEventListener('click', function () {
    banner.style.display = 'none';
  });
})();
</script>
"""

registration = """
<script>
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', function () {
      navigator.serviceWorker.register('cepqar-sw.js', { scope: './' })
        .catch(function (error) { console.warn('Cepqar PWA service worker:', error); });
    });
  }
</script>
"""
if "cepqar-sw.js" not in html:
    html = html.replace("</body>", install_ui + push_ui + registration + "</body>", 1)

index.write_text(html, encoding="utf-8")

# Network-first/pass-through worker: gives the installable app its own service
# worker without caching Flutter bundles, so deploy cache-busting keeps working.
sw = """const VERSION = 'cepqar-pwa-v2';
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') self.skipWaiting();
});
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter((key) => key.startsWith('cepqar-pwa-') && key !== VERSION).map((key) => caches.delete(key)));
    await self.clients.claim();
  })());
});
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  event.respondWith(fetch(event.request));
});
self.addEventListener('push', (event) => {
  var payload = {};
  try { payload = event.data ? event.data.json() : {}; } catch (_) {}
  var data = payload.data || {};
  var title = payload.title || 'Cepqar';
  var options = {
    body: payload.body || 'Yeni bir bildiriminiz var.',
    icon: payload.icon || 'icons/cepqar-192.png',
    badge: payload.badge || 'icons/cepqar-192.png',
    data: { ...data, url: payload.url || '/HeyCar/owner/' },
    tag: data.notificationId ? 'cepqar-' + data.notificationId : undefined,
    renotify: true,
    vibrate: [200, 100, 200]
  };
  event.waitUntil(self.registration.showNotification(title, options));
});
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  var target = (event.notification.data && event.notification.data.url) || '/HeyCar/owner/';
  event.waitUntil((async () => {
    var windows = await clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (var client of windows) {
      if ('focus' in client) {
        await client.focus();
        if ('navigate' in client) await client.navigate(target);
        return;
      }
    }
    if (clients.openWindow) await clients.openWindow(target);
  })());
});
"""
(build / "cepqar-sw.js").write_text(sw, encoding="utf-8")

print(f"Cepqar PWA ready: base={base_path}, manifest={build/'manifest.json'}")
