from pathlib import Path
import re

p = Path('lib/public_qr_personalized.dart')
s = p.read_text(encoding='utf-8')

# QR code-entry/scanner section and public hero are intentionally left untouched.
if "import 'cepqar_theme.dart';" not in s:
    s = s.replace("import 'public_notification_api.dart';", "import 'public_notification_api.dart';\nimport 'cepqar_theme.dart';")

# Theme-aware colors used only after a QR has been resolved.
marker = "class _PublicHome extends StatelessWidget {"
helpers = """Color get _visitorBg => CepqarTheme.isLight ? const Color(0xFFF7F8FC) : _bg;
Color get _visitorPanel => CepqarTheme.isLight ? Colors.white : _panel;
Color get _visitorPanel2 => CepqarTheme.isLight ? const Color(0xFFF0F2F8) : _panel2;
Color get _visitorLine => CepqarTheme.isLight ? const Color(0xFFDDE2EC) : _line;
Color get _visitorText => CepqarTheme.isLight ? const Color(0xFF10182D) : Colors.white;
Color get _visitorMuted => CepqarTheme.isLight ? const Color(0xFF727C91) : _muted;

class _VisitorThemeButton extends StatelessWidget {
  const _VisitorThemeButton();
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
        valueListenable: CepqarTheme.mode,
        builder: (context, _, __) => Material(
          color: CepqarTheme.isLight ? Colors.white : const Color(0xFF151E3B),
          shape: CircleBorder(side: BorderSide(color: _visitorLine)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => CepqarTheme.setLight(!CepqarTheme.isLight),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                CepqarTheme.isLight ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: CepqarTheme.isLight ? const Color(0xFF6F45D8) : _lime,
                size: 21,
              ),
            ),
          ),
        ),
      );

"""
if helpers not in s and marker in s:
    s = s.replace(marker, helpers + marker, 1)

# Add a compact theme control after the hero copy. Hero image/text itself is not changed.
needle = "SizedBox(height: compact ? 18 : 24),\n          GridView.count("
replacement = "SizedBox(height: compact ? 12 : 16),\n          const Align(alignment: Alignment.centerRight, child: _VisitorThemeButton()),\n          SizedBox(height: compact ? 10 : 12),\n          GridView.count("
if needle in s and '_VisitorThemeButton()),' not in s:
    s = s.replace(needle, replacement, 1)

# Post-QR message/call pages get a fully light/dark shell.
for title in ("Mesaj Gönder", "", "Gizli Arama"):
    old = "Widget build(BuildContext context) => _Shell(\n        child: Scaffold("
    if old in s:
        s = s.replace(old, "Widget build(BuildContext context) => _Shell(\n        themed: true,\n        child: Scaffold(", 1)

# Theme the action cards and hidden-call row on the resolved QR screen without touching hero.
s = s.replace("decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),", "decoration: BoxDecoration(color: _visitorPanel, borderRadius: BorderRadius.circular(18), border: Border.all(color: _visitorLine)),", 1)
s = s.replace("child: const Row(children: [\n                Icon(Icons.phone_rounded, color: Colors.white),", "child: Row(children: [\n                Icon(Icons.phone_rounded, color: _visitorText),", 1)
s = s.replace("Expanded(child: Text('Gizli arama', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17))),", "Expanded(child: Text('Gizli arama', style: TextStyle(color: _visitorText, fontWeight: FontWeight.w800, fontSize: 17))),", 1)
s = s.replace("Icon(Icons.chevron_right, color: Colors.white70),", "Icon(Icons.chevron_right, color: _visitorMuted),", 1)

# Everything from message composer onward may safely use visitor theme colors.
start = s.find('class _MessageComposer extends StatefulWidget')
if start >= 0:
    head, tail = s[:start], s[start:]
    tail = tail.replace('_panel2', '_visitorPanel2')
    tail = tail.replace('_panel', '_visitorPanel')
    tail = tail.replace('_line', '_visitorLine')
    tail = tail.replace('_muted', '_visitorMuted')
    tail = tail.replace('Colors.white70', '_visitorMuted')
    tail = tail.replace('Colors.white', '_visitorText')
    # Theme helper shell, while preserving the resolved QR hero shell when themed=false.
    tail = tail.replace("const _Shell({required this.child, this.background});", "const _Shell({required this.child, this.background, this.themed = false});")
    tail = tail.replace("final String? background;", "final String? background;\n  final bool themed;")
    tail = tail.replace("backgroundColor: _bg,", "backgroundColor: themed ? _visitorBg : _bg,")
    tail = tail.replace("const ColoredBox(color: Color(0xC907101F)),", "if (!themed) const ColoredBox(color: Color(0xC907101F)),")
    # Remove const where theme getters are now runtime values.
    tail = re.sub(r'\bconst\s+(?=[A-Z_][A-Za-z0-9_]*(?:<[^>]+>)?\s*\()', '', tail)
    tail = tail.replace('const <Widget>[', '<Widget>[').replace('const [', '[')
    s = head + tail

# Keep immutable public constructors const where external const call sites may exist.
for cls in ('PublicQrPersonalizedScreen',):
    s = re.sub(rf'(?m)^(\s*){cls}(\s*\(\{{)', rf'\1const {cls}\2', s)

p.write_text(s, encoding='utf-8')
print('Post-QR visitor light/dark theme applied; scanner and hero preserved.')
