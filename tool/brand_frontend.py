from pathlib import Path
import re

BRAND_FROM = 'HeyCar'
BRAND_TO = 'Cepqar'
string_re = re.compile(r"('(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\")")

def replace_literal(match):
    token = match.group(0); body = token[1:-1]
    if BRAND_FROM not in body: return token
    technical = ('http://' in body or 'https://' in body or '/HeyCar/' in body or 'github.io/HeyCar' in body)
    return token if technical else token[0] + body.replace(BRAND_FROM, BRAND_TO) + token[-1]

for path in Path('lib').rglob('*.dart'):
    text = path.read_text(encoding='utf-8')
    text = string_re.sub(replace_literal, text)
    text = text.replace('assets/Heycar3d.png', 'assets/Cepqar3d.png').replace('assets/Qrkod.png', 'assets/CepqarQr.png')

    if path.as_posix() == 'lib/owner_dashboard_live.dart':
        if "import 'owner_dashboard_stats.dart';" not in text:
            text = text.replace("import 'owner_vehicles_page.dart';", "import 'owner_vehicles_page.dart';\nimport 'owner_dashboard_stats.dart';")
        if "import 'owner_dnd_card.dart';" not in text:
            text = text.replace("import 'owner_dashboard_stats.dart';", "import 'owner_dashboard_stats.dart';\nimport 'owner_dnd_card.dart';")
        # Replace only the _logo declaration. Do not use a multiline wildcard here;
        # it could consume following header helpers such as _parkingButton.
        text = re.sub(
            r"^[ \t]*Widget _logo\(\)[^\n]*$",
            "  Widget _logo() => Image.asset('assets/Logoqr.png', height: 48, fit: BoxFit.contain);",
            text,
            count=1,
            flags=re.M,
        )
        text = text.replace("Image.asset('assets/Logoqr.jpg', height: 48, fit: BoxFit.contain)", "Image.asset('assets/Logoqr.png', height: 48, fit: BoxFit.contain)")
        marker = "        const SizedBox(height: 12),\n        OwnerDashboardStatsRow(onTap: onOpenNotifications),"
        if 'OwnerDndCard()' not in text:
            text = text.replace(marker, "        const SizedBox(height: 12),\n        const OwnerDndCard(),\n        const SizedBox(height: 12),\n        OwnerDashboardStatsRow(onTap: onOpenNotifications),")

    if path.as_posix() == 'lib/owner_settings_page.dart':
        text = re.sub(r"class _Brand extends StatelessWidget \{.*?\n\}\n\nclass _RoundIcon", """class _Brand extends StatelessWidget {
  const _Brand();
  @override Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Image.asset('assets/Logoqr.png', height: 38, fit: BoxFit.contain), const SizedBox(height: 5), const Text('Araç Sahibi', style: TextStyle(color: _muted, fontSize: 12.5))]);
}

class _RoundIcon""", text, flags=re.S)

    if path.as_posix() == 'lib/driver_invite_page.dart':
        if "import 'driver_chat_page.dart';" not in text:
            text = text.replace("import 'vehicle_api.dart';", "import 'vehicle_api.dart';\nimport 'driver_chat_page.dart';")
        if "import 'driver_account_page.dart';" not in text:
            text = text.replace("import 'driver_chat_page.dart';", "import 'driver_chat_page.dart';\nimport 'driver_account_page.dart';")
        text = text.replace(
            "child: Container(\n                  minHeight: 108,",
            "child: Container(\n                  constraints: const BoxConstraints(minHeight: 108),",
        )
        text = text.replace(
            "        width: 158,\n        height: 55,",
            "        width: 142,\n        height: 52,",
        )
        text = text.replace(
            "                      _brand(),\n                      const Spacer(),\n                      Flexible(child: _profile()),",
            "                      _brand(),\n                      const SizedBox(width: 8),\n                      Expanded(\n                        child: Align(\n                          alignment: Alignment.topRight,\n                          child: SizedBox(\n                            width: 168,\n                            child: FittedBox(\n                              fit: BoxFit.scaleDown,\n                              alignment: Alignment.centerRight,\n                              child: _profile(),\n                            ),\n                          ),\n                        ),\n                      ),",
        )
        text = text.replace("          radius: 24,", "          radius: 22,")
        text = text.replace("        const SizedBox(width: 10),", "        const SizedBox(width: 8),", 1)
        text = text.replace("                fontSize: 17,", "                fontSize: 16,", 1)
        text = text.replace("const Text('Sürücü', style: TextStyle(color: _muted, fontSize: 13))", "const Text('Sürücü', style: TextStyle(color: _muted, fontSize: 12))")
        text = text.replace("const SizedBox(width: 7),", "const SizedBox(width: 5),", 1)
        text = text.replace("padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3)", "padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2)", 1)
        text = text.replace("fontSize: 10,", "fontSize: 9.5,", 1)
        text = text.replace("const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 24)", "const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 22)")
        text = text.replace(
            "      _DriverNotificationsPage(\n        items: notifications,\n        loading: loading,\n        onRefresh: () => load(),\n      ),",
            "      _DriverNotificationsPage(\n        userId: widget.userId,\n        items: notifications,\n        loading: loading,\n        onRefresh: () => load(),\n      ),",
        )
        text = text.replace(
            "      _DriverSettingsPage(\n        driverName: driverName,",
            "      _DriverSettingsPage(\n        userId: widget.userId,\n        driverName: driverName,",
        )
        text = text.replace(
            "  const _DriverNotificationsPage({required this.items, required this.loading, required this.onRefresh});\n\n  final List<Map<String, dynamic>> items;",
            "  const _DriverNotificationsPage({required this.userId, required this.items, required this.loading, required this.onRefresh});\n\n  final String userId;\n  final List<Map<String, dynamic>> items;",
        )
        text = text.replace(
            "  const _DriverSettingsPage({\n    required this.driverName,",
            "  const _DriverSettingsPage({\n    required this.userId,\n    required this.driverName,",
        )
        text = text.replace(
            "  final String driverName;\n  final VoidCallback onOpenVehicles;",
            "  final String userId;\n  final String driverName;\n  final VoidCallback onOpenVehicles;",
            1,
        )
        text = text.replace(
            "            Text(_time(n['created_at']), style: const TextStyle(color: _purpleSoft)),",
            "            Text(_time(n['created_at']), style: const TextStyle(color: _purpleSoft)),\n            if (type != 'call_request') ...[\n              const SizedBox(height: 18),\n              SizedBox(\n                width: double.infinity,\n                child: FilledButton.icon(\n                  onPressed: () {\n                    Navigator.pop(context);\n                    Navigator.push(\n                      context,\n                      MaterialPageRoute(\n                        builder: (_) => DriverChatPage(\n                          userId: widget.userId,\n                          notificationId: n['id']?.toString() ?? '',\n                          plate: n['plate']?.toString() ?? '',\n                        ),\n                      ),\n                    );\n                  },\n                  style: FilledButton.styleFrom(backgroundColor: _purple),\n                  icon: const Icon(Icons.chat_bubble_outline_rounded),\n                  label: const Text('Anonim Sohbeti Aç', style: TextStyle(fontWeight: FontWeight.w900)),\n                ),\n              ),\n            ],",
            1,
        )
        text = text.replace(
            "onTap: () => _showInfo(context, 'Hesap bilgilerim', driverName.trim().isEmpty ? 'Sürücü hesabı' : driverName.trim()),",
            "onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DriverAccountPage(userId: userId))),",
        )
        text = text.replace(
            "onTap: () => _showInfo(context, 'Hesap bilgilerim', driverName.trim().isEmpty ? 'Sürücü hesabı' : driverName.trim()),",
            "onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DriverAccountPage(userId: userId))),",
        )
        text = re.sub(
            r"class _DriverBrand extends StatelessWidget \{.*?\n\}\n\nclass _RoundIcon",
            """class _DriverBrand extends StatelessWidget {
  const _DriverBrand();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset('assets/Logoqr.png', height: 38, fit: BoxFit.contain),
          const SizedBox(height: 5),
          const Text('Sürücü', style: TextStyle(color: _muted, fontSize: 12.5)),
        ],
      );
}

class _RoundIcon""",
            text,
            flags=re.S,
        )

    if path.as_posix() == 'lib/public_qr_entry.dart':
        text = re.sub(r"class _TopBar extends StatelessWidget\{.*\Z", """class _TopBar extends StatelessWidget{const _TopBar({required this.onMenu});final VoidCallback onMenu;@override Widget build(BuildContext context){final compact=MediaQuery.sizeOf(context).width<390;return Row(children:[Image.asset('assets/Logoqr.png',height:compact?38:42,fit:BoxFit.contain),const Spacer(),Container(padding:EdgeInsets.symmetric(horizontal:compact?11:12,vertical:compact?7:8),decoration:BoxDecoration(border:Border.all(color:_line),borderRadius:BorderRadius.circular(18)),child:Text('TR ⌄',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:compact?14:15))),const SizedBox(width:8),IconButton(onPressed:onMenu,padding:EdgeInsets.zero,constraints:const BoxConstraints(minWidth:38,minHeight:38),icon:Icon(Icons.menu_rounded,color:Colors.white,size:compact?29:31))]);}}
""", text, flags=re.S)

    if path.as_posix() == 'lib/public_qr_personalized.dart':
        text = re.sub(r"class _TopBar extends StatelessWidget \{.*?\n\}\n\nclass ", """class _TopBar extends StatelessWidget {const _TopBar();@override Widget build(BuildContext context) => Row(children:[Image.asset('assets/Logoqr.png',height:42,fit:BoxFit.contain),const Spacer()]);}

class """, text, flags=re.S)

    if path.as_posix() == 'lib/public_menu_pages.dart':
        text = re.sub(r"const Text\.rich\(TextSpan\(children: \[TextSpan\(text: 'Hey'.*?fontWeight: FontWeight\.w900\)\),", "Image.asset('assets/Logoqr.png', height: 32, fit: BoxFit.contain),", text, flags=re.S)

    path.write_text(text, encoding='utf-8')
print('Cepqar frontend branding applied; technical HeyCar infrastructure preserved.')
