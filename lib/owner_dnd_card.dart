import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'onboarding_backend.dart';
import 'owner_auth.dart';
import 'cepqar_theme.dart';

const _dndPurple = Color(0xFF8B5CFF);

class OwnerDndCard extends StatefulWidget {
  const OwnerDndCard({super.key});
  @override
  State<OwnerDndCard> createState() => _OwnerDndCardState();
}

class _OwnerDndCardState extends State<OwnerDndCard> {
  bool active = false, loading = true, premium = false;
  String? error;
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
    if (ownerId.isEmpty) {
      if (mounted) setState(() {
        loading = false;
        error = 'Araç sahibi oturumu bulunamadı.';
      });
      return;
    }
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final rs = await Future.wait([
        OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/dnd'), json:false)
            .timeout(const Duration(seconds: 12)),
        OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/vehicles'), json:false)
            .timeout(const Duration(seconds: 12)),
      ]);
      if (rs.any((r) => r.statusCode < 200 || r.statusCode >= 300)) {
        final unauthorized = rs.any((r) => r.statusCode == 401);
        throw StateError(unauthorized ? 'Oturum geçersiz. Yeniden giriş yapın.' : 'Rahatsız Etmeyin bilgileri alınamadı.');
      }
      final j = jsonDecode(rs[0].body) as Map<String, dynamic>;
      final u = jsonDecode(rs[1].body) as Map<String, dynamic>;
      if (mounted) setState(() {
        active = j['active'] == true;
        until = j['activeUntil'] == null ? null : DateTime.tryParse(j['activeUntil'].toString())?.toLocal();
        premium = u['premium'] == true;
        error = null;
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        error = e is StateError ? e.message : 'Rahatsız Etmeyin ayarları yüklenemedi.';
        loading = false;
      });
    }
  }

  void _locked() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: CepqarTheme.panel,
      title: Row(children: [const Icon(Icons.lock_rounded, color: _dndPurple), const SizedBox(width: 8), Text('Premium özellik', style: TextStyle(color: CepqarTheme.text))]),
      content: Text('Rahatsız Etmeyin özelliği Premium üyeler için kullanılabilir.', style: TextStyle(color: CepqarTheme.muted)),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam'))],
    ));
  }

  Future<void> _setHours(int hours) async {
    if (ownerId.isEmpty || !premium) return;
    setState(() => loading = true);
    try {
      final r = await OwnerHttp.put(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/dnd'), body: jsonEncode({'hours':hours}));
      if (r.statusCode < 200 || r.statusCode >= 300) {
        throw StateError(r.statusCode == 403 ? 'Premium üyelik gerekli.' : 'Ayar sunucuya kaydedilemedi (HTTP ${r.statusCode}).');
      }
      final j = jsonDecode(r.body) as Map<String,dynamic>;
      if (mounted) setState(() {
        error = null;
        active = j['active'] == true;
        until = j['activeUntil'] == null ? null : DateTime.tryParse(j['activeUntil'].toString())?.toLocal();
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() { loading = false; error = e is StateError ? e.message : 'Ayar sunucuya kaydedilemedi.'; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error!)));
      }
    }
  }

  Future<void> _chooseDuration() async {
    if (!premium) { _locked(); return; }
    final hours = await showModalBottomSheet<int>(context: context, backgroundColor: CepqarTheme.panel, builder: (c) => SafeArea(child: Wrap(children: [
      ListTile(title: Text('Ne kadar sessiz kalalım?', style: TextStyle(color: CepqarTheme.text, fontWeight: FontWeight.w900))),
      for (final h in [1,3,5,8,12]) ListTile(title: Text('$h saat', style: TextStyle(color: CepqarTheme.text)), onTap: () => Navigator.pop(c,h)),
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
      onTap: loading || premium || error != null ? null : _locked,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(15,13,10,13),
        decoration: BoxDecoration(color: CepqarTheme.panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: active ? _dndPurple : CepqarTheme.line)),
        child: Row(children: [
          Container(width:44,height:44,decoration:BoxDecoration(color:_dndPurple.withValues(alpha:.13),borderRadius:BorderRadius.circular(14)),child:Icon(active?Icons.nightlight_round:Icons.do_not_disturb_on_outlined,color:_dndPurple)),
          const SizedBox(width:12),
          Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              Flexible(child:Text('Rahatsız Etmeyin',style:TextStyle(color:CepqarTheme.text,fontWeight:FontWeight.w900,fontSize:15))),
              if (!loading && !premium) ...[const SizedBox(width:7),const Icon(Icons.lock_rounded,color:_dndPurple,size:14),const SizedBox(width:3),const Text('Premium',style:TextStyle(color:_dndPurple,fontSize:10,fontWeight:FontWeight.w900))],
            ]),
            const SizedBox(height:4),
            Text(error ?? subtitle,style:TextStyle(color:error==null?CepqarTheme.muted:Colors.redAccent,fontSize:11.5)),
            if (error != null) TextButton.icon(onPressed:_load,icon:const Icon(Icons.refresh_rounded,size:15),label:const Text('Tekrar dene')),
          ])),
          if (loading)
            const Padding(padding:EdgeInsets.all(12),child:SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:_dndPurple)))
          else
            Switch(value: premium && active, activeThumbColor: Colors.white, activeTrackColor: _dndPurple, onChanged: error!=null?null:(premium ? (v) => v ? _chooseDuration() : _setHours(0) : (_) => _locked())),
        ]),
      ),
    );
  }
}

class OwnerDndPage extends StatelessWidget {
  const OwnerDndPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor:CepqarTheme.bg,
    appBar:AppBar(
      backgroundColor:CepqarTheme.bg,
      foregroundColor:CepqarTheme.text,
      surfaceTintColor:Colors.transparent,
      title:const Text('Rahatsız Etmeyin'),
    ),
    body:SafeArea(child:ListView(
      padding:const EdgeInsets.all(16),
      children:const [
        OwnerDndCard(),
        SizedBox(height:12),
        Text(
          'Seçtiğiniz süre sonunda bu ayar otomatik olarak kapanır. '
          'Premium üyeler tarafından kullanılabilir.',
          style:TextStyle(fontSize:12),
        ),
      ],
    )),
  );
}
