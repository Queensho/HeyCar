import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displayed ONLY with data returned from the QR-scan-session-gated API.
/// This widget never fetches or guesses contact information.
class PublicMotorcycleEmergencyCard extends StatelessWidget{
  const PublicMotorcycleEmergencyCard({super.key,required this.card});
  final Map<String,dynamic> card;
  static const red=Color(0xFFCF2E4D);
  static const ink=Color(0xFF17213B);

  @override Widget build(BuildContext context){
    final rider='${card['riderFullName']??''}'.trim();
    final blood='${card['bloodGroup']??''}'.trim();
    final person='${card['emergencyContactName']??''}'.trim();
    final phone='${card['emergencyContactPhone']??''}'.trim();
    if(rider.isEmpty||person.isEmpty||phone.isEmpty)return const SizedBox.shrink();

    Future<void> callContact()async{
      final sanitized=phone.replaceAll(RegExp(r'[^+\d]'),'');
      if(sanitized.isEmpty)return;
      await launchUrl(Uri(scheme:'tel',path:sanitized),
        mode:LaunchMode.externalApplication);
    }

    return Container(
      width:double.infinity,
      padding:const EdgeInsets.all(16),
      decoration:BoxDecoration(
        color:const Color(0xFFFFF4F5),
        borderRadius:BorderRadius.circular(18),
        border:Border.all(color:const Color(0xFFF09AAA),width:1.2),
      ),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Row(children:[
          Icon(Icons.emergency_rounded,color:red,size:25),
          SizedBox(width:9),
          Expanded(child:Text('Motosiklet • Acil Durum Bilgileri',
            style:TextStyle(color:ink,fontWeight:FontWeight.w900,fontSize:15))),
        ]),
        const SizedBox(height:13),
        Text('SÜRÜCÜ',style:TextStyle(color:red,fontWeight:FontWeight.w800,
          fontSize:10,letterSpacing:1)),
        const SizedBox(height:4),
        Text(rider,style:const TextStyle(color:ink,fontWeight:FontWeight.w900,fontSize:17)),
        if(blood.isNotEmpty)...[
          const SizedBox(height:8),
          Row(children:[
            const Icon(Icons.bloodtype_outlined,color:red,size:20),
            const SizedBox(width:6),
            Text('Beyan edilen kan grubu: $blood',
              style:const TextStyle(color:ink,fontWeight:FontWeight.w700)),
          ]),
        ],
        const SizedBox(height:15),
        Text('ACİL DURUMDA ARANACAK KİŞİ',style:TextStyle(
          color:red,fontWeight:FontWeight.w800,fontSize:10,letterSpacing:1)),
        const SizedBox(height:6),
        Text(person,style:const TextStyle(color:ink,fontWeight:FontWeight.w800,fontSize:16)),
        const SizedBox(height:4),
        SelectableText(phone,style:const TextStyle(color:ink,fontSize:15)),
        const SizedBox(height:12),
        SizedBox(width:double.infinity,child:FilledButton.icon(
          onPressed:callContact,
          style:FilledButton.styleFrom(backgroundColor:red,
            padding:const EdgeInsets.symmetric(vertical:14)),
          icon:const Icon(Icons.phone_rounded),
          label:const Text('Acil Durum Kişisini Ara'),
        )),
        const SizedBox(height:12),
        const Text('Bilgiler motosiklet kullanıcısı tarafından girilmiştir; '
          'kan grubu doğrulanmamıştır. Hayati acil durumda 112’yi arayın.',
          style:TextStyle(color:Color(0xFF686B7D),fontSize:11.3,height:1.4)),
      ]),
    );
  }
}
