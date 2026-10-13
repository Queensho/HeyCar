import 'package:flutter/material.dart';
import 'onboarding_backend.dart';

/// Admin-selected icon URL takes precedence over the local service PNG.
class ServiceIconAsset extends StatelessWidget {
  const ServiceIconAsset({super.key,required this.name,required this.fallback,this.customUrl='',this.size=72});
  final String name,customUrl;
  final IconData fallback;
  final double size;

  @override Widget build(BuildContext context) {
    final url=customUrl.trim();
    final base=OnboardingBackend.baseUrl.replaceFirst(RegExp(r'/$'),'');
    final resolved=url.startsWith('/uploads/')?base+url:url;
    Widget fallbackIcon()=>Icon(fallback,size:size*.52,color:const Color(0xFF651FFF));
    final asset='assets/images/services/$name.png';
    final local=Image.asset(asset,width:size,height:size,fit:BoxFit.contain,
      errorBuilder:(_,__,___)=>fallbackIcon());
    if(!resolved.startsWith('https://'))return local;
    return Image.network(resolved,width:size,height:size,fit:BoxFit.contain,
      errorBuilder:(_,__,___)=>local);
  }
}
