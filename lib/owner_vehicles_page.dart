import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_backend.dart';
import 'qr_backend.dart';
import 'qr_activation.dart';
import 'vehicle_api.dart';
import 'active_driver_card.dart';
import 'vehicle_center_page.dart';
import 'cepqar_theme.dart';
import 'owner_auth.dart';

const _purple=Color(0xFF8B5CFF),_gold=Color(0xFFFFC857),_green=Color(0xFF38D178);
Color get _bg=>CepqarTheme.bg; Color get _panel=>CepqarTheme.panel; Color get _line=>CepqarTheme.line; Color get _muted=>CepqarTheme.muted; Color get _text=>CepqarTheme.text;
class OwnerVehiclesPage extends StatefulWidget{const OwnerVehiclesPage({super.key,this.onVehicleChanged});final VoidCallback? onVehicleChanged;@override State<OwnerVehiclesPage> createState()=>_S();}
class _S extends State<OwnerVehiclesPage>{List<Map<String,dynamic>> vehicles=[];bool loading=true,premium=false;int limit=1;String? error;String get selected=>QrDraft.vehicleId.trim().isNotEmpty?QrDraft.vehicleId.trim():OnboardingDraft.vehicleId.trim();@override void initState(){super.initState();_load();}
Future<void> _load()async{final owner=OnboardingDraft.userId.trim();if(owner.isEmpty){setState((){loading=false;error='Araç sahibi oturumu bulunamadı.';});return;}try{final r=await OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/vehicles'),json:false).timeout(const Duration(seconds:15));final d=jsonDecode(r.body);if(r.statusCode<200||r.statusCode>=300||d is! Map)throw Exception();final list=d['vehicles'];final next=list is List?list.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];if(next.isNotEmpty&&!next.any((v)=>'${v['id']}'==selected))_select(next.first,notify:false);if(!mounted)return;setState((){vehicles=next;premium=d['premium']==true;limit=int.tryParse('${d['limit']}')??1;loading=false;error=null;});}catch(_){if(mounted)setState((){loading=false;error='Araçlar yüklenemedi.';});}}
void _select(Map<String,dynamic> v,{bool notify=true}){final id='${v['id']??''}';QrDraft.vehicleId=id;OnboardingDraft.vehicleId=id;QrDraft.plate='${v['plate']??''}';QrDraft.make='${v['make']??''}';QrDraft.model='${v['model']??''}';QrDraft.token='${v['qr_token']??''}'.trim();QrDraft.scanSecret='${v['qr_scan_secret']??''}'.trim();_persistSelection();if(notify){setState((){});widget.onVehicleChanged?.call();}}
Future<void> _persistSelection()async{final p=await SharedPreferences.getInstance();await p.setString('owner_vehicle_id',QrDraft.vehicleId);await p.setString('owner_plate',QrDraft.plate);await p.setString('owner_make',QrDraft.make);await p.setString('owner_model',QrDraft.model);await p.setString('owner_qr_token',QrDraft.token);await p.setString('owner_qr_scan_secret',QrDraft.scanSecret);}
Future<void> _qr(Map<String,dynamic> v)async{_select(v);if('${v['qr_token']??''}'.trim().isNotEmpty){_showQr(v);return;}await Navigator.push(context,MaterialPageRoute(builder:(c)=>RealQrScanPage(onBack:()=>Navigator.pop(c),onFound:(){Navigator.pop(c);_activate(v);})));}
Future<void> _activate(Map<String,dynamic> v)async{try{await QrBackend.activate(token:QrDraft.token,vehicleId:'${v['id']}',plate:'${v['plate']}',make:'${v['make']}',model:'${v['model']??''}');if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${v['plate']} için QR aktif edildi.')));await _load();widget.onVehicleChanged?.call();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}
void _showQr(Map<String,dynamic> v){final t='${v['qr_token']??''}'.trim(),secret='${v['qr_scan_secret']??''}'.trim(),u='https://queensho.github.io/HeyCar/?tag=${Uri.encodeComponent(t)}${secret.isEmpty?'':'&s=${Uri.encodeComponent(secret)}'}';showModalBottomSheet(context:context,backgroundColor:_panel,builder:(c)=>Padding(padding:const EdgeInsets.all(22),child:Column(mainAxisSize:MainAxisSize.min,children:[Text('${v['plate']} QR',style:TextStyle(color:_text,fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:14),Container(width:220,height:220,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20)),child:Image.network('https://quickchart.io/qr?text=${Uri.encodeComponent(u)}&size=420',errorBuilder:(_,__,___)=>const Icon(Icons.qr_code_2,size:150,color:Colors.black))),const SizedBox(height:10),Text(t,style:TextStyle(color:_muted,fontWeight:FontWeight.w700))])));}
void _open(Map<String,dynamic> v){_select(v);final make='${v['make']??''}',model='${v['model']??''}';Navigator.push(context,MaterialPageRoute(builder:(_)=>VehicleCenterPage(plate:'${v['plate']??''}',title:model.trim().isEmpty?make:'$make $model'))).then((_){widget.onVehicleChanged?.call();_load();});}
Future<void> _remove(Map<String,dynamic> v)async{final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(backgroundColor:_panel,title:Text('Aracı Kaldır',style:TextStyle(color:_text)),content:Text('Bu işlem aracın QR kodunu kalıcı olarak iptal eder. Satış yaptıysan Aracı Devret seçeneğini kullan.',style:TextStyle(color:_muted)),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Aracı Kaldır'))]));if(yes!=true)return;final r=await OwnerHttp.delete(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/vehicles/${v['id']}'),json:false);if(r.statusCode>=200&&r.statusCode<300){await _load();widget.onVehicleChanged?.call();}else if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Araç kaldırılamadı.')));}
Future<void> _transfer(Map<String,dynamic> v)async{
  final approved=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(backgroundColor:_panel,title:Text('Aracı devretmek üzeresiniz',style:TextStyle(color:_text,fontWeight:FontWeight.w900)),content:Text('Devir tamamlandığında araç ve mevcut CepQontag QR etiketi yeni sahibin hesabına aktarılır.\n\nDevir tamamlandıktan sonra bu araç 90 gün boyunca tekrar devredilemez.\n\nOluşturulan devir kodu 24 saat geçerlidir ve yalnızca bir kez kullanılabilir.',style:TextStyle(color:_muted,height:1.45)),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Devir Kodu Oluştur'))]));
  if(approved!=true)return;
  final r=await OwnerHttp.post(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/vehicles/${v['id']}/transfer'));
  Map<String,dynamic> d={};try{if(r.body.isNotEmpty)d=Map<String,dynamic>.from(jsonDecode(r.body));}catch(_){}
  if(r.statusCode==429&&d['error']=='TRANSFER_COOLDOWN'){final raw=d['nextTransferAt']?.toString();DateTime? dt;try{if(raw!=null)dt=DateTime.parse(raw).toLocal();}catch(_){}final when=dt==null?'90 günlük bekleme süresi dolduğunda':'${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year} tarihinde';if(mounted)showDialog<void>(context:context,builder:(c)=>AlertDialog(backgroundColor:_panel,title:Text('Devir koruması aktif',style:TextStyle(color:_text,fontWeight:FontWeight.w900)),content:Text('Bu araç yakın zamanda devredildi. Güvenlik nedeniyle 90 gün içinde tekrar devredilemez.\n\nAraç $when tekrar devredilebilir.',style:TextStyle(color:_muted,height:1.45)),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Tamam'))]));return;}
  if(r.statusCode<200||r.statusCode>=300){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Devir kodu oluşturulamadı.')));return;}
  if(!mounted)return;showDialog<void>(context:context,builder:(c)=>AlertDialog(backgroundColor:_panel,title:Text('Satış / Devir',style:TextStyle(color:_text)),content:Column(mainAxisSize:MainAxisSize.min,children:[Text('Yeni araç sahibi CepQontag hesabından bu kodu girsin. QR etiketi araçta kalır ve yeni sahibine geçer.',style:TextStyle(color:_muted)),const SizedBox(height:18),SelectableText('${d['transfer_code']??''}',style:const TextStyle(color:_purple,fontSize:28,fontWeight:FontWeight.w900,letterSpacing:3)),const SizedBox(height:8),Text('Kod 24 saat geçerlidir ve tek kullanımlıktır. Devir tamamlandıktan sonra araç 90 gün boyunca tekrar devredilemez.',style:TextStyle(color:_muted))]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Tamam'))]));}
Future<void> _acceptTransfer()async{final ctrl=TextEditingController();final code=await showDialog<String>(context:context,builder:(c)=>AlertDialog(backgroundColor:_panel,title:Text('Araç Devral',style:TextStyle(color:_text)),content:TextField(controller:ctrl,textCapitalization:TextCapitalization.characters,style:TextStyle(color:_text),decoration:const InputDecoration(labelText:'Devir kodu')),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(c,ctrl.text.trim()),child:const Text('Devral'))]));if(code==null||code.isEmpty)return;final r=await OwnerHttp.post(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/vehicle-transfers/accept'),body:jsonEncode({'code':code}));if(r.statusCode>=200&&r.statusCode<300){await _load();widget.onVehicleChanged?.call();if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Araç ve QR hesabına devredildi.')));}else if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(r.statusCode==410?'Devir kodunun süresi dolmuş.':'Araç devralınamadı.')));}
Future<void> _add()async{if(vehicles.length>=limit){_limit();return;}final x=await showDialog<_Form>(context:context,builder:(_)=>const _Dialog());if(x==null)return;try{final r=await OwnerHttp.post(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/vehicles'),body:jsonEncode({'plate':x.plate,'make':x.make,'model':x.model}));final d=r.body.isEmpty?{}:jsonDecode(r.body);if(r.statusCode==403){_limit();return;}if(r.statusCode==409&&d is Map&&d['error']=='PLATE_EXISTS')throw Exception('Bu plaka zaten kayıtlı.');if(r.statusCode<200||r.statusCode>=300)throw Exception('Araç eklenemedi.');await _load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}
void _limit()=>showDialog<void>(context:context,builder:(c)=>AlertDialog(backgroundColor:_panel,title:Text(premium?'Premium araç limiti doldu':'Premium ile 3 araç ekle',style:TextStyle(color:_text,fontWeight:FontWeight.w900)),content:Text(premium?'En fazla 3 araç ekleyebilirsin.':'Standart hesapta 1, Premium ile 3 araç ekleyebilirsin.',style:TextStyle(color:_muted)),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Tamam'))]));

Widget _brandHeader(){
  return Row(children:[
    Text.rich(TextSpan(
      style:TextStyle(color:_text,fontSize:28,fontWeight:FontWeight.w900,letterSpacing:-1.3),
      children:[
        const TextSpan(text:'Cep'),
        const TextSpan(text:'q',style:TextStyle(color:_purple)),
        const TextSpan(text:'ontag'),
        TextSpan(text:'®',style:TextStyle(color:_muted,fontSize:8)),
      ],
    )),
    const Spacer(),
    Stack(clipBehavior:Clip.none,children:[
      Icon(Icons.notifications_none_rounded,color:_text,size:25),
      const Positioned(right:-1,top:-2,child:CircleAvatar(radius:4,backgroundColor:Color(0xFFFF425D))),
    ]),
    const SizedBox(width:14),
    Container(
      width:42,height:42,alignment:Alignment.center,
      decoration:BoxDecoration(shape:BoxShape.circle,gradient:const LinearGradient(colors:[Color(0xFF5720C8),Color(0xFF8A4DFF)])),
      child:Text(
        OnboardingDraft.displayName.trim().isEmpty
          ?'CQ'
          :OnboardingDraft.displayName.trim().split(RegExp(r'\s+')).where((e)=>e.isNotEmpty).take(2).map((e)=>e[0].toUpperCase()).join(),
        style:const TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w900),
      ),
    ),
  ]);
}

Widget _qrBanner(){
  return Container(
    height:112,
    clipBehavior:Clip.antiAlias,
    decoration:BoxDecoration(
      gradient:const LinearGradient(begin:Alignment.centerLeft,end:Alignment.centerRight,colors:[Color(0xFF3D0DAE),Color(0xFF6E22EA),Color(0xFF9746FF)]),
      borderRadius:BorderRadius.circular(18),
      boxShadow:CepqarTheme.isLight?[BoxShadow(color:_purple.withValues(alpha:.18),blurRadius:20,offset:const Offset(0,8))]:null,
    ),
    child:Stack(children:[
      Positioned(
        left:14,bottom:-9,
        child:Transform.rotate(
          angle:-.08,
          child:Container(
            width:105,height:89,padding:const EdgeInsets.all(8),
            decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(11)),
            child:Image.asset('assets/Qrkod.png',fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Icon(Icons.qr_code_2_rounded,color:Colors.black,size:64)),
          ),
        ),
      ),
      Positioned.fill(
        child:Padding(
          padding:const EdgeInsets.fromLTRB(126,16,14,14),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('QR Etiketleriniz Hazır',style:TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.w900)),
            const SizedBox(height:5),
            const Text('Araçlarınıza özel QR etiketlerinizi oluşturun ve her zaman güvende kalın.',maxLines:2,style:TextStyle(color:Color(0xFFE7DCFF),fontSize:10.5,height:1.25)),
            const Spacer(),
            Align(
              alignment:Alignment.centerRight,
              child:OutlinedButton(
                onPressed:vehicles.isEmpty?null:()=>_qr(vehicles.first),
                style:OutlinedButton.styleFrom(
                  foregroundColor:Colors.white,
                  side:BorderSide(color:Colors.white.withValues(alpha:.55)),
                  padding:const EdgeInsets.symmetric(horizontal:13,vertical:8),
                  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),
                ),
                child:const Row(mainAxisSize:MainAxisSize.min,children:[
                  Text('Tüm Etiketlerim',style:TextStyle(fontSize:10.5,fontWeight:FontWeight.w800)),
                  SizedBox(width:3),
                  Icon(Icons.chevron_right_rounded,size:17),
                ]),
              ),
            ),
          ]),
        ),
      ),
    ]),
  );
}

Widget _bottomAction(IconData icon,String title,String subtitle,VoidCallback tap)=>Expanded(
  child:InkWell(
    onTap:tap,
    borderRadius:BorderRadius.circular(16),
    child:Container(
      height:82,
      padding:const EdgeInsets.symmetric(horizontal:12),
      decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(16),border:Border.all(color:_line)),
      child:Row(children:[
        Container(width:42,height:42,decoration:BoxDecoration(color:_purple.withValues(alpha:CepqarTheme.isLight ? 0.09 : 0.16),borderRadius:BorderRadius.circular(12)),child:Icon(icon,color:_purple,size:24)),
        const SizedBox(width:10),
        Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(title,style:TextStyle(color:_text,fontSize:13,fontWeight:FontWeight.w900)),
          const SizedBox(height:3),
          Text(subtitle,maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(color:_muted,fontSize:9.5,height:1.2)),
        ])),
        Icon(Icons.chevron_right_rounded,color:_muted,size:19),
      ]),
    ),
  ),
);

@override Widget build(BuildContext context){
  final top=MediaQuery.paddingOf(context).top;
  return Scaffold(
    backgroundColor:_bg,
    body:RefreshIndicator(
      onRefresh:_load,
      color:_purple,
      child:ListView(
        padding:EdgeInsets.fromLTRB(16,top+10,16,24),
        children:[
          _brandHeader(),
          const SizedBox(height:26),
          Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Araçlarım',style:TextStyle(color:_text,fontSize:31,fontWeight:FontWeight.w900,letterSpacing:-.6)),
              const SizedBox(height:5),
              Text('Araçlarınızı yönetin, QR etiketlerinizi\naktif edin ve tüm işlemlerinizi buradan yapın.',style:TextStyle(color:_muted,fontSize:12.5,height:1.32)),
            ])),
            const SizedBox(width:10),
            SizedBox(
              height:52,
              child:FilledButton.icon(
                onPressed:loading?null:_add,
                style:FilledButton.styleFrom(backgroundColor:_purple,foregroundColor:Colors.white,padding:const EdgeInsets.symmetric(horizontal:17),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),
                icon:const Icon(Icons.add_rounded,size:23),
                label:const Text('Yeni Araç Ekle',style:TextStyle(fontSize:12.5,fontWeight:FontWeight.w900)),
              ),
            ),
          ]),
          const SizedBox(height:22),
          if(loading)
            const Padding(padding:EdgeInsets.all(42),child:Center(child:CircularProgressIndicator(color:_purple)))
          else if(error!=null)
            Container(padding:const EdgeInsets.all(28),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),child:Text(error!,textAlign:TextAlign.center,style:TextStyle(color:_muted)))
          else if(vehicles.isEmpty)
            Container(
              padding:const EdgeInsets.all(28),
              decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(18),border:Border.all(color:_line)),
              child:Column(children:[
                const Icon(Icons.directions_car_outlined,color:_purple,size:42),
                const SizedBox(height:9),
                Text('Henüz araç eklenmedi.',style:TextStyle(color:_text,fontWeight:FontWeight.w900)),
                const SizedBox(height:4),
                Text('Yeni Araç Ekle ile ilk aracınızı kaydedin.',style:TextStyle(color:_muted,fontSize:11)),
              ]),
            )
          else
            ...vehicles.map((v)=>Padding(
              padding:const EdgeInsets.only(bottom:12),
              child:_VehicleReferenceCard(
                v:v,
                selected:'${v['id']}'==selected,
                open:()=>_open(v),
                select:()=>_select(v),
                qr:()=>_qr(v),
                transfer:()=>_transfer(v),
                remove:()=>_remove(v),
              ),
            )),
          const SizedBox(height:2),
          _qrBanner(),
          const SizedBox(height:12),
          Row(children:[
            _bottomAction(Icons.qr_code_scanner_rounded,'QR Kod Tara','Başka bir aracın etiketini tarayarak bilgi alın.',(){
              if(vehicles.isEmpty){_add();return;}
              _qr(vehicles.first);
            }),
            const SizedBox(width:9),
            _bottomAction(Icons.swap_horiz_rounded,'Araç Devri','Aracınızı kolayca devredebilirsiniz.',_acceptTransfer),
          ]),
          const SizedBox(height:18),
          const ActiveDriverCard(),
        ],
      ),
    ),
  );
}
}

class _VehicleReferenceCard extends StatelessWidget{
  const _VehicleReferenceCard({
    required this.v,
    required this.selected,
    required this.open,
    required this.select,
    required this.qr,
    required this.transfer,
    required this.remove,
  });
  final Map<String,dynamic> v;
  final bool selected;
  final VoidCallback open,select,qr,transfer,remove;

  @override Widget build(BuildContext context){
    final make='${v['make']??''}'.trim();
    final model='${v['model']??''}'.trim();
    final year='${v['year']??''}'.trim();
    final color='${v['color']??''}'.trim();
    final hasQr='${v['qr_token']??''}'.trim().isNotEmpty;
    final details=[if(year.isNotEmpty)year,if(color.isNotEmpty)color].join(' • ');
    return Container(
      height:218,
      padding:const EdgeInsets.fromLTRB(12,11,12,10),
      decoration:BoxDecoration(
        color:_panel,
        borderRadius:BorderRadius.circular(18),
        border:Border.all(color:selected?_purple.withValues(alpha:.42):_line,width:selected?1.3:1),
        boxShadow:CepqarTheme.isLight?[BoxShadow(color:Colors.black.withValues(alpha:.05),blurRadius:18,offset:const Offset(0,7))]:null,
      ),
      child:Column(children:[
        Expanded(
          child:InkWell(
            onTap:open,
            borderRadius:BorderRadius.circular(14),
            child:Row(children:[
              Expanded(
                flex:43,
                child:Stack(children:[
                  Positioned.fill(child:Align(alignment:Alignment.center,child:Image.asset('assets/Arac.png',fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Icon(Icons.directions_car_filled_rounded,color:_purple,size:74)))),
                  if(selected)Positioned(left:0,top:0,child:Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:_purple,borderRadius:BorderRadius.circular(12)),child:const Text('Ana Araç',style:TextStyle(color:Colors.white,fontSize:9.5,fontWeight:FontWeight.w900)))),
                ]),
              ),
              const SizedBox(width:10),
              Expanded(
                flex:57,
                child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Row(children:[
                    Expanded(child:Text('${v['plate']??''}',style:TextStyle(color:_text,fontSize:21,fontWeight:FontWeight.w900,letterSpacing:.2))),
                    Container(
                      padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),
                      decoration:BoxDecoration(color:hasQr?const Color(0xFFE3F9EC):const Color(0xFFFFEFE1),borderRadius:BorderRadius.circular(20)),
                      child:Row(mainAxisSize:MainAxisSize.min,children:[
                        CircleAvatar(radius:4,backgroundColor:hasQr?const Color(0xFF25D675):const Color(0xFFFF8B35)),
                        const SizedBox(width:5),
                        Text(hasQr?'Aktif':'Pasif',style:TextStyle(color:hasQr?const Color(0xFF168E4D):const Color(0xFFD76A16),fontSize:9.5,fontWeight:FontWeight.w900)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height:4),
                  Text(model.isEmpty?make:'$make $model',style:TextStyle(color:_text,fontSize:13.5,fontWeight:FontWeight.w800)),
                  if(details.isNotEmpty)...[
                    const SizedBox(height:3),
                    Text(details,style:TextStyle(color:_muted,fontSize:11.5)),
                  ],
                  const Spacer(),
                  Row(children:[
                    if(!selected)TextButton(onPressed:select,style:TextButton.styleFrom(padding:EdgeInsets.zero,minimumSize:const Size(0,28),tapTargetSize:MaterialTapTargetSize.shrinkWrap),child:const Text('Ana araç yap',style:TextStyle(fontSize:10,fontWeight:FontWeight.w800))),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded,color:_muted,size:22),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
        Divider(height:1,color:_line),
        const SizedBox(height:7),
        Row(children:[
          _VehicleAction(icon:Icons.qr_code_2_rounded,label:'QR Etiket',onTap:qr),
          _VehicleAction(icon:Icons.edit_outlined,label:'Düzenle',onTap:open),
          _VehicleAction(icon:Icons.receipt_long_outlined,label:'QR Bilgileri',onTap:qr),
          _VehicleAction(icon:Icons.bar_chart_rounded,label:'Geçmiş',onTap:open),
          _VehicleAction(
            icon:Icons.more_horiz_rounded,
            label:'Daha Fazla',
            onTap:()=>showModalBottomSheet(
              context:context,
              backgroundColor:_panel,
              shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(24))),
              builder:(c)=>SafeArea(
                child:Padding(
                  padding:const EdgeInsets.all(16),
                  child:Column(mainAxisSize:MainAxisSize.min,children:[
                    ListTile(
                      leading:const Icon(Icons.swap_horiz_rounded,color:_purple),
                      title:Text('Satış / Devir',style:TextStyle(color:_text,fontWeight:FontWeight.w800)),
                      onTap:(){Navigator.pop(c);transfer();},
                    ),
                    ListTile(
                      leading:const Icon(Icons.delete_outline_rounded,color:Colors.redAccent),
                      title:const Text('Aracı Kaldır',style:TextStyle(color:Colors.redAccent,fontWeight:FontWeight.w800)),
                      onTap:(){Navigator.pop(c);remove();},
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _VehicleAction extends StatelessWidget{
  const _VehicleAction({required this.icon,required this.label,required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override Widget build(BuildContext context)=>Expanded(
    child:InkWell(
      onTap:onTap,
      borderRadius:BorderRadius.circular(12),
      child:Padding(
        padding:const EdgeInsets.symmetric(vertical:3),
        child:Column(children:[
          Container(width:38,height:38,decoration:BoxDecoration(color:_purple.withValues(alpha:CepqarTheme.isLight ? 0.08 : 0.15),borderRadius:BorderRadius.circular(12)),child:Icon(icon,color:_purple,size:21)),
          const SizedBox(height:5),
          Text(label,maxLines:1,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,style:TextStyle(color:_muted,fontSize:9,fontWeight:FontWeight.w700)),
        ]),
      ),
    ),
  );
}
class _Form{const _Form(this.plate,this.make,this.model);final String plate,make,model;}
class _Dialog extends StatefulWidget{const _Dialog();@override State<_Dialog> createState()=>_D();}
class _D extends State<_Dialog>{
 final p=TextEditingController();
 String? make,model;
 List<String> makes=[],models=[];
 bool loading=true,loadingModels=false;
 int _modelRequest=0;

 @override void initState(){
  super.initState();
  VehicleApi.getMakes().then((x){
   if(mounted)setState((){makes=x.toSet().toList();loading=false;});
  });
 }

 Future<void> _changeMake(String? value)async{
  if(value==null)return;
  final request=++_modelRequest;
  setState((){
   make=value;
   model=null;
   models=[];
   loadingModels=true;
  });
  final result=await VehicleApi.getModels(value);
  if(!mounted||request!=_modelRequest||make!=value)return;
  final unique=<String,String>{};
  for(final item in result){
   final clean=item.trim();
   if(clean.isNotEmpty)unique.putIfAbsent(clean.toLowerCase(),()=>clean);
  }
  setState((){
   models=unique.values.toList();
   model=null;
   loadingModels=false;
  });
 }

 @override Widget build(BuildContext c){
  final safeModel=model!=null&&models.where((x)=>x==model).length==1?model:null;
  return AlertDialog(
   backgroundColor:_panel,
   title:Text('Yeni Araç',style:TextStyle(color:_text)),
   content:SingleChildScrollView(
    child:Column(mainAxisSize:MainAxisSize.min,children:[
     TextField(controller:p,style:TextStyle(color:_text),decoration:const InputDecoration(labelText:'Plaka')),
     const SizedBox(height:10),
     if(loading)
      const Padding(padding:EdgeInsets.all(12),child:CircularProgressIndicator())
     else
      DropdownButtonFormField<String>(
       value:make!=null&&makes.where((x)=>x==make).length==1?make:null,
       isExpanded:true,
       dropdownColor:_panel,
       items:makes.map((x)=>DropdownMenuItem(value:x,child:Text(x,overflow:TextOverflow.ellipsis))).toList(),
       onChanged:_changeMake,
       decoration:const InputDecoration(labelText:'Marka'),
      ),
     const SizedBox(height:10),
     if(loadingModels)
      const Padding(padding:EdgeInsets.symmetric(vertical:12),child:LinearProgressIndicator())
     else
      DropdownButtonFormField<String>(
       key:ValueKey('model-${make??'none'}'),
       value:safeModel,
       isExpanded:true,
       dropdownColor:_panel,
       items:models.map((x)=>DropdownMenuItem(value:x,child:Text(x,overflow:TextOverflow.ellipsis))).toList(),
       onChanged:models.isEmpty?null:(x)=>setState(()=>model=x),
       decoration:InputDecoration(labelText:'Model',hintText:make==null?'Önce marka seç':'Model seç'),
      ),
    ]),
   ),
   actions:[
    FilledButton(
     onPressed:(){
      if(p.text.trim().isNotEmpty&&make!=null)Navigator.pop(c,_Form(p.text.trim().toUpperCase(),make!,safeModel??''));
     },
     child:const Text('Aracı Ekle'),
    ),
   ],
  );
 }
}
