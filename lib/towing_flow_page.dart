import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'cepqar_theme.dart';
import 'owner_auth.dart';
import 'onboarding_backend.dart';
import 'qr_backend.dart';
class TowingFlowPage extends StatefulWidget{const TowingFlowPage({super.key});@override State<TowingFlowPage> createState()=>_S();}
class _S extends State<TowingFlowPage>{
  int step=0;bool busy=false,notRunning=true;String vehicleType='car',truck='platform';double? a,b,x,y;String pickup='Konumum',dropoff='Haritada bırakma noktasını seç';Map<String,dynamic>? quote;final dest=TextEditingController();List<Map<String,dynamic>> destResults=[];bool destSearching=false;Timer? destDebounce;String get api=>OnboardingBackend.baseUrl;
  @override void initState(){super.initState();locate();}
  @override void dispose(){destDebounce?.cancel();dest.dispose();super.dispose();}
  void msg(String s){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
  Future<String> address(double lat,double lng)async{try{final r=await http.get(Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&accept-language=tr'),headers:{'User-Agent':'CepQontag/1.0'});if(r.statusCode==200){final d=jsonDecode(r.body),m=d['address']??{};final district=m['town']??m['city_district']??m['suburb']??m['city'];final city=m['province']??m['city'];if(district!=null&&city!=null)return '$district, $city';}}catch(_){}return 'Seçilen konum';}
  Future<void> locate()async{setState(()=>busy=true);try{var p=await Geolocator.checkPermission();if(p==LocationPermission.denied)p=await Geolocator.requestPermission();if(p==LocationPermission.denied||p==LocationPermission.deniedForever)throw Exception();final z=await Geolocator.getCurrentPosition();final ad=await address(z.latitude,z.longitude);if(mounted)setState((){a=z.latitude;b=z.longitude;pickup=ad;});}catch(_){msg('Konum alınamadı.');}finally{if(mounted)setState(()=>busy=false);}}
  double get km=>(a==null||x==null)?0:Geolocator.distanceBetween(a!,b!,x!,y!)/1000;
  Future<void> chooseDrop(LatLng p)async{final ad=await address(p.latitude,p.longitude);if(mounted)setState((){x=p.latitude;y=p.longitude;dropoff=ad;dest.text=ad;});}
  Future<void> searchDestination(String value) async {
    destDebounce?.cancel();
    final q = value.trim();
    if (q.length < 3) {
      if (mounted) setState(() => destResults = []);
      return;
    }
    destDebounce = Timer(const Duration(milliseconds: 450), () async {
      if (mounted) setState(() => destSearching = true);
      try {
        final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
          'format': 'jsonv2',
          'q': q,
          'countrycodes': 'tr',
          'limit': '5',
          'addressdetails': '1',
          'accept-language': 'tr',
        });
        final r = await http.get(uri, headers: {'User-Agent': 'CepQontag/1.0'});
        if (r.statusCode == 200 && mounted) {
          final list = (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
          setState(() => destResults = list);
        }
      } catch (_) {
        if (mounted) setState(() => destResults = []);
      } finally {
        if (mounted) setState(() => destSearching = false);
      }
    });
  }

  void selectDestination(Map<String, dynamic> item) {
    final lat = double.tryParse('${item['lat']}');
    final lon = double.tryParse('${item['lon']}');
    if (lat == null || lon == null) return;
    final label = '${item['display_name'] ?? 'Seçilen adres'}';
    FocusScope.of(context).unfocus();
    setState(() {
      x = lat;
      y = lon;
      dropoff = label;
      dest.text = label;
      destResults = [];
    });
  }

  Future<void> price()async{if(a==null||x==null){msg('Alım ve bırakma konumunu seç.');return;}setState(()=>busy=true);try{final r=await OwnerHttp.post(Uri.parse('$api/api/owner/towing/quote'),body:jsonEncode({'distanceKm':km,'vehicleType':vehicleType,'truckType':truck}));final d=jsonDecode(r.body);if(r.statusCode==200&&d['quote'] is Map&&mounted){setState(()=>quote=Map<String,dynamic>.from(d['quote']));step=2;}else{final e='${d['error']??''}';msg(e=='TOWING_OPTION_NOT_AVAILABLE'?'Bu araç/çekici tipi için fiyatlandırma henüz aktif değil.':e=='OWNER_REQUIRED'?'Oturum süren dolmuş. Tekrar giriş yap.':'Fiyat hesaplanamadı.');}}catch(_){msg('Fiyat hesaplanamadı. Bağlantını kontrol et.');}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> call()async{if(quote==null)return;setState(()=>busy=true);try{final r=await OwnerHttp.post(Uri.parse('$api/api/owner/towing/requests'),body:jsonEncode({'vehicleId':QrDraft.vehicleId,'vehicleType':vehicleType,'truckType':truck,'issueType':notRunning?'Araç çalışmıyor':'Çekici','pickupLat':a,'pickupLng':b,'pickupAddress':pickup,'destinationLat':x,'destinationLng':y,'destinationAddress':dropoff,'distanceKm':km}));final d=jsonDecode(r.body);if(r.statusCode>=200&&r.statusCode<300){final id='${d['request']['id']}';if(mounted)Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>TowingTrackingPage(id:id)));}else msg(d['error']=='ACTIVE_TOWING_REQUEST_EXISTS'?'Aktif çekici çağrın zaten var.':'Çağrı oluşturulamadı.');}catch(_){msg('Çağrı oluşturulamadı.');}finally{if(mounted)setState(()=>busy=false);}}
  Widget pinLine(IconData i,String t)=>Container(height:58,padding:const EdgeInsets.symmetric(horizontal:14),decoration:BoxDecoration(border:Border.all(color:const Color(0xFFE5E7EB)),borderRadius:BorderRadius.circular(14)),child:Row(children:[Icon(i,color:CepqarTheme.purple),const SizedBox(width:12),Expanded(child:Text(t,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Color(0xFF25252B),fontSize:16,fontWeight:FontWeight.w700)))]));
  Widget map() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .38,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(a ?? 41.0, b ?? 28.9),
            initialZoom: 14,
            minZoom: 11,
            maxZoom: 18,
            onTap: (_, p) => chooseDrop(p),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                -.12, -.24, -.04, 0, 115,
                -.15, -.30, -.05, 0, 140,
                -.18, -.36, -.06, 0, 173,
                0, 0, 0, 1, 0,
              ]),
              child: TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.cepqar.app',
                maxNativeZoom: 19,
                panBuffer: 0,
              ),
            ),
            PolylineLayer(
              polylines: [
                if (a != null && x != null)
                  Polyline(
                    points: [LatLng(a!, b!), LatLng(x!, y!)],
                    strokeWidth: 5,
                    color: CepqarTheme.purple,
                  ),
              ],
            ),
            MarkerLayer(
              markers: [
                if (a != null)
                  Marker(
                    point: LatLng(a!, b!),
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: .22),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(7),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                  ),
                if (x != null)
                  Marker(
                    point: LatLng(x!, y!),
                    width: 48,
                    height: 58,
                    alignment: Alignment.topCenter,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        const Positioned(
                          bottom: 6,
                          child: Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF813CFF), size: 42),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFAE70FF), Color(0xFF813CFF)]),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE1CCFF), width: 2),
                            boxShadow: const [BoxShadow(color: Color(0x55813CFF), blurRadius: 10)],
                          ),
                          child: const Icon(Icons.flag_rounded, color: Colors.white, size: 21),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget locationStep() {
    return Column(
      children: [
        map(),
        Transform.translate(
          offset: const Offset(0, -18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nereden alınacak?', style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                pinLine(Icons.location_on_rounded, pickup),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: InkWell(onTap: locate, child: pinLine(Icons.my_location_rounded, 'Konumum'))),
                    const SizedBox(width: 8),
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        border: Border.all(color: CepqarTheme.purple, width: 2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.swap_vert_rounded, color: CepqarTheme.purple),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Nereye bırakılacak?', style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                TextField(
                  controller: dest,
                  onChanged: searchDestination,
                  style: const TextStyle(color: Color(0xFF25252B), fontSize: 16, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: 'Adres veya yer adı yaz',
                    hintStyle: const TextStyle(color: Color(0xFF8A8A94), fontWeight: FontWeight.w600),
                    prefixIcon: Icon(Icons.location_on_rounded, color: CepqarTheme.purple),
                    suffixIcon: destSearching
                        ? const Padding(
                            padding: EdgeInsets.all(15),
                            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : dest.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () => setState(() {
                                  dest.clear();
                                  dropoff = 'Adres veya yer adı yaz';
                                  x = null;
                                  y = null;
                                  destResults = [];
                                }),
                                icon: const Icon(Icons.close_rounded),
                              ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: CepqarTheme.purple, width: 2)),
                  ),
                ),
                if (destResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 230),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 12, offset: Offset(0, 4))],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: destResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final item = destResults[i];
                        return ListTile(
                          leading: Icon(Icons.place_outlined, color: CepqarTheme.purple),
                          title: Text('${item['display_name'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
                          onTap: () => selectDestination(item),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                Text('İstersen bırakma noktasını haritaya dokunarak da seçebilirsin.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: a != null && x != null ? () => setState(() => step = 1) : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: CepqarTheme.purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text('Devam Et', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget typeBox(String id, IconData icon, String title) {
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => vehicleType = id),
        child: Container(
          height: 105,
          decoration: BoxDecoration(
            color: vehicleType == id ? CepqarTheme.purple.withValues(alpha: .08) : const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: vehicleType == id ? CepqarTheme.purple : const Color(0xFFE5E7EB),
              width: vehicleType == id ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 38, color: vehicleType == id ? CepqarTheme.purple : Colors.black87),
              const SizedBox(height: 8),
              Text(title, style: TextStyle(color: vehicleType == id ? CepqarTheme.purple : Colors.black87, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  Widget vehicleStep() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Araç bilgisi', style: TextStyle(color: Colors.black, fontSize: 23, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Row(children: [typeBox('car', Icons.directions_car_filled_rounded, 'Otomobil'), const SizedBox(width: 10), typeBox('suv_pickup', Icons.directions_car_rounded, 'SUV / 4x4')]),
          const SizedBox(height: 10),
          Row(children: [typeBox('light_commercial', Icons.local_shipping_rounded, 'Hafif Ticari'), const SizedBox(width: 10), typeBox('motorcycle', Icons.two_wheeler_rounded, 'Motosiklet')]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: const Color(0xFFF5F5F7), borderRadius: BorderRadius.circular(14)),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Araç çalışmıyor', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
              value: notRunning,
              activeThumbColor: CepqarTheme.purple,
              onChanged: (v) => setState(() => notRunning = v),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: price,
              style: FilledButton.styleFrom(backgroundColor: CepqarTheme.purple, foregroundColor: Colors.white),
              child: const Text('Fiyat Hesapla', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget quoteStep()=>Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Tahmini Ücret',style:TextStyle(color:Colors.black,fontSize:23,fontWeight:FontWeight.w900)),const SizedBox(height:12),Text('● $pickup\n● $dropoff',style:TextStyle(color:CepqarTheme.purple,fontWeight:FontWeight.w700,height:1.7)),const SizedBox(height:12),map(),const SizedBox(height:12),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('${km.toStringAsFixed(1)} km',style:const TextStyle(color:Colors.black,fontWeight:FontWeight.w800)),Text('Rota detayı',style:TextStyle(color:CepqarTheme.purple,fontWeight:FontWeight.w800))]),const Divider(height:28),Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text('Toplam (KDV dahil)',style:TextStyle(color:Colors.black,fontWeight:FontWeight.w900)),Text('${quote?['total']??'-'} ${quote?['currency']??'TL'}',style:const TextStyle(color:Colors.black,fontSize:22,fontWeight:FontWeight.w900))]),const SizedBox(height:20),SizedBox(width:double.infinity,height:56,child:FilledButton(onPressed:call,style:FilledButton.styleFrom(backgroundColor:CepqarTheme.purple,foregroundColor:Colors.white),child:const Text('Çekici Çağır',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900))))]));
  @override Widget build(BuildContext c)=>Scaffold(backgroundColor:Colors.white,appBar:AppBar(backgroundColor:Colors.white,foregroundColor:Colors.black,elevation:0,title:step==0?null:Text(step==1?'Araç bilgisi':'Tahmini Ücret',style:const TextStyle(fontWeight:FontWeight.w900))),body:busy?const Center(child:CircularProgressIndicator()):SafeArea(child:SingleChildScrollView(child:step==0?locationStep():step==1?vehicleStep():quoteStep())));
}
class TowingTrackingPage extends StatefulWidget {
  const TowingTrackingPage({super.key, required this.id});
  final String id;
  @override State<TowingTrackingPage> createState() => _T();
}
class _T extends State<TowingTrackingPage> {
  Map<String,dynamic>? d; Timer? t;
  @override void initState(){super.initState();load();t=Timer.periodic(const Duration(seconds:5),(_)=>load());}
  @override void dispose(){t?.cancel();super.dispose();}
  Future<void> load()async{try{final r=await OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/towing/requests/${widget.id}/tracking'));if(r.statusCode==200&&mounted)setState(()=>d=Map<String,dynamic>.from(jsonDecode(r.body)['tracking']));}catch(_){}}
  double? n(dynamic v)=>double.tryParse('${v??''}');
  String label(String s)=>{'searching':'Yakındaki çekiciler aranıyor','accepted':'Çekici bulundu','arriving':'Çekici size geliyor','arrived':'Çekici geldi','vehicle_loaded':'Aracınız yüklendi','in_transit':'Aracınız hedefe gidiyor','delivered':'Teslim edildi','cancelled':'İptal edildi'}[s]??s;
  Widget searching(){
    return Container(
      height:360,color:const Color(0xFF111318),
      child:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Container(width:150,height:150,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:CepqarTheme.purple.withValues(alpha:.25),width:18)),child:Center(child:Container(width:92,height:92,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:CepqarTheme.purple.withValues(alpha:.55),width:12)),child:Icon(Icons.radar_rounded,color:CepqarTheme.purple,size:62)))),
        const SizedBox(height:24),
        const Text('Yakındaki çekiciler aranıyor',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),
        const SizedBox(height:8),
        const Text('Uygun bir çekici bulunduğunda burada göreceksiniz.',textAlign:TextAlign.center,style:TextStyle(color:Color(0xFF9CA3AF))),
      ])),
    );
  }
  Widget trackingMap(){
    final dl=n(d?['driver_lat']),dn=n(d?['driver_lng']),pl=n(d?['pickup_lat']),pn=n(d?['pickup_lng']),xl=n(d?['destination_lat']),xn=n(d?['destination_lng']);
    final driver=dl==null||dn==null?null:LatLng(dl,dn),pickup=pl==null||pn==null?null:LatLng(pl,pn),dest=xl==null||xn==null?null:LatLng(xl,xn);
    final center=driver??pickup??dest??const LatLng(41.0,28.9);
    return SizedBox(height:360,child:FlutterMap(options:MapOptions(initialCenter:center,initialZoom:14,minZoom:11,maxZoom:18,interactionOptions:const InteractionOptions(flags:InteractiveFlag.all & ~InteractiveFlag.rotate)),children:[
      ColorFiltered(colorFilter:const ColorFilter.matrix([-.12,-.24,-.04,0,115,-.15,-.30,-.05,0,140,-.18,-.36,-.06,0,173,0,0,0,1,0]),child:TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName:'com.cepqar.app',maxNativeZoom:19,panBuffer:0)),
      PolylineLayer(polylines:[if(driver!=null&&pickup!=null)Polyline(points:[driver,pickup],strokeWidth:4,color:const Color(0xFFB6FF2A)),if(pickup!=null&&dest!=null)Polyline(points:[pickup,dest],strokeWidth:5,color:CepqarTheme.purple)]),
      MarkerLayer(markers:[
        if(driver!=null)Marker(point:driver,width:48,height:58,alignment:Alignment.topCenter,child:Icon(Icons.fire_truck_rounded,color:CepqarTheme.purple,size:42)),
        if(pickup!=null)Marker(point:pickup,width:36,height:36,child:Container(decoration:BoxDecoration(color:Colors.blueAccent.withValues(alpha:.22),shape:BoxShape.circle),padding:const EdgeInsets.all(7),child:Container(decoration:BoxDecoration(color:Colors.blueAccent,shape:BoxShape.circle,border:Border.all(color:Colors.white,width:3))))),
        if(dest!=null)Marker(point:dest,width:48,height:58,alignment:Alignment.topCenter,child:Icon(Icons.location_on_rounded,color:CepqarTheme.purple,size:48)),
      ]),
    ]));
  }
  @override Widget build(BuildContext c){
    if(d==null)return Scaffold(backgroundColor:CepqarTheme.bg,body:const Center(child:CircularProgressIndicator()));
    final status='${d!['status']}'; final searchingNow=status=='searching';
    return Scaffold(backgroundColor:CepqarTheme.bg,appBar:AppBar(backgroundColor:CepqarTheme.bg,foregroundColor:CepqarTheme.text,title:Text(searchingNow?'Çekici aranıyor':'Çekici Takibi')),body:ListView(children:[
      searchingNow?searching():trackingMap(),
      Padding(padding:const EdgeInsets.all(16),child:Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:CepqarTheme.panel,borderRadius:BorderRadius.circular(22),border:Border.all(color:CepqarTheme.line)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(label(status),style:TextStyle(color:CepqarTheme.text,fontSize:21,fontWeight:FontWeight.w900)),
        if((status=='accepted'||status=='arriving'||status=='arrived')&&d!['pickup_eta_minutes']!=null&&num.tryParse('${d!['pickup_eta_minutes']}')!=null&&num.parse('${d!['pickup_eta_minutes']}')>0)...[const SizedBox(height:5),Text('${d!['pickup_eta_minutes']} dk • ${d!['pickup_distance_km']??'-'} km',style:TextStyle(color:CepqarTheme.purple,fontSize:17,fontWeight:FontWeight.w900))],
        if((status=='vehicle_loaded'||status=='in_transit')&&d!['destination_eta_minutes']!=null&&num.tryParse('${d!['destination_eta_minutes']}')!=null&&num.parse('${d!['destination_eta_minutes']}')>0)...[const SizedBox(height:5),Text('Bırakma noktasına ${d!['destination_eta_minutes']} dk • ${d!['destination_distance_km']??'-'} km',style:TextStyle(color:CepqarTheme.purple,fontSize:17,fontWeight:FontWeight.w900))],
        if(d!['provider_name']!=null)...[const SizedBox(height:16),const Divider(),const SizedBox(height:8),Text('${d!['provider_name']}',style:TextStyle(color:CepqarTheme.text,fontSize:17,fontWeight:FontWeight.w900))],
        if(d!['driver_name']!=null)Text('Sürücü: ${d!['driver_name']}',style:TextStyle(color:CepqarTheme.muted)),
        if(d!['towing_plate']!=null)Text('Çekici: ${d!['towing_plate']} ${d!['towing_brand']??''} ${d!['towing_model']??''}',style:TextStyle(color:CepqarTheme.muted)),
        if(d!['pickup_address']!=null)...[const SizedBox(height:14),Text('Alım: ${d!['pickup_address']}',style:TextStyle(color:CepqarTheme.muted))],
        if(d!['destination_address']!=null)Text('Bırakma: ${d!['destination_address']}',style:TextStyle(color:CepqarTheme.muted)),
      ]))),
    ]));
  }
}
