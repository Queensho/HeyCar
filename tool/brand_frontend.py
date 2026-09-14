from pathlib import Path
import re

BRAND_FROM = 'HeyCar'
BRAND_TO = 'Cepqar'

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

    # Swap only the asset file names. All existing width/height/fit/position
    # values remain untouched, so the visual sizes stay exactly the same.
    text = text.replace('assets/Heycar3d.png', 'assets/Cepqar3d.png')
    text = text.replace('assets/Qrkod.png', 'assets/CepqarQr.png')

    if path.as_posix() == 'lib/owner_dashboard_live.dart':
        text = text.replace(
            "import 'owner_vehicles_page.dart';",
            "import 'owner_vehicles_page.dart';\nimport 'owner_dashboard_stats.dart';",
        )
        text = re.sub(
            r"Widget _logo\(\) => const Text\.rich\(.*?\n\s*\);",
            "Widget _logo() => Image.asset('assets/Logoqr.png', height: 48, fit: BoxFit.contain);",
            text,
            flags=re.S,
        )
        text = text.replace("Image.asset('assets/Logoqr.jpg', height: 48, fit: BoxFit.contain)",
                            "Image.asset('assets/Logoqr.png', height: 48, fit: BoxFit.contain)")
        old_stats = """Row(children: [
          Expanded(child: _Stat(icon: Icons.notifications_active_rounded, value: '$unreadCount', label: 'Yeni\\nBildirim', color: const Color(0xFFFF4D63), onTap: onOpenNotifications)),
          const SizedBox(width: 8),
          Expanded(child: _Stat(icon: Icons.chat_bubble_outline_rounded, value: '12', label: 'Toplam\\nMesaj', color: _purple, onTap: onOpenNotifications)),
          const SizedBox(width: 8),
          Expanded(child: _Stat(icon: Icons.location_on_outlined, value: '5', label: 'Konum\\nPaylaşımı', color: const Color(0xFF42A5FF), onTap: onOpenNotifications)),
          const SizedBox(width: 8),
          Expanded(child: _Stat(icon: Icons.phone_in_talk_outlined, value: '2', label: 'Arama\\nTalebi', color: _purple, onTap: onOpenNotifications)),
        ]),"""
        text = text.replace(old_stats, "OwnerDashboardStatsRow(onTap: onOpenNotifications),")

    if path.as_posix() == 'lib/owner_settings_page.dart':
        text = re.sub(
            r"class _Brand extends StatelessWidget \{.*?\n\}\n\nclass _RoundIcon",
            """class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset('assets/Logoqr.png', height: 38, fit: BoxFit.contain),
          const SizedBox(height: 5),
          const Text('Araç Sahibi', style: TextStyle(color: _muted, fontSize: 12.5)),
        ],
      );
}

class _RoundIcon""",
            text,
            flags=re.S,
        )
        text = re.sub(
            r"\s*Positioned\(\n\s*right: -36,.*?\n\s*\),\n\s*Positioned\(\n\s*left: 20,",
            "\n                  Positioned(\n                    left: 20,",
            text,
            flags=re.S,
        )

    if path.as_posix() == 'lib/public_qr_entry.dart':
        text = re.sub(
            r"class _TopBar extends StatelessWidget\{.*\Z",
            """class _TopBar extends StatelessWidget{
  const _TopBar({required this.onMenu});
  final VoidCallback onMenu;
  @override
  Widget build(BuildContext context){
    final compact=MediaQuery.sizeOf(context).width<390;
    return Row(children:[
      Image.asset('assets/Logoqr.png',height:compact?38:42,fit:BoxFit.contain),
      const Spacer(),
      Container(padding:EdgeInsets.symmetric(horizontal:compact?11:12,vertical:compact?7:8),decoration:BoxDecoration(border:Border.all(color:_line),borderRadius:BorderRadius.circular(18)),child:Text('TR ⌄',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:compact?14:15))),
      const SizedBox(width:8),
      IconButton(onPressed:onMenu,padding:EdgeInsets.zero,constraints:const BoxConstraints(minWidth:38,minHeight:38),icon:Icon(Icons.menu_rounded,color:Colors.white,size:compact?29:31))
    ]);
  }
}
""",
            text,
            flags=re.S,
        )
        text = re.sub(
            r"Row\(children:\[const Text\.rich\(TextSpan\(children:\[TextSpan\(text:'Hey'.*?const Spacer\(\),IconButton",
            "Row(children:[Image.asset('assets/Logoqr.png',height:40,fit:BoxFit.contain),const Spacer(),IconButton",
            text,
            flags=re.S,
        )

    if path.as_posix() == 'lib/public_qr_personalized.dart':
        text = re.sub(
            r"class _TopBar extends StatelessWidget \{.*?\n\}\n\nclass ",
            """class _TopBar extends StatelessWidget {
  const _TopBar();
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Image.asset('assets/Logoqr.png', height: 42, fit: BoxFit.contain),
          const Spacer(),
        ],
      );
}

class """,
            text,
            flags=re.S,
        )

    if path.as_posix() == 'lib/public_menu_pages.dart':
        text = re.sub(
            r"const Text\.rich\(TextSpan\(children: \[TextSpan\(text: 'Hey'.*?fontWeight: FontWeight\.w900\)\),",
            "Image.asset('assets/Logoqr.png', height: 32, fit: BoxFit.contain),",
            text,
            flags=re.S,
        )

    path.write_text(text, encoding='utf-8')

print('Cepqar frontend branding applied; technical HeyCar infrastructure preserved.')
