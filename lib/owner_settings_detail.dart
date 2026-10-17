import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_backend.dart';
import 'qr_backend.dart';
import 'owner_auth.dart';
import 'owner_dnd_card.dart';
import 'cepqar_theme.dart';

const _bg = CepqarTheme.darkBg;
const _panel = Color(0xFFFFFFFF);
const _line = Color(0xFFE8EAF2);
const _purple = Color(0xFF8B5CFF);
const _muted = Color(0xFF778096);
const _baseUrl = 'https://heycar-api-185-165-46-213.nip.io';

Map<String, String> get _ownerHeaders => const {};

Future<void> _showOwnerRecoveryCode(BuildContext context) async {
  try {
    final r=await OwnerHttp.post(Uri.parse('$_baseUrl/api/owner/account/recovery-code')).timeout(const Duration(seconds:15));
    if(r.statusCode<200||r.statusCode>=300)throw Exception();
    final d=jsonDecode(r.body) as Map<String,dynamic>;
    final code='${d['recoveryCode']??''}';
    if(code.isEmpty)throw Exception();
    if(!context.mounted)return;
    await showDialog<void>(context:context,builder:(c)=>AlertDialog(
      backgroundColor:CepqarTheme.panel,
      title:const Text('Kurtarma kodun',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900)),
      content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Text('Bu kod şifreni unutursan hesabını kurtarmak için kullanılır. Güvenli bir yerde sakla. Yeni kod oluşturursan eskisi geçersiz olur.',style:TextStyle(color:_muted,height:1.35)),
        const SizedBox(height:16),
        SelectableText(code,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900,letterSpacing:1.2)),
      ]),
      actions:[
        TextButton(onPressed:()async{await Clipboard.setData(ClipboardData(text:code));if(c.mounted)ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('Kurtarma kodu kopyalandı.')));},child:const Text('Kopyala')),
        FilledButton(onPressed:()=>Navigator.pop(c),style:FilledButton.styleFrom(backgroundColor:_purple),child:const Text('Tamam')),
      ],
    ));
  } catch (_) {
    if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Kurtarma kodu oluşturulamadı.')));
  }
}

Future<void> _deleteOwnerAccount(BuildContext context) async {
  final pass=TextEditingController();
  String? error;bool busy=false;
  final confirmed=await showDialog<bool>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(c,setLocal)=>AlertDialog(
    backgroundColor:CepqarTheme.panel,
    title:const Text('Hesabı kalıcı olarak sil',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w900)),
    content:Column(mainAxisSize:MainAxisSize.min,children:[
      const Text('Araçların, QR bağlantıların, mesajların, bildirimlerin ve hesap oturumların silinecek. Bu işlem geri alınamaz.',style:TextStyle(color:_muted,height:1.35)),
      const SizedBox(height:14),
      TextField(controller:pass,obscureText:true,style:const TextStyle(color:Colors.white),decoration:const InputDecoration(labelText:'Şifren',border:OutlineInputBorder())),
      if(error!=null)...[const SizedBox(height:8),Text(error!,style:const TextStyle(color:Colors.redAccent))],
    ]),
    actions:[
      TextButton(onPressed:busy?null:()=>Navigator.pop(c,false),child:const Text('Vazgeç')),
      FilledButton(
        style:FilledButton.styleFrom(backgroundColor:Colors.redAccent),
        onPressed:busy?null:()async{
          if(pass.text.length<6){setLocal(()=>error='Şifreni gir.');return;}
          setLocal((){busy=true;error=null;});
          try{
            final r=await OwnerHttp.delete(Uri.parse('$_baseUrl/api/owner/account'),body:jsonEncode({'password':pass.text})).timeout(const Duration(seconds:20));
            if(r.statusCode==401){setLocal((){busy=false;error='Şifre yanlış.';});return;}
            if(r.statusCode<200||r.statusCode>=300)throw Exception();
            if(c.mounted)Navigator.pop(c,true);
          }catch(_){setLocal((){busy=false;error='Hesap silinemedi. Tekrar dene.';});}
        },
        child:Text(busy?'Siliniyor...':'Hesabı Sil'),
      ),
    ],
  )));
  pass.dispose();
  if(confirmed!=true)return;
  await OwnerAuth.clear();
  final p=await SharedPreferences.getInstance();
  for(final k in ['owner_logged_in','owner_user_id','owner_phone','owner_display_name','owner_email','owner_vehicle_id','owner_plate','owner_vehicle_type','owner_make','owner_model','owner_qr_token','push_token_registered']){await p.remove(k);}
  if(!context.mounted)return;
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder:(_)=>const _AccountDeletedPage()),(_)=>false);
}

class _AccountDeletedPage extends StatelessWidget{
  const _AccountDeletedPage();
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:CepqarTheme.bg,
    body:SafeArea(child:Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Icon(Icons.check_circle_outline_rounded,color:_purple,size:78),
      const SizedBox(height:18),
      const Text('Hesabın silindi',style:TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.w900)),
      const SizedBox(height:10),
      const Text('Hesabın ve bağlı verilerin silindi. Yeni hesap oluşturmak için CepQontag uygulamasını yeniden açabilirsin.',textAlign:TextAlign.center,style:TextStyle(color:_muted,height:1.4)),
      const SizedBox(height:22),
      OutlinedButton.icon(onPressed:SystemNavigator.pop,icon:const Icon(Icons.close_rounded),label:const Text('Uygulamayı Kapat')),
    ])))),
  );
}

class OwnerAccountSettingsPage extends StatefulWidget {
  const OwnerAccountSettingsPage({super.key});

  @override
  State<OwnerAccountSettingsPage> createState() => _OwnerAccountSettingsPageState();
}

class _OwnerAccountSettingsPageState extends State<OwnerAccountSettingsPage> {
  late final TextEditingController name;
  late final TextEditingController phone;
  late final TextEditingController email;
  bool editing = false;
  bool saving = false;
  Uint8List? avatarBytes;
  bool avatarBusy = false;
  Future<void> _loadAvatar()async{
    try{
      final r=await OwnerHttp.get(Uri.parse('$_baseUrl/api/owner/account/avatar'),json:false);
      if(r.statusCode==200&&mounted)setState(()=>avatarBytes=r.bodyBytes);
    }catch(_){}
  }
  Future<void> _pickAvatar()async{
    if(avatarBusy)return;
    try{
      final x=await ImagePicker().pickImage(source:ImageSource.gallery,maxWidth:900,maxHeight:900,imageQuality:75);
      if(x==null)return;
      final bytes=await x.readAsBytes();
      if(bytes.length>2*1024*1024)throw Exception('Fotoğraf 2 MB sınırını aşıyor.');
      final ext=x.name.toLowerCase().split('.').last;
      final mime=ext=='png'?'image/png':ext=='webp'?'image/webp':'image/jpeg';
      if(mounted)setState(()=>avatarBusy=true);
      final r=await OwnerHttp.put(Uri.parse('$_baseUrl/api/owner/account/avatar'),body:jsonEncode({'mime':mime,'data':base64Encode(bytes)})).timeout(const Duration(seconds:30));
      if(r.statusCode!=200)throw Exception('Fotoğraf yüklenemedi (${r.statusCode}).');
      if(mounted)setState(()=>avatarBytes=bytes);
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}
    finally{if(mounted)setState(()=>avatarBusy=false);}
  }

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    name = TextEditingController(text: OnboardingDraft.displayName.trim());
    phone = TextEditingController(text: OnboardingDraft.phone.trim());
    email = TextEditingController(text: OnboardingDraft.email.trim());
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    email.dispose();
    super.dispose();
  }

  String get _nameValue => name.text.trim().isEmpty ? 'Araç Sahibi' : name.text.trim();
  String get _phoneValue => phone.text.trim().isEmpty ? 'Telefon bilgisi yok' : phone.text.trim();
  String get _emailValue => email.text.trim().isEmpty ? 'E-posta eklenmemiş' : email.text.trim();

  void _cancelEdit() {
    name.text = OnboardingDraft.displayName.trim();
    phone.text = OnboardingDraft.phone.trim();
    email.text = OnboardingDraft.email.trim();
    setState(() => editing = false);
  }

  Future<void> _saveProfile() async {
    if (saving) return;
    final displayName = name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final phoneValue = phone.text.trim();
    final emailValue = email.text.trim();

    if (displayName.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad soyad bilgisini girin.')),
      );
      return;
    }
    if (phoneValue.replaceAll(RegExp(r'\D'), '').length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir telefon numarası girin.')),
      );
      return;
    }
    if (emailValue.isNotEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(emailValue)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir e-posta adresi girin.')),
      );
      return;
    }

    setState(() => saving = true);
    try {
      final r = await OwnerHttp.patch(
        Uri.parse('$_baseUrl/api/owner/account/profile'),
        body: jsonEncode({
          'displayName': displayName,
          'phone': phoneValue,
          'email': emailValue,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
      final error = data is Map ? data['error']?.toString() ?? '' : '';

      if (r.statusCode == 409) {
        final message = error == 'PHONE_IN_USE'
            ? 'Bu telefon numarası başka bir hesapta kullanılıyor.'
            : 'Bu e-posta adresi başka bir hesapta kullanılıyor.';
        throw Exception(message);
      }
      if (r.statusCode == 400) {
        final message = error == 'INVALID_PHONE'
            ? 'Geçerli bir Türkiye cep telefonu numarası girin.'
            : error == 'INVALID_EMAIL'
                ? 'E-posta adresini kontrol edin.'
                : 'Bilgileri kontrol edin.';
        throw Exception(message);
      }
      if (r.statusCode < 200 || r.statusCode >= 300 || data is! Map) {
        throw Exception('Bilgiler kaydedilemedi.');
      }

      final user = data['user'];
      final nextName = user is Map ? user['display_name']?.toString() ?? displayName : displayName;
      final nextPhone = user is Map ? user['phone']?.toString() ?? phoneValue : phoneValue;
      final nextEmail = user is Map ? user['email']?.toString() ?? emailValue : emailValue;

      OnboardingDraft.displayName = nextName;
      OnboardingDraft.phone = nextPhone;
      OnboardingDraft.email = nextEmail;
      QrDraft.ownerName = nextName.isEmpty ? 'CepQontag Kullanıcısı' : nextName;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('owner_display_name', nextName);
      await prefs.setString('owner_phone', nextPhone);
      await prefs.setString('owner_email', nextEmail);

      name.text = nextName;
      phone.text = nextPhone;
      email.text = nextEmail;

      if (!mounted) return;
      setState(() {
        saving = false;
        editing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hesap bilgileri güncellendi.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', '').trim().isEmpty
                ? 'Bilgiler kaydedilemedi.'
                : e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xFF10152D);
    return Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF651FFF), brightness: Brightness.light),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FC),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF8F9FC),
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          title: const Text('Hesap Bilgilerim', style: TextStyle(color: dark, fontWeight: FontWeight.w900, fontSize: 21)),
          leadingWidth: 66,
          leading: Padding(
            padding: const EdgeInsets.only(left: 15, top: 6, bottom: 6),
            child: IconButton.filledTonal(
              onPressed: () => Navigator.maybePop(context),
              style: IconButton.styleFrom(backgroundColor: const Color(0xFFF3EDFF)),
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF4912C8)),
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
            children: [
              Center(
                child: Stack(clipBehavior: Clip.none, children: [
                  CircleAvatar(
                    radius: 64,
                    backgroundColor: const Color(0xFFF3EDFF),
                    foregroundImage: avatarBytes==null?null:MemoryImage(avatarBytes!),
                    child: avatarBytes!=null?null:Text(_nameValue.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).take(2).map((x) => x[0].toUpperCase()).join(),
                      style: const TextStyle(fontSize: 37, color: Color(0xFF651FFF), fontWeight: FontWeight.w800)),
                  ),
                  Positioned(
                    right: -3, bottom: 0,
                    child: IconButton.filled(
                      onPressed: avatarBusy?null:_pickAvatar,
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFF651FFF), foregroundColor: Colors.white),
                      icon: const Icon(Icons.camera_alt_rounded, size: 20),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Center(child: Text(_nameValue, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(color: dark, fontWeight: FontWeight.w900, fontSize: 22))),
              const SizedBox(height: 3),
              Center(child: Text(_phoneValue, style: const TextStyle(color: Color(0xFF778096), fontSize: 15))),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: Text(editing ? 'Bilgilerini düzenle' : 'Kişisel bilgiler', style: const TextStyle(color: dark, fontSize: 22, fontWeight: FontWeight.w900))),
                TextButton.icon(
                  onPressed: saving ? null : () => editing ? _cancelEdit() : setState(() => editing = true),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF651FFF),
                    backgroundColor: const Color(0xFFF3EDFF),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: Icon(editing ? Icons.close_rounded : Icons.edit_rounded, size: 18),
                  label: Text(editing ? 'Vazgeç' : 'Düzenle', style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 12),
              if (!editing) ...[
                _ReferenceAccountTile(icon: Icons.person_outline_rounded, title: 'Ad Soyad', subtitle: _nameValue, onTap: () => setState(() => editing = true)),
                _ReferenceAccountTile(icon: Icons.phone_rounded, title: 'Telefon', subtitle: _phoneValue, onTap: () => setState(() => editing = true)),
                _ReferenceAccountTile(icon: Icons.mail_outline_rounded, title: 'E-posta', subtitle: _emailValue, onTap: () => setState(() => editing = true)),
              ] else ...[
                _EditableAccountField(controller: name, icon: Icons.person_outline_rounded, label: 'Ad Soyad', textCapitalization: TextCapitalization.words, enabled: !saving),
                _EditableAccountField(controller: phone, icon: Icons.phone_outlined, label: 'Telefon', keyboardType: TextInputType.phone, enabled: !saving),
                _EditableAccountField(controller: email, icon: Icons.mail_outline_rounded, label: 'E-posta', keyboardType: TextInputType.emailAddress, enabled: !saving),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: saving ? null : _saveProfile,
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF651FFF), foregroundColor: Colors.white),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(saving ? 'Kaydediliyor...' : 'Değişiklikleri Kaydet'),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              _ReferenceAccountTile(icon: Icons.key_rounded, title: 'Hesap kurtarma kodu', subtitle: 'Şifreni unutursan kullanacağın kodu oluştur.', onTap: () => _showOwnerRecoveryCode(context)),
              _ReferenceAccountTile(icon: Icons.delete_outline_rounded, title: 'Hesabı sil', subtitle: 'Hesabını ve bağlı verilerini kalıcı olarak sil.', onTap: () => _deleteOwnerAccount(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReferenceAccountTile extends StatelessWidget {
  const _ReferenceAccountTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        borderRadius: BorderRadius.circular(21),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE8EAF1)),
            borderRadius: BorderRadius.circular(21),
            boxShadow: [BoxShadow(color: const Color(0xFF10152D).withValues(alpha: .025), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: const Color(0xFFF3EDFF), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: const Color(0xFF651FFF), size: 27),
            ),
            const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Color(0xFF10152D), fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF778096), fontSize: 13)),
            ])),
            const SizedBox(width: 5),
            const Icon(Icons.chevron_right_rounded, size: 24, color: Color(0xFF778096)),
          ]),
        ),
      ),
    ),
  );
}

class _EditableAccountField extends StatelessWidget {
  const _EditableAccountField({
    required this.controller,
    required this.icon,
    required this.label,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.enabled = true,
  });

  final TextEditingController controller;
  final IconData icon;
  final String label;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            Icon(icon, color: _purple, size: 25),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                keyboardType: keyboardType,
                textCapitalization: textCapitalization,
                autocorrect: false,
                style: const TextStyle(
                  color: Color(0xFF10152D),
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  labelText: label,
                  labelStyle: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),
          ],
        ),
      );
}

class OwnerNotificationSettingsPage extends StatefulWidget {
  const OwnerNotificationSettingsPage({super.key});

  @override
  State<OwnerNotificationSettingsPage> createState() => _OwnerNotificationSettingsPageState();
}

class _OwnerNotificationSettingsPageState extends State<OwnerNotificationSettingsPage> {
  bool messages = true;
  bool calls = true;
  bool damage = true;
  bool system = true;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (OnboardingDraft.userId.trim().isEmpty) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Araç sahibi oturumu bulunamadı.';
        });
      }
      return;
    }
    try {
      final r = await OwnerHttp
          .get(Uri.parse('$_baseUrl/api/owner/notification-settings'), headers: _ownerHeaders)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode < 200 || r.statusCode >= 300) throw Exception();
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final settings = Map<String, dynamic>.from(data['settings'] as Map);
      if (!mounted) return;
      setState(() {
        messages = settings['messages'] != false;
        calls = settings['calls'] != false;
        damage = settings['damage'] != false;
        system = settings['system'] != false;
        loading = false;
        error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Bildirim ayarları alınamadı.';
        });
      }
    }
  }

  Future<void> _save() async {
    try {
      final r = await OwnerHttp
          .put(
            Uri.parse('$_baseUrl/api/owner/notification-settings'),
            headers: {..._ownerHeaders, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'messages': messages,
              'calls': calls,
              'damage': damage,
              'system': system,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode < 200 || r.statusCode >= 300) throw Exception();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notify_messages', messages);
      await prefs.setBool('notify_calls', calls);
      await prefs.setBool('notify_damage', damage);
      await prefs.setBool('notify_system', system);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bildirim ayarı sunucuya kaydedilemedi.')),
        );
      }
    }
  }

  void _change(String key, bool value) {
    setState(() {
      if (key == 'messages') messages = value;
      if (key == 'calls') calls = value;
      if (key == 'damage') damage = value;
      if (key == 'system') system = value;
    });
    _save();
  }

  @override
  Widget build(BuildContext context) => _SettingsScaffold(
        title: 'Bildirim ayarları',
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: _purple)),
              )
            : Column(
                children: [
                  const OwnerDndCard(),
                  const SizedBox(height: 12),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(error!, style: const TextStyle(color: Colors.orangeAccent)),
                    ),
                  _SwitchTile(
                    title: 'Mesaj bildirimleri',
                    subtitle: 'QR üzerinden gelen mesajları bildir',
                    value: messages,
                    onChanged: (v) => _change('messages', v),
                  ),
                  _SwitchTile(
                    title: 'Arama talepleri',
                    subtitle: 'Gizli arama taleplerini bildir',
                    value: calls,
                    onChanged: (v) => _change('calls', v),
                  ),
                  _SwitchTile(
                    title: 'Hasar bildirimleri',
                    subtitle: 'Araç hasarı bildirimlerini öne çıkar',
                    value: damage,
                    onChanged: (v) => _change('damage', v),
                  ),
                  _SwitchTile(
                    title: 'Sistem bildirimleri',
                    subtitle: 'HeyCar servis ve güvenlik bildirimleri',
                    value: system,
                    onChanged: (v) => _change('system', v),
                  ),
                ],
              ),
      );
}

class OwnerPrivacySettingsPage extends StatefulWidget {
  const OwnerPrivacySettingsPage({super.key});

  @override
  State<OwnerPrivacySettingsPage> createState() => _OwnerPrivacySettingsPageState();
}

class _OwnerPrivacySettingsPageState extends State<OwnerPrivacySettingsPage> {
  bool suspiciousLoginAlerts = true;
  bool qrAbuseProtection = true;
  bool autoCloseOldChats = true;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (OnboardingDraft.userId.trim().isEmpty) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Araç sahibi oturumu bulunamadı.';
        });
      }
      return;
    }
    try {
      final r = await OwnerHttp
          .get(Uri.parse('$_baseUrl/api/owner/privacy-settings'), headers: _ownerHeaders)
          .timeout(const Duration(seconds: 15));
      if (r.statusCode < 200 || r.statusCode >= 300) throw Exception();
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final settings = Map<String, dynamic>.from(data['settings'] as Map);
      if (!mounted) return;
      setState(() {
        suspiciousLoginAlerts = settings['suspiciousLoginAlerts'] != false;
        qrAbuseProtection = settings['qrAbuseProtection'] != false;
        autoCloseOldChats = settings['autoCloseOldChats'] != false;
        loading = false;
        error = null;
      });
      await _registerThisDevice();
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Güvenlik ayarları alınamadı.';
        });
      }
    }
  }

  Future<void> _save() async {
    try {
      final r = await OwnerHttp
          .put(
            Uri.parse('$_baseUrl/api/owner/privacy-settings'),
            headers: {..._ownerHeaders, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'suspiciousLoginAlerts': suspiciousLoginAlerts,
              'qrAbuseProtection': qrAbuseProtection,
              'autoCloseOldChats': autoCloseOldChats,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode < 200 || r.statusCode >= 300) throw Exception();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ayar sunucuya kaydedilemedi.')),
        );
      }
    }
  }

  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('owner_device_id');
    if (id == null || id.isEmpty) {
      final random = Random.secure();
      id = List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
      await prefs.setString('owner_device_id', id);
    }
    return id;
  }

  Future<void> _registerThisDevice() async {
    final id = await _deviceId();
    try {
      await OwnerHttp
          .post(
            Uri.parse('$_baseUrl/api/owner/device-presence'),
            headers: {..._ownerHeaders, 'Content-Type': 'application/json'},
            body: jsonEncode({'deviceId': id, 'deviceName': 'Android cihaz'}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  Future<void> _renewSecurity() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CepqarTheme.panel,
        title: const Text(
          'Güvenlik kodunu yenile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Eski cihaz oturumları kapatılacak. Devam edilsin mi?',
          style: TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: _purple),
            child: const Text('Yenile'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final id = await _deviceId();
      final r = await OwnerHttp
          .post(
            Uri.parse('$_baseUrl/api/owner/privacy-reset'),
            headers: {..._ownerHeaders, 'Content-Type': 'application/json'},
            body: jsonEncode({'keepDeviceId': id}),
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode < 200 || r.statusCode >= 300) throw Exception();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Güvenlik kodu yenilendi, diğer oturumlar kapatıldı.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Güvenlik kodu yenilenemedi.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => _SettingsScaffold(
        title: 'Gizlilik ve güvenlik',
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: _purple)),
              )
            : Column(
                children: [
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(error!, style: const TextStyle(color: Colors.orangeAccent)),
                    ),
                  _SwitchTile(
                    title: 'Şüpheli giriş uyarıları',
                    subtitle: 'Yeni cihaz veya olağandışı girişte seni uyar',
                    value: suspiciousLoginAlerts,
                    onChanged: (v) {
                      setState(() => suspiciousLoginAlerts = v);
                      _save();
                    },
                  ),
                  _SwitchTile(
                    title: 'QR kötüye kullanım koruması',
                    subtitle: 'Aynı kişiden gelen aşırı istekleri otomatik sınırla',
                    value: qrAbuseProtection,
                    onChanged: (v) {
                      setState(() => qrAbuseProtection = v);
                      _save();
                    },
                  ),
                  _SwitchTile(
                    title: 'Eski sohbetleri otomatik kapat',
                    subtitle: '30 gün kullanılmayan QR sohbetlerini arşivle',
                    value: autoCloseOldChats,
                    onChanged: (v) {
                      setState(() => autoCloseOldChats = v);
                      _save();
                    },
                  ),
                  const SizedBox(height: 4),
                  _ActionTile(
                    icon: Icons.devices_outlined,
                    title: 'Açık oturumlar',
                    subtitle: 'Hesabının açık olduğu cihazları görüntüle',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OwnerActiveSessionsPage()),
                    ),
                  ),
                  _ActionTile(
                    icon: Icons.block_rounded,
                    title: 'Engellenen kişiler',
                    subtitle: 'Engellediğin QR ziyaretçilerini yönet',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const OwnerBlockedVisitorsPage()),
                    ),
                  ),
                  _ActionTile(
                    icon: Icons.lock_reset_rounded,
                    title: 'Güvenlik kodunu yenile',
                    subtitle: 'Güvenlik anahtarını yenileyerek eski oturumları kapat',
                    onTap: _renewSecurity,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _line),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_outlined, color: _purple),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Telefon numaran ve kişisel bilgilerin HeyCar public QR ekranında hiçbir zaman gösterilmez.',
                            style: TextStyle(color: _muted, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      );
}

class OwnerActiveSessionsPage extends StatefulWidget {
  const OwnerActiveSessionsPage({super.key});

  @override
  State<OwnerActiveSessionsPage> createState() => _OwnerActiveSessionsPageState();
}

class _OwnerActiveSessionsPageState extends State<OwnerActiveSessionsPage> {
  List<Map<String, dynamic>> devices = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await OwnerHttp
          .get(Uri.parse('$_baseUrl/api/owner/devices'), headers: _ownerHeaders)
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final list = data['devices'];
      if (r.statusCode >= 200 && r.statusCode < 300 && list is List && mounted) {
        setState(() {
          devices = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          loading = false;
        });
      } else {
        throw Exception();
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _SettingsScaffold(
        title: 'Açık oturumlar',
        child: loading
            ? const Center(child: CircularProgressIndicator(color: _purple))
            : devices.isEmpty
                ? const _EmptyBox(
                    icon: Icons.devices_outlined,
                    title: 'Aktif oturum yok',
                    subtitle: 'Aktif cihazlar burada görünecek.',
                  )
                : Column(
                    children: devices
                        .map(
                          (d) => _InfoTile(
                            icon: Icons.smartphone_rounded,
                            label: d['device_name']?.toString() ?? 'Cihaz',
                            value: 'Son erişim: ${_formatDate(d['last_seen_at'])}',
                          ),
                        )
                        .toList(),
                  ),
      );
}

class OwnerBlockedVisitorsPage extends StatefulWidget {
  const OwnerBlockedVisitorsPage({super.key});

  @override
  State<OwnerBlockedVisitorsPage> createState() => _OwnerBlockedVisitorsPageState();
}

class _OwnerBlockedVisitorsPageState extends State<OwnerBlockedVisitorsPage> {
  List<Map<String, dynamic>> blocked = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await OwnerHttp
          .get(Uri.parse('$_baseUrl/api/owner/blocked-visitors'), headers: _ownerHeaders)
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      final list = data['visitors'];
      if (r.statusCode >= 200 && r.statusCode < 300 && list is List && mounted) {
        setState(() {
          blocked = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          loading = false;
        });
      } else {
        throw Exception();
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _remove(String key) async {
    try {
      await OwnerHttp
          .delete(
            Uri.parse('$_baseUrl/api/owner/blocked-visitors/${Uri.encodeComponent(key)}'),
            headers: _ownerHeaders,
          )
          .timeout(const Duration(seconds: 15));
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => _SettingsScaffold(
        title: 'Engellenen kişiler',
        child: loading
            ? const Center(child: CircularProgressIndicator(color: _purple))
            : blocked.isEmpty
                ? const _EmptyBox(
                    icon: Icons.block_rounded,
                    title: 'Engellenen ziyaretçi yok',
                    subtitle: 'Engellediğin QR ziyaretçileri burada görünür.',
                  )
                : Column(
                    children: blocked.map((item) {
                      final key = item['visitor_key']?.toString() ?? '';
                      final shortKey = key.length > 6 ? key.substring(0, 6) : key;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _panel,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _line),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person_off_outlined, color: _purple),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Anonim ziyaretçi $shortKey',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                              ),
                            ),
                            TextButton(
                              onPressed: () => _remove(key),
                              child: const Text('Engeli kaldır'),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
      );
}

class OwnerVehicleSummaryPage extends StatelessWidget {
  const OwnerVehicleSummaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final model = QrDraft.model.trim();
    final vehicle = '${QrDraft.make.trim()} ${model.isEmpty ? '' : model}'.trim();
    return _SettingsScaffold(
      title: 'Araç bilgileri',
      child: Column(
        children: [
          _InfoTile(
            icon: Icons.directions_car_filled_rounded,
            label: 'Araç',
            value: vehicle.isEmpty ? 'Araç bilgisi yok' : vehicle,
          ),
          _InfoTile(
            icon: Icons.pin_outlined,
            label: 'Plaka',
            value: QrDraft.plate.trim().isEmpty ? 'Plaka yok' : QrDraft.plate.trim(),
          ),
          _InfoTile(
            icon: Icons.qr_code_2_rounded,
            label: 'QR Etiketi',
            value: QrDraft.token.trim().isEmpty ? 'Aktif QR bulunamadı' : QrDraft.token.trim(),
          ),
        ],
      ),
    );
  }
}

String _formatDate(dynamic raw) {
  final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (d == null) return '-';
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _SettingsScaffold extends StatelessWidget {
  const _SettingsScaffold({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF8F9FC),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF8F9FC),
          foregroundColor: const Color(0xFF10152D),
          elevation: 0,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [child],
        ),
      );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            Icon(icon, color: _purple, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF10152D),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: CepqarTheme.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CepqarTheme.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: CepqarTheme.text,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: CepqarTheme.muted, fontSize: 12.5, height: 1.25),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: _purple,
            ),
          ],
        ),
      );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              child: Row(
                children: [
                  Icon(icon, color: _purple, size: 25),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF10152D),
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.25),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF778096)),
                ],
              ),
            ),
          ),
        ),
      );
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
        ),
        child: Column(
          children: [
            Icon(icon, color: _purple, size: 42),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: _muted)),
          ],
        ),
      );
}


/// Loads the authenticated owner's photo for home and profile headers.
/// Falls back to initials when no image has been uploaded.
class OwnerAvatar extends StatefulWidget {
  const OwnerAvatar({super.key, required this.initials, required this.radius,
    this.backgroundColor = const Color(0xFFF2EDFF),
    this.foregroundColor = const Color(0xFF211751)});
  final String initials;
  final double radius;
  final Color backgroundColor, foregroundColor;

  @override
  State<OwnerAvatar> createState() => _OwnerAvatarState();
}

class _OwnerAvatarState extends State<OwnerAvatar> {
  Uint8List? _bytes;
  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    try {
      final response = await OwnerHttp.get(
        Uri.parse('$_baseUrl/api/owner/account/avatar'), json: false,
      ).timeout(const Duration(seconds: 8));
      if (mounted && response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        setState(() => _bytes = response.bodyBytes);
      }
    } catch (_) {
      // A missing photo or a temporary network error keeps the initials visible.
    }
  }
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: widget.radius,
    backgroundColor: widget.backgroundColor,
    foregroundImage: _bytes == null ? null : MemoryImage(_bytes!),
    child: _bytes == null ? Text(widget.initials, maxLines: 1,
      style: TextStyle(color: widget.foregroundColor,
        fontSize: widget.radius * .62, fontWeight: FontWeight.w800)) : null,
  );
}
