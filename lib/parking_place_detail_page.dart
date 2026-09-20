import 'package:flutter/material.dart';
import 'parking_place.dart';
import 'parking_style.dart';
import 'parking_navigation.dart';
import 'parking_record_api.dart';
import 'parking_record_editor.dart';
import 'cepqar_theme.dart';

class ParkingPlaceDetailPage extends StatefulWidget {
  const ParkingPlaceDetailPage({
    super.key,
    required this.place,
    required this.vehicleId,
    required this.userLatitude,
    required this.userLongitude,
  });
  final ParkingPlace place;
  final String vehicleId;
  final double userLatitude, userLongitude;
  @override
  State<ParkingPlaceDetailPage> createState() => _ParkingPlaceDetailPageState();
}

class _ParkingPlaceDetailPageState extends State<ParkingPlaceDetailPage> {
  bool _saving = false;
  String? _error;
  Future<void> _navigate() async {
    final p = widget.place;
    final ok = await navigateToParking(p.latitude, p.longitude, p.name);
    if (!ok && mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harita uygulaması açılamadı.')),
      );
  }

  Future<void> _park() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final record = await ParkingRecordApi.save(
        widget.vehicleId,
        place: widget.place,
      );
      if (!mounted) return;
      await showParkingRecordEditor(
        context,
        widget.vehicleId,
        initial: record,
        dark: !CepqarTheme.isLight,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _value(String v) =>
      {
        'yes': 'Evet',
        'no': 'Hayır',
        'limited': 'Sınırlı',
        'customers': 'Müşterilere özel',
        'permissive': 'İzin verilen kullanım',
        'public': 'Halka açık',
        'designated': 'Ayrılmış',
      }[v] ??
      v;
  @override
  Widget build(BuildContext context) {
    final p = widget.place;
    final light = CepqarTheme.isLight;
    final bg = CepqarTheme.bg, panel = CepqarTheme.panel, line = CepqarTheme.line;
    final text = CepqarTheme.text, muted = CepqarTheme.muted;
    final fee = p.tags['fee'] == 'yes' ? 'Ücretli' : p.tags['fee'] == 'no' ? 'Ücretsiz' : 'Ücret bilgisi yok';
    final capacity = p.tags['capacity'];
    final cards = <({IconData icon, String value})>[
      (icon: Icons.payments_outlined, value: fee),
      (icon: Icons.garage_outlined, value: p.typeLabel),
      if (capacity != null) (icon: Icons.directions_car_rounded, value: '~$capacity Araç\nKapasitesi'),
    ];
    final features = <({IconData icon, String value})>[
      if (p.tags['supervised'] == 'yes') (icon: Icons.security_rounded, value: 'Güvenlik'),
      if (p.tags['covered'] == 'yes' || ['multi-storey','underground'].contains(p.tags['parking']))
        (icon: Icons.garage_rounded, value: 'Kapalı Alan'),
      if (p.tags['wheelchair'] == 'yes' || p.tags['capacity:disabled'] != null)
        (icon: Icons.accessible_rounded, value: 'Engelli\nPark Yeri'),
      if (p.tags['charging_station'] == 'yes' || p.tags['amenity'] == 'charging_station' || p.tags.keys.any((k) => k.startsWith('socket:')))
        (icon: Icons.bolt_rounded, value: 'Elektrikli\nAraç Şarjı'),
      if (p.tags['lit'] == 'yes') (icon: Icons.lightbulb_outline_rounded, value: 'Aydınlatma'),
    ];
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: bg,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 230,
              pinned: true,
              backgroundColor: bg,
              foregroundColor: text,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: light
                          ? [const Color(0xFFEDE5FF), const Color(0xFFF8F6FF)]
                          : [const Color(0xFF25124B), const Color(0xFF07111F)],
                    ),
                  ),
                  child: Center(
                    child: Icon(Icons.local_parking_rounded,
                        size: 100, color: parkingPurple.withValues(alpha: .9)),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Text(p.name, style: TextStyle(color:text,fontSize:25,fontWeight:FontWeight.w900))),
                    const SizedBox(width:10),
                    Text(p.distanceLabel(widget.userLatitude, widget.userLongitude),
                      style: TextStyle(color:muted,fontSize:16,fontWeight:FontWeight.w700)),
                  ]),
                  const SizedBox(height:14),
                  if (p.address.isNotEmpty) _line(Icons.location_on_rounded,p.address,text,muted),
                  if (p.hours.isNotEmpty) ...[
                    const SizedBox(height:10),
                    _line(Icons.circle, p.hoursLabel, text, const Color(0xFF25D366), smallIcon:true),
                  ],
                  const SizedBox(height:20),
                  Row(children:[
                    Expanded(child:_action(Icons.turn_right_rounded,'Yol Tarifi',true,_navigate,panel,line,text)),
                    const SizedBox(width:10),
                    Expanded(child:_action(Icons.navigation_rounded,'Navigasyonda Aç',false,_navigate,panel,line,text)),
                  ]),
                  const SizedBox(height:18),
                  Row(children:[
                    for (var i=0;i<cards.length;i++) ...[
                      if(i>0) const SizedBox(width:8),
                      Expanded(child:_tile(cards[i].icon,cards[i].value,panel,line,text,muted)),
                    ]
                  ]),
                  if(features.isNotEmpty) ...[
                    const SizedBox(height:28),
                    Text('Özellikler',style:TextStyle(color:text,fontSize:19,fontWeight:FontWeight.w900)),
                    const SizedBox(height:12),
                    Wrap(spacing:8,runSpacing:8,children:features.map((e)=>SizedBox(
                      width:(MediaQuery.sizeOf(context).width-64)/4,
                      child:_tile(e.icon,e.value,panel,line,text,muted),
                    )).toList()),
                  ],
                  const SizedBox(height:28),
                  Text('Çalışma Saatleri',style:TextStyle(color:text,fontSize:19,fontWeight:FontWeight.w900)),
                  const SizedBox(height:12),
                  Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(
                    color:panel,borderRadius:BorderRadius.circular(16),border:Border.all(color:line)),
                    child:Row(children:[
                      Icon(Icons.schedule_rounded,color:muted),
                      const SizedBox(width:12),
                      Expanded(child:Text(p.hours.isEmpty?'Saat bilgisi eklenmemiş':'Pazartesi - Pazar',
                        style:TextStyle(color:text,fontWeight:FontWeight.w700))),
                      if(p.hours.isNotEmpty) Text(p.hoursLabel,style:TextStyle(color:muted,fontWeight:FontWeight.w700)),
                    ])),
                  const SizedBox(height:16),
                  Center(child:Text('Bilgiler OpenStreetMap katkıcılarından gelir; güncellik ve müsaitlik garanti edilmez.',
                    textAlign:TextAlign.center,style:TextStyle(color:muted,fontSize:11,height:1.4))),
                  if(_error!=null) Padding(padding:const EdgeInsets.only(top:14),child:Text(_error!,style:const TextStyle(color:Colors.redAccent))),
                ]),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(top:false,child:Container(
          color:bg,padding:const EdgeInsets.fromLTRB(20,10,20,16),
          child:FilledButton.icon(
            onPressed:_saving?null:_park,
            icon:_saving?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.local_parking_rounded,size:30),
            label:Text(_saving?'Kaydediliyor…':'Burada Park Ettim',style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),
            style:FilledButton.styleFrom(backgroundColor:parkingPurple,foregroundColor:Colors.white,
              minimumSize:const Size.fromHeight(62),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18))),
          ),
        )),
      ),
    );
  }

  Widget _line(IconData icon,String value,Color text,Color iconColor,{bool smallIcon=false})=>Row(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(icon,color:iconColor,size:smallIcon?12:22),
      const SizedBox(width:10),
      Expanded(child:Text(value,style:TextStyle(color:text.withValues(alpha:.78),fontSize:15,height:1.45,fontWeight:FontWeight.w600))),
    ]);

  Widget _action(IconData icon,String label,bool primary,VoidCallback tap,Color panel,Color line,Color text)=>SizedBox(
    height:58,child:primary?FilledButton.icon(onPressed:tap,icon:Icon(icon),label:Text(label),
      style:FilledButton.styleFrom(backgroundColor:parkingPurple,foregroundColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16))))
    :OutlinedButton.icon(onPressed:tap,icon:Icon(icon),label:Text(label),
      style:OutlinedButton.styleFrom(foregroundColor:text,side:BorderSide(color:line),backgroundColor:panel,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)))));

  Widget _tile(IconData icon,String value,Color panel,Color line,Color text,Color muted)=>Container(
    constraints:const BoxConstraints(minHeight:105),padding:const EdgeInsets.symmetric(horizontal:8,vertical:14),
    decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(16),border:Border.all(color:line)),
    child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      Icon(icon,color:text,size:27),const SizedBox(height:10),
      Text(value,textAlign:TextAlign.center,style:TextStyle(color:muted,fontSize:12.5,height:1.25,fontWeight:FontWeight.w700)),
    ]));

}
