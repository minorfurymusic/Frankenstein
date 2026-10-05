import 'package:frankstein_ai/ai.dart';
import 'package:test/test.dart';

void main() {
  test('lê médico, datas e remédios como escritos; descarta o que não fecha', () {
    final r = parsePrescriptionReading({
      'doctor': ' Dra. Ana Souza ',
      'specialty': 'Clínica geral',
      'date': '2026-10-01',
      'valid_until': '2026-10-31',
      'medicines': [
        {
          'name': 'Amoxicilina 500 mg',
          'dose_amount': 1,
          'dose_unit': 'unidade',
          'form': 'capsule',
          'instructions': '1 cápsula de 8 em 8 horas por 7 dias',
          'interval_hours': 8,
          'duration_days': 7,
        },
        {'name': 'Losartana 50 mg', 'dose_amount': 1, 'dose_unit': 'comprimido', 'interval_hours': 5, 'continuous': true},
        {'name': '  '},
      ],
    });
    expect(r.doctor, 'Dra. Ana Souza');
    expect(r.date, DateTime(2026, 10, 1));
    expect(r.validUntil, DateTime(2026, 10, 31));
    expect(r.medicines, hasLength(2));
    final amox = r.medicines.first;
    expect((amox.doseAmount, amox.doseUnit, amox.form, amox.intervalHours, amox.durationDays), (1, 'unidade', 'capsule', 8, 7));
    final losartana = r.medicines.last;
    // Unidade fora da lista e intervalo que o app não usa: ficam de fora.
    expect((losartana.doseAmount, losartana.doseUnit, losartana.intervalHours, losartana.continuous), (null, null, null, true));
  });

  test('validade antes da data da receita é descartada; data impossível também', () {
    final r = parsePrescriptionReading({'date': '2026-10-10', 'valid_until': '2026-10-01', 'medicines': []});
    expect(r.validUntil, isNull);
    expect(parsePrescriptionReading({'date': '2026-02-31', 'medicines': []}).date, isNull);
  });

  test('a instrução proíbe deduzir validade e completar dose', () {
    expect(prescriptionReadingInstruction, contains('Não deduza pelo tipo de receita'));
    expect(prescriptionReadingInstruction, contains('Nunca calcule, ajuste ou complete dose'));
  });
}
