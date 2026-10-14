import 'package:flutter/material.dart';
import 'public_motorcycle_emergency_card.dart';

// Fail closed: the QR resolver's explicit consent-aware boolean is the
// only authority for displaying the entire visitor emergency section.
// Never infer publication from the vehicle type or make.
bool motorcycleEmergencyEntryVisible({
  required Map<String,dynamic> vehicle,
  bool? published,
}) => published == true;

/// Visitor-facing emergency access never contains private data until the
/// server verifies a matching, unexpired physical QR scan session.
String motorcycleEmergencyAccessMessage({
  int? statusCode,
  Object? error,
}) {
  final code=error?.toString().toUpperCase()??'';
  if(code.contains('LOCATION_REQUIRED') ||
      code.contains('PERMISSION_DENIED') ||
      code.contains('PERMISSIONDENIED')) {
    return 'Acil durum bilgilerini açmak için konum izni verin. '
        'Motosikletin yanındayken tekrar deneyin.';
  }
  if(code.contains('VEHICLE_NOT_NEARBY')) {
    return 'Konumunuz motosiklete yeterince yakın görünmüyor. '
        'Aracın yanındayken tekrar deneyin.';
  }
  if(code.contains('TOO_MANY_REQUESTS')||statusCode==429) {
    return 'Çok fazla deneme yapıldı. Biraz bekleyip tekrar deneyin.';
  }
  if(code.contains('QR_SCAN_PROOF_INVALID') ||
      code.contains('PROXIMITY_PROOF_REQUIRED') ||
      code.contains('SCAN_SESSION_REQUIRED') ||
      statusCode==401||statusCode==403) {
    return 'Geçerli QR taraması doğrulanamadı. '
        'Motosikletin etiketini kamerayla tekrar okutun.';
  }
  if(statusCode==404) {
    return 'Bu QR etiketi için acil durum kartı şu anda paylaşıma açık değil.';
  }
  return 'Acil durum bilgileri yüklenemedi. İnternet bağlantınızı '
      'kontrol edip tekrar deneyin.';
}

class PublicMotorcycleEmergencyAccess extends StatelessWidget {
  const PublicMotorcycleEmergencyAccess({
    super.key,
    required this.onReveal,
    required this.loading,
    this.card,
    this.error,
    this.vehicleType='Motosiklet',
  });

  final VoidCallback onReveal;
  final bool loading;
  final Map<String,dynamic>? card;
  final String? error;
  final String vehicleType;

  @override
  Widget build(BuildContext context) {
    final available=card!=null;
    return Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,
      children:[
        Material(
          key:const ValueKey('emergency-access-panel'),
          color:Colors.white,
          borderRadius:BorderRadius.circular(24),
          elevation:3,
          shadowColor:const Color(0x270C034A),
          child:InkWell(
            key:const ValueKey('emergency-access-open'),
            onTap:loading||available?null:onReveal,
            borderRadius:BorderRadius.circular(24),
            child:Container(
              constraints:const BoxConstraints(minHeight:76),
              padding:const EdgeInsets.symmetric(horizontal:13,vertical:8),
              child:Row(children:[
                Container(
                  width:60,height:60,
                  decoration:BoxDecoration(
                    color:const Color(0xFFF3EDFF),
                    borderRadius:BorderRadius.circular(19)),
                  child:Stack(alignment:Alignment.center,children:[
                    const Icon(Icons.shield_rounded,
                      color:Color(0xFF651FFF),size:39),
                    const Icon(Icons.add_rounded,
                      color:Colors.white,size:21),
                  ]),
                ),
                const SizedBox(width:14),
                Expanded(child:Column(
                  crossAxisAlignment:CrossAxisAlignment.start,
                  mainAxisSize:MainAxisSize.min,
                  children:[
                    const Text('Acil Durum Bilgileri',
                      style:TextStyle(color:Color(0xFF10152D),
                        fontSize:16,height:1.12,fontWeight:FontWeight.w900)),
                    const SizedBox(height:5),
                    Text('$vehicleType • Sürücünün paylaştığı bilgiler',
                      maxLines:2,overflow:TextOverflow.ellipsis,
                      style:const TextStyle(color:Color(0xFF778096),
                        fontSize:12,height:1.2,fontWeight:FontWeight.w500)),
                  ],
                )),
                const SizedBox(width:8),
                CircleAvatar(
                  radius:21,backgroundColor:const Color(0xFFB9FF45),
                  child:loading
                    ?const SizedBox(width:18,height:18,
                      child:CircularProgressIndicator(strokeWidth:2,
                        color:Color(0xFF10152D)))
                    :Icon(available?Icons.check_rounded:Icons.arrow_forward_rounded,
                      color:const Color(0xFF10152D),size:26),
                ),
              ]),
            ),
          ),
        ),
        if(error!=null&&error!.isNotEmpty)
          Padding(
            padding:const EdgeInsets.fromLTRB(10,9,10,0),
            child:Text(error!,key:const ValueKey('emergency-access-error'),
              style:const TextStyle(color:Colors.white,fontSize:12.5,
                fontWeight:FontWeight.w700,height:1.35)),
          ),
        if(available)
          Padding(
            padding:const EdgeInsets.only(top:10),
            child:PublicMotorcycleEmergencyCard(card:card!),
          ),
      ],
    );
  }
}
