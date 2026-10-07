import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cepqar_theme.dart';
import 'onboarding_backend.dart';
import 'owner_auth.dart';
import 'vehicle_api.dart';

class VehicleEditSheet extends StatefulWidget {
  const VehicleEditSheet({super.key,required this.vehicle,required this.currentKm,required this.isPrimary});
  final Map<String,dynamic> vehicle;
  final int currentKm;
  final bool isPrimary;
  @override State<VehicleEditSheet> createState()=>_VehicleEditSheetState();
}

class _VehicleEditSheetState extends State<VehicleEditSheet>{
  final form=GlobalKey<FormState>();
  late final TextEditingController plate,model,km;
  List<Map<String,dynamic>> brands=[];
  List<String> models=[];
  String make='',vehicleType='',fuelType='',color='';
  int? year;
  bool saving=false,loadingBrands=true,loadingModels=false,makePrimary=false;
  String? error;
  late final Map<String,dynamic> initial;

  static const types={'car':'Otomobil','motorcycle':'Motosiklet','suv':'SUV','light_commercial':'Hafif Ticari','commercial':'Ticari','minivan':'Minivan','pickup':'Pickup'};
  static const fuels={'gasoline':'Benzin','diesel':'Dizel','lpg':'LPG','hybrid':'Hibrit','electric':'Elektrik'};
  static const colors=['Beyaz','Siyah','Gri','Gümüş','Mavi','Kırmızı','Yeşil','Sarı','Turuncu','Kahverengi','Bej','Mor','Diğer'];
  static const fallbackBrandNames=['Alfa Romeo','Aprilia','Audi','Benelli','BMW','BMW Motorrad','CFMOTO','Citroën','Cupra','Dacia','Ducati','Fiat','Ford','Harley-Davidson','Honda','Hyundai','Kawasaki','Keeway','Kia','Kymco','KTM','Land Rover','Mercedes-Benz','Nissan','Opel','Peugeot','Piaggio','Porsche','QJMotor','Renault','RKS','SEAT','Skoda','Suzuki','SYM','Tesla','TOGG','Toyota','Triumph','Vespa','Voge','Volkswagen','Volvo','Yamaha'];

  String s(String k)=>'${widget.vehicle[k]??''}'.trim();
  @override void initState(){
    super.initState();
    plate=TextEditingController(text:s('plate'));
    model=TextEditingController(text:s('model'));
    final rawKm=widget.vehicle['mileage']??widget.currentKm;
    km=TextEditingController(text:(int.tryParse('$rawKm')??0)>0?'${int.tryParse('$rawKm')??0}':'');
    make=s('make');
    year=int.tryParse('${widget.vehicle['model_year']??widget.vehicle['year']??''}');
    vehicleType=s('vehicle_type');
    fuelType=s('fuel_type');
    color=s('color');
    makePrimary=widget.isPrimary;
    initial=_snapshot();
    _loadBrands();
    if(make.isNotEmpty)_loadModels(make);
  }
  @override void dispose(){plate.dispose();model.dispose();km.dispose();super.dispose();}

  Map<String,dynamic> _snapshot()=>{'plate':plate.text.trim().toUpperCase(),'make':make,'model':model.text.trim(),'year':year,'vehicleType':vehicleType,'fuelType':fuelType,'color':color,'mileage':int.tryParse(km.text.replaceAll('.','')),'primary':makePrimary};
  bool get dirty=>jsonEncode(_snapshot())!=jsonEncode(initial);

  Future<void> _loadBrands()async{
    try{
      final r=await OwnerHttp.get(Uri.parse('${OnboardingBackend.baseUrl}/api/vehicle-brands'),json:false).timeout(const Duration(seconds:12));
      final d=jsonDecode(r.body);
      if(r.statusCode==200&&d is Map&&d['brands'] is List){
        brands=(d['brands'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();
      }
    }catch(_){}
    if(brands.isEmpty){
      brands=fallbackBrandNames.map((name)=><String,dynamic>{'name':name}).toList();
    }
    if(make.isNotEmpty&&!brands.any((b)=>'${b['name']??''}'.toLowerCase()==make.toLowerCase())){
      brands.add(<String,dynamic>{'name':make});
      brands.sort((a,b)=>'${a['name']}'.compareTo('${b['name']}'));
    }
    if(mounted)setState(()=>loadingBrands=false);
  }
  Future<void> _loadModels(String brand)async{
    setState(()=>loadingModels=true);
    try{models=(await VehicleApi.getModels(brand)).map((e)=>e.trim()).where((e)=>e.isNotEmpty).toSet().toList()..sort();}
    catch(_){models=[];}
    if(mounted)setState(()=>loadingModels=false);
  }
  String logoFor(String brand){
    for(final b in brands){if('${b['name']??''}'.toLowerCase()==brand.toLowerCase()){final x=b['brandLogo'];if(x is Map)return '${x['url']??''}';}}
    final current=widget.vehicle['brandLogo'];if(brand==s('make')&&current is Map)return '${current['url']??''}';
    return '';
  }
  Widget logo(String brand,{double size=64}){
    final u=logoFor(brand),letter=brand.isEmpty?'?':brand.characters.first.toUpperCase();
    final fallback=Container(width:size,height:size,alignment:Alignment.center,decoration:BoxDecoration(shape:BoxShape.circle,color:CepqarTheme.text.withValues(alpha:.08)),child:Text(letter,style:TextStyle(color:CepqarTheme.text,fontSize:size*.4,fontWeight:FontWeight.w900)));
    if(!u.startsWith('https://'))return fallback;
    return SizedBox(width:size,height:size,child:Image.network(u,fit:BoxFit.contain,errorBuilder:(_,__,___)=>fallback));
  }
  Future<void> _pickBrand()async{
    if(loadingBrands)return;
    final search=TextEditingController();
    final picked=await showModalBottomSheet<Map<String,dynamic>>(context:context,isScrollControlled:true,backgroundColor:CepqarTheme.panel,shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(26))),builder:(ctx)=>StatefulBuilder(builder:(ctx,setLocal){
      final q=search.text.trim().toLowerCase(),list=brands.where((b)=>'${b['name']??''}'.toLowerCase().contains(q)).toList();
      return SafeArea(child:Padding(padding:EdgeInsets.fromLTRB(16,12,16,16+MediaQuery.viewInsetsOf(ctx).bottom),child:SizedBox(height:MediaQuery.sizeOf(ctx).height*.68,child:Column(children:[
        Container(width:44,height:5,decoration:BoxDecoration(color:CepqarTheme.muted.withValues(alpha:.35),borderRadius:BorderRadius.circular(9))),const SizedBox(height:14),
        TextField(controller:search,onChanged:(_)=>setLocal((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Marka ara')),
        const SizedBox(height:10),
        Expanded(child:ListView.builder(itemCount:list.length,itemBuilder:(_,i){final b=list[i],name='${b['name']??''}';return ListTile(leading:logo(name,size:38),title:Text(name,style:TextStyle(color:CepqarTheme.text,fontWeight:FontWeight.w700)),onTap:()=>Navigator.pop(ctx,b));}))
      ]))));
    }));
    search.dispose();
    if(picked==null)return;
    final next='${picked['name']??''}'.trim();if(next.isEmpty)return;
    setState((){make=next;model.clear();models=[];});
    await _loadModels(next);
  }
  Future<void> _pickModel()async{
    if(make.isEmpty)return;
    final search=TextEditingController(text:model.text);
    final picked=await showModalBottomSheet<String>(context:context,isScrollControlled:true,backgroundColor:CepqarTheme.panel,shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(26))),builder:(ctx)=>StatefulBuilder(builder:(ctx,setLocal){
      final q=search.text.trim().toLowerCase(),list=models.where((x)=>x.toLowerCase().contains(q)).take(100).toList();
      return SafeArea(child:Padding(padding:EdgeInsets.fromLTRB(16,12,16,16+MediaQuery.viewInsetsOf(ctx).bottom),child:SizedBox(height:MediaQuery.sizeOf(ctx).height*.65,child:Column(children:[
        TextField(controller:search,autofocus:true,onChanged:(_)=>setLocal((){}),decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:'Model ara veya yaz',suffixIcon:IconButton(icon:const Icon(Icons.check),onPressed:()=>Navigator.pop(ctx,search.text.trim())))),
        if(loadingModels)const LinearProgressIndicator(),
        Expanded(child:ListView.builder(itemCount:list.length,itemBuilder:(_,i)=>ListTile(title:Text(list[i],style:TextStyle(color:CepqarTheme.text)),onTap:()=>Navigator.pop(ctx,list[i]))))
      ]))));
    }));
    search.dispose();if(picked!=null&&picked.trim().isNotEmpty)setState(()=>model.text=picked.trim());
  }
  Future<bool> _confirmDiscard()async{
    if(!dirty)return true;
    return await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Kaydedilmemiş değişiklikleriniz var.'),content:const Text('Yaptığınız değişiklikler kaybolacak.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Düzenlemeye Devam Et')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Değişiklikleri Sil'))]))??false;
  }
  Future<void> _close()async{if(saving)return;if(await _confirmDiscard()&&mounted)Navigator.pop(context);}
  Future<void> _save()async{
    if(saving||!(form.currentState?.validate()??false))return;
    final mileage=km.text.trim().isEmpty?null:int.tryParse(km.text.replaceAll('.',''));
    if(mileage!=null&&(mileage<0||mileage>9999999)){setState(()=>error='Geçerli bir kilometre girin.');return;}
    setState((){saving=true;error=null;});
    try{
      final body={'plate':plate.text.trim().toUpperCase(),'make':make.trim(),'model':model.text.trim(),'modelYear':year,'vehicleType':vehicleType.isEmpty?null:vehicleType,'fuelType':fuelType.isEmpty?null:fuelType,'color':color.isEmpty?null:color,'mileage':mileage};
      final r=await OwnerHttp.put(Uri.parse('${OnboardingBackend.baseUrl}/api/owner/vehicles/${Uri.encodeComponent('${widget.vehicle['id']}')}'),body:jsonEncode(body)).timeout(const Duration(seconds:15));
      if(r.statusCode==409)throw Exception('Bu plaka başka bir araca kayıtlı.');
      if(r.statusCode==403)throw Exception('Bu aracı düzenleme yetkin yok.');
      if(r.statusCode<200||r.statusCode>=300)throw Exception('Araç güncellenemedi. Tekrar dene.');
      final d=jsonDecode(r.body);if(d is! Map||d['vehicle'] is! Map)throw Exception('Sunucu yanıtı doğrulanamadı.');
      if(!mounted)return;Navigator.pop(context,{'vehicle':Map<String,dynamic>.from(d['vehicle'] as Map),'makePrimary':makePrimary&&!widget.isPrimary});
    }catch(e){if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));}
    finally{if(mounted)setState(()=>saving=false);}
  }

  InputDecoration deco(String label,{Widget? prefix,String? suffix})=>InputDecoration(labelText:label,prefixIcon:prefix,suffixText:suffix,filled:true,fillColor:CepqarTheme.isLight ? Colors.white : const Color(0xFF11182B),border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide(color:CepqarTheme.line)),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide(color:CepqarTheme.line)));
  Widget selectField(String label,String value,VoidCallback tap,{Widget? prefix})=>InkWell(onTap:saving?null:tap,borderRadius:BorderRadius.circular(14),child:InputDecorator(decoration:deco(label,prefix:prefix),child:Row(children:[Expanded(child:Text(value.isEmpty?'Seçin':value,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(color:value.isEmpty?CepqarTheme.muted:CepqarTheme.text,fontWeight:FontWeight.w700))),const Icon(Icons.keyboard_arrow_down_rounded)])));
  Widget dropdown(String label,String value,Map<String,String> items,ValueChanged<String?> change)=>DropdownButtonFormField<String>(value:items.containsKey(value)?value:null,isExpanded:true,decoration:deco(label),items:items.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text(e.value))).toList(),onChanged:saving?null:change);
  Widget preview(){
    final type=types[vehicleType]??vehicleType,fuel=fuels[fuelType]??fuelType;
    return Container(height:132,padding:const EdgeInsets.all(16),decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xFF7E49FF)),gradient:const LinearGradient(colors:[Color(0xFF081126),Color(0xFF17103E),Color(0xFF4A16D2)])),child:Row(children:[
      logo(make,size:72),const SizedBox(width:18),Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(plate.text.trim().isEmpty?'PLAKA':plate.text.trim().toUpperCase(),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),
        const SizedBox(height:3),Text([make,model.text.trim()].where((x)=>x.isNotEmpty).join(' '),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white,fontSize:15,fontWeight:FontWeight.w700)),
        const SizedBox(height:9),Wrap(spacing:6,children:[if(type.isNotEmpty)_previewChip(Icons.directions_car_rounded,type),if(fuel.isNotEmpty)_previewChip(Icons.local_gas_station_rounded,fuel)])
      ]))
    ]));
  }
  Widget _previewChip(IconData i,String t)=>Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.12),borderRadius:BorderRadius.circular(16)),child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(i,size:14,color:Colors.white),const SizedBox(width:4),Text(t,style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w700))]));

  @override Widget build(BuildContext context){
    final now=DateTime.now().year,years=[for(int y=now+1;y>=1950;y--)y];
    return PopScope(canPop:false,onPopInvokedWithResult:(didPop,_) {if(!didPop)_close();},child:SafeArea(top:false,child:Padding(padding:EdgeInsets.only(bottom:MediaQuery.viewInsetsOf(context).bottom),child:Container(decoration:BoxDecoration(color:CepqarTheme.bg,borderRadius:const BorderRadius.vertical(top:Radius.circular(28))),child:Column(children:[
      const SizedBox(height:8),Container(width:48,height:5,decoration:BoxDecoration(color:CepqarTheme.muted.withValues(alpha:.28),borderRadius:BorderRadius.circular(9))),
      Padding(padding:const EdgeInsets.fromLTRB(18,10,10,8),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Aracı Düzenle',style:TextStyle(color:CepqarTheme.text,fontSize:25,fontWeight:FontWeight.w900)),Text('Araç bilgilerinizi güncelleyebilirsiniz.',style:TextStyle(color:CepqarTheme.muted,fontSize:12.5))])),IconButton(onPressed:_close,icon:const Icon(Icons.close_rounded))])),
      Expanded(child:Form(key:form,child:ListView(padding:const EdgeInsets.fromLTRB(16,4,16,18),children:[
        preview(),const SizedBox(height:16),
        TextFormField(controller:plate,enabled:!saving,maxLength:20,textCapitalization:TextCapitalization.characters,onChanged:(_)=>setState((){}),decoration:deco('Plaka *',prefix:const Icon(Icons.pin_outlined)),validator:(v)=>(v??'').trim().isEmpty?'Geçerli bir plaka girin.':null),
        const SizedBox(height:8),
        LayoutBuilder(builder:(_,c){final two=c.maxWidth>=370;final a=selectField('Marka *',make,_pickBrand,prefix:make.isEmpty?const Icon(Icons.directions_car_outlined):logo(make,size:28));final b=selectField('Model *',model.text,_pickModel);return two?Row(children:[Expanded(child:a),const SizedBox(width:10),Expanded(child:b)]):Column(children:[a,const SizedBox(height:10),b]);}),
        const SizedBox(height:10),
        LayoutBuilder(builder:(_,c){final y=DropdownButtonFormField<int>(value:years.contains(year)?year:null,isExpanded:true,decoration:deco('Model Yılı'),items:years.map((x)=>DropdownMenuItem(value:x,child:Text('$x'))).toList(),onChanged:saving?null:(v)=>setState(()=>year=v));final t=dropdown('Araç Tipi',vehicleType,types,(v)=>setState(()=>vehicleType=v??''));return c.maxWidth>=370?Row(children:[Expanded(child:y),const SizedBox(width:10),Expanded(child:t)]):Column(children:[y,const SizedBox(height:10),t]);}),
        const SizedBox(height:10),
        LayoutBuilder(builder:(_,c){final f=dropdown('Yakıt Türü',fuelType,fuels,(v)=>setState(()=>fuelType=v??''));final co=DropdownButtonFormField<String>(value:colors.contains(color)?color:null,isExpanded:true,decoration:deco('Renk'),items:colors.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:saving?null:(v)=>setState(()=>color=v??''));return c.maxWidth>=370?Row(children:[Expanded(child:f),const SizedBox(width:10),Expanded(child:co)]):Column(children:[f,const SizedBox(height:10),co]);}),
        const SizedBox(height:10),
        TextFormField(controller:km,enabled:!saving,keyboardType:TextInputType.number,inputFormatters:[FilteringTextInputFormatter.digitsOnly],decoration:deco('Güncel Kilometre',prefix:const Icon(Icons.speed_rounded),suffix:'km')),
        const SizedBox(height:14),
        Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFF813CFF).withValues(alpha:.07),borderRadius:BorderRadius.circular(16),border:Border.all(color:const Color(0xFF813CFF).withValues(alpha:.14))),child:Row(children:[Container(width:42,height:42,decoration:BoxDecoration(color:const Color(0xFF813CFF).withValues(alpha:.1),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.workspace_premium_rounded,color:Color(0xFF813CFF))),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Ana Araç Yap',style:TextStyle(color:CepqarTheme.text,fontWeight:FontWeight.w900)),Text('Bu aracı hesabınızdaki ana araç olarak ayarla.',style:TextStyle(color:CepqarTheme.muted,fontSize:11))])),Switch(value:makePrimary,onChanged:widget.isPrimary||saving?null:(v)=>setState(()=>makePrimary=v))])),
        if(error!=null)...[const SizedBox(height:10),Text(error!,style:const TextStyle(color:Colors.redAccent,fontWeight:FontWeight.w700))],
      ]))),
      Padding(padding:const EdgeInsets.fromLTRB(16,8,16,14),child:Row(children:[Expanded(child:OutlinedButton(onPressed:saving?null:_close,style:OutlinedButton.styleFrom(minimumSize:const Size.fromHeight(48),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),child:const Text('Vazgeç'))),const SizedBox(width:10),Expanded(flex:2,child:FilledButton.icon(onPressed:saving?null:_save,style:FilledButton.styleFrom(backgroundColor:const Color(0xFF713BFF),minimumSize:const Size.fromHeight(48),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),icon:saving?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.save_rounded),label:Text(saving?'Kaydediliyor…':'Değişiklikleri Kaydet')))]))
    ])))));
  }
}
