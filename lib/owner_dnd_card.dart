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
  @override
  State<OwnerDndCard> createState() => _OwnerDndCardState();
}

class _OwnerDndCardState extends State<OwnerDndCard> {
  bool active = false, loading = true, premium = false;
  DateTime? until;
  Timer? timer;
  String get ownerId => OnboardingDraft.userId.trim();

  @override
  void initState() {
    super.initState();
    _load();
    timer = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (active && until != null && !until!.isAfter(DateTime.now())) {
      setState(() { active = false; until = null; });
    }
  }

  Future<void> _load() async {
    if (ownerId.isEmpty) { if (mounted) setState(() => loading = false); return; }
    try {
      final rs = await Future.wait([
        http.get(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/dnd'), headers: {'x-owner-id': ownerId}),
        http.get(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/vehicles'), headers: {'x-owner-id': ownerId}),
      ]);
      final j = jsonDecode(rs[0].body) as Map<String, dynamic>;
      final u = jsonDecode(rs[1].body) as Map<String, dynamic>;
      if (mounted) setState(() {
        active = j['active'] == true;
        until = j['activeUntil'] == null ? null : DateTime.tryParse(j['activeUntil'].toString())?.toLocal();
        premium = u['premium'] == true;
        loading = false;
      });
    } catch (_) { if (mounted) setState(() => loading = false); }
  }

  void _locked() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: _dndPanel,
      title: const Row(children: [Icon(Icons.lock_rounded, color: _dndPurple), SizedBox(width: 8), Text('Premium özellik', style: TextStyle(color: Colors.white))]),
      content: const Text('Rahatsız Etmeyin özelliği Premium üyeler için kullanılabilir.', style: TextStyle(color: _dndMuted)),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam'))],
    ));
  }

  Future<void> _setHours(int hours) async {
    if (ownerId.isEmpty || !premium) return;
    setState(() => loading = true);
    try {
      final r = await http.put(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/dnd'), headers: {'Content-Type':'application/json','x-owner-id':ownerId}, body: jsonEncode({'hours':hours}));
      final j = jsonDecode(r.body) as Map<String,dynamic>;
      if (mounted) setState(() {
        active = j['active'] == true;
        until = j['activeUntil'] == null ? null : DateTime.tryParse(j['activeUntil'].toString())?.toLocal();
        loading = false;
      });
    } catch (_) { if (mounted) setState(() => loading = false); }
  }

  Future<void> _chooseDuration() async {
    if (!premium) { _locked(); return; }
    final hours = await showModalBottomSheet<int>(context: context, backgroundColor: _dndPanel, builder: (c) => SafeArea(child: Wrap(children: [
      const ListTile(title: Text('Ne kadar sessiz kalalım?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
      for (final h in [1,3,5,8,12]) ListTile(title: Text('$h saat', style: const TextStyle(color: Colors.white)), onTap: () => Navigator.pop(c,h)),
    ])));
    if (hours != null) await _setHours(hours);
  }

  String get subtitle {
    if (!active || until == null) return 'Mesaj ve aramalara geçici olarak ara ver';
    final t = '${until!.hour.toString().padLeft(2,'0')}:${until!.minute.toString().padLeft(2,'0')}';
    return '$t saatinde otomatik kapanacak';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading || premium ? null : _locked,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(15,13,10,13),
        decoration: BoxDecoration(color: _dndPanel, borderRadius: BorderRadius.circular(20), border: Border.all(color: active ? _dndPurple : _dndLine)),
        child: Row(children: [
          Container(width:44,height:44,decoration:BoxDecoration(color:_dndPurple.withValues(alpha:.13),borderRadius:BorderRadius.circular(14)),child:Icon(active?Icons.nightlight_round:Icons.do_not_disturb_on_outlined,color:_dndPurple)),
          const SizedBox(width:12),
          Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              const Flexible(child:Text('Rahatsız Etmeyin',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900,fontSize:15))),
              if (!loading && !premium) ...[const SizedBox(width:7),const Icon(Icons.lock_rounded,color:_dndPurple,size:14),const SizedBox(width:3),const Text('Premium',style:TextStyle(color:_dndPurple,fontSize:10,fontWeight:FontWeight.w900))],
            ]),
            const SizedBox(height:4),
            Text(subtitle,style:const TextStyle(color:_dndMuted,fontSize:11.5)),
          ])),
          if (loading)
            const Padding(padding:EdgeInsets.all(12),child:SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:_dndPurple)))
          else
            Switch(value: premium && active, activeThumbColor: Colors.white, activeTrackColor: _dndPurple, onChanged: premium ? (v) => v ? _chooseDuration() : _setHours(0) : (_) => _locked()),
        ]),
      ),
    );
  }
}
