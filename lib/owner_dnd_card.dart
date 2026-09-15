import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'onboarding_backend.dart';

const _dndPanel = Color(0xFF101A30);
const _dndLine = Color(0xFF27355D);
const _dndPurple = Color(0xFF8B5CFF);
const _dndMuted = Color(0xFFA7B0C7);

class OwnerDndCard extends StatefulWidget {
  const OwnerDndCard({super.key});
  @override State<OwnerDndCard> createState() => _OwnerDndCardState();
}

class _OwnerDndCardState extends State<OwnerDndCard> {
  bool active = false, loading = true;
  DateTime? until;
  Timer? timer;
  String get ownerId => OnboardingDraft.userId.trim();

  @override void initState() { super.initState(); _load(); timer = Timer.periodic(const Duration(seconds: 30), (_) => _tick()); }
  @override void dispose() { timer?.cancel(); super.dispose(); }

  void _tick() {
    if (active && until != null && !until!.isAfter(DateTime.now())) setState(() { active = false; until = null; });
  }

  Future<void> _load() async {
    if (ownerId.isEmpty) { if (mounted) setState(() => loading = false); return; }
    try {
      final r = await http.get(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/dnd'), headers: {'x-owner-id': ownerId}).timeout(const Duration(seconds: 8));
      final j = jsonDecode(r.body) as Map<String,dynamic>;
      if (mounted) setState(() { active = j['active'] == true; until = j['activeUntil'] == null ? null : DateTime.tryParse(j['activeUntil'].toString())?.toLocal(); loading = false; });
    } catch (_) { if (mounted) setState(() => loading = false); }
  }

  Future<void> _setHours(int hours) async {
    if (ownerId.isEmpty) return;
    setState(() => loading = true);
    try {
      final r = await http.put(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/dnd'), headers: {'Content-Type':'application/json','x-owner-id':ownerId}, body: jsonEncode({'hours':hours})).timeout(const Duration(seconds: 8));
      final j = jsonDecode(r.body) as Map<String,dynamic>;
      if (!mounted) return;
      setState(() { active = j['active'] == true; until = j['activeUntil'] == null ? null : DateTime.tryParse(j['activeUntil'].toString())?.toLocal(); loading = false; });
    } catch (_) { if (mounted) { setState(() => loading = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rahatsız Etmeyin modu güncellenemedi.'))); } }
  }

  Future<void> _chooseDuration() async {
    final hours = await showModalBottomSheet<int>(context: context, backgroundColor: _dndPanel, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))), builder: (context) => SafeArea(top:false, child: Padding(padding: const EdgeInsets.fromLTRB(20,18,20,24), child: Column(mainAxisSize:MainAxisSize.min, children:[
      Container(width:44,height:4,decoration:BoxDecoration(color:_dndLine,borderRadius:BorderRadius.circular(8))),
      const SizedBox(height:18),
      const Row(children:[Icon(Icons.do_not_disturb_on_rounded,color:_dndPurple),SizedBox(width:10),Text('Ne kadar sessiz kalalım?',style:TextStyle(color:Colors.white,fontSize:20,fontWeight:FontWeight.w900))]),
      const SizedBox(height:8), const Align(alignment:Alignment.centerLeft,child:Text('Süre dolunca Rahatsız Etmeyin otomatik kapanır.',style:TextStyle(color:_dndMuted))),
      const SizedBox(height:16),
      Wrap(spacing:9,runSpacing:9,children:[1,3,5,8,12].map((h)=>ActionChip(onPressed:()=>Navigator.pop(context,h),backgroundColor:const Color(0xFF18243E),side:const BorderSide(color:_dndLine),label:Text('$h saat',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800)))).toList()),
    ]))));
    if (hours != null) await _setHours(hours);
  }

  String get subtitle {
    if (!active || until == null) return 'Mesaj ve aramalara geçici olarak ara ver';
    final t = '${until!.hour.toString().padLeft(2,'0')}:${until!.minute.toString().padLeft(2,'0')}';
    return '$t saatinde otomatik kapanacak';
  }

  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(15,13,10,13),
    decoration: BoxDecoration(color:_dndPanel,borderRadius:BorderRadius.circular(20),border:Border.all(color:active?_dndPurple:_dndLine)),
    child: Row(children:[
      Container(width:44,height:44,decoration:BoxDecoration(color:_dndPurple.withValues(alpha:.13),borderRadius:BorderRadius.circular(14)),child:Icon(active?Icons.nightlight_round:Icons.do_not_disturb_on_outlined,color:_dndPurple)),
      const SizedBox(width:12),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Flexible(child:Text('Rahatsız Etmeyin',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:15))),const SizedBox(width:7),Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),decoration:BoxDecoration(color:_dndPurple.withValues(alpha:.16),borderRadius:BorderRadius.circular(8)),child:const Text('PREMIUM',style:TextStyle(color:_dndPurple,fontSize:9,fontWeight:FontWeight.w900)))]),const SizedBox(height:4),Text(subtitle,style:const TextStyle(color:_dndMuted,fontSize:11.5))])),
      if (loading) const Padding(padding:EdgeInsets.all(12),child:SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:_dndPurple))) else Switch(value:active,activeThumbColor:Colors.white,activeTrackColor:_dndPurple,onChanged:(v)=>v?_chooseDuration():_setHours(0)),
    ]),
  );
}
