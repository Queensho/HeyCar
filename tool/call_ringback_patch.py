from pathlib import Path

p = Path('lib/public_call_page.dart')
s = p.read_text(encoding='utf-8')

if "import 'call_ringback.dart';" not in s:
    s = s.replace("import 'anonymous_call_api.dart';", "import 'anonymous_call_api.dart';\nimport 'call_ringback.dart';", 1)

s = s.replace(
    "  final remoteRenderer = RTCVideoRenderer();\n  Timer? poller;",
    "  final remoteRenderer = RTCVideoRenderer();\n  final ringback = CallRingback();\n  Timer? poller;",
    1,
)

s = s.replace(
    "      if (mounted) setState(() => status = 'ringing');\n      poller = Timer.periodic",
    "      if (mounted) setState(() => status = 'ringing');\n      await ringback.start();\n      poller = Timer.periodic",
    1,
)

s = s.replace(
    "      if (mounted && next != status) setState(() => status = next);\n      if (const {'rejected','missed','ended','cancelled'}.contains(next)) poller?.cancel();",
    "      if (next == 'accepted' || const {'rejected','missed','ended','cancelled'}.contains(next)) {\n        await ringback.stop();\n      }\n      if (mounted && next != status) setState(() => status = next);\n      if (const {'rejected','missed','ended','cancelled'}.contains(next)) poller?.cancel();",
    1,
)

s = s.replace(
    "  Future<void> _hangup() async {\n    poller?.cancel();",
    "  Future<void> _hangup() async {\n    poller?.cancel();\n    await ringback.stop();",
    1,
)

s = s.replace(
    "    poller?.cancel();\n    pulseController.dispose();",
    "    poller?.cancel();\n    ringback.dispose();\n    pulseController.dispose();",
    1,
)

p.write_text(s, encoding='utf-8')
print('Anonymous call ringback: starts on ringing, stops on answer/end/cancel.')
