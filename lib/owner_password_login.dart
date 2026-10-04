import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'onboarding_backend.dart';
import 'qr_backend.dart';
import 'owner_auth.dart';
import 'account_recovery_page.dart';

const _bg = Color(0xFFFDFDFF);
const _panel = Colors.white;
const _line = Color(0xFFE5E7EF);
const _purple = Color(0xFF5E24F5);
const _purple2 = Color(0xFF7A35FF);
const _text = Color(0xFF090B18);
const _muted = Color(0xFF747A8D);

class PasswordOwnerLoginScreen extends StatefulWidget {
  const PasswordOwnerLoginScreen({super.key, required this.onDone, required this.onBack});
  final VoidCallback onDone;
  final VoidCallback onBack;

  @override
  State<PasswordOwnerLoginScreen> createState() => _PasswordOwnerLoginScreenState();
}

class _PasswordOwnerLoginScreenState extends State<PasswordOwnerLoginScreen> {
  final phone = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  bool busy = false;

  @override
  void dispose() {
    phone.dispose();
    password.dispose();
    super.dispose();
  }

  String? _normalize(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('90') && digits.length == 12) digits = digits.substring(2);
    if (digits.startsWith('0') && digits.length == 11) digits = digits.substring(1);
    if (!RegExp(r'^5\d{9}$').hasMatch(digits)) return null;
    return '+90$digits';
  }

  Future<void> _login() async {
    if (busy) return;
    final normalized = _normalize(phone.text);
    if (normalized == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçerli bir Türkiye cep telefonu numarası gir.')));
      return;
    }
    if (password.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifreni gir.')));
      return;
    }

    setState(() => busy = true);
    try {
      final r = await http.post(
        Uri.parse('${OnboardingBackend.baseUrl}/api/owner/login-phone'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': normalized, 'password': password.text}),
      ).timeout(const Duration(seconds: 15));

      final data = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body);
      if (r.statusCode >= 200 && r.statusCode < 300 && data is Map<String, dynamic>) {
        await OwnerAuth.saveFrom(data);
        final user = data['user'];
        final vehicles = data['vehicles'];
        if (user is Map) {
          OnboardingDraft.userId = user['id']?.toString() ?? '';
          OnboardingDraft.phone = user['phone']?.toString() ?? normalized;
          OnboardingDraft.displayName = user['display_name']?.toString() ?? '';
          OnboardingDraft.email = user['email']?.toString() ?? '';
        }
        // Always clear the previous account's selected vehicle before applying
        // the newly authenticated owner's vehicle list.
        OnboardingDraft.vehicleId = '';
        QrDraft.vehicleId = '';
        QrDraft.plate = '';
        QrDraft.make = '';
        QrDraft.model = '';
        QrDraft.token = '';
        QrDraft.scanSecret = '';
        QrDraft.ownerName = OnboardingDraft.displayName.isEmpty ? 'HeyCar Kullanıcısı' : OnboardingDraft.displayName;
        if (vehicles is List && vehicles.isNotEmpty && vehicles.first is Map) {
          final v = Map<String, dynamic>.from(vehicles.first as Map);
          OnboardingDraft.vehicleId = v['id']?.toString() ?? '';
          QrDraft.vehicleId = OnboardingDraft.vehicleId;
          QrDraft.plate = v['plate']?.toString() ?? '';
          QrDraft.make = v['make']?.toString() ?? '';
          QrDraft.model = v['model']?.toString() ?? '';
          QrDraft.token = v['qr_token']?.toString() ?? '';
          QrDraft.scanSecret = v['qr_scan_secret']?.toString() ?? '';
          QrDraft.ownerName = OnboardingDraft.displayName.isEmpty ? 'HeyCar Kullanıcısı' : OnboardingDraft.displayName;
        }
        if (mounted) widget.onDone();
        return;
      }

      final code = data is Map ? data['error']?.toString() ?? '' : '';
      final message = switch (code) {
        'USER_NOT_FOUND' => 'Telefon numarası veya şifre hatalı.',
        'INVALID_CREDENTIALS' => 'Telefon numarası veya şifre hatalı.',
        'USER_SUSPENDED' => 'Bu hesap şu anda kullanıma kapalı.',
        'PASSWORD_INVALID' => 'Telefon numarası veya şifre hatalı.',
        'INVALID_PHONE' => 'Geçerli bir cep telefonu numarası gir.',
        _ => 'Giriş yapılamadı. Tekrar dene.',
      };
      throw Exception(message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size=MediaQuery.sizeOf(context);
    final compact=size.height<720;
    return Scaffold(
      backgroundColor:_bg,
      body:SafeArea(
        child:Center(
          child:ConstrainedBox(
            constraints:const BoxConstraints(maxWidth:460),
            child:SingleChildScrollView(
              padding:EdgeInsets.fromLTRB(20,10,20,compact?104:110),
              child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Row(children:[
                    InkWell(
                      onTap:widget.onBack,
                      borderRadius:BorderRadius.circular(14),
                      child:Container(
                        width:40,height:40,
                        decoration:BoxDecoration(
                          color:Colors.white,
                          borderRadius:BorderRadius.circular(14),
                          border:Border.all(color:_line),
                        ),
                        child:const Icon(Icons.arrow_back_rounded,color:_text,size:20),
                      ),
                    ),
                    const Spacer(),
                    Image.asset(
                      'assets/Aylogo.png',
                      height:compact?30:32,
                      fit:BoxFit.contain,
                      filterQuality:FilterQuality.high,
                    ),
                    const Spacer(),
                    const SizedBox(width:40),
                  ]),
                  SizedBox(height:compact?12:15),
                  Container(
                    height:compact?172:190,
                    width:double.infinity,
                    clipBehavior:Clip.antiAlias,
                    decoration:BoxDecoration(
                      borderRadius:BorderRadius.circular(24),
                      border:Border.all(color:const Color(0xFFE9E3FF)),
                    ),
                    child:Stack(
                      fit:StackFit.expand,
                      children:[
                        Image.asset(
                          'assets/IMG_20261004_191854.png',
                          fit:BoxFit.cover,
                          alignment:const Alignment(.25,.52),
                          filterQuality:FilterQuality.high,
                        ),
                        DecoratedBox(
                          decoration:BoxDecoration(
                            gradient:LinearGradient(
                              begin:Alignment.topLeft,
                              end:Alignment.bottomRight,
                              colors:[
                                Colors.white.withValues(alpha:.90),
                                Colors.white.withValues(alpha:.48),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left:18,
                          top:18,
                          width:205,
                          child:Column(
                            crossAxisAlignment:CrossAxisAlignment.start,
                            children:[
                              Container(
                                padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
                                decoration:BoxDecoration(
                                  color:const Color(0xFFF0E8FF),
                                  borderRadius:BorderRadius.circular(18),
                                ),
                                child:const Row(
                                  mainAxisSize:MainAxisSize.min,
                                  children:[
                                    Icon(Icons.lock_outline_rounded,color:_purple,size:14),
                                    SizedBox(width:6),
                                    Text('GÜVENLİ GİRİŞ',style:TextStyle(color:_purple,fontSize:10.5,fontWeight:FontWeight.w900)),
                                  ],
                                ),
                              ),
                              const SizedBox(height:11),
                              Text(
                                'Tekrar hoş geldin',
                                style:TextStyle(
                                  color:_text,
                                  fontSize:compact?24:27,
                                  height:1,
                                  fontWeight:FontWeight.w900,
                                  letterSpacing:-1,
                                ),
                              ),
                              const SizedBox(height:7),
                              Text(
                                'Aracınla ilgili tüm bildirimlere\nve hizmetlere ulaş.',
                                style:TextStyle(color:_muted,fontSize:compact?11.5:12.5,height:1.35,fontWeight:FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height:compact?17:20),
                  Text(
                    'Giriş Yap',
                    style:TextStyle(color:_text,fontSize:compact?25:28,fontWeight:FontWeight.w900,letterSpacing:-.8),
                  ),
                  const SizedBox(height:4),
                  const Text(
                    'CepQontag hesabına telefon numaran ve şifrenle giriş yap.',
                    style:TextStyle(color:_muted,fontSize:11.5,height:1.35),
                  ),
                  SizedBox(height:compact?15:18),
                  const Text('Telefon Numarası',style:TextStyle(color:_text,fontSize:12.5,fontWeight:FontWeight.w800)),
                  const SizedBox(height:6),
                  TextField(
                    controller:phone,
                    keyboardType:TextInputType.phone,
                    style:const TextStyle(color:_text,fontWeight:FontWeight.w700,fontSize:14),
                    decoration:_input('5XX XXX XX XX',Icons.phone_rounded),
                  ),
                  const SizedBox(height:12),
                  const Text('Şifre',style:TextStyle(color:_text,fontSize:12.5,fontWeight:FontWeight.w800)),
                  const SizedBox(height:6),
                  TextField(
                    controller:password,
                    obscureText:obscure,
                    style:const TextStyle(color:_text,fontWeight:FontWeight.w700,fontSize:14),
                    decoration:_input('Şifreni gir',Icons.lock_outline_rounded).copyWith(
                      suffixIcon:IconButton(
                        onPressed:()=>setState(()=>obscure=!obscure),
                        icon:Icon(obscure?Icons.visibility_outlined:Icons.visibility_off_outlined,color:_muted,size:19),
                      ),
                    ),
                  ),
                  Align(
                    alignment:Alignment.centerRight,
                    child:TextButton(
                      onPressed:busy?null:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const AccountRecoveryPage(mode:'owner'))),
                      style:TextButton.styleFrom(
                        foregroundColor:_purple,
                        padding:const EdgeInsets.symmetric(horizontal:4,vertical:5),
                        minimumSize:const Size(0,34),
                      ),
                      child:const Text('Şifremi unuttum',style:TextStyle(fontSize:11.5,fontWeight:FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(height:5),
                  SizedBox(
                    width:double.infinity,
                    height:52,
                    child:FilledButton(
                      onPressed:busy?null:_login,
                      style:FilledButton.styleFrom(
                        backgroundColor:_purple,
                        foregroundColor:Colors.white,
                        disabledBackgroundColor:_purple.withValues(alpha:.55),
                        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(17)),
                        elevation:0,
                      ),
                      child:Row(
                        mainAxisAlignment:MainAxisAlignment.center,
                        children:[
                          if(busy)
                            const SizedBox(width:17,height:17,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
                          else
                            const Icon(Icons.person_rounded,size:19),
                          const SizedBox(width:10),
                          Text(busy?'Giriş yapılıyor...':'Giriş Yap',style:const TextStyle(fontSize:15.5,fontWeight:FontWeight.w900)),
                          if(!busy)...[
                            const SizedBox(width:11),
                            const Icon(Icons.arrow_forward_rounded,size:20),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height:12),
                  Row(children:[
                    Expanded(child:Container(height:1,color:_line)),
                    const Padding(
                      padding:EdgeInsets.symmetric(horizontal:10),
                      child:Text('GÜVENLİ • ANONİM • HIZLI',style:TextStyle(color:_muted,fontSize:8.5,fontWeight:FontWeight.w700,letterSpacing:.5)),
                    ),
                    Expanded(child:Container(height:1,color:_line)),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _input(String hint, IconData icon) => InputDecoration(
        hintText:hint,
        hintStyle:const TextStyle(color:Color(0xFF9AA0AF),fontSize:13),
        prefixIcon:Icon(icon,color:_purple,size:18),
        filled:true,
        fillColor:Colors.white,
        isDense:true,
        contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:15),
        enabledBorder:OutlineInputBorder(
          borderRadius:BorderRadius.circular(15),
          borderSide:const BorderSide(color:_line),
        ),
        focusedBorder:OutlineInputBorder(
          borderRadius:BorderRadius.circular(15),
          borderSide:const BorderSide(color:_purple,width:1.5),
        ),
      );

