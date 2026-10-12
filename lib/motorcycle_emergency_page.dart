import 'dart:convert';
import 'package:flutter/material.dart';
import 'onboarding_backend.dart';
import 'owner_auth.dart';
import 'cepqar_theme.dart';

/// Explicitly opt-in, per-vehicle emergency information.
class MotorcycleEmergencyPage extends StatefulWidget {
  const MotorcycleEmergencyPage({
    super.key,required this.vehicleId,required this.plate,
  });
  final String vehicleId;
  final String plate;
  @override State<MotorcycleEmergencyPage> createState()=>_MotorcycleEmergencyPageState();
}
class _MotorcycleEmergencyPageState extends State<MotorcycleEmergencyPage>{
  final rider=TextEditingController();
  final contact=TextEditingController();
  final phone=TextEditingController();
  static const groups=['','A+','A-','B+','B-','AB+','AB-','0+','0-'];
  String blood='';
  bool isPublic=false,consent=false,contactConsent=false,loading=true,saving=false;
  String? error;
  String? _savedSnapshot;
  String get _currentSnapshot=>jsonEncode([
    rider.text.trim(),blood,contact.text.trim(),phone.text.trim(),
    isPublic,consent,contactConsent,
  ]);
  bool get _unsavedChanges=>
    _savedSnapshot!=null&&_currentSnapshot!=_savedSnapshot;
  void _formChanged(){if(mounted&&!loading)setState((){});}

  @override void initState(){
    super.initState();
    rider.addListener(_formChanged);
    contact.addListener(_formChanged);
    phone.addListener(_formChanged);
    _load();
  }
  @override void dispose(){rider.dispose();contact.dispose();phone.dispose();super.dispose();}

  Uri get endpoint=>Uri.parse(
    '${OnboardingBackend.baseUrl}/api/owner/vehicles/'
    '${Uri.encodeComponent(widget.vehicleId)}/emergency-card');

  Future<void> _load()async{
    if(mounted)setState((){loading=true;error=null;});
    try{
      final r=await OwnerHttp.get(endpoint,json:false).timeout(
        const Duration(seconds:12));
      if(r.statusCode!=200)throw Exception('Bilgiler alınamadı (${r.statusCode}).');
      final data=jsonDecode(r.body);
      final card=Map<String,dynamic>.from(data['card'] as Map? ?? {});
      rider.text='${card['riderFullName']??''}';
      contact.text='${card['emergencyContactName']??''}';
      phone.text='${card['emergencyContactPhone']??''}';
      if(!mounted)return;
      setState((){
        blood=groups.contains(card['bloodGroup'])?card['bloodGroup'].toString():'';
        isPublic=card['isPublic']==true;
        consent=isPublic;
        contactConsent=isPublic;
        _savedSnapshot=_currentSnapshot;
      });
    }catch(e){
      if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));
    }finally{if(mounted)setState(()=>loading=false);}
  }

  Future<void> _save()async{
    if(saving)return;
    if(isPublic&&(!consent||!contactConsent)){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:Text('Yayınlamak için her iki izin kutusunu işaretleyin.')));
      return;
    }
    setState((){saving=true;error=null;});
    try{
      final payload=jsonEncode({
        'riderFullName':rider.text.trim(),
        'bloodGroup':blood,
        'emergencyContactName':contact.text.trim(),
        'emergencyContactPhone':phone.text.trim(),
        'isPublic':isPublic,
        'consent':isPublic&&consent,
        'contactConsent':isPublic&&contactConsent,
      });
      final response=await OwnerHttp.put(endpoint,body:payload).timeout(
        const Duration(seconds:12));
      if(response.statusCode!=200){
        final detail=response.statusCode==400
            ?'Ad-soyad, telefon ve yayın izinlerini kontrol edin.'
            :'Kaydedilemedi (${response.statusCode}).';
        throw Exception(detail);
      }
      if(!mounted)return;
      setState(()=>_savedSnapshot=_currentSnapshot);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:Text(isPublic
          ?'Acil durum bilgileri QR ziyaretçileri için yayımlandı.'
          :'Acil durum bilgileri kaydedildi, QR paylaşımı kapalı.')));
    }catch(e){
      if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));
    }finally{if(mounted)setState(()=>saving=false);}
  }

  InputDecoration _dec(String label,String hint,{IconData? icon})=>InputDecoration(
    labelText:label,hintText:hint,
    prefixIcon:icon==null?null:Icon(icon,color:const Color(0xFF762FF5)),
    filled:true,fillColor:CepqarTheme.panel,
    border:OutlineInputBorder(borderRadius:BorderRadius.circular(15)));

  @override Widget build(BuildContext context){
    final color=CepqarTheme.text,muted=CepqarTheme.muted;
    return Scaffold(
      backgroundColor:CepqarTheme.bg,
      appBar:AppBar(backgroundColor:CepqarTheme.bg,foregroundColor:color,
        title:const Text('Motosiklet Acil Durum')),
      body:loading
        ?const Center(child:CircularProgressIndicator())
        :ListView(padding:const EdgeInsets.fromLTRB(18,12,18,40),children:[
          Container(
            padding:const EdgeInsets.all(16),
            decoration:BoxDecoration(
              color:const Color(0xFFEA395B).withValues(alpha:.09),
              borderRadius:BorderRadius.circular(18)),
            child:Row(children:[
              const Icon(Icons.emergency_rounded,color:Color(0xFFE23A57),size:34),
              const SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(widget.plate,style:TextStyle(color:color,fontSize:19,fontWeight:FontWeight.w900)),
                Text('QR etiketi için acil durum kimlik kartı',
                  style:TextStyle(color:muted,fontSize:12)),
              ])),
            ]),
          ),
          const SizedBox(height:20),
          Text('Sürücü bilgileri',style:TextStyle(color:color,
            fontWeight:FontWeight.w800,fontSize:18)),
          const SizedBox(height:12),
          TextField(
            controller:rider,
            textCapitalization:TextCapitalization.words,
            maxLength:90,
            decoration:_dec('Ad soyad','Motosiklet sürücüsünün adı',
              icon:Icons.person_outline_rounded),
          ),
          const SizedBox(height:10),
          DropdownButtonFormField<String>(
            value:blood,
            decoration:_dec('Kan grubu','Bilinmiyor',
              icon:Icons.bloodtype_outlined),
            items:groups.map((value)=>DropdownMenuItem(
              value:value,
              child:Text(value.isEmpty?'Bilinmiyor / belirtme':value),
            )).toList(),
            onChanged:(v)=>setState(()=>blood=v??''),
          ),
          const SizedBox(height:20),
          Text('Acil durumda aranacak kişi',style:TextStyle(color:color,
            fontWeight:FontWeight.w800,fontSize:18)),
          const SizedBox(height:10),
          TextField(
            controller:contact,maxLength:90,
            textCapitalization:TextCapitalization.words,
            decoration:_dec('Ad soyad','Örn. Yakınımın adı',
              icon:Icons.contact_phone_outlined),
          ),
          const SizedBox(height:10),
          TextField(
            controller:phone,keyboardType:TextInputType.phone,
            decoration:_dec('Telefon numarası','Örn. +90 5xx xxx xx xx',
              icon:Icons.phone_outlined),
          ),
          const SizedBox(height:18),
          SwitchListTile.adaptive(
            contentPadding:EdgeInsets.zero,
            title:Text('QR’da acil bilgileri göster',style:TextStyle(
              color:color,fontWeight:FontWeight.w800)),
            subtitle:Text(_unsavedChanges
              ?'Değişiklikler henüz kaydedilmedi. Yayınlamak için aşağıdan Bilgileri Kaydet’e basın.'
              :isPublic
                ?'Açık ve kayıtlı: Bilgiler geçerli QR taraması sonrasında gösterilebilir.'
                :'Kapalı: Bilgiler yalnızca hesabında saklanır.',
              style:TextStyle(color:muted,fontSize:12)),
            value:isPublic,
            activeColor:const Color(0xFF762FF5),
            onChanged:(value)=>setState((){
              isPublic=value;
              if(value){consent=false;contactConsent=false;}
            }),
          ),
          if(_unsavedChanges)...[
            const SizedBox(height:8),
            Container(
              width:double.infinity,
              padding:const EdgeInsets.all(12),
              decoration:BoxDecoration(
                color:const Color(0xFFFFF0D7),
                borderRadius:BorderRadius.circular(12),
              ),
              child:const Row(children:[
                Icon(Icons.info_outline_rounded,color:Color(0xFF915400),size:20),
                SizedBox(width:8),
                Expanded(child:Text('Henüz kaydedilmedi. QR sayfası bu değişiklikleri görmez.',
                  style:TextStyle(fontSize:12.5,color:Color(0xFF653C00),fontWeight:FontWeight.w700))),
              ]),
            ),
          ],
          if(isPublic)...[
            CheckboxListTile(
              contentPadding:EdgeInsets.zero,
              title:Text('Adımı ve kan grubumu QR ziyaretçilerine göstermeyi kabul ediyorum.',
                style:TextStyle(color:color,fontSize:13)),
              value:consent,
              onChanged:(v)=>setState(()=>consent=v??false),
              controlAffinity:ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              contentPadding:EdgeInsets.zero,
              title:Text('Acil durum kişisini bilgilendirdim ve adını/telefonunu paylaşma iznim var.',
                style:TextStyle(color:color,fontSize:13)),
              value:contactConsent,
              onChanged:(v)=>setState(()=>contactConsent=v??false),
              controlAffinity:ListTileControlAffinity.leading,
            ),
          ],
          const SizedBox(height:12),
          Text('Önemli: Kan grubu kullanıcı beyanıdır, tıbben doğrulanmamıştır. '
               'Kişisel bilgiler yalnızca yayın seçeneği açıkken paylaşılır.',
               style:TextStyle(color:muted,fontSize:12,height:1.5)),
          if(error!=null)...[
            const SizedBox(height:12),
            Text(error!,style:const TextStyle(color:Colors.redAccent)),
          ],
          const SizedBox(height:18),
          FilledButton.icon(
            onPressed:saving?null:_save,
            style:FilledButton.styleFrom(
              backgroundColor:const Color(0xFF762FF5),
              padding:const EdgeInsets.symmetric(vertical:17)),
            icon:const Icon(Icons.save_rounded),
            label:Text(saving?'Kaydediliyor...':'Bilgileri Kaydet'),
          ),
        ]),
    );
  }
}
