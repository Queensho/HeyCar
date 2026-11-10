import 'package:flutter/material.dart';
import 'api_environment.dart';
import 'business_panel_page.dart';

void main(){validateApiEnvironment();runApp(const CepqarBusinessApp());}

class CepqarBusinessApp extends StatelessWidget{
  const CepqarBusinessApp({super.key});
  @override
  Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false,
    title:'CepQontag İşletme',
    builder:(context,child)=>isStagingBuild?Banner(message:'STAGING',location:BannerLocation.topEnd,color:const Color(0xFF651FFF),child:child!):child!,
    theme:ThemeData(useMaterial3:true,brightness:Brightness.dark),
    home:const BusinessPanelPage(),
  );
}
