import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Resolves manufacturer names from the existing vehicle state. It does not
/// depend on remote branding URLs or request any additional permissions.
abstract final class VehicleBrandMarkResolver {
  static String normalize(String input) {
    return input.toLowerCase().trim()
      .replaceAll('ı','i').replaceAll('ğ','g').replaceAll('ü','u')
      .replaceAll('ş','s').replaceAll('ö','o').replaceAll('ç','c')
      .replaceAll(RegExp(r'[^a-z0-9]'),'');
  }

  static String? slugFor(String? make){
    final key=normalize(make??'');
    if(key.isEmpty)return null;
    if(key=='vw'||key.startsWith('volkswagen')||key.startsWith('volkswagenag'))return 'volkswagen';
    if(key.startsWith('bmw')||key.startsWith('bayerischemotorenwerke'))return 'bmw';
    if(key.startsWith('mercedes')||key.startsWith('mercedesbenz')||key.startsWith('benz'))return 'mercedes-benz';
    if(key.startsWith('audi'))return 'audi';
    if(key.startsWith('opel')||key.startsWith('vauxhallopel'))return 'opel';
    if(key.startsWith('toyota'))return 'toyota';
    if(key.startsWith('renault'))return 'renault';
    if(key.startsWith('ford'))return 'ford';
    return null;
  }

  static String? assetFor(String? make){
    final slug=slugFor(make);
    return slug==null?null:'assets/vehicle_brand_logos/'+slug+'.svg';
  }
}

/// The right-hand logo mark for the lime portion of the owner home vehicle
/// card. Always transparent, monochrome, proportionally scaled and offline.
class OwnerVehicleBrandMark extends StatelessWidget{
  const OwnerVehicleBrandMark({super.key,required this.make});
  final String make;
  static const ink=Color(0xFF651FFF);

  @override Widget build(BuildContext context){
    final slug=VehicleBrandMarkResolver.slugFor(make);
    final asset=VehicleBrandMarkResolver.assetFor(make);
    return LayoutBuilder(builder:(context,box){
      final height=box.maxHeight.isFinite?box.maxHeight:130.0;
      final side=(height*.68).clamp(50.0,89.0);
      return Semantics(
        label:slug==null?'Genel araç markası simgesi':make.trim()+' marka logosu',
        image:true,
        child:Center(child:Column(
          mainAxisSize:MainAxisSize.min,
          mainAxisAlignment:MainAxisAlignment.center,
          children:[
            if(asset!=null)
              SvgPicture.asset(
                asset,
                key:ValueKey('owner-brand-logo-'+slug),
                width:side,height:side,
                fit:BoxFit.contain,
                colorFilter:const ColorFilter.mode(ink,BlendMode.srcIn),
              )
            else
              Icon(Icons.directions_car_filled_rounded,
                key:const ValueKey('owner-brand-logo-generic'),
                size:side,color:ink),
            if(slug=='bmw')...[
              const SizedBox(height:1),
              const Text('BMW',style:TextStyle(
                color:ink,fontSize:17,fontWeight:FontWeight.w900,
                letterSpacing:6,height:1)),
            ],
          ],
        )),
      );
    });
  }
}
