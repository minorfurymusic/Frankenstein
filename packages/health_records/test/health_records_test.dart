import 'dart:io';

import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_health_records/health_records.dart';
import 'package:frankstein_tool_registry/tool_registry.dart';
import 'package:test/test.dart';

Medication _med({
  String id = 'm1',
  String name = 'Losartana',
  List<int>? times,
  required String start,
  String? end,
}) =>
    Medication(
      id: id,
      name: name,
      doseAmount: 50,
      doseUnit: 'mg',
      form: MedicationForm.tablet,
      timesOfDay: times ?? [parseTimeOfDay('08:00'), parseTimeOfDay('20:00')],
      startDate: LocalDate.parse(start),
      endDate: end == null ? null : LocalDate.parse(end),
    );

void main() {
  group('unidades — banco em SI, tela em unidade clínica', () {
    test('120/80 mmHg viram kPa e voltam sem perda', () {
      expect(mmHgToKpa(120), closeTo(15.9987, 0.0001));
      expect(kpaToMmHg(mmHgToKpa(80)), closeTo(80, 1e-9));
    });

    test('glicemia 100 mg/dL ≈ 5,55 mmol/L e volta sem perda', () {
      expect(glucoseMgDlToMmolL(100), closeTo(5.5507, 0.0001));
      expect(glucoseMmolLToMgDl(glucoseMgDlToMmolL(126)), closeTo(126, 1e-9));
    });
  });

  group('LocalDate e horários', () {
    test('rejeita data inexistente e formato errado', () {
      expect(() => LocalDate.parse('2026-02-30'), throwsArgumentError);
      expect(() => LocalDate.parse('02/10/2026'), throwsArgumentError);
      expect(LocalDate.parse('2026-10-02').toIso(), '2026-10-02');
    });

    test('HH:mm ida e volta; rejeita 24:00', () {
      expect(parseTimeOfDay('08:30'), 510);
      expect(formatTimeOfDay(510), '08:30');
      expect(() => parseTimeOfDay('24:00'), throwsArgumentError);
    });
  });

  group('Medication — validação', () {
    test('sem nome, dose zero, sem horário ou fim antes do início é recusado', () {
      expect(
          () => Medication(id: 'x', name: ' ', doseAmount: 1, doseUnit: 'mg', timesOfDay: [480], startDate: LocalDate(2026, 10, 1)),
          throwsArgumentError);
      expect(
          () => Medication(id: 'x', name: 'A', doseAmount: 0, doseUnit: 'mg', timesOfDay: [480], startDate: LocalDate(2026, 10, 1)),
          throwsArgumentError);
      expect(
          () => Medication(id: 'x', name: 'A', doseAmount: 1, doseUnit: 'mg', timesOfDay: [], startDate: LocalDate(2026, 10, 1)),
          throwsArgumentError);
      expect(() => _med(start: '2026-10-05', end: '2026-10-01'), throwsArgumentError);
    });

    test('horários repetidos/fora de ordem são normalizados', () {
      final m = _med(start: '2026-10-01', times: [1200, 480, 480]);
      expect(m.timesOfDay, [480, 1200]);
    });
  });

  group('MedicationRepository — catálogo e agenda', () {
    late MedicationRepository repo;
    setUp(() => repo = MedicationRepository.openInMemory());
    tearDown(() => repo.close());

    test('uso contínuo aparece todo dia a partir do início, nunca antes', () {
      repo.save(_med(start: '2026-10-02'));
      expect(repo.scheduleFor(LocalDate.parse('2026-10-01')), isEmpty);
      expect(repo.scheduleFor(LocalDate.parse('2026-10-02')).map((d) => d.scheduledLocal),
          ['2026-10-02T08:00', '2026-10-02T20:00']);
      expect(repo.scheduleFor(LocalDate.parse('2027-03-15')), hasLength(2));
    });

    test('receita de uso curto (3 dias) só agenda esses 3 dias', () {
      repo.save(_med(id: 'amox', name: 'Amoxicilina', start: '2026-10-02', end: '2026-10-04', times: [480, 960, 1440 - 60]));
      expect(repo.scheduleFor(LocalDate.parse('2026-10-02')), hasLength(3));
      expect(repo.scheduleFor(LocalDate.parse('2026-10-04')), hasLength(3));
      expect(repo.scheduleFor(LocalDate.parse('2026-10-05')), isEmpty);
    });

    test('editar = salvar com o mesmo id; encerrar não apaga o cadastro', () {
      repo.save(_med(start: '2026-10-01'));
      repo.save(_med(start: '2026-10-01', name: 'Losartana potássica'));
      expect(repo.listAll(), hasLength(1));
      expect(repo.findById('m1')!.name, 'Losartana potássica');

      repo.endOn('m1', LocalDate.parse('2026-10-10'));
      expect(repo.findById('m1')!.endDate!.toIso(), '2026-10-10');
      expect(repo.scheduleFor(LocalDate.parse('2026-10-11')), isEmpty);
    });

    test('agenda junta remédios diferentes em ordem de horário', () {
      repo.save(_med(id: 'a', name: 'A', start: '2026-10-01', times: [1200]));
      repo.save(_med(id: 'b', name: 'B', start: '2026-10-01', times: [420]));
      expect(repo.scheduleFor(LocalDate.parse('2026-10-02')).map((d) => d.medication.name), ['B', 'A']);
    });

    test('arquivo real: fecha, reabre e o cadastro continua lá', () {
      final dir = Directory.systemTemp.createTempSync('meds');
      final path = '${dir.path}/meds.sqlite3';
      final r1 = MedicationRepository.open(path)..save(_med(start: '2026-10-01', end: '2026-12-31'));
      r1.close();
      final r2 = MedicationRepository.open(path);
      final m = r2.findById('m1')!;
      expect(m.timesOfDay, [480, 1200]);
      expect(m.endDate!.toIso(), '2026-12-31');
      r2.close();
      dir.deleteSync(recursive: true);
    });
  });

  group('MedicationAgenda — previsto x acontecido', () {
    late MedicationRepository repo;
    late HealthDataCore core;
    setUp(() {
      repo = MedicationRepository.openInMemory();
      core = HealthDataCore.openInMemory();
    });
    tearDown(() {
      repo.close();
      core.close();
    });

    test('tomado, pulado e pendente; a última marcação da mesma dose vale', () {
      repo.save(_med(start: '2026-10-01'));
      final logger = MedicationDoseLogger(core: core);
      final agenda = MedicationAgenda(repository: repo, core: core);

      logger.log(
          name: 'Losartana', doseAmount: 50, doseUnit: 'mg', status: DoseStatus.skipped,
          occurredAt: DateTime.utc(2026, 10, 2, 11, 5), occurredAtTzOffsetMinutes: -180,
          medicationId: 'm1', scheduledLocal: '2026-10-02T08:00');
      // Corrigiu: na verdade tomou.
      logger.log(
          name: 'Losartana', doseAmount: 50, doseUnit: 'mg', status: DoseStatus.taken,
          occurredAt: DateTime.utc(2026, 10, 2, 11, 10), occurredAtTzOffsetMinutes: -180,
          medicationId: 'm1', scheduledLocal: '2026-10-02T08:00');

      final day = agenda.forDay(LocalDate.parse('2026-10-02'));
      expect(day.map((e) => e.status), [DoseStatus.taken, null]);
      // O histórico guarda as duas marcações (append-only).
      expect(core.queryByType(HealthEventType.medicationDose), hasLength(2));
    });

    test('dose avulsa (dipirona sem cadastro) é gravada e não mexe na agenda', () {
      repo.save(_med(start: '2026-10-01'));
      final e = MedicationDoseLogger(core: core).log(
          name: 'Dipirona', doseAmount: 500, doseUnit: 'mg', status: DoseStatus.taken,
          occurredAt: DateTime.utc(2026, 10, 2, 12), occurredAtTzOffsetMinutes: -180);
      expect(e.payload.containsKey('medication_id'), isFalse);
      final day = MedicationAgenda(repository: repo, core: core).forDay(LocalDate.parse('2026-10-02'));
      expect(day.every((x) => x.status == null), isTrue);
    });
  });

  group('sintomas, sinais vitais e corpo', () {
    late HealthDataCore core;
    setUp(() => core = HealthDataCore.openInMemory());
    tearDown(() => core.close());
    final at = DateTime.utc(2026, 10, 2, 11);

    test('sintoma grava o que foi dito; intensidade fora de 0–10 é recusada', () {
      final e = SymptomLogger(core: core)
          .log(name: 'dor de cabeça', intensity: 6, occurredAt: at, occurredAtTzOffsetMinutes: -180);
      expect(e.type, HealthEventType.symptom);
      expect(e.payload, {'name': 'dor de cabeça', 'intensity': 6});
      expect(() => SymptomLogger(core: core).log(name: 'x', intensity: 11, occurredAt: at, occurredAtTzOffsetMinutes: 0),
          throwsArgumentError);
    });

    test('pressão gravada em kPa; diastólica >= sistólica é recusada', () {
      final v = VitalSignLogger(core: core);
      final e = v.bloodPressure(systolicMmHg: 120, diastolicMmHg: 80, occurredAt: at, occurredAtTzOffsetMinutes: -180);
      expect(e.payload['kind'], 'blood_pressure');
      expect(e.payload['systolic_kpa'] as double, closeTo(15.9987, 0.0001));
      expect(e.payload.containsKey('systolic_mmhg'), isFalse);
      expect(() => v.bloodPressure(systolicMmHg: 80, diastolicMmHg: 80, occurredAt: at, occurredAtTzOffsetMinutes: 0),
          throwsArgumentError);
    });

    test('glicemia em mmol/L; frequência cardíaca manual vai na série heart_rate (bpm, igual ao wearable)', () {
      final v = VitalSignLogger(core: core);
      expect(v.glucose(mgDl: 90, occurredAt: at, occurredAtTzOffsetMinutes: 0).payload['mmol_per_l'] as double,
          closeTo(4.9957, 0.0001));
      final hr = v.heartRate(bpm: 72, occurredAt: at, occurredAtTzOffsetMinutes: 0);
      expect(hr.type, HealthEventType.heartRate);
      expect(hr.payload, {'bpm': 72});
    });

    test('peso em kg (tipo weight), cintura em metros, gordura em fração', () {
      final b = BodyLogger(core: core);
      expect(b.weight(kg: 82.5, occurredAt: at, occurredAtTzOffsetMinutes: 0).type, HealthEventType.weight);
      expect(
          b.circumference(kind: BodyMeasurementKind.waist, centimeters: 90, occurredAt: at, occurredAtTzOffsetMinutes: 0)
              .payload,
          {'kind': 'waist', 'meters': 0.9});
      expect(b.bodyFat(percent: 22, occurredAt: at, occurredAtTzOffsetMinutes: 0).payload['fraction'], closeTo(0.22, 1e-12));
    });
  });

  group('ferramentas do cérebro — aba Saúde', () {
    late MedicationRepository repo;
    late HealthDataCore core;
    late ToolRegistry registry;

    setUp(() {
      repo = MedicationRepository.openInMemory();
      core = HealthDataCore.openInMemory();
      int tz() => -180;
      registry = ToolRegistry()
        ..register(addMedicationSpec(), addMedicationHandler(repo))
        ..register(logMedicationDoseSpec(),
            logMedicationDoseHandler(MedicationDoseLogger(core: core), repo, tzOffsetMinutesProvider: tz))
        ..register(getMedicationAgendaSpec(), getMedicationAgendaHandler(MedicationAgenda(repository: repo, core: core)))
        ..register(logSymptomSpec(), logSymptomHandler(SymptomLogger(core: core), tzOffsetMinutesProvider: tz))
        ..register(logVitalSignSpec(), logVitalSignHandler(VitalSignLogger(core: core), tzOffsetMinutesProvider: tz))
        ..register(logBodyMeasurementSpec(),
            logBodyMeasurementHandler(BodyLogger(core: core), tzOffsetMinutesProvider: tz));
    });
    tearDown(() {
      repo.close();
      core.close();
    });

    test('toda ferramenta de escrita exige confirmação; agenda é só leitura', () {
      for (final spec in registry.specs) {
        expect(spec.confirm, spec.write, reason: spec.name);
      }
      expect(registry.specFor('get_medication_agenda').write, isFalse);
    });

    test('cadastrar remédio pela ferramenta e ver na agenda do dia', () async {
      final added = await registry.execute('add_medication', {
        'name': 'Losartana',
        'dose_amount': 50,
        'dose_unit': 'mg',
        'times': ['08:00', '20:00'],
        'start_date': '2026-10-02',
      });
      expect(added.success, isTrue);
      expect(added.data!['continuous'], isTrue);

      final id = added.data!['medication_id'] as String;
      await registry.execute('log_medication_dose',
          {'medication_id': id, 'status': 'taken', 'scheduled_local': '2026-10-02T08:00'});

      final agenda = await registry.execute('get_medication_agenda', {'date': '2026-10-02'});
      final doses = agenda.data!['doses'] as List;
      expect(doses.map((d) => (d as Map)['status']), ['taken', 'pending']);
      expect((doses.first as Map)['name'], 'Losartana');
    });

    test('horário mal formado é barrado pelo schema antes do handler', () {
      expect(
        () => registry.execute('add_medication', {
          'name': 'X',
          'dose_amount': 1,
          'dose_unit': 'mg',
          'times': ['8h'],
          'start_date': '2026-10-02',
        }),
        throwsA(isA<ToolValidationException>()),
      );
    });

    test('"dor de cabeça de manhã e dipirona 500 mg às 9h" vira dois registros certos', () async {
      final symptom = await registry.execute('log_symptom', {'name': 'dor de cabeça', 'at': '2026-10-02T10:00:00Z'});
      final dose = await registry.execute('log_medication_dose', {
        'name': 'Dipirona',
        'dose_amount': 500,
        'dose_unit': 'mg',
        'status': 'taken',
        'at': '2026-10-02T12:00:00Z',
      });
      expect(symptom.success && dose.success, isTrue);
      expect(core.queryByType(HealthEventType.symptom).single.payload['name'], 'dor de cabeça');
      expect(core.queryByType(HealthEventType.medicationDose).single.payload['dose_amount'], 500);
    });

    test('dose sem medication_id e sem nome/dose falha com mensagem, sem gravar', () async {
      final r = await registry.execute('log_medication_dose', {'status': 'taken'});
      expect(r.success, isFalse);
      expect(core.queryByType(HealthEventType.medicationDose), isEmpty);
    });

    test('sinais vitais e corpo pela ferramenta; faltando campo do tipo = falha', () async {
      expect((await registry.execute('log_vital_sign', {'kind': 'blood_pressure', 'systolic_mmhg': 130, 'diastolic_mmhg': 85}))
          .success, isTrue);
      expect((await registry.execute('log_vital_sign', {'kind': 'glucose'})).success, isFalse);
      expect((await registry.execute('log_body_measurement', {'kind': 'waist', 'value': 88})).success, isTrue);
      expect(core.queryByType(HealthEventType.vitalSign), hasLength(1));
      expect(core.queryByType(HealthEventType.bodyMeasurement).single.payload['meters'], 0.88);
    });
  });
}
