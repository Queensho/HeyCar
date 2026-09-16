from pathlib import Path
import re

TARGETS = {
    'lib/owner_notifications_page.dart': {
        "const _bg = Color(0xFF07111F);": "Color get _bg => CepqarTheme.bg;",
        "const _panel = Color(0xFF101A30);": "Color get _panel => CepqarTheme.panel;",
        "const _panel2 = Color(0xFF0D1728);": "Color get _panel2 => CepqarTheme.panel;",
        "const _line = Color(0xFF27355D);": "Color get _line => CepqarTheme.line;",
        "const _muted = Color(0xFFA7B0C7);": "Color get _muted => CepqarTheme.muted;",
    },
    'lib/owner_settings_page.dart': {
        "const _bg = Color(0xFF07111F);": "Color get _bg => CepqarTheme.bg;",
        "const _panel = Color(0xFF111A31);": "Color get _panel => CepqarTheme.panel;",
        "const _line = Color(0xFF29345A);": "Color get _line => CepqarTheme.line;",
        "const _muted = Color(0xFFA7B0C7);": "Color get _muted => CepqarTheme.muted;",
        "const Color(0xFF080F20)": "CepqarTheme.bg",
        "const Color(0xFF121530)": "CepqarTheme.panel",
        "const Color(0xFF10172B)": "CepqarTheme.panel",
        "Color(0xFF080F20)": "CepqarTheme.bg",
        "Color(0xFF121530)": "CepqarTheme.panel",
        "Color(0xFF10172B)": "CepqarTheme.panel",
    },
    'lib/owner_vehicles_page.dart': {
        "const _bg=Color(0xFF07111F),_panel=Color(0xFF101A30),_line=Color(0xFF27355D),_purple=Color(0xFF8B5CFF),_muted=Color(0xFFA7B0C7),_gold=Color(0xFFFFC857);": "Color get _bg=>CepqarTheme.bg; Color get _panel=>CepqarTheme.panel; Color get _line=>CepqarTheme.line; const _purple=Color(0xFF8B5CFF); Color get _muted=>CepqarTheme.muted; const _gold=Color(0xFFFFC857);",
    },
    'lib/owner_chat_page.dart': {
        "const _bg = Color(0xFF07111F);": "Color get _bg => CepqarTheme.bg;",
        "const _panel = Color(0xFF101A30);": "Color get _panel => CepqarTheme.panel;",
        "const _muted = Color(0xFFA7B0C7);": "Color get _muted => CepqarTheme.muted;",
        "const Color(0xFF0B1426)": "CepqarTheme.panel",
        "Color(0xFF0B1426)": "CepqarTheme.panel",
    },
}

for filename, replacements in TARGETS.items():
    p = Path(filename)
    text = p.read_text(encoding='utf-8')
    if "import 'cepqar_theme.dart';" not in text:
        lines = text.splitlines()
        insert_at = max((i + 1 for i, line in enumerate(lines) if line.startswith('import ')), default=0)
        lines.insert(insert_at, "import 'cepqar_theme.dart';")
        text = '\n'.join(lines) + ('\n' if text.endswith('\n') else '')
    for old, new in replacements.items():
        text = text.replace(old, new)

    # Keep white70 valid before converting plain white foregrounds.
    text = text.replace('Colors.white70', 'CepqarTheme.muted')
    text = text.replace('Colors.white', 'CepqarTheme.text')
    text = text.replace('foregroundColor: CepqarTheme.text', 'foregroundColor: Colors.white')
    text = text.replace('foregroundColor:CepqarTheme.text', 'foregroundColor:Colors.white')

    # Runtime theme getters cannot be nested under const widget expressions.
    text = re.sub(r'\bconst\s+(?=[A-Z][A-Za-z0-9_]*(?:<[^>]+>)?\s*\()', '', text)

    # Restore public const constructors used from other screens.
    constructors = {
        'lib/owner_notifications_page.dart': ('OwnerNotificationsPage',),
        'lib/owner_settings_page.dart': ('OwnerSettingsPage',),
        'lib/owner_vehicles_page.dart': ('OwnerVehiclesPage',),
        'lib/owner_chat_page.dart': ('OwnerChatPage',),
    }[filename]
    for cls in constructors:
        text = re.sub(rf'(?m)^(\s*){cls}(\s*\(\{{)', rf'\1const {cls}\2', text)

    p.write_text(text, encoding='utf-8')

# Hero copy must remain white on both photographic header assets.
p = Path('lib/owner_dashboard_live.dart')
text = p.read_text(encoding='utf-8')
text = text.replace("color:light?CepqarTheme.lightText:Colors.white,fontSize:32", "color:Colors.white,fontSize:32")
text = text.replace("color:light?CepqarTheme.lightMuted:Colors.white70,fontSize:17", "color:Colors.white70,fontSize:17")
p.write_text(text, encoding='utf-8')

print('Owner light theme patch applied safely.')
