import 'package:frankstein_health_records/health_records.dart';
import 'package:test/test.dart';

void main() {
  test('salva, lista por tipo (mais recente primeiro) e apaga', () {
    final repo = MedicalHistoryRepository.openInMemory();
    addTearDown(repo.close);
    repo.save(MedicalHistoryItem(id: 'a', kind: MedicalHistoryKind.allergy, title: 'Dipirona'));
    repo.save(MedicalHistoryItem(id: 'v1', kind: MedicalHistoryKind.vaccine, title: 'Gripe', date: LocalDate(2025, 4, 10)));
    repo.save(MedicalHistoryItem(id: 'v2', kind: MedicalHistoryKind.vaccine, title: 'Covid', date: LocalDate(2026, 5, 2)));
    repo.save(MedicalHistoryItem(
      id: 'c',
      kind: MedicalHistoryKind.appointment,
      title: 'Cardiologia',
      date: LocalDate(2026, 9, 1),
      professional: 'Dra. Helena',
      notes: 'Retorno em 6 meses',
    ));
    expect(repo.list(kind: MedicalHistoryKind.vaccine).map((i) => i.title), ['Covid', 'Gripe']);
    expect(repo.list(kind: MedicalHistoryKind.appointment).single.professional, 'Dra. Helena');
    expect(repo.list(), hasLength(4));
    expect(repo.list().last.title, 'Dipirona'); // sem data vai para o fim
    repo.delete('a');
    expect(repo.list(kind: MedicalHistoryKind.allergy), isEmpty);
  });

  test('item sem nome é recusado', () {
    expect(() => MedicalHistoryItem(id: 'x', kind: MedicalHistoryKind.condition, title: '  '), throwsArgumentError);
  });
}
