import 'package:flutter/material.dart';

const _bg = Color(0xFF06101B);
const _panel = Color(0xFF0B1A2B);
const _orange = Color(0xFFFCA311);

class PublicQrWebScreen extends StatelessWidget {
  const PublicQrWebScreen({super.key, required this.token});
  final String token;

  @override
  Widget build(BuildContext context) {
    if (token.trim().isEmpty) {
      return const Scaffold(backgroundColor: _bg, body: Center(child: Text('Geçersiz HeyCar QR etiketi', style: TextStyle(color: Colors.white))));
    }
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/Arka2.png', fit: BoxFit.cover, alignment: Alignment.topCenter),
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x33030A12), Color(0x9906101B), Color(0xF506101B)]))),
        SafeArea(child: LayoutBuilder(builder: (context, c) {
          const w = 390.0, h = 720.0;
          final s = ((c.maxWidth / w) < (c.maxHeight / h) ? c.maxWidth / w : c.maxHeight / h).clamp(.72, 1.15);
          return Center(child: Transform.scale(scale: s, child: SizedBox(width: w, height: h, child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _header(), const SizedBox(height: 18), _hero(), const SizedBox(height: 12), _grid(context), const SizedBox(height: 10), _call(context), const Spacer(), const _PrivacyFooter(),
            ]),
          ))));
        })),
      ]),
    );
  }

  Widget _header() => Row(children: [
    const Icon(Icons.directions_car_filled_rounded, color: _orange, size: 31), const SizedBox(width: 8),
    const Text.rich(TextSpan(children: [TextSpan(text: 'Hey', style: TextStyle(color: Colors.white)), TextSpan(text: 'Car', style: TextStyle(color: _orange))]), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
    const Spacer(), Container(width: 38, height: 38, decoration: const BoxDecoration(color: _panel, shape: BoxShape.circle), child: const Icon(Icons.more_horiz_rounded, color: Colors.white)),
  ]);

  Widget _hero() => const SizedBox(height: 185, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Bana\nulaşmak', style: TextStyle(color: Colors.white, fontSize: 35, height: .98, fontWeight: FontWeight.w900)), SizedBox(height: 2),
    Text('çok kolay.', style: TextStyle(color: _orange, fontSize: 35, height: .98, fontWeight: FontWeight.w900)), SizedBox(height: 11),
    Text('Numaram gizli,\nyolun açık.', style: TextStyle(color: Colors.white, fontSize: 18.5, height: 1.28)),
  ]));

  Widget _grid(BuildContext context) => SizedBox(height: 264, child: GridView.count(
    physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.28,
    children: [
      _ActionTile(background: _orange, icon: Icons.phone_rounded, title: 'Aracınızı\nçekebilir misiniz?', onTap: () => _openMessageScreen(context, 'Aracınızı çekebilir misiniz?')),
      _ActionTile(background: const Color(0xFFF7F7F7), icon: Icons.lightbulb_rounded, title: 'Farlarınız açık', onTap: () => _openMessageScreen(context, 'Farlarınız açık')),
      _ActionTile(background: const Color(0xFFF7F7F7), icon: Icons.warning_rounded, title: 'Aracınızda\nhasar var', onTap: () => _openMessageScreen(context, 'Aracınızda hasar var')),
      _ActionTile(background: const Color(0xFFF7F7F7), icon: Icons.chat_bubble_rounded, title: 'Diğer mesaj', onTap: () => _openMessageScreen(context, 'Diğer mesaj')),
    ],
  ));

  Widget _call(BuildContext context) => SizedBox(width: double.infinity, height: 56, child: Material(
    color: _panel, borderRadius: BorderRadius.circular(18), child: InkWell(
      borderRadius: BorderRadius.circular(18), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _MaskedCallScreen())),
      child: const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: Row(children: [
        Icon(Icons.phone_rounded, color: Colors.white, size: 27), SizedBox(width: 16), Expanded(child: Text('Gizli arama', style: TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w700))), Icon(Icons.chevron_right_rounded, color: Colors.white70),
      ])),
    ),
  ));
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.background, required this.icon, required this.title, required this.onTap});
  final Color background; final IconData icon; final String title; final VoidCallback onTap;
  @override Widget build(BuildContext context) => Material(color: background, borderRadius: BorderRadius.circular(18), child: InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(18), child: Padding(padding: const EdgeInsets.fromLTRB(10, 13, 10, 11), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: Colors.black, size: 34), const SizedBox(height: 9), Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 14.2, height: 1.14, fontWeight: FontWeight.w800)),
    ])),
  ));
}

class _PrivacyFooter extends StatelessWidget { const _PrivacyFooter(); @override Widget build(BuildContext context) => const SizedBox(height: 30, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.verified_user_rounded, color: Colors.white, size: 22), SizedBox(width: 9), Text('Kişisel bilgileriniz gizli kalır.', style: TextStyle(color: Color(0xFFBFC7D1), fontSize: 13.2))])); }

class _MaskedCallScreen extends StatefulWidget { const _MaskedCallScreen(); @override State<_MaskedCallScreen> createState() => _MaskedCallScreenState(); }
class _MaskedCallScreenState extends State<_MaskedCallScreen> {
  bool muted = false, speaker = false; int seconds = 12;
  String get timer => '00:${seconds.toString().padLeft(2, '0')}';
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    body: Stack(fit: StackFit.expand, children: [
      Image.asset('assets/Arka2.png', fit: BoxFit.cover),
      const ColoredBox(color: Color(0xD806101B)),
      SafeArea(child: LayoutBuilder(builder: (context, c) {
        final compact = c.maxHeight < 720;
        return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: Padding(
          padding: EdgeInsets.fromLTRB(24, compact ? 18 : 28, 24, 22),
          child: Column(children: [
            const Text('Gizli Arama', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            SizedBox(height: compact ? 30 : 46), Text(timer, style: const TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.w400)),
            SizedBox(height: compact ? 35 : 52),
            SizedBox(width: compact ? 230 : 270, height: compact ? 230 : 270, child: Stack(alignment: Alignment.center, children: [
              Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _orange.withValues(alpha: .18), width: 2))),
              Container(width: compact ? 195 : 225, height: compact ? 195 : 225, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0x221D2734), border: Border.all(color: _orange.withValues(alpha: .25), width: 2))),
              Container(width: compact ? 154 : 180, height: compact ? 154 : 180, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _orange, width: 7), boxShadow: [BoxShadow(color: _orange.withValues(alpha: .28), blurRadius: 24)]), child: const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 62)),
            ])),
            SizedBox(height: compact ? 34 : 48),
            const Text('Numaranız gizli kalır.\n0850 üzerinden güvenli arama\ngerçekleştiriliyor.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 18, height: 1.48, fontWeight: FontWeight.w600)),
            const Spacer(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _CallControl(icon: muted ? Icons.mic_off_rounded : Icons.mic_none_rounded, label: 'Sessiz', active: muted, onTap: () => setState(() => muted = !muted)),
              _CallControl(icon: Icons.call_end_rounded, label: 'Sonlandır', danger: true, onTap: () => Navigator.pop(context)),
              _CallControl(icon: speaker ? Icons.volume_up_rounded : Icons.volume_down_rounded, label: 'Hoparlör', active: speaker, onTap: () => setState(() => speaker = !speaker)),
            ]),
          ]),
        )));
      })),
    ]),
  );
}

class _CallControl extends StatelessWidget {
  const _CallControl({required this.icon, required this.label, required this.onTap, this.danger = false, this.active = false});
  final IconData icon; final String label; final VoidCallback onTap; final bool danger, active;
  @override Widget build(BuildContext context) => Column(children: [
    InkWell(onTap: onTap, customBorder: const CircleBorder(), child: Container(width: 92, height: 92, decoration: BoxDecoration(shape: BoxShape.circle, color: danger ? const Color(0xFFFF2424) : (active ? const Color(0xFF24374D) : const Color(0xFF172333))), child: Icon(icon, color: Colors.white, size: danger ? 45 : 37))),
    const SizedBox(height: 12), Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
  ]);
}

void _openMessageScreen(BuildContext context, String type) => Navigator.push(context, MaterialPageRoute(builder: (_) => _MessageScreen(initialType: type)));

class _MessageScreen extends StatefulWidget { const _MessageScreen({required this.initialType}); final String initialType; @override State<_MessageScreen> createState() => _MessageScreenState(); }
class _MessageScreenState extends State<_MessageScreen> {
  late final TextEditingController controller; late String selected;
  @override void initState(){ super.initState(); selected = widget.initialType; controller = TextEditingController(text: _defaultText(selected)); }
  String _defaultText(String t) => t == 'Farlarınız açık' ? 'Farlarınız açık görünüyor, bilginize.' : t == 'Aracınızda hasar var' ? 'Aracınızda hasar fark ettim, bilginize.' : t == 'Diğer mesaj' ? '' : 'Çıkışımı kapatıyor, müsaitseniz aracı çekebilir misiniz?';
  @override void dispose(){ controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: _bg, body: Stack(fit: StackFit.expand, children: [
    Image.asset('assets/Arka2.png', fit: BoxFit.cover), const ColoredBox(color: Color(0xBB06101B)),
    SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(14,8,14,2), child: Row(children: [IconButton(onPressed: ()=>Navigator.pop(context), icon: const Icon(Icons.chevron_left_rounded,color:Colors.white,size:36)), const Expanded(child: Text('Mesaj Gönder',textAlign:TextAlign.center,style:TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w800))), const SizedBox(width:50)])),
      const SizedBox(height:10), Container(width:76,height:76,decoration:BoxDecoration(color:const Color(0xAA10243B),shape:BoxShape.circle,border:Border.all(color:Colors.white12)),child:const Icon(Icons.directions_car_filled_rounded,color:Colors.white,size:40)),
      const SizedBox(height:10), const Text('34 ABC 123',style:TextStyle(color:Colors.white,fontSize:27,fontWeight:FontWeight.w900)), const SizedBox(height:4), const Text('Araç sahibine anonim mesaj\ngönderilecektir.',textAlign:TextAlign.center,style:TextStyle(color:Colors.white70,fontSize:15.5,height:1.3)), const SizedBox(height:18),
      Expanded(child: Container(width:double.infinity,padding:const EdgeInsets.fromLTRB(18,20,18,16),decoration:const BoxDecoration(color:Colors.white,borderRadius:BorderRadius.vertical(top:Radius.circular(30))),child:SingleChildScrollView(child:Column(children:[
        Container(padding:const EdgeInsets.symmetric(horizontal:14),decoration:BoxDecoration(color:const Color(0xFFF5F6F8),borderRadius:BorderRadius.circular(18)),child:DropdownButtonHideUnderline(child:DropdownButton<String>(isExpanded:true,value:selected,items:['Aracınızı çekebilir misiniz?','Farlarınız açık','Aracınızda hasar var','Diğer mesaj'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v){if(v!=null)setState((){selected=v;controller.text=_defaultText(v);});}))),
        const SizedBox(height:12), TextField(controller:controller,maxLength:120,maxLines:4,decoration:InputDecoration(hintText:'Araç sahibine mesaj yaz...',filled:true,fillColor:const Color(0xFFF5F6F8),border:OutlineInputBorder(borderRadius:BorderRadius.circular(18),borderSide:BorderSide.none))),
        Row(children:[Expanded(child:_AttachBox(icon:Icons.camera_alt_rounded,title:'Fotoğraf ekle',subtitle:'(isteğe bağlı)',color:_orange)),const SizedBox(width:12),const Expanded(child:_AttachBox(icon:Icons.location_on_rounded,title:'Konum ekle',subtitle:'(isteğe bağlı)',color:Color(0xFF07111E)))]),
        const SizedBox(height:14), SizedBox(width:double.infinity,height:56,child:FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:_orange,foregroundColor:Colors.black,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18))),onPressed:(){final t=controller.text.trim();if(t.isNotEmpty)Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>_MessageSentScreen(message:t)));},icon:const Icon(Icons.send_rounded),label:const Text('Mesaj Gönder',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800))))
      ]))))
    ]))))
  ]));
}

class _AttachBox extends StatelessWidget { const _AttachBox({required this.icon,required this.title,required this.subtitle,required this.color}); final IconData icon; final String title,subtitle; final Color color; @override Widget build(BuildContext context)=>Container(height:108,decoration:BoxDecoration(color:const Color(0xFFF5F6F8),borderRadius:BorderRadius.circular(18)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,color:color,size:32),const SizedBox(height:7),Text(title,style:const TextStyle(fontWeight:FontWeight.w700)),Text(subtitle,style:const TextStyle(color:Color(0xFF667085),fontSize:12.5))])); }

class _MessageSentScreen extends StatelessWidget { const _MessageSentScreen({required this.message}); final String message; @override Widget build(BuildContext context)=>Scaffold(backgroundColor:_bg,body:Stack(fit:StackFit.expand,children:[Image.asset('assets/Arka2.png',fit:BoxFit.cover),const ColoredBox(color:Color(0xCC06101B)),SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:430),child:Column(children:[
  Align(alignment:Alignment.topRight,child:IconButton(onPressed:()=>Navigator.of(context).popUntil((r)=>r.isFirst),icon:const Icon(Icons.close_rounded,color:Colors.white,size:32))),
  Container(width:88,height:88,decoration:const BoxDecoration(color:Color(0xAA1B2430),shape:BoxShape.circle),child:const Icon(Icons.send_rounded,color:_orange,size:46)), const SizedBox(height:14), const Text('Mesajınız gönderildi!',style:TextStyle(color:Colors.white,fontSize:28,fontWeight:FontWeight.w900)), const SizedBox(height:9), const Padding(padding:EdgeInsets.symmetric(horizontal:24),child:Text('Araç sahibine bildiriminiz ulaştı.\nCevap verdiğinde bu sayfa otomatik güncellenecektir.',textAlign:TextAlign.center,style:TextStyle(color:Colors.white70,fontSize:16,height:1.4))), const SizedBox(height:22),
  Expanded(child:Container(width:double.infinity,padding:const EdgeInsets.fromLTRB(24,22,24,18),decoration:const BoxDecoration(color:Colors.white,borderRadius:BorderRadius.vertical(top:Radius.circular(30))),child:Column(children:[const _StatusStep(color:Color(0xFF159A8C),title:'Mesaj gönderildi',sub:'Şimdi',line:true),const _StatusStep(color:_orange,title:'Araç sahibine iletildi',sub:'Bildirim gönderildi',line:true),const _StatusStep(color:Color(0xFFDDE2E8),title:'Cevap bekleniyor',sub:'Ortalama yanıt süresi: 2 dk'),const Spacer(),Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFFF5F6F8),borderRadius:BorderRadius.circular(18)),child:const Row(children:[Icon(Icons.notifications_active_rounded,color:_orange,size:30),SizedBox(width:12),Expanded(child:Text('Acil bir durum varsa lütfen gizli arama seçeneğini kullanın.',style:TextStyle(fontWeight:FontWeight.w700)))])),const SizedBox(height:12),SizedBox(width:double.infinity,height:54,child:OutlinedButton.icon(onPressed:()=>_openMessageScreen(context,'Diğer mesaj'),icon:const Icon(Icons.chat_bubble_outline_rounded),label:const Text('Yeni mesaj gönder'))),TextButton(onPressed:()=>Navigator.of(context).popUntil((r)=>r.isFirst),child:const Text('Ana sayfaya dön'))]))
]))))))])); }

class _StatusStep extends StatelessWidget { const _StatusStep({required this.color,required this.title,required this.sub,this.line=false}); final Color color; final String title,sub; final bool line; @override Widget build(BuildContext context)=>Row(crossAxisAlignment:CrossAxisAlignment.start,children:[SizedBox(width:42,child:Column(children:[Container(width:32,height:32,decoration:BoxDecoration(color:color,shape:BoxShape.circle),child:const Icon(Icons.circle,color:Colors.white,size:12)),if(line)Container(width:3,height:42,color:const Color(0xFFB6C0CC))])),const SizedBox(width:8),Expanded(child:Padding(padding:const EdgeInsets.only(bottom:16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800)),Text(sub,style:const TextStyle(color:Color(0xFF7B8492))) ]))) ]); }
