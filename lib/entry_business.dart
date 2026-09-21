import 'package:flutter/material.dart';
import 'business_panel_page.dart';

void main()=>runApp(const CepqarBusinessApp());

class CepqarBusinessApp extends StatelessWidget{
  const CepqarBusinessApp({super.key});
  @override
  Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false,
    title:'Cepqar İşletme',
    theme:ThemeData(useMaterial3:true,brightness:Brightness.dark),
    home:const BusinessPanelPage(),
  );
}
