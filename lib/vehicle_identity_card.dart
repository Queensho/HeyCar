import 'package:flutter/material.dart';
import 'cepqar_theme.dart';

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

  Widget _logo({double size=68,double opacity=1}) {
    final url=_logoUrl;
    final letter=_make.isEmpty?'?':_make.characters.first.toUpperCase();
    final fallback=Container(
      width:size,height:size,alignment:Alignment.center,
      decoration:BoxDecoration(color:Colors.white.withValues(alpha:.08),shape:BoxShape.circle),
      child:Text(letter,style:TextStyle(color:Colors.white.withValues(alpha:opacity),fontSize:size*.4,fontWeight:FontWeight.w900)),
    );
    if(!url.toLowerCase().startsWith('https://'))return fallback;
    return Opacity(
      opacity:opacity,
      child:SizedBox(
        width:size,height:size,
        child:Image.network(
          url,key:ValueKey('vehicle-identity-$url-$opacity'),fit:BoxFit.contain,gaplessPlayback:true,
          filterQuality:FilterQuality.high,
          frameBuilder:(context,child,frame,sync)=>sync||frame!=null?child:fallback,
          errorBuilder:(_,__,___)=>fallback,
        ),
      ),
    );
  }

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
          gradient:const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF091226),Color(0xFF14113B),Color(0xFF28106A)]),
          boxShadow:[BoxShadow(color:const Color(0xFF6E32FF).withValues(alpha:.18),blurRadius:20,offset:const Offset(0,8))],
        ),
        child:Column(children:[
          SizedBox(
            height:compact?132:140,
            child:Stack(children:[
              Positioned(right:-10,bottom:-22,child:_logo(size:118,opacity:.065)),
              Positioned(right:12,top:12,child:Container(
                padding:const EdgeInsets.symmetric(horizontal:9,vertical:4),
                decoration:BoxDecoration(color:statusColor.withValues(alpha:.07),borderRadius:BorderRadius.circular(18),border:Border.all(color:statusColor)),
                child:Row(mainAxisSize:MainAxisSize.min,children:[CircleAvatar(radius:3.5,backgroundColor:statusColor),const SizedBox(width:6),Text(_active?'Aktif':'Pasif',style:TextStyle(color:statusColor,fontSize:11.5,fontWeight:FontWeight.w900))]),
              )),
              Positioned(left:10,top:10,bottom:8,width:compact?76:88,child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                _logo(size:logoSize),
                if(isPrimary)...[
                  const SizedBox(height:5),
                  Container(
                    padding:EdgeInsets.symmetric(horizontal:compact?6:8,vertical:4),
                    decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFF5D22E8),Color(0xFF8B43FF)]),borderRadius:BorderRadius.circular(18)),
                    child:const Row(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.workspace_premium_rounded,color:Colors.white,size:13),SizedBox(width:4),Text('Ana Araç',style:TextStyle(color:Colors.white,fontSize:10.5,fontWeight:FontWeight.w900))]),
                  ),
                ],
              ])),
              Positioned(left:compact?96:108,top:34,right:10,bottom:7,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Padding(padding:const EdgeInsets.only(right:72),child:Text(plate,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:Colors.white,fontSize:compact?18:20,fontWeight:FontWeight.w900,letterSpacing:.4))),
                const SizedBox(height:3),
                Text(title,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:Colors.white,fontSize:compact?14:16,fontWeight:FontWeight.w800)),
                const SizedBox(height:6),
                if(type.isNotEmpty||fuel.isNotEmpty)Wrap(spacing:6,runSpacing:5,children:[
                  if(type.isNotEmpty)_chip(type.toLowerCase().contains('moto')?Icons.two_wheeler_rounded:Icons.directions_car_rounded,type),
                  if(fuel.isNotEmpty)_chip(Icons.local_gas_station_rounded,fuel),
                ]),
                if(currentKm>0)...[const SizedBox(height:5),Text('${_number(currentKm)} km',style:const TextStyle(color:Color(0xFFD0D5E5),fontSize:13,fontWeight:FontWeight.w700))],
              ])),
            ]),
          ),
          Container(
            decoration:BoxDecoration(color:const Color(0xFF070D20).withValues(alpha:.48),border:Border(top:BorderSide(color:Colors.white.withValues(alpha:.09)))),
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
