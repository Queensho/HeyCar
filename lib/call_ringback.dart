import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Local ringback tone used while the remote party is being called.
/// The WAV is generated in memory so web and Android use the same sound
/// without shipping an extra binary asset.
class CallRingback {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  Future<void> start() async {
    if (_playing) return;
    _playing = true;
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(0.42);
    try {
      await _player.play(BytesSource(_buildTone()));
    } catch (_) {
      _playing = false;
    }
  }

  Future<void> stop() async {
    if (!_playing) return;
    _playing = false;
    try { await _player.stop(); } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }

  Uint8List _buildTone() {
    const sampleRate = 8000;
    const seconds = 4;
    const samples = sampleRate * seconds;
    const dataSize = samples * 2;
    final bytes = ByteData(44 + dataSize);

    void ascii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        bytes.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    bytes.setUint32(4, 36 + dataSize, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    bytes.setUint32(40, dataSize, Endian.little);

    for (var i = 0; i < samples; i++) {
      final t = i / sampleRate;
      // 1.6 s audible + 2.4 s silence, repeated by AudioPlayer.
      final audible = t < 1.6;
      final wave = audible
          ? (math.sin(2 * math.pi * 425 * t) * 0.22)
          : 0.0;
      bytes.setInt16(44 + i * 2, (wave * 32767).round(), Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}
