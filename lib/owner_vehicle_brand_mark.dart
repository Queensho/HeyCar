import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Maps the owner's current vehicle make to a locally bundled brand SVG.
abstract final class VehicleBrandMarkResolver {
  static String normalize(String input) {
    return input.toLowerCase().trim()
      .replaceAll('ı','i').replaceAll('ğ','g').replaceAll('ü','u')
      .replaceAll('ş','s').replaceAll('ö','o').replaceAll('ç','c')
      .replaceAll('é','e').replaceAll('ë','e')
      .replaceAll(RegExp(r'[^a-z0-9]'),'');
  }

  static const Map<String,String> _assets={
    'acura':'acura','alfaromeo':'alfa-romeo','audi':'audi',
    'bentley':'bentley','bmw':'bmw','chevrolet':'chevrolet',
    'citroen':'citroen','dacia':'dacia','ducati':'ducati',
    'ferrari':'ferrari','fiat':'fiat','ford':'ford',
    'honda':'honda','hyundai':'hyundai','jaguar':'jaguar',
    'jeep':'jeep','kia':'kia','ktm':'ktm',
    'landrover':'land-rover','lexus':'lexus','maserati':'maserati',
    'mazda':'mazda','mercedesbenz':'mercedes-benz','mini':'mini',
    'mitsubishi':'mitsubishi','nissan':'nissan','opel':'opel',
    'peugeot':'peugeot','porsche':'porsche','renault':'renault',
    'rollsroyce':'rolls-royce','seat':'seat','skoda':'skoda',
    'subaru':'subaru','suzuki':'suzuki','tesla':'tesla',
    'toyota':'toyota','vespa':'vespa','volkswagen':'volkswagen',
    'volvo':'volvo',
    'aprilia':'aprilia','byd':'byd','chery':'chery',
    'chrysler':'chrysler','cupra':'cupra','daihatsu':'daihatsu',
    'dfsk':'dfsk','dodge':'dodge','dsautomobiles':'ds',
    'isuzu':'isuzu','jaecoo':'jaecoo','kawasaki':'kawasaki',
    'kgm':'kgm','lada':'lada','maxus':'maxus','mg':'mg',
    'omoda':'omoda','piaggio':'piaggio','proton':'proton',
    'rover':'rover','saab':'saab','smart':'smart',
    'togg':'togg','triumph':'triumph','yamaha':'yamaha',
    'harleydavidson':'harley-davidson','husqvarna':'husqvarna',
  };
  static const Map<String,String> _aliases={
    'vw':'volkswagen','vwagen':'volkswagen',
    'volkswagenag':'volkswagen','benz':'mercedesbenz',
    'mercedes':'mercedesbenz','mercedesamg':'mercedesbenz',
    'mercedesbenzag':'mercedesbenz','bmwmotorrad':'bmw',
    'bayerischemotorenwerke':'bmw','vauxhall':'opel',
    'vauxhallopel':'opel','alfaromeoautomobiles':'alfaromeo',
    'alfaromeospa':'alfaromeo','audiag':'audi',
    'fordmotorcompany':'ford','landrovergroup':'landrover',
    'minicooper':'mini',
    'harleydavidsonmotorcompany':'harleydavidson',
    'harleydavidsoninc':'harleydavidson',
    'ds':'dsautomobiles','dsautomobile':'dsautomobiles',
    'ssangyong':'kgm','kgmmotors':'kgm',
    'mgmotor':'mg','mgmotors':'mg',
    'bydauto':'byd','cheryautomobile':'chery',
    'citroenautomobiles':'citroen',
    'yamahamotor':'yamaha',
    'kawasakimotors':'kawasaki','triumphmotorcycles':'triumph',
    'apriliaspa':'aprilia','piaggiogroup':'piaggio',
  };

  static String? slugFor(String? make){
    final key=normalize(make??'');
    if(key.isEmpty)return null;
    final resolved=_aliases[key]??key;
    if(_assets.containsKey(resolved))return _assets[resolved];
    // Some import sources append a manufacturer suffix or model.
    for(final entry in _assets.entries){
      if(resolved.startsWith(entry.key)&&resolved.length>entry.key.length){
        return entry.value;
      }
    }
    return null;
  }

  static String? assetFor(String? make){
    final slug=slugFor(make);
    return slug==null?null:'assets/vehicle_brand_logos/$slug.svg';
  }
}


/// Choose only safe first-party logo files from the existing owner vehicle API.
/// The payload may contain either a relative path or a legacy absolute URL.
abstract final class OwnerBrandLogoUrl {
  static String? resolve(Map<dynamic,dynamic>? data,String apiBaseUrl){
    if(data==null||data['available']!=true)return null;
    final base=Uri.tryParse(apiBaseUrl.trim());
    if(base==null||base.scheme!='https'||base.host.isEmpty)return null;
    for(final field in ['path','url']){
      final source=(data[field]??'').toString().trim();
      if(source.isEmpty||source.contains('%')||source.contains('..'))continue;
      final parsed=Uri.tryParse(source);
      if(parsed==null)continue;
      final resolved=source.startsWith('/')?base.resolveUri(parsed):parsed;
      final prefix='/uploads/vehicle-brands/';
      if(resolved.scheme!='https'||resolved.host!=base.host||
        resolved.port!=base.port||resolved.hasQuery||resolved.hasFragment||
        resolved.userInfo.isNotEmpty||!resolved.path.startsWith(prefix)){
        continue;
      }
      final filename=resolved.path.substring(prefix.length);
      final fileNamePattern=RegExp(
        r'^[a-z0-9-]+-[a-f0-9]{12}\.(png|jpg|webp)',caseSensitive:false);
      final match=fileNamePattern.firstMatch(filename);
      if(match!=null&&match.start==0&&match.end==filename.length){
        return resolved.toString();
      }
    }
    return null;
  }
}

/// Local SVGs take precedence; the existing owner-controlled brand logo is
/// only used when a local mark is not bundled. All logos are purple.
class OwnerVehicleBrandMark extends StatelessWidget{
  const OwnerVehicleBrandMark({
    super.key,required this.make,this.isMotorcycle=false,this.backendLogoUrl,
  });
  final String make;
  final bool isMotorcycle;
  final String? backendLogoUrl;
  static const ink=Color(0xFF651FFF);

  Widget _fallback(double side)=>Icon(
    isMotorcycle?Icons.two_wheeler_rounded:Icons.directions_car_filled_rounded,
    key:const ValueKey('owner-brand-logo-generic'),
    size:side,color:ink,
  );

  @override Widget build(BuildContext context){
    final slug=VehicleBrandMarkResolver.slugFor(make);
    final asset=VehicleBrandMarkResolver.assetFor(make);
    return LayoutBuilder(builder:(context,box){
      final height=box.maxHeight.isFinite?box.maxHeight:130.0;
      final side=(height*.68).clamp(50.0,89.0);
      final remote=backendLogoUrl?.trim()??'';
      final validRemote=remote.startsWith('https://')&&
        (remote.endsWith('.svg')||remote.endsWith('.png')||
         remote.endsWith('.webp')||remote.endsWith('.jpg'));
      return Semantics(
        label:slug==null?'Araç marka simgesi':'${make.trim()} marka logosu',
        image:true,
        child:Center(child:Column(
          mainAxisSize:MainAxisSize.min,
          mainAxisAlignment:MainAxisAlignment.center,
          children:[
            if(asset!=null)
              SvgPicture.asset(
                asset,key:ValueKey('owner-brand-logo-$slug'),
                width:side,height:side,fit:BoxFit.contain,
                colorFilter:const ColorFilter.mode(ink,BlendMode.srcIn),
              )
            else if(validRemote)
              remote.toLowerCase().endsWith('.svg')
                ?SvgPicture.network(remote,
                  key:const ValueKey('owner-brand-logo-backend'),
                  width:side,height:side,fit:BoxFit.contain,
                  colorFilter:const ColorFilter.mode(ink,BlendMode.srcIn),
                  placeholderBuilder:(_)=>_fallback(side))
                :ColorFiltered(
                  colorFilter:const ColorFilter.mode(ink,BlendMode.srcIn),
                  child:Image.network(remote,
                    key:const ValueKey('owner-brand-logo-backend'),
                    width:side,height:side,fit:BoxFit.contain,
                    errorBuilder:(_,__,___)=>_fallback(side)),
                )
            else
              _fallback(side),
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
