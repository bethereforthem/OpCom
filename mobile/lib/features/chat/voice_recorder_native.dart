import 'package:flutter/services.dart';

class VoiceRecorder {
  static const _ch = MethodChannel('com.opcom.opcom_mobile/recorder');

  Future<void> start() => _ch.invokeMethod<void>('start');

  Future<Uint8List?> stop() => _ch.invokeMethod<Uint8List>('stop');

  Future<void> cancel() async {
    try { await _ch.invokeMethod<void>('cancel'); } catch (_) {}
  }

  String get mimeType => 'audio/mp4';
  String get fileName => 'voice_note.m4a';
}
