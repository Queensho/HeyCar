from pathlib import Path
import re

p = Path('lib/driver_invite_page.dart')
s = p.read_text(encoding='utf-8')

if "import 'cepqar_theme.dart';" not in s:
    s = s.replace("import 'vehicle_api.dart';", "import 'vehicle_api.dart';\nimport 'cepqar_theme.dart';")

# Use exactly the same shared palette as the owner side.
s = s.replace("const _bg = Color(0xFF07111F);", "Color get _bg => CepqarTheme.bg;")
s = s.replace("const _panel = Color(0xFF101A30);", "Color get _panel => CepqarTheme.panel;")
s = s.replace("const _panel2 = Color(0xFF0D1728);", "Color get _panel2 => CepqarTheme.isLight ? const Color(0xFFF3F0FA) : const Color(0xFF0D1728);")
s = s.replace("const _line = Color(0xFF27355D);", "Color get _line => CepqarTheme.line;")
s = s.replace("const _muted = Color(0xFFA7B0C7);", "Color get _muted => CepqarTheme.muted;")
s = s.replace("const _purpleSoft = Color(0xFFC8B4FF);", "Color get _purpleSoft => CepqarTheme.isLight ? const Color(0xFF6F45D8) : const Color(0xFFC8B4FF);")

# Remaining fixed dark surfaces used by app bars, cards and bottom navigation.
s = s.replace("const Color(0xFF0A1020)", "(CepqarTheme.isLight ? Colors.white : const Color(0xFF0A1020))")
s = s.replace("const Color(0xFF0B1426)", "(CepqarTheme.isLight ? Colors.white : const Color(0xFF0B1426))")
s = s.replace("const Color(0xFF10172B)", "(CepqarTheme.isLight ? const Color(0xFFF3F0FA) : const Color(0xFF10172B))")
s = s.replace("const Color(0xFF080F20)", "(CepqarTheme.isLight ? const Color(0xFFF8F6FC) : const Color(0xFF080F20))")
s = s.replace("const Color(0xFF121530)", "(CepqarTheme.isLight ? const Color(0xFFEDE8F7) : const Color(0xFF121530))")
s = s.replace("const Color(0xFF111B31)", "(CepqarTheme.isLight ? const Color(0xFFF1EDF8) : const Color(0xFF111B31))")

# Driver hero follows the owner hero: separate light/dark artwork and switch.
s = s.replace("'assets/Aracsahibi.png',\n                  fit: BoxFit.cover,", "CepqarTheme.isLight ? 'assets/Aracsahibig.png' : 'assets/Aracsahibi.png',\n                  key: ValueKey(CepqarTheme.isLight),\n                  fit: BoxFit.cover,")
# Remove the dark fade overlay in light mode so the light artwork stays light.
s = s.replace("const DecoratedBox(\n                  decoration: BoxDecoration(\n                    gradient: LinearGradient(\n                      begin: Alignment.topCenter,\n                      end: Alignment.bottomCenter,\n                      stops: [0.0, .54, 1.0],\n                      colors: [Color(0x16000000), Color(0x08000000), Color(0xA807111F)],\n                    ),\n                  ),\n                ),", "if (!CepqarTheme.isLight) const DecoratedBox(\n                  decoration: BoxDecoration(\n                    gradient: LinearGradient(\n                      begin: Alignment.topCenter,\n                      end: Alignment.bottomCenter,\n                      stops: [0.0, .54, 1.0],\n                      colors: [Color(0x16000000), Color(0x08000000), Color(0xA807111F)],\n                    ),\n                  ),\n                ),")

# Put the same theme switch used by the owner in the driver header.
profile_old = "Flexible(child: _profile()),"
profile_new = "Flexible(child: _profile()),\n                      const SizedBox(width: 10),\n                      const CepqarThemeSwitch(),"
if profile_new not in s:
    s = s.replace(profile_old, profile_new, 1)

# Normal driver text/cards follow the shared light/dark text palette.
s = s.replace('Colors.white70', 'CepqarTheme.muted')
s = re.sub(r'color:\s*Colors\.white(?=\s*[,\)])', 'color: CepqarTheme.text', s)
# Hero copy remains white over both owner/driver artwork, matching owner header.
s = s.replace("color: CepqarTheme.text,\n                          fontSize: 32,", "color: Colors.white,\n                          fontSize: 32,")
s = s.replace("color: _purple,\n                          fontSize: 43,", "color: Colors.white,\n                          fontSize: 43,")
s = s.replace("color: CepqarTheme.muted,\n                            fontSize: 17,", "color: Colors.white70,\n                            fontSize: 17,")
# Purple filled buttons must keep white labels/icons in both themes.
s = re.sub(r'FilledButton\.styleFrom\(backgroundColor:\s*_purple(?!\s*,\s*foregroundColor)', 'FilledButton.styleFrom(backgroundColor:_purple,foregroundColor:Colors.white', s)

# Runtime theme values cannot live under const widget invocations.
s = re.sub(r'\bconst\s+(?=[_A-Z][A-Za-z0-9_]*(?:<[^>]+>)?\s*\()', '', s)
s = s.replace('const <Widget>[', '<Widget>[').replace('const [', '[')

# Restore public immutable constructors referenced by const call sites elsewhere.
for cls in ('DriverCodeEntryPage', 'DriverRegisterPage', 'DriverHomePage', 'DriverInvitePage'):
    s = re.sub(rf'(?<!const )\b{cls}(\s*\(\{{)', rf'const {cls}\1', s, count=1)

# Rebuild the complete driver shell whenever the shared theme mode changes.
needle = "  @override\n  Widget build(BuildContext context) {\n    final screens = <Widget>["
replacement = "  @override\n  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(\n    valueListenable: CepqarTheme.mode,\n    builder: (context, _, __) {\n    final screens = <Widget>["
if needle in s:
    s = s.replace(needle, replacement, 1)
    marker = "      ),\n    );\n  }\n}\n\nclass _DriverHome extends StatelessWidget"
    repl = "      ),\n    );\n    },\n  );\n}\n\nclass _DriverHome extends StatelessWidget"
    s = s.replace(marker, repl, 1)

p.write_text(s, encoding='utf-8')
print('Driver now uses the same Cepqar light/dark theme behavior as owner screens.')
