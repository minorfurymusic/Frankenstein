import 'package:frankstein_tool_registry/tool_registry.dart';
import 'package:test/test.dart';

// Mesmo contrato do exemplo em docs/ARQUITETURA.md:45-64.
final logMealSchema = <String, dynamic>{
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
    'at': {'type': 'string', 'format': 'date-time'},
  },
  'required': ['items', 'meal_type'],
};

ToolSpec logMealSpec() => ToolSpec(
      name: 'log_meal',
      description: 'Registra uma refeição no diário alimentar',
      write: true,
      confirm: true,
      module: 'nutrition',
      parametersSchema: logMealSchema,
    );

void main() {
  group('ToolSpec', () {
    test('ferramenta de escrita sem confirm lança ArgumentError', () {
      expect(
        () => ToolSpec(
          name: 'x',
          description: 'x',
          write: true,
          confirm: false,
          module: 'x',
          parametersSchema: const {},
        ),
        throwsArgumentError,
      );
    });

    test('ferramenta de leitura não exige confirm', () {
      expect(
        () => ToolSpec(
          name: 'get_steps',
          description: 'Lê passos do dia',
          write: false,
          confirm: false,
          module: 'activity',
          parametersSchema: const {},
        ),
        returnsNormally,
      );
    });
  });

  group('validateToolParameters', () {
    test('aceita payload válido do contrato de log_meal', () {
      final result = validateToolParameters(logMealSchema, {
        'items': [
          {'food_id': 'arroz-branco', 'grams': 150},
        ],
        'meal_type': 'lunch',
      });
      expect(result.valid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('rejeita payload sem meal_type (required)', () {
      final result = validateToolParameters(logMealSchema, {
        'items': [
          {'food_id': 'arroz-branco', 'grams': 150},
        ],
      });
      expect(result.valid, isFalse);
      expect(result.errors, isNotEmpty);
    });

    test('rejeita meal_type fora do enum', () {
      final result = validateToolParameters(logMealSchema, {
        'items': <Map<String, dynamic>>[],
        'meal_type': 'brunch',
      });
      expect(result.valid, isFalse);
    });

    test('rejeita item sem grams', () {
      final result = validateToolParameters(logMealSchema, {
        'items': [
          {'food_id': 'arroz-branco'},
        ],
        'meal_type': 'lunch',
      });
      expect(result.valid, isFalse);
    });
  });

  group('ToolRegistry', () {
    test('registra, encontra por nome e lista specs', () {
      final registry = ToolRegistry();
      registry.register(logMealSpec(), (params) async => ToolResult.ok());

      expect(registry.has('log_meal'), isTrue);
      expect(registry.specFor('log_meal').module, 'nutrition');
      expect(registry.specs, hasLength(1));
    });

    test('specFor de ferramenta desconhecida lança ToolNotFoundException', () {
      final registry = ToolRegistry();
      expect(() => registry.specFor('nao_existe'), throwsA(isA<ToolNotFoundException>()));
    });

    test('execute com params válidos chama o handler e devolve o resultado',
        () async {
      final registry = ToolRegistry();
      Map<String, dynamic>? received;
      registry.register(logMealSpec(), (params) async {
        received = params;
        return ToolResult.ok({'event_id': 'evt-123'});
      });

      final result = await registry.execute('log_meal', {
        'items': [
          {'food_id': 'feijao-carioca', 'grams': 100},
        ],
        'meal_type': 'dinner',
      });

      expect(result.success, isTrue);
      expect(result.data!['event_id'], 'evt-123');
      expect(received!['meal_type'], 'dinner');
    });

    test('execute com params inválidos lança ToolValidationException e NÃO chama o handler',
        () async {
      final registry = ToolRegistry();
      var handlerCalled = false;
      registry.register(logMealSpec(), (params) async {
        handlerCalled = true;
        return ToolResult.ok();
      });

      await expectLater(
        () => registry.execute('log_meal', {'items': <Map<String, dynamic>>[]}),
        throwsA(isA<ToolValidationException>()),
      );
      expect(handlerCalled, isFalse);
    });

    test('execute de ferramenta não registrada lança ToolNotFoundException', () async {
      final registry = ToolRegistry();
      await expectLater(
        () => registry.execute('log_meal', {}),
        throwsA(isA<ToolNotFoundException>()),
      );
    });
  });
}
