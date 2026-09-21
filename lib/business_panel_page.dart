import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const _bg=Color(0xFF07111F),_panel=Color(0xFF101A30),_line=Color(0xFF27355D),_purple=Color(0xFF713BFF),_muted=Color(0xFFA7B0C7);

const _businessApi='https://heycar-api-185-165-46-213.nip.io';

class BusinessPanelPage extends StatefulWidget{const BusinessPanelPage({super.key});@override State<BusinessPanelPage> createState()=>_BusinessPanelPageState();}
class _BusinessPanelPageState extends State<BusinessPanelPage>{
 int tab=0; String token=''; bool loading=false; Map<String,dynamic>? business,stats; List<Map<String,dynamic>> liveCampaigns=[];
 @override void initState(){super.initState();_restore();}
 Future<void> _restore()async{final p=await SharedPreferences.getInstance();token=p.getString('business_token')??'';if(token.isNotEmpty)await _loadAll();else if(mounted)setState((){});}
 Future<Map<String,dynamic>?> _get(String path)async{final r=await http.get(Uri.parse('$_businessApi$path'),headers:{'Authorization':'Bearer $token'});if(r.statusCode==401){await _logout();return null;}if(r.statusCode<200||r.statusCode>=300)return null;return Map<String,dynamic>.from(jsonDecode(r.body));}
 Future<void> _loadAll()async{if(token.isEmpty)return;if(mounted)setState(()=>loading=true);final rs=await Future.wait([_get('/api/business/me'),_get('/api/business/campaigns'),_get('/api/business/stats')]);if(!mounted)return;setState((){business=rs[0]?['business'] is Map?Map<String,dynamic>.from(rs[0]!['business']):null;liveCampaigns=(rs[1]?['campaigns'] as List? ?? []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();stats=rs[2]?['stats'] is Map?Map<String,dynamic>.from(rs[2]!['stats']):null;loading=false;});}
 Future<void> _logout()async{if(token.isNotEmpty){try{await http.post(Uri.parse('$_businessApi/api/business/auth/logout'),headers:{'Authorization':'Bearer $token'});}catch(_){}}final p=await SharedPreferences.getInstance();await p.remove('business_token');if(mounted)setState((){token='';business=null;stats=null;liveCampaigns=[];tab=0;});}

 @override
 Widget build(BuildContext context){
  final desktop=MediaQuery.sizeOf(context).width>=900;
  if(token.isEmpty&&!loading)return _BusinessWelcome(onLogin:()=>_showAuth(context),onRegister:()=>_showAuth(context,register:true));
  final home=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   _Header(desktop:desktop,onLogin:token.isEmpty?()=>_showAuth(context):_logout),
   const SizedBox(height:16),if(loading)const LinearProgressIndicator(color:_purple),if(loading)const SizedBox(height:10),_Hero(name:(business?['name']??'İşletmen').toString()),const SizedBox(height:16),_Stats(desktop:desktop,stats:stats),const SizedBox(height:16),
   SizedBox(width:double.infinity,height:48,child:FilledButton.icon(onPressed:()=>_showCampaign(context),style:FilledButton.styleFrom(backgroundColor:_purple,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),icon:const Icon(Icons.add_circle_rounded),label:const Text('Yeni Kampanya Oluştur',style:TextStyle(fontWeight:FontWeight.w900)))),
   const SizedBox(height:16),
   if(!desktop)...[_Quick(onTap:(i){if(i==0){_editProfile(context);}else if(i==1){setState(()=>tab=desktop?2:0);_showCampaign(context);}else if(i==2){setState(()=>tab=desktop?3:1);}else{setState(()=>tab=desktop?4:1);}}),const SizedBox(height:16)],
   if(desktop) Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(flex:2,child:_Campaigns(items:liveCampaigns,onEdit:(x)=>_editCampaign(context,x),onAll:()=>setState(()=>tab=desktop?2:0))),const SizedBox(width:16),Expanded(child:Column(children:[_Profile(business:business,onEdit:()=>_editProfile(context)),const SizedBox(height:16),_Quick(onTap:(i){if(i==0){_editProfile(context);}else if(i==1){_showCampaign(context);}else{setState(()=>tab=i==2?3:4);}})]))])
   else Column(children:[_Campaigns(items:liveCampaigns,onEdit:(x)=>_editCampaign(context,x),onAll:()=>setState(()=>tab=desktop?2:0)),const SizedBox(height:16),_Profile(business:business,onEdit:()=>_editProfile(context))]),
   const SizedBox(height:20),
  ]);
  Widget page=home;
  if(tab==1) page=_StatsPage(stats:stats);
  if(tab==3) page=_SettingsPage(business:business,onEdit:()=>_editProfile(context),onLogout:_logout);
  if(desktop&&tab==4) page=_StatsPage(stats:stats);
  if(desktop&&tab==1) page=_SettingsPage(business:business,onEdit:()=>_editProfile(context),onLogout:_logout);
  if(desktop&&tab==2) page=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[_Header(desktop:true,onLogin:token.isEmpty?()=>_showAuth(context):_logout),const SizedBox(height:18),SizedBox(width:260,height:46,child:FilledButton.icon(onPressed:()=>_showCampaign(context),icon:const Icon(Icons.add),label:const Text('Yeni Kampanya'))),const SizedBox(height:16),_Campaigns(items:liveCampaigns,onEdit:(x)=>_editCampaign(context,x),onAll:()=>setState(()=>tab=desktop?2:0))]);
  return Scaffold(backgroundColor:_bg,bottomNavigationBar:desktop?null:_Bottom(tab:tab,onTap:(i){if(i==2){_showCampaign(context);}else{setState(()=>tab=i);}}),body:SafeArea(child:Row(children:[if(desktop)_Side(tab:tab,onTap:(i)=>setState(()=>tab=i)),Expanded(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1180),child:SingleChildScrollView(padding:EdgeInsets.all(desktop?28:16),child:page))))])));
 }
 Future<void> _editCampaign(BuildContext context,Map<String,dynamic> x)async{final title=TextEditingController(text:(x['title']??'').toString()),desc=TextEditingController(text:(x['description']??'').toString()),badge=TextEditingController(text:(x['badge']??'').toString()),code=TextEditingController(text:(x['coupon_code']??x['couponCode']??'').toString());bool active=x['is_active']==true||x['isActive']==true;await showDialog(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(backgroundColor:_panel,title:const Text('Kampanyayı Düzenle',style:TextStyle(color:Colors.white)),content:SizedBox(width:430,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[_Field(title,'Başlık'),_Field(desc,'Açıklama'),_Field(badge,'İndirim etiketi'),_Field(code,'Kampanya kodu'),SwitchListTile(value:active,onChanged:(v)=>setD(()=>active=v),title:const Text('Aktif',style:TextStyle(color:Colors.white)),activeThumbColor:_purple)]))),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),FilledButton(onPressed:()async{final id=x['id'];final r=await http.patch(Uri.parse('$_businessApi/api/business/campaigns/$id'),headers:{'Content-Type':'application/json','Authorization':'Bearer $token'},body:jsonEncode({'title':title.text,'description':desc.text,'badge':badge.text,'couponCode':code.text,'isActive':active}));if(r.statusCode==200){if(d.mounted)Navigator.pop(d);await _loadAll();}},child:const Text('Kaydet'))])));}
 Future<void> _editProfile(BuildContext context)async{if(token.isEmpty){await _showAuth(context);return;}final n=TextEditingController(text:(business?['name']??'').toString()),cat=TextEditingController(text:(business?['category']??'').toString()),phone=TextEditingController(text:(business?['phone']??'').toString()),address=TextEditingController(text:(business?['address']??'').toString()),hours=TextEditingController(text:(business?['opening_hours']??'').toString()),desc=TextEditingController(text:(business?['description']??'').toString());await showDialog(context:context,builder:(d)=>AlertDialog(backgroundColor:_panel,title:const Text('İşletme Bilgileri',style:TextStyle(color:Colors.white)),content:SizedBox(width:430,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[_Field(n,'İşletme adı'),_Field(cat,'Kategori'),_Field(phone,'Telefon'),_Field(address,'Adres'),_Field(hours,'Çalışma saatleri'),_Field(desc,'Açıklama')]))),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),FilledButton(onPressed:()async{final r=await http.patch(Uri.parse('$_businessApi/api/business/me'),headers:{'Content-Type':'application/json','Authorization':'Bearer $token'},body:jsonEncode({'name':n.text,'category':cat.text,'phone':phone.text,'address':address.text,'openingHours':hours.text,'description':desc.text,'latitude':business?['latitude'],'longitude':business?['longitude']}));if(r.statusCode==200){if(d.mounted)Navigator.pop(d);await _loadAll();}},child:const Text('Kaydet'))]));}
 Future<void> _showCampaign(BuildContext context) async {
  final title=TextEditingController(),desc=TextEditingController(),badge=TextEditingController(),code=TextEditingController();
  final now=DateTime.now(); DateTime start=DateTime(now.year,now.month,now.day),end=DateTime(now.year,now.month,now.day).add(const Duration(days:30));
  String dateLabel(DateTime x)=>'${x.day.toString().padLeft(2,'0')}.${x.month.toString().padLeft(2,'0')}.${x.year}';
  await showDialog(context:context,builder:(d)=>StatefulBuilder(builder:(d,setD)=>AlertDialog(
   backgroundColor:_panel,title:const Text('Yeni Kampanya Oluştur',style:TextStyle(color:Colors.white)),
   content:SizedBox(width:430,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    _Field(title,'Kampanya başlığı'),_Field(desc,'Açıklama'),_Field(badge,'İndirim etiketi (%30 İndirim)'),_Field(code,'Kampanya kodu'),
    const SizedBox(height:4),
    Row(children:[
     Expanded(child:OutlinedButton.icon(onPressed:()async{final x=await showDatePicker(context:d,initialDate:start,firstDate:DateTime(now.year-1),lastDate:DateTime(now.year+5));if(x!=null)setD(()=>start=x);},icon:const Icon(Icons.calendar_month_rounded),label:Text('Başlangıç\n${dateLabel(start)}',textAlign:TextAlign.center))),
     const SizedBox(width:10),
     Expanded(child:OutlinedButton.icon(onPressed:()async{final x=await showDatePicker(context:d,initialDate:end.isBefore(start)?start:end,firstDate:start,lastDate:DateTime(now.year+6));if(x!=null)setD(()=>end=x);},icon:const Icon(Icons.event_available_rounded),label:Text('Bitiş\n${dateLabel(end)}',textAlign:TextAlign.center)))
    ])
   ]))),
   actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const Text('Vazgeç')),FilledButton(onPressed:()async{
    if(token.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Önce işletme hesabıyla giriş yapmalısın.')));return;}
    if(end.isBefore(start)){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Bitiş tarihi başlangıç tarihinden önce olamaz.')));return;}
    final startUtc=DateTime(start.year,start.month,start.day).toUtc();
    final endUtc=DateTime(end.year,end.month,end.day,23,59,59).toUtc();
    final r=await http.post(Uri.parse('$_businessApi/api/business/campaigns'),headers:{'Content-Type':'application/json','Authorization':'Bearer $token'},body:jsonEncode({'title':title.text,'description':desc.text,'badge':badge.text,'couponCode':code.text,'startsAt':startUtc.toIso8601String(),'endsAt':endUtc.toIso8601String()}));
    if(d.mounted&&r.statusCode==201){Navigator.pop(d);await _loadAll();}
   },child:const Text('Yayınla'))]
  )));
 }
 Future<void> _showAuth(BuildContext context,{bool register=false}) async {
  final email=TextEditingController(),pw=TextEditingController(),name=TextEditingController(),cat=TextEditingController(),phone=TextEditingController(),address=TextEditingController(),street=TextEditingController(),houseNumber=TextEditingController(),district=TextEditingController(),city=TextEditingController();
  final result=await Navigator.push<bool>(context,MaterialPageRoute(fullscreenDialog:true,builder:(_)=>_BusinessAuthPage(
   register:register,email:email,pw:pw,name:name,cat:cat,phone:phone,address:address,street:street,houseNumber:houseNumber,district:district,city:city,
   submit:()async{
    final path=register?'register':'login';
    double? selectedLat,selectedLon; String? selectedAddress;
    if(register){
     final vr=await http.post(Uri.parse('$_businessApi/api/business/address-candidates'),headers:{'Content-Type':'application/json'},body:jsonEncode({'street':street.text.trim(),'houseNumber':houseNumber.text.trim(),'district':district.text.trim(),'city':city.text.trim()}));
     if(vr.statusCode!=200)return 'Adres doğrulanamadı. Bilgileri kontrol et.';
     final candidates=(jsonDecode(vr.body)['candidates'] as List? ?? []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
     if(candidates.isEmpty)return 'Adres bulunamadı.';
     final chosen=await showDialog<Map<String,dynamic>>(context:context,builder:(d)=>AlertDialog(backgroundColor:_panel,title:const Text('İşletme adresini seç',style:TextStyle(color:Colors.white)),content:SizedBox(width:430,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[...candidates.take(5).map((item)=>ListTile(title:Text((item['formatted']??'').toString(),style:const TextStyle(color:Colors.white)),subtitle:Text('Eşleşme güveni: %'+(((item['confidence']??0) as num)*100).round().toString(),style:const TextStyle(color:_muted)),onTap:()=>Navigator.pop(d,item))),const Divider(color:_line),ListTile(leading:const Icon(Icons.map_rounded,color:Color(0xFFB6FF2A)),title:const Text('Haritada konumu seç',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900)),subtitle:const Text('Adres doğru çıkmıyorsa işletmenin üstüne pini bırak.',style:TextStyle(color:_muted)),onTap:()async{final seed=candidates.first;final picked=await Navigator.push<Map<String,dynamic>>(d,MaterialPageRoute(fullscreenDialog:true,builder:(_)=>_BusinessLocationPicker(initial:LatLng((seed['latitude'] as num).toDouble(),(seed['longitude'] as num).toDouble()))));if(picked!=null&&d.mounted)Navigator.pop(d,picked);})])))));
     if(chosen==null)return 'Kayıt için işletme adresini seçmelisin.';
     selectedLat=(chosen['latitude'] as num?)?.toDouble();selectedLon=(chosen['longitude'] as num?)?.toDouble();selectedAddress=(chosen['formatted']??[street.text.trim(),'No: '+houseNumber.text.trim(),district.text.trim(),city.text.trim()].where((e)=>e.isNotEmpty).join(', ')).toString();
    }
    final body=register?{'email':email.text.trim(),'password':pw.text,'name':name.text.trim(),'category':cat.text.trim(),'phone':phone.text.trim(),'address':selectedAddress,'street':street.text.trim(),'houseNumber':houseNumber.text.trim(),'district':district.text.trim(),'city':city.text.trim(),'latitude':selectedLat,'longitude':selectedLon}:{'email':email.text.trim(),'password':pw.text};
    final r=await http.post(Uri.parse('$_businessApi/api/business/auth/$path'),headers:{'Content-Type':'application/json'},body:jsonEncode(body));
    if(r.statusCode==200||r.statusCode==201){final j=jsonDecode(r.body);token=(j['token']??'').toString();final p=await SharedPreferences.getInstance();await p.setString('business_token',token);await _loadAll();return null;}
    if(r.statusCode==409)return 'Bu e-posta ile daha önce kayıt olunmuş.';
    if(register&&r.statusCode==400&&r.body.contains('ADDRESS_NOT_FOUND'))return 'Adres bulunamadı. Mahalle, cadde/sokak, bina no, ilçe ve il bilgilerini kontrol et.';
    if(register&&r.statusCode==503)return 'Adres konumu şu anda doğrulanamadı. Biraz sonra tekrar dene.';
    return register?'Kayıt oluşturulamadı. Bilgileri kontrol et.':'E-posta veya şifre hatalı.';
   },
   switchMode:()=>Navigator.pop(context,true),
  )));
  if(result==true&&mounted)await _showAuth(context,register:!register);
 }
}
class _Field extends StatelessWidget{const _Field(this.c,this.label,{this.secret=false});final TextEditingController c;final String label;final bool secret;@override Widget build(BuildContext x)=>Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:c,obscureText:secret,style:const TextStyle(color:Colors.white),decoration:InputDecoration(labelText:label,labelStyle:const TextStyle(color:_muted),filled:true,fillColor:_bg,border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)))));}
class _Header extends StatelessWidget{
 const _Header({required this.desktop,required this.onLogin});
 final bool desktop; final VoidCallback onLogin;
 @override Widget build(BuildContext c){
  if(!desktop){
   return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Image.asset('assets/Logoqr.png',height:32),const Spacer(),IconButton(onPressed:onLogin,icon:const Icon(Icons.login_rounded,color:_purple)),const Icon(Icons.notifications_none_rounded,color:_muted,size:23)]),
    const SizedBox(height:12),
    const Text('İşletme Paneli',style:TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900)),
    const SizedBox(height:3),
    const Text('İşletmeni yönet, daha fazla müşteriye ulaş.',style:TextStyle(color:_muted,fontSize:11))
   ]);
  }
  return Row(children:[
   Image.asset('assets/Logoqr.png',height:42),const SizedBox(width:16),Container(width:1,height:35,color:_line),const SizedBox(width:14),
   const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('İşletme Paneli',style:TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.w900)),Text('İşletmeni yönet, daha fazla müşteriye ulaş.',style:TextStyle(color:_muted,fontSize:10))])),
   IconButton(onPressed:onLogin,icon:const Icon(Icons.login_rounded,color:_purple)),const Icon(Icons.notifications_none_rounded,color:_muted)
  ]);
 }
}
class _Hero extends StatelessWidget{const _Hero({required this.name});final String name;@override Widget build(BuildContext c)=>Container(height:125,padding:const EdgeInsets.all(20),decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF25105D),Color(0xFF713BFF),Color(0xFF101A30)]),borderRadius:BorderRadius.circular(20),border:Border.all(color:_purple.withValues(alpha:.45))),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Text('Merhaba, $name 👋',style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:5),const Text('Bugün de harika fırsatlar paylaş!',style:TextStyle(color:Color(0xFFD6C8FF),fontSize:12))])),const Icon(Icons.directions_car_rounded,color:Colors.white,size:72)]));}
class _Stats extends StatelessWidget{const _Stats({required this.desktop,required this.stats});final bool desktop;final Map<String,dynamic>? stats;@override Widget build(BuildContext c){final s=stats??{};final xs=[(Icons.local_offer_rounded,'Toplam Kampanya','${s['campaigns']??0}'),(Icons.campaign_rounded,'Aktif Kampanya','${s['active_campaigns']??0}'),(Icons.qr_code_scanner_rounded,'Toplam Kullanım','${s['redemptions']??0}')];return GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:3,gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:desktop?3:2,crossAxisSpacing:10,mainAxisSpacing:10,childAspectRatio:desktop?1.8:1.45),itemBuilder:(_,i){final x=xs[i];return _Box(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Icon(x.$1,color:_purple,size:24),const SizedBox(height:6),Text(x.$2,style:const TextStyle(color:_muted,fontSize:10)),Text(x.$3,style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900))]));});}}
class _Campaigns extends StatelessWidget{
 const _Campaigns({required this.items,required this.onEdit,required this.onAll});
 final List<Map<String,dynamic>> items; final ValueChanged<Map<String,dynamic>> onEdit; final VoidCallback onAll;
 @override Widget build(BuildContext c){
  return _Box(child:Column(children:[
   Row(children:[const Expanded(child:Text('Kampanyalarım',style:TextStyle(color:Colors.white,fontSize:17,fontWeight:FontWeight.w900))),TextButton(onPressed:onAll,child:const Text('Tümünü Gör ›'))]),
   if(items.isEmpty)const Padding(padding:EdgeInsets.all(22),child:Text('Henüz kampanya yok.',style:TextStyle(color:_muted))),
   ...items.map((x){
    final active=x['is_active']==true||x['isActive']==true;
    return Container(
     padding:const EdgeInsets.symmetric(vertical:10),
     decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:_line))),
     child:Row(children:[
      Container(width:64,height:58,decoration:BoxDecoration(color:_purple.withValues(alpha:.15),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.local_offer_rounded,color:_purple)),
      const SizedBox(width:10),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       Text((x['title']??'Kampanya').toString(),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900)),
       Text((x['badge']??x['description']??'').toString(),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_muted,fontSize:10))
      ])),
      Column(children:[
       Text(active?'Aktif':'Pasif',style:TextStyle(color:active?const Color(0xFF39D98A):_muted,fontSize:9,fontWeight:FontWeight.w900)),
       OutlinedButton(onPressed:()=>onEdit(x),style:OutlinedButton.styleFrom(side:const BorderSide(color:_purple)),child:const Text('Düzenle',style:TextStyle(color:_purple,fontSize:9)))
      ])
     ])
    );
   })
  ]));
 }
}
class _Profile extends StatelessWidget{const _Profile({required this.business,required this.onEdit});final Map<String,dynamic>? business;final VoidCallback onEdit;@override Widget build(BuildContext c){final b=business??{};return _Box(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Expanded(child:Text('İşletme Profilim',style:TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.w900))),TextButton(onPressed:onEdit,child:const Text('Düzenle ›'))]),const SizedBox(height:8),Row(children:[const CircleAvatar(radius:34,backgroundColor:Color(0xFF25105D),child:Icon(Icons.storefront,color:_purple,size:30)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text((b['name']??'İşletme').toString(),style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w900)),Text((b['category']??'Kategori belirtilmedi').toString(),style:const TextStyle(color:_muted,fontSize:10)),Text((b['address']??'Adres eklenmedi').toString(),maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:_muted,fontSize:10))]))]),const SizedBox(height:12),SizedBox(width:double.infinity,child:OutlinedButton(onPressed:onEdit,child:const Text('Profili Düzenle',style:TextStyle(color:_purple))))]));}}
class _Quick extends StatelessWidget{const _Quick({required this.onTap});final ValueChanged<int> onTap;@override Widget build(BuildContext c){final xs=[(Icons.storefront_rounded,'İşletme Bilgilerim'),(Icons.local_offer_rounded,'Kampanyalar'),(Icons.qr_code_rounded,'Kullanım Kodları'),(Icons.bar_chart_rounded,'İstatistikler')];return _Box(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Hızlı İşlemler',style:TextStyle(color:Colors.white,fontSize:15,fontWeight:FontWeight.w900)),const SizedBox(height:10),Row(children:xs.asMap().entries.map((e)=>Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:3),child:InkWell(borderRadius:BorderRadius.circular(12),onTap:()=>onTap(e.key),child:Container(height:72,decoration:BoxDecoration(border:Border.all(color:_line),borderRadius:BorderRadius.circular(12)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(e.value.$1,color:_purple,size:22),const SizedBox(height:5),Text(e.value.$2,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:8.5))])))))).toList())]));}}
class _Box extends StatelessWidget{const _Box({required this.child});final Widget child;@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),child:child);}
class _Side extends StatelessWidget{const _Side({required this.tab,required this.onTap});final int tab;final ValueChanged<int> onTap;@override Widget build(BuildContext c)=>Container(width:210,color:const Color(0xFF091528),padding:const EdgeInsets.fromLTRB(14,28,14,14),child:Column(children:[Image.asset('assets/Logoqr.png',height:40),const SizedBox(height:30),...['Ana Sayfa','İşletme Bilgileri','Kampanyalar','Kullanım Kodları','İstatistikler','Müşteri Yorumları','Ayarlar'].asMap().entries.map((e)=>ListTile(onTap:()=>onTap(e.key),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),tileColor:e.key==tab?_purple:null,leading:Icon([Icons.home_rounded,Icons.storefront,Icons.local_offer,Icons.qr_code,Icons.bar_chart,Icons.chat,Icons.settings][e.key],color:e.key==tab?Colors.white:_muted,size:20),title:Text(e.value,style:TextStyle(color:e.key==tab?Colors.white:_muted,fontSize:11,fontWeight:FontWeight.w700))))]));}
class _Bottom extends StatelessWidget{const _Bottom({required this.tab,required this.onTap});final int tab;final ValueChanged<int> onTap;@override Widget build(BuildContext c)=>Container(height:74,decoration:const BoxDecoration(color:Color(0xFF0D192D),border:Border(top:BorderSide(color:_line))),child:SafeArea(top:false,child:Row(children:[(Icons.home_rounded,'Ana Sayfa'),(Icons.bar_chart_rounded,'İstatistikler'),(Icons.add_circle_rounded,'Kampanya'),(Icons.settings_rounded,'Ayarlar')].asMap().entries.map((e)=>Expanded(child:InkWell(onTap:()=>onTap(e.key),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(e.value.$1,color:e.key==tab?_purple:_muted,size:25),Text(e.value.$2,style:TextStyle(color:e.key==tab?_purple:_muted,fontSize:9.5,fontWeight:FontWeight.w700))])))).toList())));}

class _StatsPage extends StatelessWidget{const _StatsPage({required this.stats});final Map<String,dynamic>? stats;@override Widget build(BuildContext c){final s=stats??{};return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('İstatistikler',style:TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w900)),const SizedBox(height:6),const Text('Gerçek kampanya verilerin',style:TextStyle(color:_muted)),const SizedBox(height:18),_Metric('Toplam Kampanya','${s['campaigns']??0}',Icons.local_offer_rounded),const SizedBox(height:10),_Metric('Aktif Kampanya','${s['active_campaigns']??0}',Icons.campaign_rounded),const SizedBox(height:10),_Metric('Toplam Kullanım','${s['redemptions']??0}',Icons.qr_code_scanner_rounded)]);}}
class _Metric extends StatelessWidget{const _Metric(this.t,this.v,this.i);final String t,v;final IconData i;@override Widget build(BuildContext c)=>_Box(child:Row(children:[Container(width:48,height:48,decoration:BoxDecoration(color:_purple.withValues(alpha:.15),borderRadius:BorderRadius.circular(14)),child:Icon(i,color:_purple)),const SizedBox(width:13),Expanded(child:Text(t,style:const TextStyle(color:_muted,fontSize:13))),Text(v,style:const TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w900))]));}
class _SettingsPage extends StatelessWidget{const _SettingsPage({required this.business,required this.onEdit,required this.onLogout});final Map<String,dynamic>? business;final VoidCallback onEdit,onLogout;@override Widget build(BuildContext c)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Ayarlar',style:TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w900)),const SizedBox(height:18),_Box(child:Column(children:[ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.storefront_rounded,color:_purple),title:Text((business?['name']??'İşletme Bilgileri').toString(),style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800)),subtitle:Text((business?['category']??'Profilini düzenle').toString(),style:const TextStyle(color:_muted)),trailing:const Icon(Icons.chevron_right,color:_muted),onTap:onEdit),const Divider(color:_line),ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.logout_rounded,color:Colors.redAccent),title:const Text('Çıkış Yap',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w800)),onTap:onLogout)]))]);}

class _BusinessWelcome extends StatelessWidget{
 const _BusinessWelcome({required this.onLogin,required this.onRegister});
 final VoidCallback onLogin,onRegister;
 @override Widget build(BuildContext c)=>Scaffold(
  backgroundColor:_bg,
  body:SafeArea(child:Center(child:SingleChildScrollView(
   padding:const EdgeInsets.fromLTRB(24,18,24,26),
   child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:430),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Image.asset('assets/Logoqr.png',height:48),
    const SizedBox(height:12),
    Container(padding:const EdgeInsets.symmetric(horizontal:13,vertical:7),decoration:BoxDecoration(border:Border.all(color:_line),borderRadius:BorderRadius.circular(20)),child:const Text('İşletme Paneli',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w700))),
    const SizedBox(height:28),
    SizedBox(height:285,child:Stack(clipBehavior:Clip.none,children:[
     const Positioned(left:0,top:0,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('İşletmen',style:TextStyle(color:Colors.white,fontSize:38,height:1,fontWeight:FontWeight.w900)),
      Text('hep görünür',style:TextStyle(color:Colors.white,fontSize:38,height:1,fontWeight:FontWeight.w900)),
      Text('olsun.',style:TextStyle(color:Color(0xFFB6FF2A),fontSize:38,height:1.02,fontWeight:FontWeight.w900))
     ])),
     Positioned(right:-2,top:58,width:245,height:230,child:Image.asset('assets/İsletmeh.png',fit:BoxFit.contain,alignment:Alignment.bottomRight))
    ])),
    const SizedBox(height:6),
    const SizedBox(width:300,child:Text('Daha fazla müşteriye ulaş,\nkampanyalarını yönet,\nişletmeni büyüt.',style:TextStyle(color:_muted,fontSize:16,height:1.45))),
    const SizedBox(height:18),
    Row(children:[_Benefit(Icons.campaign_rounded,'Kampanya\noluştur'),const SizedBox(width:9),_Benefit(Icons.bar_chart_rounded,'Daha fazla\nmüşteri'),const SizedBox(width:9),_Benefit(Icons.storefront_rounded,'İşletmeni\nöne çıkar')]),
    const SizedBox(height:24),
    SizedBox(width:double.infinity,height:54,child:FilledButton(onPressed:onLogin,style:FilledButton.styleFrom(backgroundColor:const Color(0xFFB6FF2A),foregroundColor:Colors.black,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(17))),child:const Row(mainAxisAlignment:MainAxisAlignment.center,children:[Text('Giriş Yap',style:TextStyle(fontSize:17,fontWeight:FontWeight.w900)),SizedBox(width:8),Icon(Icons.arrow_forward_rounded)]))),
    const SizedBox(height:11),
    SizedBox(width:double.infinity,height:54,child:OutlinedButton(onPressed:onRegister,style:OutlinedButton.styleFrom(side:const BorderSide(color:_line,width:1.4),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(17))),child:const Text('Kayıt Ol',style:TextStyle(color:Colors.white,fontSize:17,fontWeight:FontWeight.w900)))),
    const SizedBox(height:22),
    const Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.lock_outline_rounded,color:_muted,size:18),SizedBox(width:7),Text('İşletme bilgileriniz güvende.',style:TextStyle(color:_muted,fontSize:13))])
   ]))
  )))
 );
}
class _Benefit extends StatelessWidget{const _Benefit(this.icon,this.text);final IconData icon;final String text;@override Widget build(BuildContext c)=>Expanded(child:Container(height:112,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,color:_purple,size:28),const SizedBox(height:9),Text(text,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w700))])));}
class _BusinessAuthPage extends StatefulWidget{
 const _BusinessAuthPage({required this.register,required this.email,required this.pw,required this.name,required this.cat,required this.phone,required this.address,required this.street,required this.houseNumber,required this.district,required this.city,required this.submit,required this.switchMode});
 final bool register;final TextEditingController email,pw,name,cat,phone,address,street,houseNumber,district,city;final Future<String?> Function() submit;final VoidCallback switchMode;
 @override State<_BusinessAuthPage> createState()=>_BusinessAuthPageState();
}
class _BusinessAuthPageState extends State<_BusinessAuthPage>{bool busy=false,hide=true,agree=false;String? error;
 Future<void> go()async{if(widget.register&&!agree){setState(()=>error='Devam etmek için kullanım koşullarını kabul et.');return;}setState((){busy=true;error=null;});final e=await widget.submit();if(!mounted)return;if(e==null){Navigator.pop(context);return;}setState((){busy=false;error=e;});}
 @override Widget build(BuildContext c)=>Scaffold(backgroundColor:_bg,body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(22,16,22,28),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:470),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Row(children:[IconButton(onPressed:()=>Navigator.pop(c),icon:const Icon(Icons.arrow_back,color:_muted)),const Spacer(),Image.asset('assets/Logoqr.png',height:40),const Spacer(),const SizedBox(width:48)]),
  const SizedBox(height:8),Center(child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),decoration:BoxDecoration(border:Border.all(color:_line),borderRadius:BorderRadius.circular(20)),child:const Text('İşletme Paneli',style:TextStyle(color:Colors.white,fontSize:13)))),
  const SizedBox(height:22),Text(widget.register?'İşletmeni Kaydet':'Tekrar Hoş Geldin',style:const TextStyle(color:Colors.white,fontSize:30,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text(widget.register?'Dakikalar içinde hesap oluştur, hemen müşterilerine ulaş.':'İşletme paneline devam etmek için giriş yap.',style:const TextStyle(color:_muted,fontSize:16,height:1.35)),const SizedBox(height:22),
  if(widget.register)...[_AuthField(widget.name,'İşletme Adı',Icons.storefront_rounded),_AuthField(widget.cat,'Kategori',Icons.category_rounded),_AuthField(widget.street,'Sokak / Cadde',Icons.location_on_rounded),_AuthField(widget.houseNumber,'Bina No',Icons.numbers_rounded,keyboard:TextInputType.streetAddress),_AuthField(widget.district,'İlçe',Icons.location_city_rounded),_AuthField(widget.city,'İl',Icons.map_rounded),_AuthField(widget.phone,'Telefon Numarası',Icons.phone_rounded,keyboard:TextInputType.phone)],
  _AuthField(widget.email,'E-posta',Icons.mail_rounded,keyboard:TextInputType.emailAddress),
  _AuthField(widget.pw,'Şifre',Icons.lock_rounded,secret:hide,suffix:IconButton(onPressed:()=>setState(()=>hide=!hide),icon:Icon(hide?Icons.visibility_outlined:Icons.visibility_off_outlined,color:_muted))),
  if(widget.register)CheckboxListTile(contentPadding:EdgeInsets.zero,value:agree,onChanged:(v)=>setState(()=>agree=v??false),activeColor:_purple,controlAffinity:ListTileControlAffinity.leading,title:const Text('Kullanım koşullarını ve gizlilik politikasını kabul ediyorum.',style:TextStyle(color:_muted,fontSize:12.5))),
  if(error!=null)Padding(padding:const EdgeInsets.only(bottom:10),child:Text(error!,style:const TextStyle(color:Colors.redAccent,fontWeight:FontWeight.w700))),
  SizedBox(width:double.infinity,height:54,child:FilledButton(onPressed:busy?null:go,style:FilledButton.styleFrom(backgroundColor:const Color(0xFFB6FF2A),foregroundColor:Colors.black,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(17))),child:busy?const SizedBox(width:22,height:22,child:CircularProgressIndicator(strokeWidth:2.5,color:Colors.black)):Text(widget.register?'Hesap Oluştur':'Giriş Yap',style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900)))),
  const SizedBox(height:16),Center(child:TextButton(onPressed:widget.switchMode,child:Text(widget.register?'Zaten hesabın var mı? Giriş Yap':'Hesabın yok mu? Kayıt Ol',style:const TextStyle(color:_purple,fontWeight:FontWeight.w800))))
 ]))))));}
class _BusinessLocationPicker extends StatefulWidget{const _BusinessLocationPicker({required this.initial});final LatLng initial;@override State<_BusinessLocationPicker> createState()=>_BusinessLocationPickerState();}
class _BusinessLocationPickerState extends State<_BusinessLocationPicker>{late LatLng point;@override void initState(){super.initState();point=widget.initial;}@override Widget build(BuildContext c)=>Scaffold(backgroundColor:_bg,appBar:AppBar(backgroundColor:_bg,foregroundColor:Colors.white,title:const Text('İşletme konumunu seç')),body:Stack(children:[FlutterMap(options:MapOptions(initialCenter:point,initialZoom:16,onTap:(_,p)=>setState(()=>point=p)),children:[TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'com.cepqar.app'),MarkerLayer(markers:[Marker(point:point,width:54,height:54,child:const Icon(Icons.location_pin,color:_purple,size:54))])]),Positioned(left:16,right:16,bottom:20,child:SafeArea(child:FilledButton.icon(onPressed:()=>Navigator.pop(c,{'latitude':point.latitude,'longitude':point.longitude}),style:FilledButton.styleFrom(backgroundColor:const Color(0xFFB6FF2A),foregroundColor:Colors.black,padding:const EdgeInsets.symmetric(vertical:16)),icon:const Icon(Icons.check_circle_rounded),label:const Text('Bu konumu kullan',style:TextStyle(fontWeight:FontWeight.w900)))))]));}
class _AuthField extends StatelessWidget{const _AuthField(this.c,this.label,this.icon,{this.secret=false,this.suffix,this.keyboard});final TextEditingController c;final String label;final IconData icon;final bool secret;final Widget? suffix;final TextInputType? keyboard;@override Widget build(BuildContext x)=>Padding(padding:const EdgeInsets.only(bottom:11),child:TextField(controller:c,obscureText:secret,keyboardType:keyboard,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700),decoration:InputDecoration(labelText:label,labelStyle:const TextStyle(color:_muted),prefixIcon:Icon(icon,color:const Color(0xFFD3D8E6)),suffixIcon:suffix,filled:true,fillColor:_panel,contentPadding:const EdgeInsets.symmetric(vertical:19,horizontal:14),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(18),borderSide:const BorderSide(color:_line)),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(18),borderSide:const BorderSide(color:_purple,width:1.4)),border:OutlineInputBorder(borderRadius:BorderRadius.circular(18)))));}
