import 'package:flutter/semantics.dart';
import 'app_environment.dart';
import 'staging_banner.dart';
import 'package:flutter/material.dart';
import 'business_panel_page.dart';

SemanticsHandle? stagingSemantics;
Future<void> main() async { WidgetsFlutterBinding.ensureInitialized(); await AppEnvironment.verifyServer(); if(AppEnvironment.isStaging)stagingSemantics=SemanticsBinding.instance.ensureSemantics(); runApp(const CepqarBusinessApp()); }

class CepqarBusinessApp extends StatelessWidget{
  const CepqarBusinessApp({super.key});
  @override
  Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false,
    title:AppEnvironment.isStaging?'CepQontag İşletme STAGING':'CepQontag İşletme',
    builder:environmentBanner,
    theme:ThemeData(useMaterial3:true,brightness:Brightness.dark),
    home:const BusinessPanelPage(),
  );
}

