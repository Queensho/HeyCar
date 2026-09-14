from pathlib import Path
import re

BRAND_FROM = 'HeyCar'
BRAND_TO = 'Cepqar'

# Only change user-facing string literals. Technical URLs, repo paths and API
# identifiers remain untouched so the current infrastructure keeps working.
string_re = re.compile(r"('(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\")")


def replace_literal(match):
    token = match.group(0)
    body = token[1:-1]
    if BRAND_FROM not in body:
        return token
    technical = (
        'http://' in body
        or 'https://' in body
        or '/HeyCar/' in body
        or 'github.io/HeyCar' in body
    )
    if technical:
        return token
    return token[0] + body.replace(BRAND_FROM, BRAND_TO) + token[-1]


for path in Path('lib').rglob('*.dart'):
    text = path.read_text(encoding='utf-8')
    text = string_re.sub(replace_literal, text)

    # The main owner dashboard previously drew the old name as two TextSpans.
    # Use the uploaded Cepqar PNG logo asset instead, without touching QR/API URLs.
    if path.as_posix() == 'lib/owner_dashboard_live.dart':
        text = re.sub(
            r"Widget _logo\(\) => const Text\.rich\(.*?\n\s*\);",
            "Widget _logo() => Image.asset('assets/Logoqr.png', height: 48, fit: BoxFit.contain);",
            text,
            flags=re.S,
        )
        text = text.replace("Image.asset('assets/Logoqr.jpg', height: 48, fit: BoxFit.contain)",
                            "Image.asset('assets/Logoqr.png', height: 48, fit: BoxFit.contain)")
        text = text.replace('HeyCar etiketin her zaman yanında, yollarda daha güvende.',
                            'Cepqar etiketin her zaman yanında, yollarda daha güvende.')

    path.write_text(text, encoding='utf-8')

print('Cepqar frontend branding applied; technical HeyCar infrastructure preserved.')
