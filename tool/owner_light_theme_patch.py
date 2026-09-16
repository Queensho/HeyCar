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
    'lib/owner_settings_detail.dart': {
        "const _bg = Color(0xFF07111F);": "Color get _bg => CepqarTheme.bg;",
        "const _panel = Color(0xFF111A31);": "Color get _panel => CepqarTheme.panel;",
        "const _line = Color(0xFF29345A);": "Color get _line => CepqarTheme.line;",
        "const _muted = Color(0xFFA7B0C7);": "Color get _muted => CepqarTheme.muted;",
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
    'lib/maintenance_page.dart': {
        "const _bg=Color(0xFF07111F),_panel=Color(0xFF101A30),_line=Color(0xFF27355D),_purple=Color(0xFF8B5CFF),_muted=Color(0xFFA7B0C7),_lime=Color(0xFF79FF45);": "Color get _bg=>CepqarTheme.bg; Color get _panel=>CepqarTheme.panel; Color get _line=>CepqarTheme.line; const _purple=Color(0xFF8B5CFF); Color get _muted=>CepqarTheme.muted; const _lime=Color(0xFF79FF45);",
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

    text = text.replace('Colors.white70', 'CepqarTheme.muted')
    text = text.replace('Colors.white60', 'CepqarTheme.muted')
    text = text.replace('Colors.white54', 'CepqarTheme.muted')
    text = text.replace('Colors.white38', 'CepqarTheme.muted')
    text = text.replace('Colors.white', 'CepqarTheme.text')
    text = re.sub(r'\bconst\s+(?=[A-Z][A-Za-z0-9_]*(?:<[^>]+>)?\s*\()', '', text)

    constructors = {
        'lib/owner_notifications_page.dart': ('OwnerNotificationsPage',),
        'lib/owner_settings_page.dart': ('OwnerSettingsPage',),
        'lib/owner_settings_detail.dart': ('OwnerAccountSettingsPage','OwnerNotificationSettingsPage','OwnerPrivacySettingsPage','OwnerActiveSessionsPage','OwnerBlockedVisitorsPage'),
        'lib/owner_vehicles_page.dart': ('OwnerVehiclesPage',),
        'lib/owner_chat_page.dart': ('OwnerChatPage',),
        'lib/maintenance_page.dart': ('MaintenancePage','MaintenanceAddPage'),
    }[filename]
    for cls in constructors:
        text = re.sub(rf'(?<!const )\b{cls}(\s*\(\{{)', rf'const {cls}\1', text, count=1)

    text = re.sub(r'FilledButton\.styleFrom\(backgroundColor:\s*_purple,\s*foregroundColor:\s*CepqarTheme\.text','FilledButton.styleFrom(backgroundColor:_purple,foregroundColor:Colors.white',text)
    text = re.sub(r'FilledButton\.styleFrom\(backgroundColor:\s*_purple(?!\s*,\s*foregroundColor)','FilledButton.styleFrom(backgroundColor:_purple,foregroundColor:Colors.white',text)

    # QR promo is intentionally purple in both themes: its QR and copy stay white.
    if filename == 'lib/owner_settings_page.dart' and 'class _QrPromo' in text:
        before, promo = text.split('class _QrPromo', 1)
        promo = promo.replace('CepqarTheme.text', 'Colors.white')
        text = before + 'class _QrPromo' + promo

    p.write_text(text, encoding='utf-8')

# Driver assignment card: keep the requested purple premium card with white copy.
p = Path('lib/active_driver_card.dart')
text = p.read_text(encoding='utf-8')
text = text.replace("color:const Color(0xFF101A30),borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xFF27355D))", "color:const Color(0xFF6F3DE8),borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xFF8F6BFF))")
text = text.replace("style:const TextStyle(color:Color(0xFFA7B0C7),fontSize:12)", "style:const TextStyle(color:Colors.white70,fontSize:12)")
text = text.replace("const Text('Şu an kim kullanıyor?  PREMIUM',style:TextStyle(fontWeight:FontWeight.w900))", "const Text('Şu an kim kullanıyor?  PREMIUM',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900))")
text = text.replace("OutlinedButton.icon(onPressed:loading?null:invite,icon:const Icon(Icons.person_add),label:const Text('Sürücü Davet Et'))", "OutlinedButton.icon(onPressed:loading?null:invite,style:OutlinedButton.styleFrom(foregroundColor:Colors.white,side:const BorderSide(color:Colors.white70)),icon:const Icon(Icons.person_add),label:const Text('Sürücü Davet Et'))")
text = text.replace("FilledButton(onPressed:loading?null:(active?stop:choose),child:Text(active?'Sürüşü Bitir':'Sürücü Seç'))", "FilledButton(style:FilledButton.styleFrom(backgroundColor:Colors.white24,foregroundColor:Colors.white),onPressed:loading?null:(active?stop:choose),child:Text(active?'Sürüşü Bitir':'Sürücü Seç'))")
p.write_text(text, encoding='utf-8')

# Parking sheet/card: compact height again and follow light/dark palette.
p = Path('lib/parking_location_card.dart')
text = p.read_text(encoding='utf-8')
if "import 'cepqar_theme.dart';" not in text:
    text = text.replace("import 'onboarding_backend.dart';", "import 'onboarding_backend.dart';\nimport 'cepqar_theme.dart';")
text = text.replace("const _panel=Color(0xFF0E172A),_line=Color(0xFF263657),_purple=Color(0xFF813CFF),_muted=Color(0xFFA7B0C7),_bg=Color(0xFF07111F),_red=Color(0xFFFF6B74);", "Color get _panel=>CepqarTheme.panel; Color get _line=>CepqarTheme.line; const _purple=Color(0xFF813CFF); Color get _muted=>CepqarTheme.muted; Color get _bg=>CepqarTheme.bg; const _red=Color(0xFFFF6B74);")
text = text.replace("child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:", "child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:", 1)
text = text.replace('Colors.white', 'CepqarTheme.text')
text = re.sub(r'\bconst\s+(?=[A-Z_][A-Za-z0-9_]*(?:<[^>]+>)?\s*\()', '', text)
text = re.sub(r'(?<!const )\bParkingLocationCard(\s*\(\{)', r'const ParkingLocationCard\1', text, count=1)
text = text.replace("backgroundColor:_purple,shape:", "backgroundColor:_purple,foregroundColor:Colors.white,shape:")
text = text.replace("backgroundColor:_red),", "backgroundColor:_red,foregroundColor:Colors.white),")
p.write_text(text, encoding='utf-8')

p = Path('lib/owner_dashboard_live.dart')
text = p.read_text(encoding='utf-8')
text = text.replace("color:light?CepqarTheme.lightText:Colors.white,fontSize:32", "color:Colors.white,fontSize:32")
text = text.replace("color:light?CepqarTheme.lightMuted:Colors.white70,fontSize:17", "color:Colors.white70,fontSize:17")
p.write_text(text, encoding='utf-8')

print('Owner light theme, premium driver card, QR promo and compact parking card applied.')
