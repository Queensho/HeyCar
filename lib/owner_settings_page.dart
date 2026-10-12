import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'cepqar_theme.dart';
import 'cepqontag_store_page.dart';
import 'legal_pages.dart';
import 'onboarding_backend.dart';
import 'owner_auth.dart';
import 'owner_dnd_card.dart';
import 'owner_qr_dialog.dart';
import 'owner_settings_detail.dart';
import 'premium_page.dart';
import 'qr_backend.dart';
import 'support_ticket_page.dart';
import 'owner_reference_design.dart';
import 'qr_security_page.dart';

const _purple = Color(0xFF7A35F5);
const _gold = Color(0xFFFFB51B);
const _danger = Color(0xFFFF405D);

class OwnerSettingsPage extends StatelessWidget {
  const OwnerSettingsPage({
    super.key,
    this.onOpenVehicles,
    this.onOpenQr,
    this.onOpenNotifications,
  });

  final VoidCallback? onOpenVehicles;
  final VoidCallback? onOpenQr;
  final VoidCallback? onOpenNotifications;

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _showPremium(BuildContext context) {
    _push(context, const PremiumPage());
  }

  void _soon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title yakında burada olacak.')),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final panel = CepqarTheme.panel;
    final text = CepqarTheme.text;
    final muted = CepqarTheme.muted;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: panel,
        title: Text(
          'Çıkış yapılsın mı?',
          style: TextStyle(color: text, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'CepQontag hesabından çıkış yapacaksın.',
          style: TextStyle(color: muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('owner_device_id') ?? '';

    if (deviceId.isNotEmpty && OwnerAuth.accessToken.isNotEmpty) {
      try {
        await http.delete(
          Uri.parse('${OnboardingBackend.baseUrl}/api/owner/push-token'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${OwnerAuth.accessToken}',
          },
          body: jsonEncode({'deviceId': deviceId}),
        ).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }

    final refresh = OwnerAuth.refreshToken;
    if (refresh.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('${OnboardingBackend.baseUrl}/api/owner/auth/logout'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refresh}),
        ).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }

    await OwnerAuth.clear();
    try {
      await FirebaseMessaging.instance.deleteToken().timeout(const Duration(seconds: 8));
    } catch (_) {}
    await prefs.setBool('push_token_registered', false);
    await prefs.remove('push_token_last_registered_at');
    await prefs.remove('push_token_last_error');

    for (final key in [
      'owner_logged_in',
      'owner_user_id',
      'owner_phone',
      'owner_display_name',
      'owner_email',
      'owner_vehicle_id',
      'owner_plate',
      'owner_vehicle_type',
      'owner_make',
      'owner_model',
      'owner_qr_token',
      'owner_qr_scan_secret',
    ]) {
      await prefs.remove(key);
    }

    for (final key in prefs
        .getKeys()
        .where((k) =>
            k.startsWith('valet_delivery_code_') ||
            k.startsWith('owner_valet_delivery_code_') ||
            k.startsWith('owner_valet_delivery_session_'))
        .toList()) {
      await prefs.remove(key);
    }

    OnboardingDraft.phone = '';
    OnboardingDraft.displayName = '';
    OnboardingDraft.email = '';
    OnboardingDraft.password = '';
    OnboardingDraft.otpCode = '';
    OnboardingDraft.userId = '';
    OnboardingDraft.vehicleId = '';
    OnboardingDraft.transferCode = '';
    QrDraft.token = '';
    QrDraft.scanSecret = '';
    QrDraft.plate = '';
    QrDraft.make = '';
    QrDraft.model = '';
    QrDraft.ownerName = 'CepQontag Kullanıcısı';
    QrDraft.vehicleId = '';

    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  String get _displayName {
    final v = OnboardingDraft.displayName.trim();
    return v.isEmpty ? 'Araç Sahibi' : v;
  }

  String get _email {
    final v = OnboardingDraft.email.trim();
    return v.isEmpty ? 'E-posta eklenmemiş' : v;
  }

  String get _phone {
    final v = OnboardingDraft.phone.trim();
    return v.isEmpty ? 'Telefon bilgisi yok' : v;
  }

  String get _initials {
    final parts = _displayName.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).take(2);
    final value = parts.map((e) => e.characters.first.toUpperCase()).join();
    return value.isEmpty ? 'CQ' : value;
  }

  Future<({int? count,bool? premium})> _vehicleStats()async{
    try{
      final response=await OwnerHttp.get(
        Uri.parse('${OnboardingBackend.baseUrl}/api/owner/vehicles'),
        json:false,
      ).timeout(const Duration(seconds:8));
      if(response.statusCode<200||response.statusCode>=300){
        return (count:null,premium:null);
      }
      final raw=jsonDecode(response.body);
      if(raw is! Map||raw['vehicles'] is! List){
        return (count:null,premium:null);
      }
      return (count:(raw['vehicles'] as List).length,premium:raw['premium']==true);
    }catch(_){
      return (count:null,premium:null);
    }
  }

  void _openQrSecurity(BuildContext context){
    final id=QrDraft.vehicleId.trim();
    if(id.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text('Önce Araçlarım sayfasından araç seçin.')),
      );
      return;
    }
    _push(context,QrSecurityPage(vehicleId:id,plate:QrDraft.plate));
  }

  Widget _profileStat(IconData icon,String value,String label){
    return Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      Icon(icon,color:OwnerReference.purple,size:25),
      const SizedBox(height:7),
      Text(value,style:TextStyle(color:OwnerReference.foreground,
        fontSize:20,fontWeight:FontWeight.w900)),
      Text(label,maxLines:2,textAlign:TextAlign.center,
        style:TextStyle(color:OwnerReference.subtitle,fontSize:10.8)),
    ]));
  }

  Widget _mainMenu(BuildContext context){
    final sections=<({IconData icon,String title,String subtitle,VoidCallback onTap})>[
      (icon:Icons.person_outline_rounded,title:'Hesap Bilgilerim',
        subtitle:'Ad, telefon, e-posta ve profil ayarları',
        onTap:()=>_push(context,const OwnerAccountSettingsPage())),
      (icon:Icons.verified_user_outlined,title:'QR Güvenliği',
        subtitle:'QR ve görünür bilgileri yönet',
        onTap:()=>_openQrSecurity(context)),
      (icon:Icons.directions_car_outlined,title:'Araçlarım',
        subtitle:'Araç ekle, düzenle, QR ayarları',
        onTap:onOpenVehicles??()=>_push(context,const OwnerVehicleSummaryPage())),
      (icon:Icons.groups_outlined,title:'Sürücüler',
        subtitle:'Sürücü ekle, yetkilendir',
        onTap:onOpenVehicles??()=>_push(context,const OwnerVehicleSummaryPage())),
      (icon:Icons.workspace_premium_outlined,title:'Premium',
        subtitle:'Paketler ve üyelik yönetimi',
        onTap:()=>_showPremium(context)),
      (icon:Icons.settings_outlined,title:'Uygulama Ayarları',
        subtitle:'Bildirimler, tema, dil',
        onTap:()=>_appSettings(context)),
      (icon:Icons.help_outline_rounded,title:'Yardım & Destek',
        subtitle:'Sık sorulan sorular, destek talebi',
        onTap:()=>_push(context,const SupportTicketPage())),
    ];
    return Container(
      decoration:OwnerReference.card(radius:24),
      child:Column(children:[
        for(var i=0;i<sections.length;i++)...[
          ListTile(
            onTap:sections[i].onTap,
            contentPadding:const EdgeInsets.symmetric(horizontal:15,vertical:3),
            leading:Container(
              height:47,width:47,
              decoration:BoxDecoration(
                color:OwnerReference.lilac,
                borderRadius:BorderRadius.circular(17),
              ),
              child:Icon(sections[i].icon,color:OwnerReference.purple,size:25),
            ),
            title:Text(sections[i].title,
              style:TextStyle(color:OwnerReference.foreground,
                fontSize:14,fontWeight:FontWeight.w900)),
            subtitle:Text(sections[i].subtitle,maxLines:2,
              style:TextStyle(color:OwnerReference.subtitle,fontSize:11.5)),
            trailing:const Icon(Icons.chevron_right_rounded,
              color:OwnerReference.purple),
          ),
          if(i<sections.length-1)Divider(height:1,indent:76,endIndent:15,
            color:OwnerReference.deep.withValues(alpha:.08)),
        ],
      ]),
    );
  }

  void _appSettings(BuildContext context){
    showModalBottomSheet<void>(
      context:context,
      backgroundColor:OwnerReference.surface,
      shape:const RoundedRectangleBorder(borderRadius:
        BorderRadius.vertical(top:Radius.circular(24))),
      builder:(sheetContext)=>SafeArea(child:Padding(
        padding:const EdgeInsets.all(17),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
          const Text('Uygulama Ayarları',style:TextStyle(
            fontSize:18,fontWeight:FontWeight.w900)),
          ListTile(
            leading:const Icon(Icons.notifications_outlined),
            title:const Text('Bildirim Ayarları'),
            onTap:(){Navigator.pop(sheetContext);
              _push(context,const OwnerNotificationSettingsPage());},
          ),
          ListTile(
            leading:const Icon(Icons.do_not_disturb_rounded),
            title:const Text('Rahatsız Etmeyin'),
            onTap:(){Navigator.pop(sheetContext);_push(context,const OwnerDndPage());},
          ),
          const _ThemeProfileRow(),
          ListTile(
            leading:const Icon(Icons.lock_outline_rounded),
            title:const Text('Gizlilik ve Güvenlik'),
            onTap:(){Navigator.pop(sheetContext);
              _push(context,const OwnerPrivacySettingsPage());},
          ),
        ]),
      )),
    );
  }

  @override
  Widget build(BuildContext context){
    final statsFuture=_vehicleStats();
    return Scaffold(
      backgroundColor:OwnerReference.background,
      body:SafeArea(bottom:false,child:ListView(
        padding:const EdgeInsets.fromLTRB(17,7,17,28),
        children:[
          OwnerReferenceHeader(
            onNotifications:onOpenNotifications??
              ()=>_push(context,const OwnerNotificationSettingsPage()),
            onSettings:()=>_appSettings(context),
            unread:false,
          ),
          const SizedBox(height:21),
          Row(children:[
            InkWell(
              onTap:()=>_push(context,const OwnerAccountSettingsPage()),
              child:Stack(clipBehavior:Clip.none,children:[
                Container(
                  height:82,width:82,alignment:Alignment.center,
                  decoration:BoxDecoration(
                    shape:BoxShape.circle,
                    gradient:const LinearGradient(colors:[
                      Color(0xFF5120B8),Color(0xFFA66DFF)]),
                    border:Border.all(color:Colors.white,width:3),
                  ),
                  child:Text(_initials,style:const TextStyle(
                    color:Colors.white,fontWeight:FontWeight.w900,fontSize:26)),
                ),
                Positioned(right:0,bottom:0,child:Container(
                  padding:const EdgeInsets.all(5),
                  decoration:const BoxDecoration(shape:BoxShape.circle,
                    color:OwnerReference.purple),
                  child:const Icon(Icons.photo_camera_outlined,
                    color:Colors.white,size:16),
                )),
              ]),
            ),
            const SizedBox(width:14),
            Expanded(child:Column(
              crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(_displayName,maxLines:2,overflow:TextOverflow.ellipsis,
                  style:TextStyle(color:OwnerReference.foreground,
                    fontSize:19,fontWeight:FontWeight.w900)),
                TextButton.icon(
                  onPressed:()=>_push(context,const OwnerAccountSettingsPage()),
                  style:TextButton.styleFrom(padding:EdgeInsets.zero),
                  icon:const Icon(Icons.edit_outlined,size:14),
                  label:Text(_phone,maxLines:1,overflow:TextOverflow.ellipsis,
                    style:const TextStyle(fontSize:11.5)),
                ),
                Text(_email,maxLines:1,overflow:TextOverflow.ellipsis,
                  style:TextStyle(color:OwnerReference.subtitle,fontSize:11.5)),
              ],
            )),
            const SizedBox(width:7),
            FutureBuilder<({int? count,bool? premium})>(
              future:statsFuture,
              builder:(context,snapshot){
                final isPro=snapshot.data?.premium==true;
                return InkWell(
                  onTap:()=>_showPremium(context),
                  borderRadius:BorderRadius.circular(21),
                  child:Container(
                    width:98,height:84,
                    padding:const EdgeInsets.symmetric(horizontal:9),
                    decoration:const BoxDecoration(
                      borderRadius:BorderRadius.all(Radius.circular(21)),
                      gradient:LinearGradient(colors:[
                        Color(0xFF33105D),Color(0xFF6922DA)]),
                    ),
                    child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                      Icon(Icons.workspace_premium_rounded,
                        color:const Color(0xFFFFCF43),size:23),
                      Text(isPro?'PRO':'Premium',
                        style:const TextStyle(color:Colors.white,
                          fontWeight:FontWeight.w900,fontSize:16)),
                      const Text('Üyelik',style:TextStyle(
                        color:Color(0xFFE5D7FF),fontSize:10)),
                    ]),
                  ),
                );
              },
            ),
          ]),
          const SizedBox(height:20),
          FutureBuilder<({int? count,bool? premium})>(
            future:statsFuture,
            builder:(context,snapshot){
              final count=snapshot.data?.count?.toString()??'—';
              return Container(
                height:115,
                padding:const EdgeInsets.symmetric(horizontal:7),
                decoration:OwnerReference.card(),
                child:Row(children:[
                  _profileStat(Icons.directions_car_outlined,count,'Aracım'),
                  _profileStat(Icons.groups_rounded,'—','Sürücüm'),
                  _profileStat(Icons.access_time_rounded,'—','Park Kaydı'),
                  _profileStat(Icons.favorite_rounded,'—','Favori Yer'),
                ]),
              );
            },
          ),
          const SizedBox(height:18),
          _mainMenu(context),
          const SizedBox(height:20),
          InkWell(
            onTap:()=>_logout(context),
            borderRadius:BorderRadius.circular(22),
            child:Container(
              height:64,padding:const EdgeInsets.symmetric(horizontal:17),
              decoration:BoxDecoration(
                color:const Color(0xFFFFEDF1),
                borderRadius:BorderRadius.circular(22)),
              child:Row(children:[
                const Icon(Icons.logout_rounded,color:OwnerReference.danger),
                const SizedBox(width:15),
                const Expanded(child:Text('Çıkış yap',
                  style:TextStyle(color:OwnerReference.danger,
                    fontWeight:FontWeight.w900,fontSize:17))),
                const Icon(Icons.chevron_right_rounded,color:OwnerReference.danger),
              ]),
            ),
          ),
        ],
      )),
    );
  }

}

class _ProfileBrandHeader extends StatelessWidget {
  const _ProfileBrandHeader({
    required this.initials,
    required this.onNotifications,
  });

  final String initials;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final light = CepqarTheme.isLight;
    final text = CepqarTheme.text;
    final line = CepqarTheme.line;

    return Row(
      children: [
        Image.asset(
          CepqarTheme.isLight ? 'assets/file_00000000b130820abb8d411e67ab0d25.png' : 'assets/Logoyeni.png',
          key: ValueKey(CepqarTheme.isLight),
          height: 31,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
        ),
        const Spacer(),
        Stack(
          clipBehavior: Clip.none,
          children: [
            InkWell(
              onTap: onNotifications,
              customBorder: const CircleBorder(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: light ? Colors.white : const Color(0xFF0B1220),
                  border: Border.all(color: line),
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: text,
                  size: 21,
                ),
              ),
            ),
            const Positioned(
              right: 1,
              top: 0,
              child: CircleAvatar(radius: 4.5, backgroundColor: _danger),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4D17D3), Color(0xFF8A36FF)],
            ),
          ),
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileIdentityCard extends StatelessWidget {
  const _ProfileIdentityCard({
    required this.name,
    required this.email,
    required this.phone,
    required this.initials,
    required this.onProfile,
    required this.onPremium,
  });

  final String name;
  final String email;
  final String phone;
  final String initials;
  final VoidCallback onProfile;
  final VoidCallback onPremium;

  @override
  Widget build(BuildContext context) {
    final light = CepqarTheme.isLight;
    final panel = CepqarTheme.panel;
    final line = CepqarTheme.line;
    final text = CepqarTheme.text;
    final muted = CepqarTheme.muted;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: line),
        boxShadow: light
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .035),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(13),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(7, 5, 6, 7),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF4F16D5), Color(0xFF8D39FF)],
                          ),
                        ),
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -3,
                        bottom: -2,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: light ? const Color(0xFF151728) : const Color(0xFF111728),
                            shape: BoxShape.circle,
                            border: Border.all(color: panel, width: 2),
                          ),
                          child: const Icon(
                            Icons.photo_camera_outlined,
                            color: Colors.white,
                            size: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: text,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Container(
                              width: 15,
                              height: 15,
                              decoration: const BoxDecoration(
                                color: _purple,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: muted, fontSize: 11.2),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: muted, fontSize: 11.2),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: muted, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          InkWell(
            onTap: onPremium,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 43,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: light
                    ? const LinearGradient(
                        colors: [Color(0xFFFFF4CC), Color(0xFFFFF8E6)],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF3A176E), Color(0xFF1F153D)],
                      ),
                border: Border.all(
                  color: light
                      ? const Color(0xFFFFE6A0)
                      : _purple.withValues(alpha: .65),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium_rounded, color: _gold, size: 25),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Premium Üye',
                          style: TextStyle(
                            color: light ? const Color(0xFF634600) : const Color(0xFFFFCC4F),
                            fontSize: 12.8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Daha fazla özellikten yararlanın.',
                          style: TextStyle(color: muted, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: muted, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickProfileAction extends StatelessWidget {
  const _QuickProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final light = CepqarTheme.isLight;
    final panel = CepqarTheme.panel;
    final line = CepqarTheme.line;
    final text = CepqarTheme.text;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 74,
          padding: const EdgeInsets.fromLTRB(3, 8, 3, 6),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: line),
            boxShadow: light
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .025),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: light ? .10 : .16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: _purple, size: 19),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: text,
                  fontSize: CepqarTheme.caption,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeProfileRow extends StatelessWidget {
  const _ThemeProfileRow();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: CepqarTheme.mode,
      builder: (_, mode, __) {
        final dark = mode == ThemeMode.dark;
        final text = CepqarTheme.text;
        final muted = CepqarTheme.muted;
        final line = CepqarTheme.line;

        return Column(
          children: [
            InkWell(
              onTap: () => CepqarTheme.setDarkMode(!dark),
              child: SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  child: Row(
                    children: [
                      Icon(
                        dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: text,
                        size: 17,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Karanlık Mod',
                              style: TextStyle(
                                color: text,
                                fontSize: 12.0,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              dark ? 'Açık' : 'Kapalı • Aydınlık tema',
                              style: TextStyle(
                                color: muted,
                                fontSize: 10.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: dark,
                        onChanged: CepqarTheme.setDarkMode,
                        activeThumbColor: _purple,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 39, right: 10),
              child: Container(height: 1, color: line.withValues(alpha: .72)),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.danger = false,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final text = CepqarTheme.text;
    final muted = CepqarTheme.muted;
    final line = CepqarTheme.line;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 45,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: danger ? _danger : text,
                    size: 17,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: danger ? _danger : text,
                        fontSize: 12.1,
                        fontWeight: danger ? FontWeight.w800 : FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: danger ? _danger.withValues(alpha: .8) : muted,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 39, right: 10),
            child: Container(height: 1, color: line.withValues(alpha: .72)),
          ),
      ],
    );
  }
}
