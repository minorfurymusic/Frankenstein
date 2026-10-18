import 'dart:convert';
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

  /// Nome do modelo que deu a última resposta, para mostrar embaixo dela.
  final ValueNotifier<String?> lastModelLabel = ValueNotifier(null);

  /// Escolha em Conta › Cérebro: [auto] (escada de modelos) ou um nome.
  /// Chave nova de ajuste: a antiga (`ai_model`) prendia todo mundo num
  /// modelo só.
  static const auto = 'auto';
  String get modelChoice {
    final v = settings.getSetting('ai_model_choice');
    return v == null || v.isEmpty ? auto : v;
  }

  void setModelChoice(String m) => settings.setSetting('ai_model_choice', m.trim().isEmpty ? auto : m.trim());

  /// Modelos que a chave pode usar, lidos em "Testar e salvar" ou
  /// "Atualizar lista", já na ordem da escada. Vazio: escada padrão.
  List<AiModel> get availableModels {
    final v = settings.getSetting('ai_models');
    if (v == null || v.isEmpty) return const [];
    try {
      return [for (final m in jsonDecode(v) as List) AiModel.fromJson((m as Map).cast<String, dynamic>())];
    } on Object {
      return const [];
    }
  }

  /// Nome para a tela: o do Google quando conhecido.
  String displayName(String model) {
    for (final m in availableModels) {
      if (m.name == model) return m.displayName;
    }
    return model;
  }

  List<String> get ladder {
    if (modelChoice != auto) return [modelChoice];
    final known = availableModels;
    return known.isEmpty ? GeminiClient.defaultLadder : [for (final m in known) m.name];
  }

  /// Dia da cota do Google: vira à meia-noite do Pacífico (UTC−8; no
  /// horário de verão de lá vira 1 h depois — só atrasa a volta ao topo).
  static String quotaDay(DateTime now) {
    final p = now.toUtc().subtract(const Duration(hours: 8));
    return '${p.year}-${p.month}-${p.day}';
  }

  /// Onde a escada parou hoje; num dia novo, volta ao melhor modelo.
  int ladderStart([DateTime? now]) {
    final v = settings.getSetting('ai_ladder');
    if (v == null || v.isEmpty) return 0;
    try {
      final m = jsonDecode(v) as Map<String, dynamic>;
      if (m['day'] != quotaDay(now ?? DateTime.now())) return 0;
      final name = m['model'] as String?;
      final i = ladder.indexOf(name ?? '');
      return i < 0 ? 0 : i;
    } on Object {
      return 0;
    }
  }

  void _saveLadder(String model) =>
      settings.setSetting('ai_ladder', jsonEncode({'day': quotaDay(DateTime.now()), 'model': model}));

  /// Lê de novo a lista de modelos da chave (só nomes; nenhum dado vai).
  Future<List<AiModel>> refreshModels() async {
    final k = await secrets.read(_keyName);
    if (k == null || k.isEmpty) throw const AiException(AiFailure.noKey);
    return _fetchModels(k);
  }

  Future<List<AiModel>> _fetchModels(String key) async {
    final list = await GeminiClient(apiKey: key, transport: transport).listModels();
    if (list.isNotEmpty) settings.setSetting('ai_models', jsonEncode([for (final m in list) m.toJson()]));
    return list;
  }

  /// Humor e sintomas mentais nas análises da IA (ADR-25): consentimento
  /// próprio, desligado por padrão.
  bool get mentalHealthConsent => settings.getSetting('ai_mental_consent') == 'on';
  set mentalHealthConsent(bool on) => settings.setSetting('ai_mental_consent', on ? 'on' : 'off');

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
    // Primeiro a lista de modelos da chave (só nomes), para o teste já
    // usar a escada certa.
    try {
      await _fetchModels(k);
    } on AiException catch (e) {
      if (e.failure == AiFailure.badKey) rethrow;
      // Sem a lista, vale a escada padrão.
    }
    await _client(k).ping();
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
    return _client(k);
  }

  GeminiClient _client(String key) => GeminiClient(
        apiKey: key,
        models: ladder,
        startIndex: ladderStart(),
        transport: transport,
        onModel: (i, m, {required ok}) {
          _saveLadder(m);
          if (ok) lastModelLabel.value = displayName(m);
        },
      );

  void dispose() {
    hasKey.dispose();
    lastModelLabel.dispose();
  }
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
    AiFailure.exhausted => error.httpStatus == 429
        ? 'O limite gratuito do Google acabou nos modelos que tentei (3). Tente mais tarde — a cota volta todo dia. '
            'Para não depender disso, ative o faturamento no Google AI Studio.'
        : 'Os servidores do Google estão ocupados nos modelos que tentei (3, erro ${error.httpStatus}). '
            'Espere um pouco e mande outra vez.',
    AiFailure.busy => 'O servidor da IA está ocupado agora (erro ${error.httpStatus} do provedor). '
        'Já tentei de novo sozinho; espere um pouco e mande outra vez.',
    AiFailure.provider => 'O provedor de IA recusou o pedido (erro ${error.httpStatus ?? '?'}'
        '${error.detail == null ? '' : ': ${_short(error.detail!)}'}).',
  };
}

/// Mensagem do provedor (em inglês) cortada para caber no balão — ajuda a
/// descobrir a causa num print, sem dado da pessoa (só o texto do erro).
String _short(String s) {
  final one = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return one.length <= 140 ? one : '${one.substring(0, 140)}…';
}
