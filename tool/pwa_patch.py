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
    html = html.replace("</body>", registration + "</body>", 1)

index.write_text(html, encoding="utf-8")

# Network-first/pass-through worker: gives the installable app its own service
# worker without caching Flutter bundles, so deploy cache-busting keeps working.
sw = """const VERSION = 'cepqar-pwa-v1';
self.addEventListener('install', () => self.skipWaiting());
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
"""
(build / "cepqar-sw.js").write_text(sw, encoding="utf-8")

print(f"Cepqar PWA ready: base={base_path}, manifest={build/'manifest.json'}")
