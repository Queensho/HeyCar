import 'dart:convert';

import 'package:flutter/material.dart';

import 'cepqar_theme.dart';
import 'onboarding_backend.dart';
import 'owner_auth.dart';

// Demo builds cannot write to the database. Enable only after a separate
// backend rollout and pilot-region access enforcement review.
const bool towingInterestLive=bool.fromEnvironment('TOWING_INTEREST_LIVE',defaultValue:false);

class TowingInterestPage extends StatefulWidget {
  const TowingInterestPage({super.key});
  @override
  State<TowingInterestPage> createState()=>_TowingInterestPageState();
}

class _TowingInterestPageState extends State<TowingInterestPage>{
  static const _purple=Color(0xFF713BFF);
  static const _cities=<String>[
    'Adana','Adıyaman','Afyonkarahisar','Ağrı','Aksaray','Amasya','Ankara','Antalya','Ardahan','Artvin',
    'Aydın','Balıkesir','Bartın','Batman','Bayburt','Bilecik','Bingöl','Bitlis','Bolu','Burdur',
    'Bursa','Çanakkale','Çankırı','Çorum','Denizli','Diyarbakır','Düzce','Edirne','Elazığ','Erzincan',
    'Erzurum','Eskişehir','Gaziantep','Giresun','Gümüşhane','Hakkâri','Hatay','Iğdır','Isparta',
    'İstanbul','İzmir','Kahramanmaraş','Karabük','Karaman','Kars','Kastamonu','Kayseri','Kırıkkale',
    'Kırklareli','Kırşehir','Kilis','Kocaeli','Konya','Kütahya','Malatya','Manisa','Mardin',
    'Mersin','Muğla','Muş','Nevşehir','Niğde','Ordu','Osmaniye','Rize','Sakarya','Samsun',
    'Siirt','Sinop','Sivas','Şanlıurfa','Şırnak','Tekirdağ','Tokat','Trabzon','Tunceli',
    'Uşak','Van','Yalova','Yozgat','Zonguldak',
  ];
  final _district=TextEditingController(text:'Avcılar');
  String city='İstanbul';
  bool notify=true,busy=false,submitted=false;
  String? error;
  String availability='coming_soon';

  @override void initState(){super.initState();if(towingInterestLive)_load();}
  @override void dispose(){_district.dispose();super.dispose();}

  Future<void> _load()async{
    try{
      final r=await OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/towing-interest'));
      if(r.statusCode!=200||!mounted)return;
      final d=jsonDecode(r.body);
      if(d is Map&&d['interest'] is Map){
        final saved=d['interest'] as Map;
        final savedCity='${saved['city']??''}';
        setState((){
          if(_cities.contains(savedCity))city=savedCity;
          _district.text='${saved['district']??''}';
          notify=saved['notify_on_launch']==true;
        });
      }
    }catch(_){}
  }
  Future<void> _submit()async{
    final district=_district.text.trim().replaceAll(RegExp(r'\s+'),' ');
    if(district.length<2||district.length>90){
      setState(()=>error='Lütfen geçerli bir ilçe adı girin.');
      return;
    }
    if(!towingInterestLive){
      // Deliberately no local storage, HTTP call, or database change.
      setState((){error=null;submitted=true;});
      return;
    }
    setState((){busy=true;error=null;});
    try{
      final r=await OwnerHttp.put(
        Uri.parse('${OnboardingBackend.baseUrl}/api/owner/towing-interest'),
        body:jsonEncode({'city':city,'district':district,'notifyOnLaunch':notify}),
      );
      if(r.statusCode!=200)throw StateError('Talep kaydedilemedi (HTTP ${r.statusCode}).');
      if(mounted)setState(()=>submitted=true);
    }catch(_){if(mounted)setState(()=>error='Tercih kaydedilemedi. Lütfen tekrar deneyin.');}
    finally{if(mounted)setState(()=>busy=false);}
  }

  @override Widget build(BuildContext context){
    final light=CepqarTheme.isLight;
    final ink=light?const Color(0xFF151B30):Colors.white;
    final muted=light?const Color(0xFF6D7589):const Color(0xFFAFBAD0);
    final surface=light?Colors.white:const Color(0xFF12192B);
    return Scaffold(
      backgroundColor:CepqarTheme.bg,
      appBar:AppBar(
        title:const Text('CepQontag Çekici',style:TextStyle(fontWeight:FontWeight.w900,fontSize:18)),
        backgroundColor:CepqarTheme.bg,
        foregroundColor:ink,
      ),
      body:SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(20,12,20,30),children:[
        Container(
          decoration:BoxDecoration(
            color:_purple,borderRadius:BorderRadius.circular(23),
          ),
          padding:const EdgeInsets.all(21),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[
              const Icon(Icons.fire_truck_rounded,size:36,color:Colors.white),
              const Spacer(),
              Container(
                padding:const EdgeInsets.symmetric(horizontal:11,vertical:6),
                decoration:BoxDecoration(color:Colors.white.withValues(alpha:.22),borderRadius:BorderRadius.circular(30)),
                child:const Text('YAKINDA',style:TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w900)),
              ),
            ]),
            const SizedBox(height:20),
            const Text('Çekici ilk nerede başlasın?',style:TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w900)),
            const SizedBox(height:8),
            const Text('Hizmetimizi hangi bölgede görmek istersiniz? İl ve ilçenizi seçerek pilot bölgeyi belirlememize yardımcı olun.',
              style:TextStyle(color:Colors.white,fontSize:13,height:1.5)),
          ]),
        ),
        const SizedBox(height:17),
        if(!towingInterestLive)Container(
          padding:const EdgeInsets.all(12),
          decoration:BoxDecoration(color:_purple.withValues(alpha:.10),borderRadius:BorderRadius.circular(13)),
          child:Row(children:[
            const Icon(Icons.science_outlined,color:_purple),
            const SizedBox(width:9),
            Expanded(child:Text('Demo ekranı: Tercihiniz gerçek veritabanına kaydedilmez.',
              style:TextStyle(color:ink,fontSize:12,fontWeight:FontWeight.w700))),
          ]),
        ),
        const SizedBox(height:16),
        if(submitted)...[
          Container(
            padding:const EdgeInsets.all(18),
            decoration:BoxDecoration(color:surface,borderRadius:BorderRadius.circular(18)),
            child:Column(children:[
              const Icon(Icons.check_circle_rounded,color:Color(0xFF24B879),size:52),
              const SizedBox(height:12),
              Text(towingInterestLive?'Tercihiniz alındı!':'Demo tamamlandı!',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:ink)),
              const SizedBox(height:8),
              Text('$city / ${_district.text.trim()} • ${notify?'Bildirim açık':'Bildirim kapalı'}',
                textAlign:TextAlign.center,style:TextStyle(color:muted)),
              const SizedBox(height:8),
              Text(towingInterestLive
                ?'Bölgenizde çekici hizmeti başladığında, izin verdiyseniz bilgilendirileceksiniz.'
                :'Bu bir ön izlemedir. Gerçek talep oluşturulmadı ve kimseye bildirim gönderilmeyecek.',
                textAlign:TextAlign.center,style:TextStyle(color:muted,height:1.4)),
              const SizedBox(height:14),
              TextButton(onPressed:()=>setState(()=>submitted=false),child:const Text('Tercihi düzenle')),
            ]),
          ),
        ]else...[
          Container(
            padding:const EdgeInsets.all(17),
            decoration:BoxDecoration(color:surface,borderRadius:BorderRadius.circular(18)),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Tercih ettiğiniz il',style:TextStyle(color:ink,fontSize:13,fontWeight:FontWeight.w800)),
              const SizedBox(height:8),
              DropdownButtonFormField<String>(
                value:city,isExpanded:true,
                decoration:InputDecoration(border:OutlineInputBorder(borderRadius:BorderRadius.circular(12))),
                items:_cities.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),
                onChanged:(v){if(v!=null)setState(()=>city=v);},
              ),
              const SizedBox(height:17),
              Text('İlçe',style:TextStyle(color:ink,fontSize:13,fontWeight:FontWeight.w800)),
              const SizedBox(height:8),
              TextField(controller:_district,textCapitalization:TextCapitalization.words,maxLength:90,
                decoration:InputDecoration(hintText:'Örneğin Avcılar',counterText:'',
                  border:OutlineInputBorder(borderRadius:BorderRadius.circular(12))),
              ),
              const SizedBox(height:9),
              SwitchListTile.adaptive(
                contentPadding:EdgeInsets.zero,
                title:Text('Hizmet açılınca haber ver',style:TextStyle(color:ink,fontWeight:FontWeight.w800,fontSize:13)),
                subtitle:Text('Yalnızca seçtiğiniz bölgedeki açılış duyurusu için.',style:TextStyle(color:muted,fontSize:11)),
                value:notify,activeColor:_purple,onChanged:(v)=>setState(()=>notify=v),
              ),
              if(error!=null)Padding(padding:const EdgeInsets.only(bottom:9),
                child:Text(error!,style:const TextStyle(color:Colors.red,fontSize:12))),
              const SizedBox(height:10),
              SizedBox(width:double.infinity,height:49,child:FilledButton.icon(
                onPressed:busy?null:_submit,
                style:FilledButton.styleFrom(backgroundColor:_purple,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13))),
                icon:busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.location_on_outlined),
                label:Text(busy?'Kaydediliyor...':'Bölgeme Çekici İstiyorum',style:const TextStyle(fontWeight:FontWeight.w900)),
              )),
            ]),
          ),
        ],
        const SizedBox(height:18),
        Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(Icons.info_outline,color:muted,size:19),
          const SizedBox(width:9),
          Expanded(child:Text('Bu form bir acil yol yardım veya çekici çağrısı değildir. Hizmet henüz aktif değildir; fiyatlandırma ya da araç yönlendirmesi yapılmaz.',
            style:TextStyle(fontSize:11.5,height:1.4,color:muted))),
        ]),
      ])),
    );
  }
}
