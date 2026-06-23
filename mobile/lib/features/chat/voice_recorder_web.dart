// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

class VoiceRecorder {
  html.MediaStream? _stream;
  html.MediaRecorder? _recorder;
  final _chunks = <html.Blob>[];
  String _activeMime = '';

  // Pick the best MIME type the current browser supports.
  static String _bestMime() {
    const candidates = [
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
      'audio/mp4',
      '',
    ];
    for (final t in candidates) {
      if (t.isEmpty || html.MediaRecorder.isTypeSupported(t)) return t;
    }
    return '';
  }

  Future<void> start() async {
    final devices = html.window.navigator.mediaDevices;
    if (devices == null) throw Exception('Media devices not available in this browser.');
    _stream = await devices.getUserMedia({'audio': true, 'video': false});
    _chunks.clear();
    _activeMime = _bestMime();

    final opts = _activeMime.isNotEmpty
        ? {'mimeType': _activeMime}
        : <String, dynamic>{};
    _recorder = html.MediaRecorder(_stream!, opts);

    _recorder!.addEventListener('dataavailable', (event) {
      final e = event as html.BlobEvent;
      if (e.data != null && e.data!.size > 0) _chunks.add(e.data!);
    });

    // 100 ms timeslice — ensures dataavailable fires regularly so chunks
    // are populated before the stop event runs.
    _recorder!.start(100);
  }

  Future<Uint8List?> stop() async {
    if (_recorder == null) return null;
    final completer = Completer<Uint8List>();

    _recorder!.addEventListener('stop', (_) async {
      try {
        if (_chunks.isEmpty) {
          completer.completeError('No audio data was captured.');
          return;
        }
        final blobType = _activeMime.isNotEmpty ? _activeMime : 'audio/webm';
        final blob = html.Blob(_chunks, blobType);
        final reader = html.FileReader();
        reader.readAsArrayBuffer(blob);
        await reader.onLoadEnd.first;
        final result = reader.result;
        if (result is ByteBuffer) {
          completer.complete(result.asUint8List());
        } else {
          // Some environments return a JS typed-array instead of ByteBuffer.
          try {
            // ignore: avoid_dynamic_calls
            final buf = (result as dynamic).buffer as ByteBuffer;
            completer.complete(buf.asUint8List());
          } catch (_) {
            completer.completeError('Could not read recorded audio.');
          }
        }
      } catch (e) {
        completer.completeError(e);
      }
    });

    _recorder!.stop();
    _stream?.getTracks().forEach((t) => t.stop());
    _recorder = null;
    _stream = null;
    return completer.future;
  }

  Future<void> cancel() async {
    _chunks.clear();
    try { _recorder?.stop(); } catch (_) {}
    _stream?.getTracks().forEach((t) => t.stop());
    _recorder = null;
    _stream = null;
  }

  String get mimeType {
    if (_activeMime.contains('mp4')) return 'audio/mp4';
    if (_activeMime.contains('ogg')) return 'audio/ogg';
    return 'audio/webm';
  }

  String get fileName {
    if (_activeMime.contains('mp4')) return 'voice_note.mp4';
    if (_activeMime.contains('ogg')) return 'voice_note.ogg';
    return 'voice_note.webm';
  }
}
