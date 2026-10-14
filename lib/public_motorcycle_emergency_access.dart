import 'package:flutter/material.dart';
import 'public_motorcycle_emergency_card.dart';

// The server availability flag is consent-aware. Never show the public
// emergency access panel based on vehicle type alone: the owner may have
// disabled publication after previously sharing their card.
bool motorcycleEmergencyEntryVisible({
  required Map<String,dynamic> vehicle,
  bool? published,
}) {
  return published == true;
}

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
  });

  final VoidCallback onReveal;
  final bool loading;
  final Map<String,dynamic>? card;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final available=card!=null;
    return Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,
      children:[
        if(!available)
          Container(
            key:const ValueKey('emergency-access-panel'),
            padding:const EdgeInsets.all(15),
            decoration:BoxDecoration(
              color:const Color(0xFFFFF3F5),
              borderRadius:BorderRadius.circular(17),
              border:Border.all(color:const Color(0xFFEDBAC4)),
            ),
            child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                const Row(children:[
                  Icon(Icons.emergency_rounded,
                    color:Color(0xFFC52B50),size:25),
                  SizedBox(width:9),
                  Expanded(child:Text(
                    'Motosiklet • Acil Durum Bilgileri',
                    style:TextStyle(fontWeight:FontWeight.w900,
                      color:Color(0xFF17213B),fontSize:15),
                  )),
                ]),
                const SizedBox(height:8),
                const Text(
                  'Sürücünün paylaşmayı seçtiği acil durum bilgileri, '
                  'yalnızca geçerli QR taraması doğrulandıktan sonra gösterilir.',
                  style:TextStyle(color:Color(0xFF576175),
                    fontSize:12.5,height:1.4),
                ),
                if(error!=null&&error!.isNotEmpty)...[
                  const SizedBox(height:10),
                  Text(error!,key:const ValueKey('emergency-access-error'),
                    style:const TextStyle(color:Color(0xFFA72243),
                      fontWeight:FontWeight.w700,fontSize:12.5,height:1.4)),
                ],
                const SizedBox(height:12),
                SizedBox(
                  width:double.infinity,
                  child:FilledButton.icon(
                    key:const ValueKey('emergency-access-open'),
                    onPressed:loading?null:onReveal,
                    style:FilledButton.styleFrom(
                      backgroundColor:const Color(0xFFC52B50),
                      foregroundColor:Colors.white,
                      padding:const EdgeInsets.symmetric(vertical:13),
                    ),
                    icon:loading
                      ?const SizedBox(width:18,height:18,child:
                        CircularProgressIndicator(strokeWidth:2,
                          color:Colors.white))
                      :const Icon(Icons.health_and_safety_rounded),
                    label:Text(loading?'Doğrulanıyor...':
                      'Acil Durum Bilgilerini Göster'),
                  ),
                ),
              ],
            ),
          ),
        if(available)
          PublicMotorcycleEmergencyCard(card:card!),
      ],
    );
  }
}
