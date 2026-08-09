import 'package:frankstein_brain/brain.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_tool_registry/tool_registry.dart';
import 'package:test/test.dart';

// Mesmo contrato de docs/ARQUITETURA.md:45-64 — a "1 ferramenta só" da
// Fase 5. Fica fora de packages/nutrition de propósito: esse pacote é
// travado por clean room (.claude/rules/port.md), e este teste não
// precisa de nenhuma lógica de nutrição de verdade, só provar que o
// pipeline do cérebro executa uma ferramenta de escrita registrada.
final _logMealSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'items': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'food_id': {'type': 'string'},
          'grams': {'type': 'number'},
        },
        'required': ['food_id', 'grams'],
      },
    },
    'meal_type': {
      'enum': ['breakfast', 'lunch', 'dinner', 'snack'],
    },
  },
  'required': ['items', 'meal_type'],
};

/// Roteador de demonstração: reconhece um comando estruturado explícito
/// — `registrar refeição TIPO: ITEM GRAMASg, ...` — não é entendimento
/// de linguagem natural livre. Isso é o esperado do passo 1
/// do pipeline (`.claude/rules/brain.md`): resolve o comando frequente
/// sem chamar modelo nenhum; frases fora desse formato ficam
/// `unresolved` (sem LLM implementado nesta fase para escalar).
final _logMealPattern = RegExp(
  r'^registrar refeição (breakfast|lunch|dinner|snack): (.+)$',
  caseSensitive: false,
);
final _itemPattern = RegExp(r'([a-z0-9\-]+)\s+(\d+(?:\.\d+)?)g');

DeterministicRouter _buildRouter() => DeterministicRouter([
      RouterRule(
        toolName: 'log_meal',
        pattern: _logMealPattern,
        extractParams: (match) {
          final mealType = match.group(1)!.toLowerCase();
          final itemsRaw = match.group(2)!;
          final items = _itemPattern.allMatches(itemsRaw).map((m) => {
                'food_id': m.group(1),
                'grams': double.parse(m.group(2)!),
              }).toList();
          return {'items': items, 'meal_type': mealType};
        },
      ),
      // Regra deliberadamente "quebrada" — só para exercitar o caminho
      // de rejeição por validação sem alterar o schema real de log_meal.
      RouterRule(
        toolName: 'log_meal',
        pattern: RegExp(r'^log invalido$'),
        extractParams: (_) => {'items': <Map<String, dynamic>>[]}, // sem meal_type
      ),
    ]);

class _FakeConfirmationGate implements ConfirmationGate {
  final bool answer;
  bool asked = false;
  _FakeConfirmationGate(this.answer);

  @override
  Future<bool> confirm(ToolSpec spec, Map<String, dynamic> params) async {
    asked = true;
    return answer;
  }
}

/// Handler de demonstração: grava a refeição como HealthEvent tipo
/// `meal` no Health Data Core (F3). É a parte mecânica de "gravar um
/// evento" — não lógica de negócio de nutrição (catálogo de alimentos,
/// cálculo de macro), que pertence ao módulo de nutrição quando ele for
/// liberado do clean room.
ToolHandler _logMealHandler(HealthDataCore core) {
  return (params) async {
    final event = HealthEvent(
      id: HealthDataCore.newId(),
      type: HealthEventType.meal,
      source: HealthEventSource.manual,
      occurredAt: DateTime.now().toUtc(),
      occurredAtTzOffsetMinutes: -180,
      recordedAt: DateTime.now().toUtc(),
      payload: params,
      confidence: 1.0,
    );
    core.insertEvent(event);
    return ToolResult.ok({'event_id': event.id});
  };
}

void main() {
  late HealthDataCore core;
  late ToolRegistry registry;

  setUp(() {
    core = HealthDataCore.openInMemory();
    registry = ToolRegistry();
    registry.register(
      ToolSpec(
        name: 'log_meal',
        description: 'Registra uma refeição no diário alimentar',
        write: true,
        confirm: true,
        module: 'nutrition',
        parametersSchema: _logMealSchema,
      ),
      _logMealHandler(core),
    );
  });

  tearDown(() => core.close());

  group('BrainPipeline — ponta a ponta com log_meal', () {
    test(
        'texto reconhecido + confirmado grava HealthEvent de verdade no Health Data Core',
        () async {
      final gate = _FakeConfirmationGate(true);
      final pipeline = BrainPipeline(
        registry: registry,
        callers: [_buildRouter()],
        confirmationGate: gate,
      );

      final result = await pipeline.handle(
        'registrar refeição lunch: arroz-branco 150g, feijao-carioca 100g',
      );

      expect(result.outcome, PipelineOutcome.executed);
      expect(gate.asked, isTrue);
      expect(result.toolResult!.success, isTrue);

      final eventId = result.toolResult!.data!['event_id'] as String;
      final stored = core.getById(eventId);
      expect(stored, isNotNull);
      expect(stored!.type, HealthEventType.meal);
      expect(stored.payload['meal_type'], 'lunch');
      expect((stored.payload['items'] as List), hasLength(2));
      expect((stored.payload['items'] as List)[0], {
        'food_id': 'arroz-branco',
        'grams': 150.0,
      });
    });

    test('usuário recusa a confirmação — nada é gravado', () async {
      final gate = _FakeConfirmationGate(false);
      final pipeline = BrainPipeline(
        registry: registry,
        callers: [_buildRouter()],
        confirmationGate: gate,
      );

      final result = await pipeline.handle(
        'registrar refeição dinner: frango 200g',
      );

      expect(result.outcome, PipelineOutcome.abortedByUser);
      expect(gate.asked, isTrue);
      expect(core.queryByType(HealthEventType.meal), isEmpty);
    });

    test('texto que o roteador não reconhece fica unresolved (sem LLM ainda)',
        () async {
      final gate = _FakeConfirmationGate(true);
      final pipeline = BrainPipeline(
        registry: registry,
        callers: [_buildRouter()],
        confirmationGate: gate,
      );

      final result = await pipeline.handle('oi, tudo bem?');

      expect(result.outcome, PipelineOutcome.unresolved);
      expect(gate.asked, isFalse);
      expect(core.queryByType(HealthEventType.meal), isEmpty);
    });

    test('parâmetros inválidos são rejeitados antes de pedir confirmação',
        () async {
      final gate = _FakeConfirmationGate(true);
      final pipeline = BrainPipeline(
        registry: registry,
        callers: [_buildRouter()],
        confirmationGate: gate,
      );

      final result = await pipeline.handle('log invalido');

      expect(result.outcome, PipelineOutcome.rejected);
      expect(result.validationErrors, isNotEmpty);
      // Confirmação nunca deveria ter sido pedida para params inválidos.
      expect(gate.asked, isFalse);
      expect(core.queryByType(HealthEventType.meal), isEmpty);
    });

    test('ferramenta decidida pelo roteador mas não registrada vira unresolved',
        () async {
      final orphanRouter = DeterministicRouter([
        RouterRule(
          toolName: 'ferramenta_fantasma',
          pattern: RegExp(r'^fantasma$'),
          extractParams: (_) => {},
        ),
      ]);
      final gate = _FakeConfirmationGate(true);
      final pipeline = BrainPipeline(
        registry: registry,
        callers: [orphanRouter],
        confirmationGate: gate,
      );

      final result = await pipeline.handle('fantasma');
      expect(result.outcome, PipelineOutcome.unresolved);
    });
  });
}
