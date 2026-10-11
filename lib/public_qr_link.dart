/// Safe public QR URL handling. The signed scan proof must be carried by a
/// physical QR (or owner-generated preview); knowing a tag alone is not proof.
class PublicQrLink {
  static const baseUrl='https://queensho.github.io/HeyCar/';

  static String forVehicle({required String token,required String scanSecret}){
    final code=token.trim().toUpperCase();
    final proof=scanSecret.trim();
    if(code.isEmpty||proof.isEmpty){
      throw StateError('QR güvenlik anahtarı bulunamadı. Etiketinizi yeniden oluşturun.');
    }
    return Uri.parse(baseUrl).replace(queryParameters:{'tag':code,'s':proof}).toString();
  }

  static ({String token,String secret}) parse(String raw){
    final value=raw.trim();
    final uri=Uri.tryParse(value);
    if(uri!=null&&(uri.scheme=='http'||uri.scheme=='https')){
      final tag=(uri.queryParameters['tag']??'').trim().toUpperCase();
      if(tag.isNotEmpty)return (token:tag,secret:(uri.queryParameters['s']??'').trim());
    }
    final match=RegExp(r'HC-[A-Z0-9-]+',caseSensitive:false).firstMatch(value);
    return (token:(match?.group(0)??value).trim().toUpperCase(),secret:'');
  }
}
