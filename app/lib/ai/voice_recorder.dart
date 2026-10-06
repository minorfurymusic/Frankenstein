import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Áudio gravado no celular, em AAC (`audio/aac`, formato aceito pelo
/// Gemini). Fica só na memória: nada é guardado depois de enviado.
class RecordedAudio {
  final Uint8List bytes;
  final Duration duration;
  const RecordedAudio(this.bytes, this.duration);

  static const mimeType = 'audio/aac';
}

/// Voz no Cérebro (prancheta CerebroEntradas). Microfone pedido só quando
/// a pessoa segura o botão de gravar pela primeira vez.
abstract class VoiceRecorder {
  Future<bool> hasPermission();
  Future<bool> requestPermission();

  /// `false` sem permissão ou se o microfone não abrir.
  Future<bool> start();

  /// `null` quando nada foi gravado (toque curto demais).
  Future<RecordedAudio?> stop();
  Future<void> cancel();
}

/// `VoiceBridge.kt` pelo canal `rlt/voice` (MediaRecorder do Android).
class AndroidVoiceRecorder implements VoiceRecorder {
  static const _channel = MethodChannel('rlt/voice');

  @override
  Future<bool> hasPermission() async => await _channel.invokeMethod<bool>('hasPermission') ?? false;

  @override
  Future<bool> requestPermission() async => await _channel.invokeMethod<bool>('requestPermission') ?? false;

  @override
  Future<bool> start() async {
    try {
      return await _channel.invokeMethod<bool>('start') ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<RecordedAudio?> stop() async {
    final raw = await _channel.invokeMapMethod<String, Object?>('stop');
    if (raw == null) return null;
    return RecordedAudio(raw['bytes'] as Uint8List, Duration(milliseconds: (raw['duration_ms'] as num).toInt()));
  }

  @override
  Future<void> cancel() => _channel.invokeMethod<void>('cancel');
}

/// Para teste e fora do Android: devolve [next] ao parar.
class FakeVoiceRecorder implements VoiceRecorder {
  bool granted;
  bool recording = false;
  bool cancelled = false;
  int permissionRequests = 0;
  RecordedAudio? next;
  FakeVoiceRecorder({this.granted = true, this.next});

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return granted;
  }

  @override
  Future<bool> start() async => recording = granted;

  @override
  Future<RecordedAudio?> stop() async {
    final was = recording;
    recording = false;
    return was ? next : null;
  }

  @override
  Future<void> cancel() async {
    recording = false;
    cancelled = true;
  }
}

VoiceRecorder defaultVoiceRecorder() => !kIsWeb && Platform.isAndroid ? AndroidVoiceRecorder() : FakeVoiceRecorder(granted: false);
