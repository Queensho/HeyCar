import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _base='https://heycar-api-185-165-46-213.nip.io';
const _card=Color(0xFF0C1226),_line=Color(0xFF242D49),_muted=Color(0xFF8993AD),_purple=Color(0xFFA72BFF),_amber=Color(0xFFFFBF55),_green=Color(0xFF28F39A);

class AdminPremiumPricingCard extends StatefulWidget{
  const AdminPremiumPricingCard({super.key,required this.token,required this.admin});
  final String token;
  final Map<String,dynamic>? admin;
  @override State<AdminPremiumPricingCard> createState()=>_AdminPremiumPricingCardState();
}

class _AdminPremiumPricingCardState extends State<AdminPremiumPricingCard>{
  final monthly=TextEditingController();
  final yearly=TextEditingController();
  bool loading=true,saving=false;
  String? error;

  Map<String,String> get headers=>{
    'Authorization':'Bearer \${widget.token}',
    'Content-Type':'application/json',
    if((widget.admin?['id']??'').toString().isNotEmpty)'X-Admin-Id':(widget.admin?['id']??'').toString(),
    if((widget.admin?['email']??'').toString().isNotEmpty)'X-Admin-Email':(widget.admin?['email']??'').toString(),
    if((widget.admin?['display_name']??widget.admin?['name']??'').toString().isNotEmpty)'X-Admin-Name':(widget.admin?['display_name']??widget.admin?['name']).toString(),
  };

  @override void initState(){super.initState();load();}
  @override void dispose(){monthly.dispose();yearly.dispose();super.dispose();}

  Future<void> load()async{
    if(mounted)setState((){loading=true;error=null;});
    try{
      final r=await http.get(Uri.parse('$_base/api/admin/manage/app-settings'),headers:headers);
      final d=r.body.isEmpty?<String,dynamic>{}:jsonDecode(r.body);
      if(r.statusCode<200||r.statusCode>=300)throw Exception(d is Map?d['error']??'SERVER_ERROR':'SERVER_ERROR');
      final s=d is Map&&d['settings'] is Map?Map<String,dynamic>.from(d['settings'] as Map):<String,dynamic>{};
      monthly.text=_priceText(s['premium_monthly_price']??49.99);
      yearly.text=_priceText(s['premium_yearly_price']??499.99);
      if(mounted)setState((){});
    }catch(e){
      if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));
    }finally{
      if(mounted)setState(()=>loading=false);
    }
  }

  String _priceText(dynamic v){
    final n=v is num?v.toDouble():double.tryParse(v.toString())??0;
    return n.toStringAsFixed(n%1==0?0:2).replaceAll('.',',');
  }

  double? _parse(String v)=>double.tryParse(v.trim().replaceAll('.','').replaceAll(',','.'));

  Future<void> save()async{
    final m=_parse(monthly.text),y=_parse(yearly.text);
    if(m==null||m<0){_snack('Geçerli bir aylık fiyat gir.');return;}
    if(y==null||y<0){_snack('Geçerli bir yıllık fiyat gir.');return;}
    setState(()=>saving=true);
    try{
      final r=await http.patch(
        Uri.parse('$_base/api/admin/manage/app-settings'),
        headers:headers,
        body:jsonEncode({
          'premiumMonthlyPrice':m,
          'premiumYearlyPrice':y,
          'premiumCurrency':'TRY',
        }),
      );
      final d=r.body.isEmpty?<String,dynamic>{}:jsonDecode(r.body);
      if(r.statusCode<200||r.statusCode>=300)throw Exception(d is Map?d['error']??'SERVER_ERROR':'SERVER_ERROR');
      final s=d is Map&&d['settings'] is Map?Map<String,dynamic>.from(d['settings'] as Map):<String,dynamic>{};
      monthly.text=_priceText(s['premium_monthly_price']??m);
      yearly.text=_priceText(s['premium_yearly_price']??y);
      _snack('Premium fiyatları güncellendi.');
      if(mounted)setState(()=>error=null);
    }catch(e){
      if(mounted)setState(()=>error=e.toString().replaceFirst('Exception: ',''));
      _snack('Fiyatlar kaydedilemedi.');
    }finally{
      if(mounted)setState(()=>saving=false);
    }
  }

  void _snack(String t){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t)));}

  @override Widget build(BuildContext context){
    return Container(
      padding:const EdgeInsets.all(14),
      decoration:BoxDecoration(
        color:_card,
        borderRadius:BorderRadius.circular(18),
        border:Border.all(color:_amber.withValues(alpha:.32)),
      ),
      child:loading
        ?const SizedBox(height:92,child:Center(child:CircularProgressIndicator(color:_amber)))
        :Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[
            Container(width:40,height:40,decoration:BoxDecoration(color:_amber.withValues(alpha:.12),borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.sell_rounded,color:_amber)),
            const SizedBox(width:10),
            const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Premium Fiyatlandırma',style:TextStyle(color:Colors.white,fontSize:15,fontWeight:FontWeight.w900)),
              SizedBox(height:2),
              Text('Kullanıcı uygulamasında gösterilecek aylık ve yıllık fiyatı değiştir.',style:TextStyle(color:_muted,fontSize:10.5)),
            ])),
            IconButton(onPressed:saving?null:load,icon:const Icon(Icons.refresh_rounded,color:_muted)),
          ]),
          const SizedBox(height:12),
          Row(children:[
            Expanded(child:_priceField(monthly,'Aylık fiyat')),
            const SizedBox(width:9),
            Expanded(child:_priceField(yearly,'Yıllık fiyat')),
          ]),
          const SizedBox(height:10),
          Row(children:[
            const Expanded(child:Text('Para birimi: TRY (₺)',style:TextStyle(color:_muted,fontSize:10.5,fontWeight:FontWeight.w700))),
            FilledButton.icon(
              onPressed:saving?null:save,
              style:FilledButton.styleFrom(backgroundColor:_amber,foregroundColor:Colors.black),
              icon:saving?const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.black)):const Icon(Icons.save_rounded,size:18),
              label:Text(saving?'Kaydediliyor':'Fiyatları Kaydet',style:const TextStyle(fontWeight:FontWeight.w900)),
            ),
          ]),
          if(error!=null)...[
            const SizedBox(height:8),
            Text(error!,style:const TextStyle(color:Colors.redAccent,fontSize:10.5)),
          ],
          const SizedBox(height:8),
          Container(
            width:double.infinity,
            padding:const EdgeInsets.all(10),
            decoration:BoxDecoration(color:_green.withValues(alpha:.06),borderRadius:BorderRadius.circular(12),border:Border.all(color:_green.withValues(alpha:.18))),
            child:const Text('Kaydedilen değerler Cepqar Premium ekranına backend üzerinden yansır. Google Play Billing bağlandığında ödeme ekranındaki gerçek fiyatı Google Play belirler.',style:TextStyle(color:_muted,fontSize:10,height:1.35)),
          ),
        ]),
    );
  }

  Widget _priceField(TextEditingController c,String label)=>TextField(
    controller:c,
    keyboardType:const TextInputType.numberWithOptions(decimal:true),
    style:const TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.w900),
    decoration:InputDecoration(
      labelText:label,
      prefixText:'₺ ',
      filled:true,
      fillColor:const Color(0xFF10172B),
      border:OutlineInputBorder(borderRadius:BorderRadius.circular(13),borderSide:const BorderSide(color:_line)),
      enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(13),borderSide:const BorderSide(color:_line)),
      focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(13),borderSide:const BorderSide(color:_amber)),
    ),
  );
}
