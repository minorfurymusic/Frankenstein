import 'dart:convert';

import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_profile/profile.dart';

/// Uma conversa do Cérebro (prancheta CerebroConversas), guardada só no
/// celular. Cada item é o JSON de uma mensagem como a tela a mostra — texto,
/// voz (só a duração; o áudio não é guardado), anexo (só nome e tipo),
/// resumo de documento e cartão (ferramenta, parâmetros e estado final).
/// Entra na exportação e sai em "apagar todos os dados".
class BrainConversation {
  final String id;
  final DateTime startedAt;
  DateTime updatedAt;
  final List<Map<String, dynamic>> messages;

  BrainConversation({required this.id, required this.startedAt, DateTime? updatedAt, List<Map<String, dynamic>>? messages})
      : updatedAt = updatedAt ?? startedAt,
        messages = messages ?? [];

  factory BrainConversation.start() {
    final now = DateTime.now();
    return BrainConversation(id: HealthDataCore.newId(), startedAt: now);
  }

  /// Título: o começo da primeira coisa que a pessoa mandou.
  String get title {
    for (final m in messages) {
      final t = switch (m['t']) {
        'user' => m['text'] as String?,
        'voice' => 'Mensagem de voz',
        'attach' => m['label'] as String?,
        _ => null,
      };
      if (t != null && t.trim().isNotEmpty) {
        final s = t.trim();
        return s.length <= 42 ? s : '${s.substring(0, 41)}…';
      }
    }
    return 'Conversa';
  }

  /// "3 itens salvos · Nutrição, Saúde" (só cartões confirmados).
  String get summary {
    final saved = [for (final m in messages) if (m['t'] == 'card' && m['state'] == 'confirmed') m];
    if (saved.isEmpty) return 'Nada salvo';
    final areas = <String>{for (final m in saved) '${m['saved_in'] ?? ''}'.split(' › ').first}..remove('');
    final n = saved.length == 1 ? '1 item salvo' : '${saved.length} itens salvos';
    return areas.isEmpty ? n : '$n · ${areas.join(', ')}';
  }

  bool get isEmpty => messages.isEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'started_at': startedAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'messages': messages,
      };

  factory BrainConversation.fromJson(Map<String, dynamic> m) => BrainConversation(
        id: m['id'] as String,
        startedAt: DateTime.parse(m['started_at'] as String).toLocal(),
        updatedAt: DateTime.parse(m['updated_at'] as String).toLocal(),
        messages: [for (final x in (m['messages'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)],
      );
}

/// Conversas na tabela de configurações do perfil (como o plano de
/// refeições). Mais recentes primeiro.
class BrainConversationStore {
  static const _key = 'brain_conversations';
  final ProfileRepository settings;
  BrainConversationStore(this.settings);

  List<BrainConversation> list() {
    final raw = settings.getSetting(_key);
    if (raw == null || raw.isEmpty) return [];
    final all = [for (final c in jsonDecode(raw) as List) BrainConversation.fromJson(c as Map<String, dynamic>)];
    return all..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  BrainConversation? find(String id) => list().where((c) => c.id == id).firstOrNull;

  /// Grava (ou troca) a conversa; conversa vazia não é guardada.
  void save(BrainConversation c) {
    if (c.isEmpty) return;
    c.updatedAt = DateTime.now();
    final all = [for (final x in list()) if (x.id != c.id) x, c];
    settings.setSetting(_key, jsonEncode([for (final x in all) x.toJson()]));
  }

  void delete(String id) {
    final all = [for (final x in list()) if (x.id != id) x];
    settings.setSetting(_key, all.isEmpty ? null : jsonEncode([for (final x in all) x.toJson()]));
  }
}
