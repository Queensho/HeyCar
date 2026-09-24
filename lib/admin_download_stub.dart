import 'dart:typed_data';

Future<void> saveAdminPng(Uint8List bytes,String fileName) async {
  throw UnsupportedError('PNG download is only available on web.');
}

Future<void> saveAdminFile(Uint8List bytes,String fileName,String mimeType) async {
  throw UnsupportedError('File download is only available on web.');
}
