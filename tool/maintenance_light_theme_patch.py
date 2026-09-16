from pathlib import Path
import re

FILES = {
    'lib/vehicle_center_page.dart': [
        ("const _bg = Color(0xFF060D1B);", "Color get _bg => CepqarTheme.bg;"),
        ("const _panel = Color(0xFF0E172A);", "Color get _panel => CepqarTheme.panel;"),
        ("const _line = Color(0xFF202D47);", "Color get _line => CepqarTheme.line;"),
        ("const _muted = Color(0xFF9CA8BE);", "Color get _muted => CepqarTheme.muted;"),
    ],
    'lib/upcoming_maintenance_page.dart': [
        ("const _bg=Color(0xFF07111F),_panel=Color(0xFF101A30),_line=Color(0xFF27355D),_purple=Color(0xFF9B5CFF),_muted=Color(0xFFA7B0C7),_lime=Color(0xFF79F56B),_amber=Color(0xFFFFB63E),_pink=Color(0xFFFF4F9A);", "Color get _bg=>CepqarTheme.bg; Color get _panel=>CepqarTheme.panel; Color get _line=>CepqarTheme.line; const _purple=Color(0xFF9B5CFF); Color get _muted=>CepqarTheme.muted; const _lime=Color(0xFF79F56B),_amber=Color(0xFFFFB63E),_pink=Color(0xFFFF4F9A);")
    ],
    'lib/maintenance_share_page.dart': [
        ("const _bg=Color(0xFF07111F),_panel=Color(0xFF101A30),_line=Color(0xFF27355D),_purple=Color(0xFF8B46FF),_muted=Color(0xFFA7B0C7),_gold=Color(0xFFFFC64D);", "Color get _bg=>CepqarTheme.bg; Color get _panel=>CepqarTheme.panel; Color get _line=>CepqarTheme.line; const _purple=Color(0xFF8B46FF); Color get _muted=>CepqarTheme.muted; const _gold=Color(0xFFFFC64D);")
    ],
}

for filename, replacements in FILES.items():
    p = Path(filename)
    text = p.read_text(encoding='utf-8')
    if "import 'cepqar_theme.dart';" not in text:
        lines = text.splitlines()
        at = max((i + 1 for i, line in enumerate(lines) if line.startswith('import ')), default=0)
        lines.insert(at, "import 'cepqar_theme.dart';")
        text = '\n'.join(lines) + ('\n' if text.endswith('\n') else '')
    for old, new in replacements:
        text = text.replace(old, new)

    # All normal copy/icons follow the current theme. Purple action buttons are restored to white below.
    text = text.replace('Colors.white70', 'CepqarTheme.muted')
    text = text.replace('Colors.white', 'CepqarTheme.text')

    # Light equivalents for dark-only decorative surfaces.
    text = text.replace('const Color(0xFF082321)', "(CepqarTheme.isLight ? const Color(0xFFEAF8F0) : const Color(0xFF082321))")
    text = text.replace('const Color(0xFF12543D)', "(CepqarTheme.isLight ? const Color(0xFFB9E5CA) : const Color(0xFF12543D))")
    text = text.replace('const Color(0xFF173D25)', "(CepqarTheme.isLight ? const Color(0xFFD8F2E1) : const Color(0xFF173D25))")
    text = text.replace('const Color(0xFF152A58)', "(CepqarTheme.isLight ? const Color(0xFFEAF0FF) : const Color(0xFF152A58))")
    text = text.replace('const Color(0xFF284681)', "(CepqarTheme.isLight ? const Color(0xFFC9D6F5) : const Color(0xFF284681))")
    text = text.replace('const Color(0xFF40351F)', "(CepqarTheme.isLight ? const Color(0xFFFFF2D8) : const Color(0xFF40351F))")
    text = text.replace('const Color(0xFF26334F)', "(CepqarTheme.isLight ? const Color(0xFFE2E6EF) : const Color(0xFF26334F))")
    text = text.replace('const Color(0xFF25155A)', "(CepqarTheme.isLight ? const Color(0xFFEDE4FF) : const Color(0xFF25155A))")
    text = text.replace('const Color(0xFF342D1C)', "(CepqarTheme.isLight ? const Color(0xFFFFF3D6) : const Color(0xFF342D1C))")
    text = text.replace('const Color(0xFF111B30)', 'CepqarTheme.panel')

    # Dynamic theme values cannot live in const widget expressions.
    text = re.sub(r'\bconst\s+(?=[A-Z_][A-Za-z0-9_]*(?:<[^>]+>)?\s*\()', '', text)

    # Keep text/icons on purple primary actions white in both modes.
    text = re.sub(r'FilledButton\.styleFrom\(\s*backgroundColor:\s*_purple', 'FilledButton.styleFrom(backgroundColor:_purple,foregroundColor:Colors.white', text)

    # Restore public widget constructors used by const callers elsewhere.
    for cls in {
        'lib/vehicle_center_page.dart': ('VehicleCenterPage',),
        'lib/upcoming_maintenance_page.dart': ('UpcomingMaintenancePage',),
        'lib/maintenance_share_page.dart': ('MaintenanceSharePage',),
    }[filename]:
        text = re.sub(rf'(?<!const )\b{cls}(\s*\(\{{)', rf'const {cls}\1', text, count=1)

    p.write_text(text, encoding='utf-8')

print('Vehicle center, upcoming maintenance and maintenance sharing now follow Cepqar light/dark theme.')
