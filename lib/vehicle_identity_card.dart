import 'package:flutter/material.dart';
import 'cepqar_theme.dart';
import 'vehicle_kind.dart';
import 'owner_vehicle_brand_mark.dart';

class VehicleIdentityCard extends StatelessWidget {
  const VehicleIdentityCard({
    super.key,
    required this.vehicle,
    required this.currentKm,
    required this.isPrimary,
  });

  final Map<String,dynamic> vehicle;
  final int currentKm;
  final bool isPrimary;

  String _s(String key)=>'${vehicle[key]??''}'.trim();
  bool get _qrActive=>_s('qr_status')=='active'&&_s('qr_token').isNotEmpty;
  String get _make=>_s('make');
  String get _model=>_s('model');
  bool get _motorcycle=>VehicleKind.isMotorcycle(vehicle['vehicle_type']);
  String get _logoUrl {
    final raw=vehicle['brandLogo'];
    if(raw is Map)return '${raw['url']??''}'.trim();
    return '';
  }
  int get _driverCount=>int.tryParse('${vehicle['driver_count']??0}')??0;
  bool get _hasActiveDriver=>vehicle['has_active_driver']==true||'${vehicle['has_active_driver']}'=='true';
  bool get _active {
    final status=_s('status').toLowerCase();
    if(status.isNotEmpty)return const {'active','aktif','enabled'}.contains(status);
    return _qrActive;
  }
  String _number(int value)=>value.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'),(m)=>'${m[1]}.');

  Widget _logo({double size=68,double opacity=1,Color color=Colors.white}) =>
    Opacity(opacity:opacity,child:SizedBox(width:size,height:size,child:ColorFiltered(
      colorFilter:ColorFilter.mode(color,BlendMode.srcIn),
      child:OwnerVehicleBrandMark(make:_make,isMotorcycle:_motorcycle,backendLogoUrl:_logoUrl))));

  String _scanLabel(){
    final raw=_s('last_scan_at');
    final dt=DateTime.tryParse(raw)?.toLocal();
    if(dt==null)return 'Henüz yok';
    final now=DateTime.now();
    final today=DateTime(now.year,now.month,now.day);
    final day=DateTime(dt.year,dt.month,dt.day);
    final diff=today.difference(day).inDays;
    final time='${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    if(diff==0)return 'Bugün $time';
    if(diff==1)return 'Dün $time';
    const months=['Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'];
    return '${dt.day} ${months[dt.month-1]} $time';
  }

  Widget _chip(IconData icon,String text)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),
    decoration:BoxDecoration(color:Colors.white.withValues(alpha:.10),borderRadius:BorderRadius.circular(18),border:Border.all(color:Colors.white.withValues(alpha:.08))),
    child:Row(mainAxisSize:MainAxisSize.min,children:[
      Icon(icon,color:Colors.white,size:14),const SizedBox(width:5),
      Flexible(child:Text(text,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w700))),
    ]),
  );

  Widget _metric(IconData icon,String title,String subtitle)=>Expanded(
    child:Padding(
      padding:const EdgeInsets.symmetric(horizontal:5,vertical:7),
      child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        Icon(icon,color:Colors.white,size:19),
        const SizedBox(width:5),
        Flexible(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:10.5,fontWeight:FontWeight.w900)),
          const SizedBox(height:1),
          Text(subtitle,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Color(0xFFAEB8D4),fontSize:8.8,fontWeight:FontWeight.w600)),
        ])),
      ]),
    ),
  );

  @override Widget build(BuildContext context){
    final plate=_s('plate');
    final title=[_make,_model].where((e)=>e.isNotEmpty).join(' ');
    final type=_s('vehicle_type').isNotEmpty?_s('vehicle_type'):_s('type');
    final typeLabel=VehicleKind.label(type);
    final fuel=_s('fuel_type').isNotEmpty?_s('fuel_type'):_s('fuel');
    final statusColor=_active?const Color(0xFF20E979):const Color(0xFFFFA23A);
    final driverTitle='$_driverCount Sürücü';
    final driverSubtitle=_hasActiveDriver?'Aktif sürücü':(_driverCount>0?'Aktif sürücü yok':'Sürücü yok');

    return LayoutBuilder(builder:(context,c){
      final compact=c.maxWidth<355;
      final logoSize=compact?50.0:58.0;
      return Container(
        clipBehavior:Clip.antiAlias,
        decoration:BoxDecoration(
          borderRadius:BorderRadius.circular(20),
          border:Border.all(color:const Color(0xFF7E49FF).withValues(alpha:.65)),
          color:const Color(0xFF4514C5),
          boxShadow:[BoxShadow(color:const Color(0xFF6E32FF).withValues(alpha:.18),blurRadius:20,offset:const Offset(0,8))],
        ),
        child:Column(children:[
          SizedBox(
            height:compact?160:174,
            child:Stack(children:[
              Positioned.fill(child:CustomPaint(painter:_VehicleLimeArc())),
              Positioned(right:compact?8:18,bottom:8,child:_logo(size:compact?88:112,opacity:.68,color:const Color(0xFF681FFF))),
              Positioned(right:12,top:12,child:Container(
                padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
                decoration:BoxDecoration(color:const Color(0xFF10152D),borderRadius:BorderRadius.circular(20)),
                child:Row(mainAxisSize:MainAxisSize.min,children:[
                  CircleAvatar(radius:4,backgroundColor:statusColor),
                  const SizedBox(width:6),
                  Text(_active?'Aktif':'Pasif',style:TextStyle(color:statusColor,fontSize:12,fontWeight:FontWeight.w900)),
                ]),
              )),
              Positioned(left:12,top:20,bottom:12,width:compact?66:82,child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                _logo(size:compact?48:63),
                const SizedBox(height:5),
                Text(_make,maxLines:2,textAlign:TextAlign.center,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w700)),
              ])),
              Positioned(left:compact?88:104,top:32,right:compact?95:115,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(plate,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:Colors.white,fontSize:compact?18:23,fontWeight:FontWeight.w900)),
                const SizedBox(height:7),
                Text(_make,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:15,fontWeight:FontWeight.w800)),
                const SizedBox(height:5),
                Text(currentKm>0?'${_number(currentKm)} km':'Km bilgisi yok',
                  maxLines:1,style:const TextStyle(color:Color(0xFFE0D6FF),fontSize:13)),
              ])),
            ]),
          ),
          Container(
            decoration:BoxDecoration(color:const Color(0xFF361092),border:Border(top:BorderSide(color:Colors.white.withValues(alpha:.09)))),
            child:Row(children:[
              _metric(Icons.qr_code_2_rounded,_qrActive?'QR Aktif':'QR Pasif',_qrActive?'Etiket bağlı':'Etiket bağlı değil'),
              Container(width:1,height:32,color:const Color(0xFF8A64FF).withValues(alpha:.38)),
              _metric(Icons.group_rounded,driverTitle,driverSubtitle),
              Container(width:1,height:32,color:const Color(0xFF8A64FF).withValues(alpha:.38)),
              _metric(Icons.schedule_rounded,'Son Tarama',_scanLabel()),
            ]),
          ),
        ]),
      );
    });
  }
}

class _VehicleLimeArc extends CustomPainter {
  @override
  void paint(Canvas canvas,Size size) {
    final paint=Paint()..color=const Color(0xFFB9FF45);
    final path=Path()
      ..moveTo(size.width*.80,0)
      ..cubicTo(size.width*.62,size.height*.30,size.width*.59,size.height*.64,size.width*.59,size.height)
      ..lineTo(size.width,size.height)
      ..lineTo(size.width,0)..close();
    canvas.drawPath(path,paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}
