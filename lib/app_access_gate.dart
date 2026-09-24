import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_runtime_config.dart';
import 'cepqar_theme.dart';

class AppAccessGatePage extends StatelessWidget {
  const AppAccessGatePage({
    super.key,
    required this.config,
    required this.onRetry,
  });

  final RuntimeAppConfig config;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final update=config.updateRequired;
    final title=update?'Cepqar güncellemesi gerekli':config.maintenanceTitle;
    final message=update
      ?'Bu sürüm artık desteklenmiyor. Cepqar’ı kullanmaya devam etmek için uygulamayı güncelle.'
      :config.maintenanceMessage;
    final icon=update?Icons.system_update_alt_rounded:Icons.build_circle_rounded;

    return Scaffold(
      backgroundColor:CepqarTheme.darkBg,
      body:SafeArea(
        child:Center(
          child:SingleChildScrollView(
            padding:const EdgeInsets.all(24),
            child:ConstrainedBox(
              constraints:const BoxConstraints(maxWidth:480),
              child:Container(
                padding:const EdgeInsets.fromLTRB(22,28,22,22),
                decoration:BoxDecoration(
                  color:CepqarTheme.darkPanel,
                  borderRadius:BorderRadius.circular(28),
                  border:Border.all(color:CepqarTheme.purple.withValues(alpha:.45)),
                ),
                child:Column(mainAxisSize:MainAxisSize.min,children:[
                  Container(
                    width:72,height:72,
                    decoration:BoxDecoration(
                      color:CepqarTheme.purple.withValues(alpha:.14),
                      shape:BoxShape.circle,
                    ),
                    child:Icon(icon,color:CepqarTheme.purple,size:38),
                  ),
                  const SizedBox(height:18),
                  Text(title,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.w900)),
                  const SizedBox(height:9),
                  Text(message,textAlign:TextAlign.center,style:const TextStyle(color:Color(0xFFB6BDD0),fontSize:13,height:1.45)),
                  if(update)...[
                    const SizedBox(height:12),
                    Container(
                      padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
                      decoration:BoxDecoration(color:Colors.white.withValues(alpha:.05),borderRadius:BorderRadius.circular(14)),
                      child:Text(
                        'Mevcut: ${config.currentVersion}  •  Minimum: ${config.minimumVersion}',
                        style:const TextStyle(color:Colors.white70,fontSize:11,fontWeight:FontWeight.w700),
                      ),
                    ),
                  ],
                  const SizedBox(height:20),
                  if(update)
                    SizedBox(
                      width:double.infinity,height:50,
                      child:FilledButton.icon(
                        onPressed:config.storeUrl.isEmpty?null:()async{
                          final u=Uri.tryParse(config.storeUrl);
                          if(u!=null)await launchUrl(u,mode:LaunchMode.externalApplication);
                        },
                        style:FilledButton.styleFrom(backgroundColor:CepqarTheme.purple,foregroundColor:Colors.white),
                        icon:const Icon(Icons.download_rounded),
                        label:const Text('Uygulamayı Güncelle',style:TextStyle(fontWeight:FontWeight.w900)),
                      ),
                    ),
                  const SizedBox(height:8),
                  SizedBox(
                    width:double.infinity,height:46,
                    child:OutlinedButton.icon(
                      onPressed:onRetry,
                      icon:const Icon(Icons.refresh_rounded),
                      label:const Text('Tekrar Kontrol Et'),
                    ),
                  ),
                  if(update&&config.storeUrl.isEmpty)...[
                    const SizedBox(height:8),
                    const Text('Mağaza bağlantısı henüz tanımlı değil. Biraz sonra tekrar dene.',textAlign:TextAlign.center,style:TextStyle(color:Colors.white54,fontSize:10.5)),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
