import 'dart:io';

import 'package:frankstein_health_records/health_records.dart';
import 'package:test/test.dart';

void main() {
  const pdf = HealthDocumentFile(storedName: 'd1_0.pdf', originalName: 'resultado.pdf', mimeType: 'application/pdf', sizeBytes: 380000);
  const photo = HealthDocumentFile(storedName: 'r1_0.jpg', originalName: 'IMG_1.jpg', mimeType: 'image/jpeg', sizeBytes: 1200000);

  test('salva receita com validade, remédios vinculados e foto; lista a mais recente primeiro', () {
    final repo = HealthDocumentRepository.openInMemory();
    addTearDown(repo.close);
    repo.save(HealthDocument(
      id: 'r1',
      kind: HealthDocumentKind.prescription,
      title: 'Dra. Helena Martins',
      specialty: 'Clínica geral',
      date: LocalDate(2026, 9, 30),
      validUntil: LocalDate(2027, 3, 30),
      linkedMedicationIds: const ['m1', 'm2'],
      files: const [photo],
    ));
    repo.save(HealthDocument(id: 'r0', kind: HealthDocumentKind.prescription, title: 'Dr. Paulo', date: LocalDate(2026, 1, 10)));
    final list = repo.list(HealthDocumentKind.prescription);
    expect(list.map((d) => d.id), ['r1', 'r0']);
    final r1 = list.first;
    expect(r1.specialty, 'Clínica geral');
    expect(r1.linkedMedicationIds, ['m1', 'm2']);
    expect(r1.files.single.originalName, 'IMG_1.jpg');
    expect(r1.files.single.isPdf, isFalse);
    expect(r1.isExpiredOn(LocalDate(2027, 3, 30)), isFalse);
    expect(r1.isExpiredOn(LocalDate(2027, 3, 31)), isTrue);
    expect(repo.list(HealthDocumentKind.exam), isEmpty);
  });

  test('exames filtram por categoria; apagar remove; nomes de arquivo guardados', () {
    final repo = HealthDocumentRepository.openInMemory();
    addTearDown(repo.close);
    repo.save(HealthDocument(
      id: 'e1',
      kind: HealthDocumentKind.exam,
      title: 'Hemograma completo',
      category: ExamCategory.blood,
      date: LocalDate(2026, 9, 25),
      files: const [pdf],
    ));
    repo.save(HealthDocument(id: 'e2', kind: HealthDocumentKind.exam, title: 'Ultrassom de abdome', category: ExamCategory.image));
    expect(repo.list(HealthDocumentKind.exam, category: ExamCategory.blood).single.title, 'Hemograma completo');
    expect(repo.list(HealthDocumentKind.exam), hasLength(2));
    expect(repo.allStoredNames(), {'d1_0.pdf'});
    expect(repo.byId('e1')!.files.single.isPdf, isTrue);
    repo.delete('e1');
    expect(repo.byId('e1'), isNull);
    expect(repo.allStoredNames(), isEmpty);
  });

  test('validação: sem nome e validade antes da data', () {
    expect(() => HealthDocument(id: 'x', kind: HealthDocumentKind.exam, title: ' '), throwsArgumentError);
    expect(
      () => HealthDocument(
        id: 'x',
        kind: HealthDocumentKind.prescription,
        title: 'Dra. A',
        date: LocalDate(2026, 5, 1),
        validUntil: LocalDate(2026, 4, 1),
      ),
      throwsArgumentError,
    );
  });

  test('divide o arquivo do banco de remédios sem atrapalhar o histórico médico', () {
    final dir = Directory.systemTemp.createTempSync('rlt_docs');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/meds.sqlite3';
    final history = MedicalHistoryRepository.open(path);
    final docs = HealthDocumentRepository.open(path);
    history.save(MedicalHistoryItem(id: 'a', kind: MedicalHistoryKind.allergy, title: 'Dipirona'));
    docs.save(HealthDocument(id: 'e', kind: HealthDocumentKind.exam, title: 'Glicemia', category: ExamCategory.blood));
    history.close();
    docs.close();
    final reopened = HealthDocumentRepository.open(path);
    addTearDown(reopened.close);
    expect(reopened.list(HealthDocumentKind.exam).single.title, 'Glicemia');
  });
}
