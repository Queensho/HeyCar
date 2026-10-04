from pathlib import Path

# Public QR/visitor screens are now maintained directly in source.
# Keep this workflow step as a stable no-op so CI does not rewrite the new UI.
required = [
    Path('lib/public_qr_entry.dart'),
    Path('lib/public_qr_personalized.dart'),
]
missing = [str(p) for p in required if not p.exists()]
if missing:
    raise SystemExit('Missing public visitor source: ' + ', '.join(missing))

print('Public visitor source UI preserved; legacy rewrite disabled.')
