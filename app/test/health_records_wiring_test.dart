import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein_brain/brain.dart';
import 'package:frankstein_tool_registry/tool_registry.dart';

class _AlwaysConfirm implements ConfirmationGate {
  @override
  Future<bool> confirm(ToolSpec spec, Map<String, dynamic> params) async => true;
}

void main() {
  // AppDependencies.close() passa por StepTrackingController.dispose(), que
  // usa o WidgetsBinding — mesmo setup dos outros testes do app.
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDependencies deps;

  setUp(() {
    deps = AppDependencies.inMemory(
      confirmationGate: _AlwaysConfirm(),
      shareSheet: FakeShareSheet(),
      imageCapturer: FakeCardImageCapturer(),
    );
  });
  tearDown(() => deps.close());

  test('as 6 ferramentas da aba Saúde estão registradas no app, escrita sempre com confirmação', () {
    const saude = [
      'add_medication',
      'log_medication_dose',
      'get_medication_agenda',
      'log_symptom',
      'log_vital_sign',
      'log_body_measurement',
    ];
    for (final name in saude) {
      expect(deps.registry.has(name), isTrue, reason: name);
      final spec = deps.registry.specFor(name);
      expect(spec.confirm, spec.write, reason: name);
    }
  });

  test('remédio cadastrado pelo registro do app aparece na agenda do dia', () async {
    final added = await deps.registry.execute('add_medication', {
      'name': 'Losartana',
      'dose_amount': 50,
      'dose_unit': 'mg',
      'times': ['08:00'],
      'start_date': '2026-10-02',
    });
    expect(added.success, isTrue);
    expect(deps.medicationRepository.listAll(), hasLength(1));

    final agenda = await deps.registry.execute('get_medication_agenda', {'date': '2026-10-02'});
    expect((agenda.data!['doses'] as List).single, containsPair('status', 'pending'));
  });
}
