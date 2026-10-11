import 'package:flutter_test/flutter_test.dart';
import 'package:heycar_app/public_qr_link.dart';

void main(){
  test('owner preview contains both token and secret required by secure scan API',(){
    const tag='HC-7XK9P2';
    const secret='secure-secret-0123456789';
    final url=PublicQrLink.forVehicle(token:tag,scanSecret:secret);
    final uri=Uri.parse(url);
    expect(uri.queryParameters['tag'],tag);
    expect(uri.queryParameters['s'],secret);
    final parsed=PublicQrLink.parse(url);
    expect(parsed.token,tag);
    expect(parsed.secret,secret);
  });

  test('never generate insecure preview without QR proximity secret',(){
    expect(
      ()=>PublicQrLink.forVehicle(token:'HC-7XK9P2',scanSecret:''),
      throwsStateError,
    );
  });

  test('manual code alone carries no privileged proximity proof',(){
    final parsed=PublicQrLink.parse('HC-7XK9P2');
    expect(parsed.token,'HC-7XK9P2');
    expect(parsed.secret,isEmpty);
  });

  test('scanned URL with encoded proof round-trips without corrupting it',(){
    final url=PublicQrLink.forVehicle(
      token:'hc-7xk9p2',
      scanSecret:'a+b/=&',
    );
    final qr=PublicQrLink.parse(url);
    expect(qr.token,'HC-7XK9P2');
    expect(qr.secret,'a+b/=&');
  });
}
