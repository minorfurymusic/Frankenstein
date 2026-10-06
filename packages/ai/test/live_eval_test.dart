import 'dart:convert';
import 'dart:io';

import 'package:frankstein_ai/ai.dart';
import 'package:test/test.dart';

/// Avaliação **ao vivo**: manda os 12 exemplos reais
/// (`fixtures/real_examples/FONTES.md`) ao Gemini e compara com o gabarito.
/// Só roda com a chave no ambiente — nunca no CI nem por acaso:
///
///     GEMINI_API_KEY=... dart test test/live_eval_test.dart
///
/// (opcional: `GEMINI_MODEL=...`). Gasta a cota da chave: 12 chamadas.
/// As margens são para estimativa, não exigência de perfeição: prato com
/// erro de calorias até 50 %; receita com médico, data e todos os remédios;
/// exame com a data e ao menos 80 % dos valores iguais ao laudo.
const _dir = 'test/fixtures/real_examples';

String _norm(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const to = 'aaaaaeeeeiiiiooooouuuuc';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

void main() {
  final key = Platform.environment['GEMINI_API_KEY'];
  final skip = key == null || key.isEmpty ? 'sem GEMINI_API_KEY no ambiente (avaliação ao vivo desligada)' : null;
  final expected = jsonDecode(File('$_dir/expected.json').readAsStringSync()) as Map<String, dynamic>;
  List<Map<String, dynamic>> cases(String g) => (expected[g] as List).cast<Map<String, dynamic>>();
  GeminiClient client() => GeminiClient(apiKey: key!, model: Platform.environment['GEMINI_MODEL'] ?? GeminiClient.defaultModel);
  AiPart part(Map<String, dynamic> c) => AiPart.file(File('$_dir/${c['file']}').readAsBytesSync(), c['mime'] as String);

  group('ao vivo — pratos (Nutrition5k, calorias medidas)', skip: skip, () {
    for (final c in cases('pratos')) {
      test(c['file'], () async {
        final e = await estimatePlate(client(), part(c));
        final truth = (c['truth'] as Map)['kcal'] as num;
        final err = (e.kcal - truth).abs() / truth;
        print('${c['file']}: IA ${e.kcal.round()} kcal × medido ${truth.round()} kcal (erro ${(err * 100).round()} %) — '
            '${e.items.map((i) => '${i.name} ${i.grams.round()} g').join(', ')}');
        expect(e.items, isNotEmpty);
        expect(err, lessThanOrEqualTo(0.5));
      }, timeout: const Timeout(Duration(minutes: 2)));
    }
  });

  group('ao vivo — receitas (sintéticas)', skip: skip, () {
    for (final c in cases('receitas')) {
      test(c['file'], () async {
        final r = await readPrescription(client(), [part(c)]);
        final truth = c['truth'] as Map<String, dynamic>;
        print('${c['file']}: ${r.doctor} ${r.date} — ${r.medicines.map((m) => '${m.name} (${m.instructions})').join('; ')}');
        expect(_norm(r.doctor ?? ''), contains(_norm((truth['doctor'] as String).split(' ').last)));
        expect(r.date?.toIso8601String().substring(0, 10), truth['date']);
        final read = r.medicines.map((m) => _norm(m.name)).join(' | ');
        for (final name in (truth['medicines'] as List).cast<String>()) {
          expect(read, contains(_norm(name)), reason: name);
        }
        // Nenhuma dose inventada: só "1 unidade" (o que está escrito) ou nada.
        for (final m in r.medicines) {
          expect(m.doseAmount == null || m.doseAmount == 1, isTrue, reason: '${m.name}: ${m.doseAmount} ${m.doseUnit}');
        }
      }, timeout: const Timeout(Duration(minutes: 2)));
    }
  });

  group('ao vivo — exames (laudos sintéticos em PDF)', skip: skip, () {
    for (final c in cases('exames')) {
      test(c['file'], () async {
        final r = await readExam(client(), [part(c)]);
        final truth = ((c['truth'] as Map)['markers'] as Map).cast<String, dynamic>();
        var hits = 0;
        final misses = <String>[];
        for (final entry in truth.entries) {
          final value = (entry.value as List)[0] as num;
          final found = r.markers.any((m) => (m.value - value).abs() <= value.abs() * 0.01 + 1e-9 && _norm(m.name).isNotEmpty);
          found ? hits++ : misses.add('${entry.key} $value');
        }
        print('${c['file']}: ${r.markers.length} valores lidos; $hits/${truth.length} do gabarito'
            '${misses.isEmpty ? '' : ' — faltaram: ${misses.join(', ')}'}');
        expect(r.date?.toIso8601String().substring(0, 10), (c['truth'] as Map)['date']);
        expect(hits / truth.length, greaterThanOrEqualTo(0.8));
      }, timeout: const Timeout(Duration(minutes: 2)));
    }
  });
}
