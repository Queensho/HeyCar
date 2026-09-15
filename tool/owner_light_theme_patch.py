from pathlib import Path

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
        "Color(0xFF0B1426)": "CepqarTheme.panel",
    },
}

for filename, replacements in TARGETS.items():
    p = Path(filename)
    text = p.read_text(encoding='utf-8')
    if "import 'cepqar_theme.dart';" not in text:
        # Insert after the last package import / local import block safely near the top.
        lines = text.splitlines()
        insert_at = 0
        for i, line in enumerate(lines):
            if line.startswith('import '):
                insert_at = i + 1
        lines.insert(insert_at, "import 'cepqar_theme.dart';")
        text = '\n'.join(lines) + ('\n' if text.endswith('\n') else '')
    for old, new in replacements.items():
        text = text.replace(old, new)

    # These owner pages were originally hard-coded dark. Their const widgets cannot
    # reference dynamic theme getters, so make the widget expressions runtime values.
    text = text.replace('const ', '')
    text = text.replace('Colors.white', 'CepqarTheme.text')
    # Purple/red action buttons must keep white foreground in both themes.
    text = text.replace('foregroundColor: CepqarTheme.text', 'foregroundColor: Colors.white')
    text = text.replace('foregroundColor:CepqarTheme.text', 'foregroundColor:Colors.white')
    p.write_text(text, encoding='utf-8')

# Hero copy stays white over both photographic header assets.
p = Path('lib/owner_dashboard_live.dart')
text = p.read_text(encoding='utf-8')
text = text.replace("color:light?CepqarTheme.lightText:Colors.white,fontSize:32", "color:Colors.white,fontSize:32")
text = text.replace("color:light?CepqarTheme.lightMuted:Colors.white70,fontSize:17", "color:Colors.white70,fontSize:17")
p.write_text(text, encoding='utf-8')

print('Owner light theme patch applied.')
