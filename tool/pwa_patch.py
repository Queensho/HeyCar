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
<script src="https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js"></script>
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
  #cepqar-push-banner .steps {
    margin-top: 7px; display: grid; gap: 4px;
    font-size: 11px; line-height: 1.25; color: #d9deea;
  }
  #cepqar-push-banner .steps span {
    display: flex; align-items: flex-start; gap: 6px;
  }
  #cepqar-push-banner .steps b { color: #fff; }

  #cepqar-push-setup {
    position: fixed; z-index: 2147483646; inset: 0; display: none;
    align-items: flex-end; justify-content: center;
    background: rgba(0,0,0,.62);
    font-family: -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;
  }
  #cepqar-push-setup .sheet {
    width: min(100%, 520px); max-height: 92vh; overflow: auto;
    border-radius: 24px 24px 0 0; background: #08111f; color: #fff;
    border: 1px solid rgba(124,77,255,.38); border-bottom: 0;
    padding: 18px 18px calc(20px + env(safe-area-inset-bottom));
    box-shadow: 0 -18px 44px rgba(0,0,0,.42);
  }
  #cepqar-push-setup .handle {
    width: 42px; height: 4px; border-radius: 8px; background: #3a4353;
    margin: 0 auto 18px;
  }
  #cepqar-push-setup .setup-head { display: flex; align-items: center; gap: 12px; }
  #cepqar-push-setup .setup-head img { width: 52px; height: 52px; border-radius: 14px; }
  #cepqar-push-setup .setup-title { font-size: 19px; font-weight: 850; }
  #cepqar-push-setup .setup-sub { color: #aeb8ca; font-size: 13px; line-height: 1.4; margin-top: 3px; }
  #cepqar-push-setup .progress { display: flex; gap: 6px; margin: 18px 0; }
  #cepqar-push-setup .progress i { height: 4px; flex: 1; border-radius: 6px; background: #263143; }
  #cepqar-push-setup .progress i.on { background: #7c4dff; }
  #cepqar-push-setup .card {
    border-radius: 18px; border: 1px solid #263247; background: #0d1828;
    padding: 15px; margin: 10px 0;
  }
  #cepqar-push-setup .card strong { display: block; font-size: 15px; margin-bottom: 7px; }
  #cepqar-push-setup .card p { margin: 0; color: #c2c9d6; font-size: 13px; line-height: 1.45; }
  #cepqar-push-setup .path {
    margin-top: 10px; padding: 10px 11px; border-radius: 12px;
    background: #101f33; color: #fff; font-size: 12px; line-height: 1.4;
  }
  #cepqar-push-setup .primary, #cepqar-push-setup .secondary {
    width: 100%; border: 0; border-radius: 14px; padding: 14px 16px;
    font-size: 14px; font-weight: 800; margin-top: 10px;
  }
  #cepqar-push-setup .primary { background: #6E22D9; color: #fff; }
  #cepqar-push-setup .secondary { background: #172337; color: #dce3ee; }
  #cepqar-push-setup .tiny { color: #8f9bad; font-size: 11px; line-height: 1.35; margin-top: 11px; }
</style>
<div id="cepqar-push-banner" role="region" aria-label="Cepqar bildirimleri">
  <img src="icons/cepqar-192.png" alt="">
  <div class="copy">
    <div class="title">Bildirimleri eksiksiz aç</div>
    <div class="sub" id="cepqar-push-subtitle">Sesli ve üstten bildirim için 3 kısa adımı tamamla.</div>
    <div class="steps" id="cepqar-push-steps">
      <span><b>1.</b> Bildirim iznini aç.</span>
      <span><b>2.</b> Ses + yüzen bildirimi aç.</span>
      <span><b>3.</b> Pil kısıtlamasını kaldır.</span>
    </div>
  </div>
  <button id="cepqar-push-enable" type="button">Başlat</button>
  <button id="cepqar-push-close" type="button" aria-label="Kapat">×</button>
</div>

<div id="cepqar-push-setup" role="dialog" aria-modal="true" aria-label="Cepqar bildirim kurulumu">
  <div class="sheet">
    <div class="handle"></div>
    <div class="setup-head">
      <img src="icons/cepqar-192.png" alt="">
      <div>
        <div class="setup-title" id="cepqar-setup-title">Bildirim kurulumu</div>
        <div class="setup-sub" id="cepqar-setup-sub">Cepqar'ın uygulama kapalıyken de sesli bildirim göndermesi için son ayarları tamamla.</div>
      </div>
    </div>
    <div class="progress"><i id="cepqar-step-1" class="on"></i><i id="cepqar-step-2"></i><i id="cepqar-step-3"></i></div>
    <div class="card">
      <strong id="cepqar-setup-card-title">1. Bildirim izni</strong>
      <p id="cepqar-setup-card-text">Önce Cepqar'ın bildirim göndermesine izin ver.</p>
      <div class="path" id="cepqar-setup-path">Bu izin Cepqar içinden açılır.</div>
    </div>
    <button class="primary" id="cepqar-setup-action" type="button">İzin ver</button>
    <button class="secondary" id="cepqar-setup-next" type="button" style="display:none">Devam et</button>
    <div class="tiny" id="cepqar-setup-note">Telefon modeli ve Android sürümüne göre ayar adları küçük farklılık gösterebilir.</div>
  </div>
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
  var setupSheet = document.getElementById('cepqar-push-setup');
  var setupTitle = document.getElementById('cepqar-setup-title');
  var setupSub = document.getElementById('cepqar-setup-sub');
  var setupCardTitle = document.getElementById('cepqar-setup-card-title');
  var setupCardText = document.getElementById('cepqar-setup-card-text');
  var setupPath = document.getElementById('cepqar-setup-path');
  var setupAction = document.getElementById('cepqar-setup-action');
  var setupNext = document.getElementById('cepqar-setup-next');
  var setupNote = document.getElementById('cepqar-setup-note');
  var setupStep = 1;

  function isAndroid() { return /Android/i.test(navigator.userAgent || ''); }
  function isXiaomi() { return /Xiaomi|Redmi|POCO|MIUI/i.test(navigator.userAgent || ''); }

  function setProgress(step) {
    setupStep = step;
    for (var i = 1; i <= 3; i++) {
      var el = document.getElementById('cepqar-step-' + i);
      if (el) el.className = i <= step ? 'on' : '';
    }
  }

  function openAndroidIntent(intentUrl) {
    try {
      var a = document.createElement('a');
      a.href = intentUrl;
      a.style.display = 'none';
      document.body.appendChild(a);
      a.click();
      setTimeout(function () { try { a.remove(); } catch (_) {} }, 500);
      return true;
    } catch (_) { return false; }
  }

  function showSetup(step) {
    if (!standalone() || !isAndroid()) return;
    setProgress(step);
    setupSheet.style.display = 'flex';
    setupNext.style.display = 'none';
    setupAction.style.display = '';

    if (step === 1) {
      setupTitle.textContent = 'Bildirim kurulumu';
      setupSub.textContent = 'Cepqar bildirimlerini uygulama gibi kullanmak için 3 kısa adım.';
      setupCardTitle.textContent = '1. Bildirim izni';
      setupCardText.textContent = 'Android bildirim iznini aç. Bu izin olmadan Cepqar bildirim gönderemez.';
      setupPath.textContent = 'Cepqar > Bildirimlere izin ver';
      setupAction.textContent = Notification.permission === 'granted' ? 'İzin açık • Devam et' : 'İzin ver';
      setupAction.onclick = async function () {
        if (Notification.permission !== 'granted') {
          try { await Notification.requestPermission(); } catch (_) {}
        }
        if (Notification.permission === 'granted') showSetup(2);
      };
    } else if (step === 2) {
      setupTitle.textContent = 'Ses ve üstten bildirim';
      setupSub.textContent = 'Bildirim geldiğinde ses çalsın ve ekranın üstünde görünsün.';
      setupCardTitle.textContent = '2. Ses + Yüzen bildirim';
      setupCardText.textContent = isXiaomi()
        ? 'Cepqar/Chrome bildirimlerinde Ses, Titreşim, Yüzen bildirimler ve Kilit ekranı bildirimlerini aç.'
        : 'Cepqar/Chrome bildirimlerinde Ses ve Açılır/Yüzen bildirimleri aç.';
      setupPath.textContent = isXiaomi()
        ? 'Ayarlar > Bildirimler ve durum çubuğu > Uygulama bildirimleri > Cepqar/Chrome'
        : 'Ayarlar > Bildirimler > Uygulama bildirimleri > Cepqar/Chrome';
      setupAction.textContent = 'Bildirim ayarını aç';
      setupAction.onclick = function () {
        openAndroidIntent('intent:#Intent;action=android.settings.NOTIFICATION_SETTINGS;end');
        setupNext.style.display = '';
      };
      setupNext.textContent = 'Yaptım • Devam et';
      setupNext.onclick = function () { showSetup(3); };
    } else {
      setupTitle.textContent = 'Arka planda çalışsın';
      setupSub.textContent = 'Cepqar kapalıyken bildirimlerin gecikmemesi için son adım.';
      setupCardTitle.textContent = '3. Pil kısıtlamasını kaldır';
      setupCardText.textContent = isXiaomi()
        ? 'Cepqar/Chrome için Pil tasarrufu ayarını “Kısıtlama yok” yap.'
        : 'Cepqar/Chrome için arka plan veya pil optimizasyonu kısıtlamasını kaldır.';
      setupPath.textContent = isXiaomi()
        ? 'Ayarlar > Uygulamalar > Cepqar/Chrome > Pil tasarrufu > Kısıtlama yok'
        : 'Ayarlar > Uygulamalar > Cepqar/Chrome > Pil > Kısıtlanmamış';
      setupAction.textContent = 'Pil ayarını aç';
      setupAction.onclick = function () {
        openAndroidIntent('intent:#Intent;action=android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS;end');
        setupNext.style.display = '';
      };
      setupNext.textContent = 'Kurulumu tamamla';
      setupNext.onclick = function () {
        try { localStorage.setItem('cepqar_push_onboarding_done_v1', '1'); } catch (_) {}
        setupSheet.style.display = 'none';
        banner.style.display = 'none';
      };
    }
  }

  var firebaseConfig = {
    apiKey: "AIzaSyDgb-J_Ep-63EQM7U5OI_Y-pfEbJxUnD-M",
    authDomain: "cepqar.firebaseapp.com",
    projectId: "cepqar",
    storageBucket: "cepqar.firebasestorage.app",
    messagingSenderId: "1003508989542",
    appId: "1:1003508989542:web:8b202856b0e298db43b7a7",
    measurementId: "G-174BCF3CR2"
  };
  var firebaseVapidKey = "BE0f7fqD5JQfay85f32TtpWfAn6ronMccihvbHD9bSEzy-PV0joBE0smgWg-Pxh4gg3tcKOdR3SDxA5_cnDhGCw";
  var messaging = null;

  async function resolveVapidKey() {
    try {
      var r = await fetch(api + '/api/push/web/config', { cache: 'no-store' });
      if (!r.ok) return firebaseVapidKey;
      var j = await r.json();
      if (j && j.enabled && j.publicKey) return String(j.publicKey);
    } catch (_) {}
    return firebaseVapidKey;
  }

  function standalone() {
    return window.matchMedia('(display-mode: standalone)').matches ||
           window.navigator.standalone === true;
  }

  function ensureFirebase() {
    if (!window.firebase || !firebase.messaging) throw new Error('FIREBASE_SDK_NOT_READY');
    if (!firebase.apps.length) firebase.initializeApp(firebaseConfig);
    if (!messaging) {
      messaging = firebase.messaging();
      messaging.onMessage(function (payload) {
        var title = (payload.notification && payload.notification.title) || (payload.data && payload.data.title) || 'Cepqar';
        var body = (payload.notification && payload.notification.body) || (payload.data && payload.data.body) || 'Yeni bir bildiriminiz var.';
        navigator.serviceWorker.ready.then(function (registration) {
          registration.showNotification(title, {
            body: body,
            icon: 'icons/cepqar-192.png',
            badge: 'icons/cepqar-192.png',
            data: Object.assign({}, payload.data || {}, { url: '/HeyCar/owner/' })
          });
        }).catch(function () {});
      });
    }
    return messaging;
  }

  function deviceId() {
    var key = 'cepqar_web_device_id';
    var current = localStorage.getItem(key);
    if (current) return current;
    current = (window.crypto && crypto.randomUUID)
      ? 'web-' + crypto.randomUUID()
      : 'web-' + Date.now() + '-' + Math.random().toString(36).slice(2);
    localStorage.setItem(key, current);
    return current;
  }

  async function subscribeNow() {
    if (!authToken || !('serviceWorker' in navigator) || !('Notification' in window)) return false;

    var permission = Notification.permission;
    if (permission !== 'granted') permission = await Notification.requestPermission();
    if (permission !== 'granted') return false;

    var registration = await navigator.serviceWorker.getRegistration('./');
    var expectedWorker = new URL('firebase-messaging-sw.js', location.href).href;
    var currentWorkerUrl = registration && (
      (registration.active && registration.active.scriptURL) ||
      (registration.waiting && registration.waiting.scriptURL) ||
      (registration.installing && registration.installing.scriptURL)
    );

    // Important migration: users who installed Cepqar before the Firebase
    // worker rename can still be controlled by the old cepqar-sw.js.
    // getRegistration() alone reuses that registration, so background FCM
    // never reaches firebase-messaging-sw.js after the PWA is closed.
    if (registration && currentWorkerUrl && currentWorkerUrl !== expectedWorker) {
      try { await registration.unregister(); } catch (_) {}
      registration = null;
    }

    if (!registration) {
      registration = await navigator.serviceWorker.register(
        'firebase-messaging-sw.js',
        { scope: './', updateViaCache: 'none' }
      );
    } else {
      registration = await navigator.serviceWorker.register(
        'firebase-messaging-sw.js',
        { scope: './', updateViaCache: 'none' }
      );
    }

    if (registration.waiting) {
      registration.waiting.postMessage({ type: 'SKIP_WAITING' });
    }
    registration = await navigator.serviceWorker.ready;

    var fcm = ensureFirebase();
    var activeVapidKey = await resolveVapidKey();
    var tokenVersion = 'cepqar-fcm-sw-v12-dual-webpush';
    var savedTokenVersion = localStorage.getItem('cepqar_fcm_token_version') || '';

    // Run destructive migration only once. If Chrome's push backend is
    // temporarily unavailable, repeated button taps must not keep deleting the
    // browser subscription and make recovery harder.
    if (savedTokenVersion !== tokenVersion) {
      localStorage.setItem('cepqar_fcm_token_version', tokenVersion);
      try { await fcm.deleteToken(); } catch (_) {}
      try {
        var oldSubscription = await registration.pushManager.getSubscription();
        if (oldSubscription) await oldSubscription.unsubscribe();
      } catch (_) {}
      try { await registration.update(); } catch (_) {}
      await new Promise(function (resolve) { setTimeout(resolve, 700); });
      registration = await navigator.serviceWorker.ready;
    }

    var token = '';
    var lastTokenError = null;
    var retryDelays = [0, 1200, 3000, 6000];
    for (var attempt = 0; attempt < retryDelays.length; attempt++) {
      if (retryDelays[attempt]) {
        await new Promise(function (resolve) { setTimeout(resolve, retryDelays[attempt]); });
      }
      try {
        registration = await navigator.serviceWorker.ready;
        token = await fcm.getToken({
          vapidKey: activeVapidKey,
          serviceWorkerRegistration: registration
        });
        if (token) break;
      } catch (error) {
        lastTokenError = error;
        console.warn('Cepqar FCM getToken attempt ' + (attempt + 1), error);
        try { await registration.update(); } catch (_) {}
      }
    }
    if (!token) {
      if (lastTokenError) throw lastTokenError;
      throw new Error('FCM_WEB_TOKEN_EMPTY');
    }

    var endpoint = authRole === 'driver' ? '/api/driver/push-token' : '/api/owner/push-token';
    async function saveWebToken(value) {
      return fetch(api + endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + authToken
        },
        body: JSON.stringify({
          token: value,
          deviceId: deviceId(),
          platform: 'web'
        })
      });
    }

    var save = await saveWebToken(token);
    if (save.status === 409) {
      var stale = {};
      try { stale = await save.json(); } catch (_) {}
      if (stale && stale.error === 'WEB_TOKEN_STALE') {
        try { await fcm.deleteToken(); } catch (_) {}
        try {
          var staleSubscription = await registration.pushManager.getSubscription();
          if (staleSubscription) await staleSubscription.unsubscribe();
        } catch (_) {}
        try { await registration.update(); } catch (_) {}
        await new Promise(function (resolve) { setTimeout(resolve, 900); });
        registration = await navigator.serviceWorker.ready;
        token = await fcm.getToken({
          vapidKey: activeVapidKey,
          serviceWorkerRegistration: registration
        });
        if (!token) throw new Error('FCM_WEB_TOKEN_REFRESH_EMPTY');
        save = await saveWebToken(token);
      }
    }
    if (!save.ok) throw new Error('FCM_WEB_SAVE_' + save.status);

    try {
      var browserSubscription = await registration.pushManager.getSubscription();
      if (browserSubscription) {
        var subJson = browserSubscription.toJSON();
        var directEndpoint = authRole === 'driver'
          ? '/api/driver/web-push-subscription'
          : '/api/owner/web-push-subscription';
        await fetch(api + directEndpoint, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ' + authToken
          },
          body: JSON.stringify(subJson)
        });
      }
    } catch (directError) {
      console.warn('Cepqar direct Web Push subscription:', directError);
    }

    localStorage.setItem('cepqar_fcm_web_token', token);
    localStorage.setItem('cepqar_web_push_enabled', '1');

    // Verify the browser can actually display a notification without asking
    // the user to run a separate test step.
    await registration.showNotification('Cepqar bildirimleri açık', {
      body: 'Araç bildirimleri artık bu cihazda gösterilecek.',
      icon: 'icons/cepqar-192.png',
      badge: 'icons/cepqar-192.png',
      tag: 'cepqar-push-ready',
      renotify: false,
      data: { url: '/HeyCar/owner/', type: 'push_ready' }
    });

    subtitle.textContent = 'Bildirim izni açık. Ses ve arka plan ayarlarını tamamla.';
    enableButton.textContent = 'Devam et';
    enableButton.disabled = false;
    enableButton.onclick = function () { showSetup(2); };
    try {
      if (localStorage.getItem('cepqar_push_onboarding_done_v1') !== '1') showSetup(2);
    } catch (_) { showSetup(2); }
    return true;
  }

  window.cepqarEnableWebPush = async function (token, role) {
    authToken = String(token || '');
    authRole = role === 'driver' ? 'driver' : 'owner';
    if (!authToken) return false;
    if (!('Notification' in window) || !('serviceWorker' in navigator)) return false;

    if (Notification.permission === 'granted') {
      try {
        var result = await subscribeNow();
        try {
          if (result && localStorage.getItem('cepqar_push_onboarding_done_v1') !== '1') showSetup(2);
        } catch (_) {}
        return result;
      }
      catch (error) {
        console.warn('Cepqar FCM web refresh:', error);
        if (standalone()) {
          subtitle.textContent = 'Bildirimler yeniden bağlanıyor…';
          banner.style.display = 'flex';
        }
      }
    }

    if (!standalone()) return false;
    if (Notification.permission === 'denied') {
      subtitle.textContent = '1/2 Bildirim izni kapalı. Tarayıcı ayarlarından Cepqar bildirimlerine izin ver.';
      enableButton.style.display = 'none';
    } else {
      subtitle.textContent = 'Uygulama kapalıyken de bildirim almak için iki izin gerekiyor.';
      enableButton.style.display = '';
    }
    banner.style.display = 'flex';
    return false;
  };

  enableButton.addEventListener('click', async function () {
    enableButton.disabled = true;
    subtitle.textContent = '1/2 Bildirim izni açılıyor…';
    try {
      var ok = await subscribeNow();
      if (!ok) subtitle.textContent = 'Bildirim izni verilmedi.';
    } catch (error) {
      console.warn('Cepqar FCM web:', error);
      var rawCode = '';
      if (error) {
        if (typeof error.code === 'string' && error.code) rawCode = error.code;
        else if (typeof error.message === 'string' && error.message) rawCode = error.message;
        else if (typeof error.name === 'string' && error.name) rawCode = error.name;
        else if (error.code != null) rawCode = 'DOM_' + String(error.code);
      }
      var code = String(rawCode || 'UNKNOWN')
        .replace(/[^A-Za-z0-9_ .:\/-]/g, '').slice(0,120);
      if (code.indexOf('FCM_WEB_SAVE_401') >= 0) {
        subtitle.textContent = 'Oturum yenileniyor. Cepqar’ı kapatıp tekrar açın.';
      } else if (code.indexOf('FCM_WEB_SAVE_') >= 0) {
        subtitle.textContent = 'Bildirimler açılamadı. Tekrar deneyin.';
      } else if (code.indexOf('permission-blocked') >= 0 || Notification.permission === 'denied') {
        subtitle.textContent = 'Bildirim izni cihaz ayarlarından kapalı.';
      } else if (code.indexOf('AbortError') >= 0 || code.indexOf('DOM_20') >= 0) {
        subtitle.textContent = 'Bildirim servisi bağlantısı yenilenemedi. Tekrar deneyin.';
      } else {
        subtitle.textContent = 'Bildirimler açılamadı (' + code + ').';
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
      navigator.serviceWorker.register('firebase-messaging-sw.js', { scope: './', updateViaCache: 'none' })
        .catch(function (error) { console.warn('Cepqar PWA service worker:', error); });
    });
  }
</script>
"""
if "firebase-messaging-sw.js" not in html:
    html = html.replace("</body>", install_ui + push_ui + registration + "</body>", 1)

index.write_text(html, encoding="utf-8")

# Network-first/pass-through worker: gives the installable app its own service
# worker without caching Flutter bundles, so deploy cache-busting keeps working.
sw = """const VERSION = 'cepqar-pwa-v11-click-openwindow';

self.addEventListener('notificationclick', (event) => {
  if (typeof event.stopImmediatePropagation === 'function') event.stopImmediatePropagation();
  event.notification.close();

  const rawTarget = (event.notification.data && event.notification.data.url) || '/HeyCar/owner/';
  const target = new URL(rawTarget, self.location.origin).href;

  event.waitUntil((async () => {
    // First focus an existing Cepqar PWA window if one exists.
    const windows = await clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of windows) {
      try {
        const url = new URL(client.url);
        if (url.origin === self.location.origin && url.pathname.startsWith('/HeyCar/owner/')) {
          if ('navigate' in client && client.url !== target) {
            try { await client.navigate(target); } catch (_) {}
          }
          if ('focus' in client) await client.focus();
          return;
        }
      } catch (_) {}
    }

    // Do not hijack an unrelated GitHub Pages window. Open the PWA target
    // directly; notificationclick is a user activation and openWindow is allowed.
    if (clients.openWindow) {
      const opened = await clients.openWindow(target);
      if (opened && 'focus' in opened) {
        try { await opened.focus(); } catch (_) {}
      }
      return;
    }
  })());
});

importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyDgb-J_Ep-63EQM7U5OI_Y-pfEbJxUnD-M",
  authDomain: "cepqar.firebaseapp.com",
  projectId: "cepqar",
  storageBucket: "cepqar.firebasestorage.app",
  messagingSenderId: "1003508989542",
  appId: "1:1003508989542:web:8b202856b0e298db43b7a7"
});

const messaging = firebase.messaging();

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
  try {
    const payload = event.data ? event.data.json() : {};
    const data =
      (payload && payload.data) ||
      (payload && payload.message && payload.message.data) ||
      {};

    const tasks = [];
    if (data.webReceiptId && data.webReceiptSig) {
      tasks.push(
        fetch('https://heycar-api-185-165-46-213.nip.io/api/push/web-receipt', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            id: data.webReceiptId,
            sig: data.webReceiptSig,
            stage: 'raw_push_event'
          }),
          keepalive: true
        }).catch(() => null)
      );
    }

    // Standards Web Push fallback sent by our backend.
    if (payload && payload.title && !payload.from && !payload.message) {
      tasks.push(self.registration.showNotification(String(payload.title || 'Cepqar'), {
        body: String(payload.body || 'Yeni bir bildiriminiz var.'),
        icon: payload.icon || '/HeyCar/owner/icons/cepqar-192.png',
        badge: payload.badge || '/HeyCar/owner/icons/cepqar-192.png',
        data: Object.assign({}, payload.data || {}, { url: payload.url || '/HeyCar/owner/' }),
        tag: 'cepqar-direct-' + String((payload.data && (payload.data.notificationId || payload.data.eventId)) || Date.now()),
        renotify: true,
        vibrate: [200, 100, 200]
      }));
    }

    if (tasks.length) event.waitUntil(Promise.all(tasks));
  } catch (_) {}
});

messaging.onBackgroundMessage((payload) => {
  const data = payload.data || {};
  const notification = payload.notification || {};
  const title = notification.title || data.title || 'Cepqar';
  const options = {
    body: notification.body || data.body || data.message || 'Yeni bir bildiriminiz var.',
    icon: '/HeyCar/owner/icons/cepqar-192.png',
    badge: '/HeyCar/owner/icons/cepqar-192.png',
    data: { ...data, url: '/HeyCar/owner/' },
    tag: data.notificationId ? 'cepqar-' + data.notificationId : 'cepqar-' + String(data.type || 'push'),
    renotify: true,
    vibrate: [200, 100, 200]
  };

  const tasks = [];
  if (data.webReceiptId && data.webReceiptSig) {
    tasks.push(
      fetch('https://heycar-api-185-165-46-213.nip.io/api/push/web-receipt', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id: data.webReceiptId,
          sig: data.webReceiptSig,
          stage: 'background_handler'
        }),
        keepalive: true
      }).catch(() => null)
    );
  }
  tasks.push(self.registration.showNotification(title, options));
  return Promise.all(tasks);
});
"""
(build / "firebase-messaging-sw.js").write_text(sw, encoding="utf-8")

print(f"Cepqar PWA ready: base={base_path}, manifest={build/'manifest.json'}")
