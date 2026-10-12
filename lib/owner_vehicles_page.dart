import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_backend.dart';
import 'qr_backend.dart';
import 'qr_activation.dart';
import 'vehicle_api.dart';
import 'vehicle_center_page.dart';
import 'cepqar_theme.dart';
import 'owner_auth.dart';
import 'active_driver_card.dart';
import 'owner_new_vehicle_page.dart';
import 'vehicle_kind.dart';
import 'owner_reference_design.dart';
import 'maintenance_page.dart';

const _purple=Color(0xFF8B5CFF),_gold=Color(0xFFFFC857),_green=Color(0xFF38D178);
Color get _bg=>CepqarTheme.bg; Color get _panel=>CepqarTheme.panel; Color get _line=>CepqarTheme.line; Color get _muted=>CepqarTheme.muted; Color get _text=>CepqarTheme.text;
class OwnerVehiclesPage extends StatefulWidget{const OwnerVehiclesPage({super.key,this.onVehicleChanged,this.onNotifications,this.onSettings});final VoidCallback? onVehicleChanged,onNotifications,onSettings;@override State<OwnerVehiclesPage> createState()=>_S();}
class _S extends State<OwnerVehiclesPage>{List<Map<String,dynamic>> vehicles=[];bool loading=true,premium=false;int limit=1;String? error;Timer? _logoRetryTimer;int _logoRetryAttempts=0;String get selected=>QrDraft.vehicleId.trim().isNotEmpty?QrDraft.vehicleId.trim():OnboardingDraft.vehicleId.trim();@override void initState(){super.initState();_load();}
@override void dispose(){_logoRetryTimer?.cancel();super.dispose();}
void _scheduleMotorcycleLogoRefresh(List<Map<String,dynamic>> list){
  final missing=list.any((vehicle){
    if(!VehicleKind.isMotorcycle(vehicle['vehicle_type']))return false;
    final raw=vehicle['brandLogo'];
    return raw is! Map || raw['available']!=true;
  });
  if(!missing||_logoRetryAttempts>=2)return;
  _logoRetryTimer?.cancel();
  final seconds=_logoRetryAttempts==0?4:9;
  _logoRetryAttempts++;
  _logoRetryTimer=Timer(Duration(seconds:seconds),(){
    if(mounted)_load();
  });
}
Future<void> _load()async{final owner=OnboardingDraft.userId.trim();if(owner.isEmpty){setState((){loading=false;error='Araç sahibi oturumu bulunamadı.';});return;}try{final r=await OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/vehicles'),json:false).timeout(const Duration(seconds:15));final d=jsonDecode(r.body);if(r.statusCode<200||r.statusCode>=300||d is! Map)throw Exception();final list=d['vehicles'];final next=list is List?list.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList():<Map<String,dynamic>>[];if(next.isNotEmpty&&!next.any((v)=>'${v['id']}'==selected))_select(next.first,notify:false);if(!mounted)return;setState((){vehicles=next;premium=d['premium']==true;limit=int.tryParse('${d['limit']}')??1;loading=false;error=null;});_scheduleMotorcycleLogoRefresh(next);}catch(_){if(mounted)setState((){loading=false;error='Araçlar yüklenemedi.';});}}
void _select(Map<String,dynamic> v,{bool notify=true}){final id='${v['id']??''}';QrDraft.vehicleId=id;OnboardingDraft.vehicleId=id;QrDraft.plate='${v['plate']??''}';QrDraft.make='${v['make']??''}';QrDraft.model='${v['model']??''}';QrDraft.vehicleType=VehicleKind.normalize(v['vehicle_type']);QrDraft.token='${v['qr_token']??''}'.trim();QrDraft.scanSecret='${v['qr_scan_secret']??''}'.trim();_persistSelection();if(notify){setState((){});widget.onVehicleChanged?.call();}}
Future<void> _persistSelection()async{final p=await SharedPreferences.getInstance();await p.setString('owner_vehicle_id',QrDraft.vehicleId);await p.setString('owner_plate',QrDraft.plate);await p.setString('owner_make',QrDraft.make);await p.setString('owner_model',QrDraft.model);await p.setString('owner_vehicle_type',QrDraft.vehicleType);await p.setString('owner_qr_token',QrDraft.token);await p.setString('owner_qr_scan_secret',QrDraft.scanSecret);}
Future<void> _qr(Map<String,dynamic> v)async{_select(v);if('${v['qr_token']??''}'.trim().isNotEmpty){_showQr(v);return;}await Navigator.push(context,MaterialPageRoute(builder:(c)=>RealQrScanPage(onBack:()=>Navigator.pop(c),onFound:(){Navigator.pop(c);_activate(v);})));}
Future<void> _activate(Map<String,dynamic> v)async{try{await QrBackend.activate(token:QrDraft.token,vehicleId:'${v['id']}',plate:'${v['plate']}',make:'${v['make']}',model:'${v['model']??''}');if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('${v['plate']} için QR aktif edildi.')));await _load();widget.onVehicleChanged?.call();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}
void _showQr(Map<String,dynamic> v){final t='${v['qr_token']??''}'.trim(),secret='${v['qr_scan_secret']??''}'.trim(),u='https://queensho.github.io/HeyCar/?tag=${Uri.encodeComponent(t)}${secret.isEmpty?'':'&s=${Uri.encodeComponent(secret)}'}';showModalBottomSheet(context:context,backgroundColor:_panel,builder:(c)=>Padding(padding:const EdgeInsets.all(22),child:Column(mainAxisSize:MainAxisSize.min,children:[Text('${v['plate']} QR',style:TextStyle(color:_text,fontSize:22,fontWeight:FontWeight.w900)),const SizedBox(height:14),Container(width:220,height:220,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20)),child:QrImageView(data:u,version:QrVersions.auto,backgroundColor:Colors.white,eyeStyle:const QrEyeStyle(eyeShape:QrEyeShape.square,color:Colors.black),dataModuleStyle:const QrDataModuleStyle(dataModuleShape:QrDataModuleShape.square,color:Colors.black))),const SizedBox(height:10),Text(t,style:TextStyle(color:_muted,fontWeight:FontWeight.w700))])));}
void _open(Map<String,dynamic> v){final wasPrimary='${v['id']??''}'==selected;_select(v);final make='${v['make']??''}',model='${v['model']??''}';Navigator.push(context,MaterialPageRoute(builder:(_)=>VehicleCenterPage(plate:'${v['plate']??''}',title:model.trim().isEmpty?make:'$make $model',initialVehicle:Map<String,dynamic>.from(v),isPrimary:wasPrimary))).then((_){widget.onVehicleChanged?.call();_load();});}
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
Future<void> _add()async{if(vehicles.length>=limit){_limit();return;}final x=await Navigator.push<OwnerNewVehicleDraft>(context,MaterialPageRoute(builder:(_)=>const OwnerNewVehiclePage()));if(x==null||!mounted)return;try{final r=await OwnerHttp.post(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/vehicles'),body:jsonEncode({'plate':x.plate,'make':x.make,'model':x.model,'color':x.color,'year':x.year,'vehicleType':x.vehicleType}));final d=r.body.isEmpty?{}:jsonDecode(r.body);if(r.statusCode==403){_limit();return;}if(r.statusCode==409&&d is Map&&d['error']=='PLATE_EXISTS')throw Exception('Bu plaka zaten kayıtlı.');if(r.statusCode<200||r.statusCode>=300)throw Exception('Araç eklenemedi.');await _load();widget.onVehicleChanged?.call();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}
void _limit()=>showDialog<void>(context:context,builder:(c)=>AlertDialog(backgroundColor:_panel,title:Text(premium?'Premium araç limiti doldu':'Premium ile 3 araç ekle',style:TextStyle(color:_text,fontWeight:FontWeight.w900)),content:Text(premium?'En fazla 3 araç ekleyebilirsin.':'Standart hesapta 1, Premium ile 3 araç ekleyebilirsin.',style:TextStyle(color:_muted)),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Tamam'))]));

Widget _brandHeader(){
  return SizedBox(
    height:42,
    child:Row(children:[
      Image.asset(
        CepqarTheme.isLight ? 'assets/file_00000000b130820abb8d411e67ab0d25.png' : 'assets/Logoyeni.png',
        key:ValueKey(CepqarTheme.isLight),
        height:31,
        fit:BoxFit.contain,
        alignment:Alignment.centerLeft,
      ),
      const Spacer(),
      Container(
        width:36,height:36,
        decoration:BoxDecoration(
          shape:BoxShape.circle,
          color:_panel,
          border:Border.all(color:_line),
        ),
        child:Stack(clipBehavior:Clip.none,alignment:Alignment.center,children:[
          Icon(Icons.notifications_rounded,color:_text,size:19),
          const Positioned(right:2,top:1,child:CircleAvatar(radius:3.5,backgroundColor:Color(0xFF8B5CFF))),
        ]),
      ),
      const SizedBox(width:8),
      Container(
        width:36,height:36,alignment:Alignment.center,
        decoration:BoxDecoration(
          shape:BoxShape.circle,
          gradient:const LinearGradient(colors:[Color(0xFF4B1EC9),Color(0xFF8B5CFF)]),
          boxShadow:CepqarTheme.isLight?null:[BoxShadow(color:_purple.withValues(alpha:.28),blurRadius:12)],
        ),
        child:Text(
          OnboardingDraft.displayName.trim().isEmpty
            ?'CQ'
            :OnboardingDraft.displayName.trim().split(RegExp(r'\s+')).where((e)=>e.isNotEmpty).take(2).map((e)=>e[0].toUpperCase()).join(),
          style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w900),
        ),
      ),
    ]),
  );
}

Widget _qrBanner(){
  return Container(
    height:78,
    clipBehavior:Clip.antiAlias,
    decoration:BoxDecoration(
      gradient:const LinearGradient(begin:Alignment.centerLeft,end:Alignment.centerRight,colors:[Color(0xFF3D0DAE),Color(0xFF6E22EA),Color(0xFF9746FF)]),
      borderRadius:BorderRadius.circular(16),
      boxShadow:CepqarTheme.isLight?[BoxShadow(color:_purple.withValues(alpha:.18),blurRadius:20,offset:const Offset(0,8))]:null,
    ),
    child:Stack(children:[
      Positioned(
        left:12,bottom:-8,
        child:Transform.rotate(
          angle:-.08,
          child:Container(
            width:74,height:65,padding:const EdgeInsets.all(6),
            decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(11)),
            child:Image.asset('assets/Qrkod.png',fit:BoxFit.contain,errorBuilder:(_,__,___)=>const Icon(Icons.qr_code_2_rounded,color:Colors.black,size:64)),
          ),
        ),
      ),
      Positioned.fill(
        child:Padding(
          padding:const EdgeInsets.fromLTRB(94,9,11,8),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('QR Etiketleriniz Hazır',style:TextStyle(color:Colors.white,fontSize:14,fontWeight:FontWeight.w900)),
            const SizedBox(height:5),
            const Text('Araçlarınıza özel QR etiketlerinizi oluşturun ve her zaman güvende kalın.',maxLines:2,style:TextStyle(color:Color(0xFFE7DCFF),fontSize:CepqarTheme.caption,height:1.18)),
            const Spacer(),
            Align(
              alignment:Alignment.centerRight,
              child:OutlinedButton(
                onPressed:vehicles.isEmpty?null:()=>_qr(vehicles.first),
                style:OutlinedButton.styleFrom(
                  foregroundColor:Colors.white,
                  side:BorderSide(color:Colors.white.withValues(alpha:.55)),
                  padding:const EdgeInsets.symmetric(horizontal:11,vertical:6),
                  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),
                ),
                child:const Row(mainAxisSize:MainAxisSize.min,children:[
                  Text('Tüm Etiketlerim',style:TextStyle(fontSize:CepqarTheme.caption,fontWeight:FontWeight.w800)),
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
      height:58,
      padding:const EdgeInsets.symmetric(horizontal:9),
      decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(16),border:Border.all(color:_line)),
      child:Row(children:[
        Container(width:32,height:32,decoration:BoxDecoration(color:_purple.withValues(alpha:CepqarTheme.isLight ? 0.09 : 0.16),borderRadius:BorderRadius.circular(10)),child:Icon(icon,color:_purple,size:20)),
        const SizedBox(width:10),
        Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(title,style:TextStyle(color:_text,fontSize:CepqarTheme.cardTitle,fontWeight:FontWeight.w900)),
          const SizedBox(height:3),
          Text(subtitle,maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(color:_muted,fontSize:CepqarTheme.bodySmall,height:1.2)),
        ])),
        Icon(Icons.chevron_right_rounded,color:_muted,size:19),
      ]),
    ),
  ),
);

@override Widget build(BuildContext context){
  final top=MediaQuery.paddingOf(context).top;
  return Scaffold(
    backgroundColor:OwnerReference.background,
    body:Stack(children:[
      Positioned(
        left:0,right:0,top:0,
        child:SizedBox(
          height:190,
          child:CustomPaint(painter:_VehiclesHeaderWavePainter(light:CepqarTheme.isLight)),
        ),
      ),
      RefreshIndicator(
        onRefresh:_load,
        color:_purple,
        child:ListView(
          padding:EdgeInsets.fromLTRB(16,top+7,16,28),
          children:[
            OwnerReferenceHeader(
              onNotifications:widget.onNotifications??(){},
              onSettings:widget.onSettings??(){},
              unread:false,
            ),
            const SizedBox(height:13),
            Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Expanded(child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Text('Araçlarım',style:TextStyle(color:_text,
                    fontSize:26,fontWeight:FontWeight.w900)),
                  const SizedBox(height:7),
                  Text('Araçlarınızı yönetin, QR ve sürücü ayarlarınızı düzenleyin.',
                    style:TextStyle(color:_muted,fontSize:12.5,height:1.35)),
                ],
              )),
              const SizedBox(width:10),
              SizedBox(width:151,child:Column(children:[
                SizedBox(width:151,height:41,child:FilledButton.icon(
                  onPressed:loading?null:_add,
                  icon:const Icon(Icons.add_rounded,size:20),
                  label:const FittedBox(child:Text('Yeni araç ekle')),
                  style:FilledButton.styleFrom(backgroundColor:OwnerReference.purple,
                    padding:const EdgeInsets.symmetric(horizontal:7),
                    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15))),
                )),
                const SizedBox(height:7),
                SizedBox(width:151,height:37,child:OutlinedButton.icon(
                  onPressed:loading?null:_acceptTransfer,
                  icon:const Icon(Icons.swap_horiz_rounded,size:18),
                  label:const FittedBox(child:Text('Araç devir al')),
                  style:OutlinedButton.styleFrom(
                    foregroundColor:OwnerReference.deep,
                    backgroundColor:OwnerReference.lilac,
                    side:BorderSide.none,padding:const EdgeInsets.symmetric(horizontal:7),
                    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),
                )),
              ])),
            ]),
            const SizedBox(height:7),
            if(loading)
              const Padding(padding:EdgeInsets.all(28),child:Center(child:CircularProgressIndicator(color:_purple)))
            else if(error!=null)
              Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(15),border:Border.all(color:_line)),child:Text(error!,textAlign:TextAlign.center,style:TextStyle(color:_muted)))
            else if(vehicles.isEmpty)
              Container(
                padding:const EdgeInsets.all(18),
                decoration:BoxDecoration(color:_panel,borderRadius:BorderRadius.circular(15),border:Border.all(color:_line)),
                child:Column(children:[
                  const Icon(Icons.two_wheeler_rounded,color:_purple,size:32),
                  const SizedBox(height:6),
                  Text('Henüz araç eklenmedi.',style:TextStyle(color:_text,fontWeight:FontWeight.w900)),
                  const SizedBox(height:3),
                  Text('Yeni Araç Ekle ile ilk aracınızı kaydedin.',style:TextStyle(color:_muted,fontSize:CepqarTheme.bodySmall)),
                ]),
              )
            else
              ...vehicles.map((v)=>Padding(
                padding:const EdgeInsets.only(bottom:8),
                child:_VehicleReferenceCard(
                  v:v,
                  selected:'${v['id']}'==selected,
                  open:()=>_open(v),
                  select:()=>_select(v),
                  qr:()=>_qr(v),
                  transfer:()=>_transfer(v),
                  remove:()=>_remove(v),
                  maintenance:()=>Navigator.push(context,MaterialPageRoute(
                    builder:(_)=>MaintenancePage(plate:'${v['plate']??''}',
                      title:'${v['make']??''} ${v['model']??''}'.trim()))),
                ),
              )),
            if(!loading&&error==null&&vehicles.isNotEmpty)...[
              const SizedBox(height:4),
              const ActiveDriverCard(),
            ],
            const SizedBox(height:12),
          ],
        ),
      ),
    ]),
  );
}
}

class _VehiclesHeaderWavePainter extends CustomPainter{
  const _VehiclesHeaderWavePainter({required this.light});
  final bool light;
  @override
  void paint(Canvas canvas,Size size){
    final rect=Offset.zero&size;
    canvas.drawRect(
      rect,
      Paint()..shader=RadialGradient(
        center:const Alignment(.75,-.35),
        radius:1.1,
        colors:[
          const Color(0xFF8D68FF).withValues(alpha:light ? .15 : .12),
          const Color(0xFF713BFF).withValues(alpha:light ? .04 : .05),
          Colors.transparent,
        ],
      ).createShader(rect),
    );
    final p=Path()
      ..moveTo(size.width*.46,0)
      ..cubicTo(size.width*.61,size.height*.08,size.width*.70,size.height*.22,size.width*.82,size.height*.16)
      ..cubicTo(size.width*.91,size.height*.12,size.width*.97,size.height*.05,size.width*1.05,size.height*.09)
      ..lineTo(size.width*1.05,size.height*.34)
      ..cubicTo(size.width*.94,size.height*.30,size.width*.86,size.height*.39,size.width*.76,size.height*.36)
      ..cubicTo(size.width*.63,size.height*.32,size.width*.57,size.height*.20,size.width*.46,size.height*.24)
      ..close();
    canvas.drawPath(
      p,
      Paint()..shader=LinearGradient(
        colors:[
          const Color(0xFF713BFF).withValues(alpha:0),
          const Color(0xFF8C64FF).withValues(alpha:light ? .06 : .08),
          const Color(0xFFB29CFF).withValues(alpha:light ? .12 : .13),
        ],
      ).createShader(rect),
    );
  }
  @override
  bool shouldRepaint(covariant _VehiclesHeaderWavePainter oldDelegate)=>oldDelegate.light!=light;
}

class _VehicleReferenceCard extends StatelessWidget{
  const _VehicleReferenceCard({
    required this.v,required this.selected,required this.open,
    required this.select,required this.qr,required this.transfer,
    required this.remove,required this.maintenance,
  });
  final Map<String,dynamic> v;
  final bool selected;
  final VoidCallback open,select,qr,transfer,remove,maintenance;

  @override Widget build(BuildContext context){
    final make='${v['make']??''}'.trim();
    final model='${v['model']??''}'.trim();
    final plate='${v['plate']??''}'.trim();
    final hasQr='${v['qr_token']??''}'.trim().isNotEmpty;
    final valeStatus='${v['valet_status']??''}'.trim();
    final light=CepqarTheme.isLight;
    final primary=OwnerReference.purple;
    final muted=OwnerReference.subtitle;
    return Container(
      key:ValueKey('reference-vehicle-$plate'),
      constraints:const BoxConstraints(minHeight:246),
      margin:const EdgeInsets.only(bottom:5),
      clipBehavior:Clip.antiAlias,
      decoration:OwnerReference.card(radius:24,highlight:selected),
      child:Column(children:[
        InkWell(
          onTap:open,
          child:Container(
            height:139,
            padding:const EdgeInsets.fromLTRB(14,10,12,7),
            decoration:BoxDecoration(
              gradient:LinearGradient(
                begin:Alignment.centerLeft,end:Alignment.topRight,
                colors:light?[Colors.white,const Color(0xFFF1E9FF),const Color(0xFFBE8DFF)]:
                  [OwnerReference.deep,const Color(0xFF422091),const Color(0xFF6E3DCE)],
              ),
            ),
            child:Column(children:[
              Expanded(child:Row(children:[
                SizedBox(width:70,child:Center(child:_VehicleBrandLogo(
                  vehicle:v,make:make))),
                const SizedBox(width:12),
                Expanded(child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  mainAxisAlignment:MainAxisAlignment.center,children:[
                    Text(make,maxLines:1,overflow:TextOverflow.ellipsis,
                      style:TextStyle(color:OwnerReference.foreground,
                        fontSize:15,fontWeight:FontWeight.w600)),
                    const SizedBox(height:2),
                    Text(model.isEmpty?make:model,maxLines:2,
                      overflow:TextOverflow.ellipsis,
                      style:TextStyle(color:OwnerReference.foreground,
                        fontSize:21,fontWeight:FontWeight.w900)),
                    const SizedBox(height:4),
                    Text(plate,maxLines:1,overflow:TextOverflow.ellipsis,
                      style:TextStyle(color:OwnerReference.foreground,
                        fontSize:12.5,fontWeight:FontWeight.w800)),
                  ],
                )),
                Icon(Icons.chevron_right_rounded,size:27,color:primary),
              ])),
              Row(children:[
                if(selected)Container(
                  padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),
                  decoration:BoxDecoration(color:primary,
                    borderRadius:BorderRadius.circular(17)),
                  child:const Text('Ana Araç',style:TextStyle(
                    fontSize:10,color:Colors.white,fontWeight:FontWeight.w800)),
                )else TextButton(
                  onPressed:select,
                  child:const Text('Ana araç yap',
                    style:TextStyle(fontSize:10.5,fontWeight:FontWeight.w800)),
                ),
                const SizedBox(width:7),
                _badge(hasQr?'QR Aktif':'QR Pasif',hasQr?primary:muted),
                if(valeStatus.isNotEmpty)...[
                  const SizedBox(width:6),
                  _badge('Vale: $valeStatus',muted),
                ],
                const Spacer(),
                _badge(hasQr?'Aktif':'Pasif',
                  hasQr?OwnerReference.success:const Color(0xFFE69B3A)),
              ]),
            ]),
          ),
        ),
        Padding(
          padding:const EdgeInsets.fromLTRB(10,9,10,10),
          child:Row(children:[
            _VehicleAction(icon:Icons.qr_code_2_rounded,label:'QR Yönetimi',onTap:qr),
            const SizedBox(width:6),
            _VehicleAction(icon:Icons.groups_rounded,label:'Sürücüler',onTap:open),
            const SizedBox(width:6),
            _VehicleAction(icon:Icons.build_rounded,label:'Bakım Geçmişi',onTap:maintenance),
            const SizedBox(width:6),
            _VehicleAction(icon:Icons.article_outlined,label:'Detaylar',onTap:open),
          ]),
        ),
      ]),
    );
  }

  Widget _badge(String label,Color accent)=>Container(
    constraints:const BoxConstraints(maxWidth:104),
    padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
    decoration:BoxDecoration(color:accent.withValues(alpha:.12),
      borderRadius:BorderRadius.circular(12)),
    child:Text(label,maxLines:1,overflow:TextOverflow.ellipsis,
      style:TextStyle(color:accent,fontWeight:FontWeight.w800,fontSize:9)),
  );
}

class _VehicleBrandLogo extends StatelessWidget{
  const _VehicleBrandLogo({required this.vehicle,required this.make});
  final Map<String,dynamic> vehicle;
  final String make;
  @override Widget build(BuildContext context){
    final raw=vehicle['brandLogo'];
    final logo=raw is Map?Map<String,dynamic>.from(raw):const <String,dynamic>{};
    // Use the same API host used to load the vehicles.
    final imagePath=(logo['path']??'').toString().trim();
    final safeImagePath=imagePath.startsWith('/uploads/vehicle-brands/')
        && !imagePath.contains('..')
        && !imagePath.contains('?')
        && !imagePath.contains('#');
    final apiBase=OnboardingBackend.baseUrl.replaceFirst(RegExp(r'/$'),'');
    final url=safeImagePath?apiBase+imagePath:(logo['url']??'').toString().trim();
    final letter=make.trim().isEmpty?'?':make.trim().characters.first.toUpperCase();
    Widget fallback()=>Container(
      width:72,height:72,alignment:Alignment.center,
      decoration:BoxDecoration(color:_purple.withValues(alpha:CepqarTheme.isLight ? .08 : .16),shape:BoxShape.circle,border:Border.all(color:_purple.withValues(alpha:.16))),
      child:VehicleKind.isMotorcycle(vehicle['vehicle_type'])
        ?const Icon(Icons.two_wheeler_rounded,color:_purple,size:36)
        :Text(letter,style:const TextStyle(color:_purple,fontSize:28,fontWeight:FontWeight.w900)),
    );
    if(!url.toLowerCase().startsWith('https://'))return fallback();
    return SizedBox(
      width:72,
      height:72,
      child:Image.network(
        url,
        key:ValueKey<String>(url),
        fit:BoxFit.contain,
        gaplessPlayback:true,
        filterQuality:FilterQuality.high,
        frameBuilder:(context,child,frame,wasSynchronouslyLoaded){
          if(wasSynchronouslyLoaded||frame!=null)return child;
          return fallback();
        },
        errorBuilder:(_,__,___)=>fallback(),
      ),
    );
  }
}
class _VehicleAction extends StatelessWidget{
  const _VehicleAction({required this.icon,required this.label,required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override Widget build(BuildContext context){
    final dark=!CepqarTheme.isLight;
    return Expanded(
      child:InkWell(
        onTap:onTap,
        borderRadius:BorderRadius.circular(8),
        child:Padding(
          padding:const EdgeInsets.symmetric(vertical:1),
          child:Column(children:[
            Container(
              width:39,height:39,
              decoration:BoxDecoration(
                color:dark?const Color(0xFF17132E):_purple.withValues(alpha:.07),
                borderRadius:BorderRadius.circular(13),
                border:dark?Border.all(color:_purple.withValues(alpha:.35)):null,
              ),
              child:Icon(icon,color:dark?const Color(0xFFA06DFF):_purple,size:22),
            ),
            const SizedBox(height:2),
            Text(label,maxLines:2,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,style:TextStyle(color:_muted,fontSize:10.4,fontWeight:FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
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
