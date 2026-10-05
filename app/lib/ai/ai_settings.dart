import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:frankstein_ai/ai.dart';
import 'package:frankstein_profile/profile.dart';

/// Onde a chave da IA fica guardada. No Android, cifrada pelo Keystore
/// (`SecureStore.kt`); nunca no banco, em log, backup ou exportação.
abstract class SecretStore {
  Future<String?> read(String name);
  Future<void> write(String name, String value);
  Future<void> delete(String name);
}

class AndroidSecretStore implements SecretStore {
  static const _channel = MethodChannel('rlt/secure');
  @override
  Future<String?> read(String name) => _channel.invokeMethod<String>('get', {'name': name});
  @override
  Future<void> write(String name, String value) => _channel.invokeMethod<bool>('set', {'name': name, 'value': value});
  @override
  Future<void> delete(String name) => _channel.invokeMethod<bool>('delete', {'name': name});
}

class MemorySecretStore implements SecretStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String name) async => values[name];
  @override
  Future<void> write(String name, String value) async => values[name] = value;
  @override
  Future<void> delete(String name) async => values.remove(name);
}

SecretStore defaultSecretStore() => !kIsWeb && Platform.isAndroid ? AndroidSecretStore() : MemorySecretStore();

/// IA do usuário (ADR-11). Provedor atual: Gemini (Google), com a chave da
/// própria pessoa. Sem chave: modo básico.
class AiSettings {
  static const providerName = 'Gemini (Google)';
  static const _keyName = 'gemini_api_key';

  final SecretStore secrets;
  final ProfileRepository settings;

  /// Troca o transporte HTTP nos testes.
  final AiTransport? transport;

  /// Se há chave guardada (lido ao abrir o app; a chave em si não fica na
  /// memória da tela).
  final ValueNotifier<bool> hasKey = ValueNotifier(false);

  AiSettings({required this.secrets, required this.settings, this.transport});

  Future<void> load() async {
    try {
      hasKey.value = (await secrets.read(_keyName))?.isNotEmpty ?? false;
    } on PlatformException {
      hasKey.value = false;
    } on MissingPluginException {
      hasKey.value = false;
    }
  }

  String get model => settings.getSetting('ai_model') ?? GeminiClient.defaultModel;
  void setModel(String m) => settings.setSetting('ai_model', m.trim().isEmpty ? GeminiClient.defaultModel : m.trim());

  /// Consentimento (prancheta CerebroConsentimento), por provedor.
  DateTime? get consentedAt {
    final v = settings.getSetting('ai_consent_gemini');
    return v == null || v.isEmpty ? null : DateTime.tryParse(v);
  }

  void giveConsent([DateTime? at]) => settings.setSetting('ai_consent_gemini', (at ?? DateTime.now()).toIso8601String());
  void revokeConsent() => settings.setSetting('ai_consent_gemini', '');

  DateTime? get lastTestedAt {
    final v = settings.getSetting('ai_key_tested');
    return v == null || v.isEmpty ? null : DateTime.tryParse(v);
  }

  /// Testa a chave com um pedido mínimo (sem dado de saúde) e guarda.
  Future<void> testAndSaveKey(String key) async {
    final k = key.trim();
    if (k.isEmpty) throw const AiException(AiFailure.noKey);
    await GeminiClient(apiKey: k, model: model, transport: transport).ping();
    await secrets.write(_keyName, k);
    settings.setSetting('ai_key_tested', DateTime.now().toIso8601String());
    hasKey.value = true;
  }

  /// Apaga a chave e o consentimento: volta ao modo básico.
  Future<void> removeKey() async {
    await secrets.delete(_keyName);
    revokeConsent();
    settings.setSetting('ai_key_tested', '');
    hasKey.value = false;
  }

  /// Cliente pronto para uma ação da pessoa, ou erro `noKey`.
  Future<GeminiClient> client() async {
    final k = await secrets.read(_keyName);
    if (k == null || k.isEmpty) throw const AiException(AiFailure.noKey);
    return GeminiClient(apiKey: k, model: model, transport: transport);
  }

  void dispose() => hasKey.dispose();
}

/// Texto para cada falha da IA, em português simples.
String aiFailureMessage(Object error) {
  if (error is! AiException) return 'Não deu certo agora. Tente de novo.';
  return switch (error.failure) {
    AiFailure.noKey => 'Configure a sua chave de IA em Conta › Cérebro (IA).',
    AiFailure.badKey => 'O provedor recusou a chave. Confira em Conta › Cérebro (IA).',
    AiFailure.quota => 'A chave atingiu o limite de uso do provedor. Tente mais tarde.',
    AiFailure.network => 'Sem conexão com a IA. Confira a internet e tente de novo.',
    AiFailure.blocked => 'A IA não quis ler este conteúdo. Tente outra foto ou preencha à mão.',
    AiFailure.tooLarge => 'Arquivo grande demais para a IA (máx. 15 MB). Tente uma foto ou um PDF menor.',
    AiFailure.invalidOutput => 'A IA respondeu fora do formato. Tente de novo ou preencha à mão.',
    AiFailure.provider => 'O provedor de IA deu erro. Tente de novo em instantes.',
  };
}
