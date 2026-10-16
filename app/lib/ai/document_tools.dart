import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_health_records/health_records.dart';
import 'package:frankstein_profile/profile.dart';
import 'package:frankstein_tool_registry/tool_registry.dart';

/// Ferramentas de escrita para o que a IA transcreveu de documentos
/// (ADR-19): cada uma vira cartão; nada grava sem "Confirmar".

const addHistoryItemSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'kind': {
      'type': 'string',
      'enum': ['condition', 'allergy', 'surgery', 'vaccine', 'appointment'],
    },
    'title': {'type': 'string', 'minLength': 1},
    'date': {'type': 'string', 'description': 'AAAA-MM-DD'},
    'professional': {'type': 'string'},
  },
  'required': ['kind', 'title'],
};

ToolSpec addHistoryItemSpec() => ToolSpec(
      name: 'add_history_item',
      description: 'Adiciona ao histórico médico um item escrito num documento (condição, alergia, cirurgia, vacina, consulta)',
      write: true,
      confirm: true,
      module: 'health_records',
      parametersSchema: addHistoryItemSchema,
    );

ToolHandler addHistoryItemHandler(MedicalHistoryRepository repository) {
  return (params) async {
    try {
      final date = params['date'] as String?;
      final item = MedicalHistoryItem(
        id: HealthDataCore.newId(),
        kind: MedicalHistoryKind.fromWireValue(params['kind'] as String),
        title: params['title'] as String,
        date: date == null ? null : LocalDate.parse(date),
        professional: params['professional'] as String?,
      );
      repository.save(item);
      return ToolResult.ok({'item_id': item.id});
    } on ArgumentError catch (e) {
      return ToolResult.failure(e.message.toString());
    } on FormatException catch (e) {
      return ToolResult.failure(e.message);
    }
  };
}

const updateHeightSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'height_cm': {'type': 'number', 'minimum': 50, 'maximum': 250},
  },
  'required': ['height_cm'],
};

ToolSpec updateHeightSpec() => ToolSpec(
      name: 'update_height',
      description: 'Atualiza a altura do perfil (cm)',
      write: true,
      confirm: true,
      module: 'profile',
      parametersSchema: updateHeightSchema,
    );

ToolHandler updateHeightHandler(ProfileRepository profiles) {
  return (params) async {
    final current = profiles.load();
    if (current == null) return ToolResult.failure('Preencha o perfil (Conta › Perfil) antes de atualizar a altura.');
    try {
      profiles.save(current.copyWith(heightMeters: (params['height_cm'] as num).toDouble() / 100));
      return ToolResult.ok({'height_cm': params['height_cm']});
    } on ArgumentError catch (e) {
      return ToolResult.failure(e.message.toString());
    }
  };
}
