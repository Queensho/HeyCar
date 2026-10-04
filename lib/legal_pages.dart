import 'package:flutter/material.dart';

const _bg=Color(0xFFFDFDFF),_panel=Colors.white,_line=Color(0xFFE5E7EF),_purple=Color(0xFF5E24F5),_muted=Color(0xFF747A8D),_text=Color(0xFF090B18);
const legalVersion='1.0';
const legalUpdated='22 Eylül 2026';

class LegalCenterPage extends StatelessWidget{
  const LegalCenterPage({super.key});
  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:_bg,
    body:SafeArea(
      child:Center(
        child:ConstrainedBox(
          constraints:const BoxConstraints(maxWidth:460),
          child:ListView(
            padding:const EdgeInsets.fromLTRB(20,10,20,28),
            children:[
              Row(children:[
                InkWell(
                  onTap:()=>Navigator.pop(context),
                  borderRadius:BorderRadius.circular(14),
                  child:Container(
                    width:40,height:40,
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:_line)),
                    child:const Icon(Icons.arrow_back_rounded,color:_text,size:20),
                  ),
                ),
                const Spacer(),
                Image.asset('assets/Aylogo.png',height:31,fit:BoxFit.contain),
                const Spacer(),
                const SizedBox(width:40),
              ]),
              const SizedBox(height:16),
              const Text('Yasal ve Gizlilik',style:TextStyle(color:_text,fontSize:26,fontWeight:FontWeight.w900,letterSpacing:-.8)),
              const SizedBox(height:4),
              const Text('CepQontag kullanım koşullarını ve kişisel veri metinlerini buradan inceleyebilirsin.',style:TextStyle(color:_muted,fontSize:11.3,height:1.4)),
              const SizedBox(height:17),
              _legalCard(context,Icons.description_outlined,'Kullanım Şartları','Hizmetin kullanım kuralları, yasaklı kullanımlar ve sorumluluklar.',const TermsOfUsePage()),
              const SizedBox(height:10),
              _legalCard(context,Icons.privacy_tip_outlined,'Gizlilik ve KVKK','İşlenen veriler, amaçlar, saklama süreleri ve KVKK kapsamındaki hakların.',const PrivacyKvkkPage()),
              const SizedBox(height:17),
              Container(
                padding:const EdgeInsets.all(11),
                decoration:BoxDecoration(color:const Color(0xFFF8F6FF),borderRadius:BorderRadius.circular(13),border:Border.all(color:const Color(0xFFE7E0FA))),
                child:const Row(children:[
                  Icon(Icons.verified_user_outlined,color:_purple,size:18),
                  SizedBox(width:9),
                  Expanded(child:Text('Sürüm $legalVersion • Son güncelleme $legalUpdated',style:TextStyle(color:_muted,fontSize:10.2,fontWeight:FontWeight.w600))),
                ]),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _legalCard(BuildContext c,IconData icon,String title,String sub,Widget page)=>Material(
    color:Colors.white,
    borderRadius:BorderRadius.circular(16),
    child:InkWell(
      onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>page)),
      borderRadius:BorderRadius.circular(16),
      child:Container(
        padding:const EdgeInsets.all(13),
        decoration:BoxDecoration(
          border:Border.all(color:_line),
          borderRadius:BorderRadius.circular(16),
          boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.025),blurRadius:10,offset:const Offset(0,3))],
        ),
        child:Row(children:[
          Container(
            width:40,height:40,
            decoration:BoxDecoration(color:const Color(0xFFF0E8FF),borderRadius:BorderRadius.circular(12)),
            child:Icon(icon,color:_purple,size:20),
          ),
          const SizedBox(width:11),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(title,style:const TextStyle(color:_text,fontWeight:FontWeight.w900,fontSize:13)),
            const SizedBox(height:3),
            Text(sub,style:const TextStyle(color:_muted,height:1.3,fontSize:10)),
          ])),
          const Icon(Icons.chevron_right_rounded,color:Color(0xFF9AA0AF),size:19),
        ]),
      ),
    ),
  );
}

class TermsOfUsePage extends StatelessWidget{
  const TermsOfUsePage({super.key});
  @override Widget build(BuildContext context)=>const _LegalDocument(
    title:'Kullanım Şartları',
    intro:'CepQontag’ı kullanarak aşağıdaki şartları kabul etmiş olursun. Bu metin araç sahipleri, yetkili sürücüler ve QR üzerinden iletişim kuran ziyaretçiler için geçerlidir.',
    sections:[
      ('1. Hizmetin kapsamı','CepQontag; araca özel QR kod üzerinden anonim mesaj, bildirim ve uygun olduğu durumlarda gizli arama iletişimi kurulmasını; araç sahibi ve yetkili sürücülerin araç, park, bakım, hatırlatma ve iletişim özelliklerini kullanmasını sağlayan dijital bir hizmettir. CepQontag acil yardım, kolluk, yol yardım veya resmi ihbar hattı değildir.'),
      ('2. Hesap ve güvenlik','Kullanıcı, hesap bilgilerinin doğru tutulmasından, şifresinin ve kurtarma kodunun güvenliğinden sorumludur. Hesabın yetkisiz kullanıldığını düşünüyorsan şifreni değiştirmen ve aktif oturumları kapatman gerekir.'),
      ('3. QR ve araç kullanımı','Bir QR etiketi yalnızca yetkili olduğun araca bağlanmalıdır. Başkasına ait araç, plaka veya QR kodu üzerinde yetkisiz işlem yapılamaz. Araç sahibi, yetkili sürücü ekleme ve kaldırma işlemlerinden sorumludur.'),
      ('4. Anonim iletişim kuralları','Tehdit, taciz, hakaret, ayrımcılık, dolandırıcılık, spam, kişisel veri ifşası, yasa dışı içerik ve güvenliği tehlikeye atan kullanım yasaktır. Kullanıcılar başkalarının kimliğini tespit etmeye veya anonimliği kötüye kullanmaya çalışamaz.'),
      ('5. Arama ve mesajlar','Mesaj ve arama özellikleri yalnızca araçla ilgili makul iletişim amacıyla kullanılmalıdır. Bağlantı, cihaz, işletim sistemi veya bildirim izinleri nedeniyle teslimat gecikebilir ya da başarısız olabilir. Acil durumlarda 112 ve ilgili resmi kanallar kullanılmalıdır.'),
      ('6. Konum, kamera ve mikrofon','Park konumu, QR tarama, sesli arama veya benzeri özellikler cihaz izni gerektirebilir. İzin vermediğinde ilgili özellik çalışmayabilir; temel hesap erişimin mümkün olduğu ölçüde devam eder.'),
      ('7. Premium ve ücretli özellikler','Ücretli özellikler sunulduğunda fiyat, dönem, yenileme ve iptal koşulları satın alma ekranında ayrıca gösterilir. Mağaza üzerinden yapılan ödemelerde ilgili uygulama mağazasının ödeme ve iade kuralları da uygulanır.'),
      ('8. Hizmetin kötüye kullanımı','Güvenlik ihlali, yetkisiz erişim, otomatik isteklerle sistemi zorlamak, tersine mühendislik, zararlı yazılım, sahte hesap veya hizmeti hukuka aykırı kullanmak yasaktır. Gerekli durumlarda erişim geçici veya kalıcı olarak sınırlandırılabilir.'),
      ('9. Hizmet sürekliliği','CepQontag makul süreklilik ve güvenlik sağlamayı hedefler ancak internet, üçüncü taraf servisleri, bakım, arıza veya mücbir sebepler nedeniyle kesintisiz çalışma garanti edilmez.'),
      ('10. Fikri mülkiyet','CepQontag adı, tasarımı, yazılımı, görselleri ve hizmete ait diğer içerikler ilgili hak sahiplerine aittir. Yazılı izin olmadan çoğaltılamaz, satılamaz veya ticari olarak kullanılamaz.'),
      ('11. Hesap kapatma','Kullanıcı uygulama içinden hesabını silebilir. Hesap silme işlemi geri alınamaz; hukuki yükümlülük nedeniyle tutulması zorunlu kayıtlar varsa yalnızca gerekli süre boyunca saklanabilir.'),
      ('12. Değişiklikler','Şartlar; ürün, mevzuat veya güvenlik gereksinimleri değiştiğinde güncellenebilir. Önemli değişiklikler uygulama içinde veya uygun iletişim kanallarıyla duyurulur.'),
      ('13. Uygulanacak hukuk','Bu şartlar Türkiye Cumhuriyeti hukukuna tabidir. Tüketici işlemlerinde kullanıcının mevzuattan doğan başvuru ve yetkili merci hakları saklıdır.'),
      ('14. İletişim','Hizmetle ilgili talepler uygulama içi destek kanalı veya uygulama mağazasında CepQontag yayıncısı için gösterilen geliştirici iletişim bilgileri üzerinden iletilebilir.'),
    ],
  );
}

class PrivacyKvkkPage extends StatelessWidget{
  const PrivacyKvkkPage({super.key});
  @override Widget build(BuildContext context)=>const _LegalDocument(
    title:'Gizlilik ve KVKK',
    intro:'Bu aydınlatma metni, 6698 sayılı Kişisel Verilerin Korunması Kanunu (KVKK) kapsamında CepQontag kullanılırken işlenen kişisel veriler hakkında bilgi verir.',
    sections:[
      ('1. Veri sorumlusu','Veri sorumlusu, CepQontag mobil uygulamasının uygulama mağazası sayfasında geliştirici/yayıncı olarak belirtilen gerçek veya tüzel kişidir. Veri sorumlusuna uygulama içi destek kanalı ve mağaza geliştirici iletişim bilgileri üzerinden ulaşılabilir.'),
      ('2. İşlenen veri kategorileri','Hesap bilgileri (telefon, ad-soyad, e-posta), kimlik doğrulama ve oturum kayıtları, araç bilgileri (plaka, marka, model), QR ve araç yetkilendirme kayıtları, mesaj/bildirim/arama işlem kayıtları, park ve konum verileri kullanıcının özelliği kullanması halinde, cihaz ve push bildirim belirteçleri, güvenlik kayıtları, uygulama sürümü ve teknik hata/çökme tanılama verileri işlenebilir. Sesli arama içeriği, açıkça belirtilmedikçe sunucuda kayıt altına alınmaz.'),
      ('3. İşleme amaçları','Hesap oluşturmak ve doğrulamak; QR tabanlı iletişim sağlamak; doğru araç sahibi veya aktif sürücüye mesaj ve arama yönlendirmek; bildirim göndermek; park, bakım ve hatırlatma özelliklerini sunmak; dolandırıcılık ve kötüye kullanımı önlemek; güvenlik olaylarını incelemek; teknik hataları tespit edip uygulama kararlılığını geliştirmek; hukuki yükümlülükleri yerine getirmek amaçlarıyla veri işlenir.'),
      ('4. Hukuki sebepler','Veriler, KVKK m.5 ve gerekli olduğu ölçüde ilgili diğer hükümler kapsamında; sözleşmenin kurulması veya ifası, hukuki yükümlülük, bir hakkın tesisi/kullanılması/korunması, veri sorumlusunun meşru menfaati ve gerekli olduğu durumlarda açık rıza hukuki sebeplerine dayanılarak işlenir.'),
      ('5. İzinler','Kamera izni QR taramak, konum izni park/konum özellikleri, mikrofon izni sesli arama, bildirim izni push bildirimleri için istenir. Bu izinleri cihaz ayarlarından yönetebilirsin. İznin kapatılması ilgili özelliğin çalışmasını etkileyebilir.'),
      ('6. Crash ve teknik tanılama','Uygulama kararlılığını izlemek için Firebase Crashlytics kullanılabilir. Çökme anında uygulama sürümü, cihaz/işletim sistemi bilgisi, teknik stack trace ve hata teşhisine yardımcı sınırlı tanılama verileri işlenebilir. Şifre ve kurtarma kodu gibi sırların hata kayıtlarına yazılmaması hedeflenir.'),
      ('7. Verilerin aktarılması','Hizmetin çalışması için barındırma, bildirim ve hata izleme altyapısı sağlayıcılarıyla sınırlı teknik veri paylaşımı yapılabilir. Firebase/Google gibi altyapı sağlayıcılarının sunucuları yurt dışında bulunabilir. Yurt dışı aktarım gerektiren hallerde KVKK m.9 kapsamındaki geçerli aktarım şartları ve uygun güvenceler esas alınır. Yetkili kamu kurumlarına yalnızca hukuki zorunluluk halinde veri aktarılır.'),
      ('8. Saklama süreleri','Veriler, işleme amacı için gerekli süre boyunca ve uygulanabilir mevzuatta öngörülen zorunlu süreler kadar tutulur. Hesap silindiğinde aktif hesap verileri silinir veya geri döndürülemeyecek şekilde anonimleştirilir; güvenlik, uyuşmazlık veya mevzuat nedeniyle saklanması zorunlu kayıtlar yalnızca gerekli süre boyunca tutulabilir.'),
      ('9. Güvenlik','Yetkisiz erişimi azaltmak için JWT tabanlı oturum, şifre doğrulama, erişim kontrolleri, oran sınırlama, güvenlik kayıtları ve uygun teknik/organizasyonel önlemler kullanılır. Hiçbir çevrimiçi sistem mutlak güvenlik garantisi veremez.'),
      ('10. KVKK m.11 kapsamındaki hakların','Kişisel verilerinin işlenip işlenmediğini öğrenme, işlenmişse bilgi talep etme, amacına uygun kullanılıp kullanılmadığını öğrenme, aktarılan üçüncü kişileri bilme, yanlış/eksik verilerin düzeltilmesini isteme, şartları oluştuğunda silme/yok etme isteme, düzeltme veya silmenin aktarılan üçüncü kişilere bildirilmesini isteme, münhasıran otomatik sistem analizine itiraz etme ve kanuna aykırı işleme nedeniyle zarar halinde tazminat talep etme hakların vardır.'),
      ('11. Başvuru yöntemi','KVKK kapsamındaki taleplerini uygulama içi destek kanalından veya mağaza sayfasında belirtilen geliştirici iletişim adresinden iletebilirsin. Kimlik doğrulaması için yalnızca talebi sonuçlandırmak için gerekli bilgiler istenir.'),
      ('12. Çocukların gizliliği','CepQontag araç sahibi ve yetkili sürücü kullanımına yöneliktir. Reşit olmayan kişilerin hizmeti, veli/vasi gözetimi ve uygulanabilir mevzuata uygunluk olmadan kullanması amaçlanmamıştır.'),
      ('13. Güncellemeler','Bu metin ürün veya mevzuat değişikliklerine göre güncellenebilir. Güncel sürüm uygulama içindeki Yasal ve Gizlilik bölümünde yayımlanır.'),
    ],
  );
}

class _LegalDocument extends StatelessWidget{
  const _LegalDocument({required this.title,required this.intro,required this.sections});
  final String title,intro;
  final List<(String,String)> sections;

  @override
  Widget build(BuildContext context)=>Scaffold(
    backgroundColor:_bg,
    body:SafeArea(
      child:Center(
        child:ConstrainedBox(
          constraints:const BoxConstraints(maxWidth:560),
          child:ListView(
            padding:const EdgeInsets.fromLTRB(18,10,18,28),
            children:[
              Row(children:[
                InkWell(
                  onTap:()=>Navigator.pop(context),
                  borderRadius:BorderRadius.circular(14),
                  child:Container(
                    width:40,height:40,
                    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:_line)),
                    child:const Icon(Icons.arrow_back_rounded,color:_text,size:20),
                  ),
                ),
                const Spacer(),
                Image.asset('assets/Aylogo.png',height:30,fit:BoxFit.contain),
                const Spacer(),
                const SizedBox(width:40),
              ]),
              const SizedBox(height:16),
              Text(title,style:const TextStyle(color:_text,fontSize:25,fontWeight:FontWeight.w900,letterSpacing:-.7)),
              const SizedBox(height:7),
              Text(intro,style:const TextStyle(color:Color(0xFF555C70),height:1.45,fontSize:11.5,fontWeight:FontWeight.w500)),
              const SizedBox(height:8),
              Container(
                padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),
                decoration:BoxDecoration(color:const Color(0xFFF8F6FF),borderRadius:BorderRadius.circular(10)),
                child:const Text('Sürüm $legalVersion • Son güncelleme $legalUpdated',style:TextStyle(color:_muted,fontSize:9.6,fontWeight:FontWeight.w600)),
              ),
              const SizedBox(height:14),
              for(final section in sections)...[
                Container(
                  width:double.infinity,
                  padding:const EdgeInsets.all(13),
                  decoration:BoxDecoration(
                    color:Colors.white,
                    border:Border.all(color:_line),
                    borderRadius:BorderRadius.circular(15),
                    boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.018),blurRadius:8,offset:const Offset(0,2))],
                  ),
                  child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    Text(section.$1,style:const TextStyle(color:_text,fontSize:12.7,fontWeight:FontWeight.w900)),
                    const SizedBox(height:6),
                    Text(section.$2,style:const TextStyle(color:Color(0xFF606779),fontSize:10.8,height:1.48,fontWeight:FontWeight.w500)),
                  ]),
                ),
                const SizedBox(height:9),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
