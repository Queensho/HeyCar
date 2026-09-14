from pathlib import Path

p = Path('lib/owner_dashboard_live.dart')
text = p.read_text(encoding='utf-8')

if "package:flutter/services.dart" not in text:
    text = text.replace(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';",
        1,
    )

state_marker = "class _OwnerDashboardLiveState extends State<OwnerDashboardLive> {\n  int current = 0;\n"
state_replacement = """class _OwnerDashboardLiveState extends State<OwnerDashboardLive> {
  int current = 0;
  DateTime? _lastBackPressed;

  Future<void> _handleSystemBack() async {
    if (current != 0) {
      setState(() => current = 0);
      return;
    }

    final now = DateTime.now();
    final pressedRecently = _lastBackPressed != null &&
        now.difference(_lastBackPressed!) <= const Duration(seconds: 2);

    if (!pressedRecently) {
      _lastBackPressed = now;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Çıkmak için tekrar dokunun'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    await SystemNavigator.pop();
  }
"""
if state_marker in text:
    text = text.replace(state_marker, state_replacement, 1)

build_marker = "  Widget build(BuildContext context) {\n    return ValueListenableBuilder<int>("
if build_marker in text:
    text = text.replace(
        build_marker,
        "  Widget build(BuildContext context) {\n    return PopScope(\n      canPop: false,\n      onPopInvokedWithResult: (didPop, _) {\n        if (!didPop) _handleSystemBack();\n      },\n      child: ValueListenableBuilder<int>(",
        1,
    )

end_marker = "      },\n    );\n  }\n}\n\nclass _OwnerHome"
if end_marker in text:
    text = text.replace(
        end_marker,
        "      },\n    ));\n  }\n}\n\nclass _OwnerHome",
        1,
    )

p.write_text(text, encoding='utf-8')
print('Android back navigation patched: tabs -> home, home -> double-back exit.')
