import 'package:flutter/material.dart';

import '../../app_dependencies.dart';
import '../../format.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/badges.dart';
import 'mental_health_screen.dart' show CrisisNotice;

/// Questionário de rastreio (ADR-23). Texto da versão oficial em português
/// do Brasil, sem mudar nenhuma palavra:
/// - PHQ-9: "Portuguese for Brazil version of the PHQ-9" — reproduzido em
///   passeidireto.com/arquivo/144633387 (PHQ9_Portuguese for Brazil) e
///   conferido com os trechos de teses da USP e do protocolo FUNESA/SE.
/// - GAD-7: "Portuguese for Brazil version of the GAD-7 Screener" (Pfizer,
///   2013), como publicado em Leite et al., Psico-USF (SciELO, 2022).
/// Licença dos dois: "Desenvolvido pelos Drs. Robert L. Spitzer, Janet B.W.
/// Williams, Kurt Kroenke e colegas, com um subsídio educacional da Pfizer
/// Inc. Não é necessária permissão para reproduzir, traduzir, exibir ou
/// distribuir."
class Questionnaire {
  final String id;
  final String title;
  final String about;
  final String prompt;
  final List<String> items;
  final int maxScore;
  const Questionnaire({
    required this.id,
    required this.title,
    required this.about,
    required this.prompt,
    required this.items,
    required this.maxScore,
  });
}

const answerLabels = ['Nenhuma vez', 'Vários dias', 'Mais da metade dos dias', 'Quase todos os dias'];
const difficultyLabels = ['Nenhuma dificuldade', 'Alguma dificuldade', 'Muita dificuldade', 'Extrema dificuldade'];
const difficultyQuestion = 'Se você assinalou qualquer um dos problemas, indique o grau de dificuldade que os mesmos lhe '
    'causaram para realizar seu trabalho, tomar conta das coisas em casa ou para se relacionar com as pessoas?';
const questionnaireCredit = 'Desenvolvido pelos Drs. Robert L. Spitzer, Janet B.W. Williams, Kurt Kroenke e colegas, com um '
    'subsídio educacional da Pfizer Inc. Não é necessária permissão para reproduzir, traduzir, exibir ou distribuir.';

const phq9 = Questionnaire(
  id: 'phq9',
  title: 'Questionário sobre a saúde do/a paciente (PHQ-9)',
  about: 'Sobre humor e depressão',
  prompt: 'Durante as últimas 2 semanas, com que freqüência você foi incomodado/a por qualquer um dos problemas abaixo?',
  items: [
    'Pouco interesse ou pouco prazer em fazer as coisas',
    'Se sentir “para baixo”, deprimido/a ou sem perspectiva',
    'Dificuldade para pegar no sono ou permanecer dormindo, ou dormir mais do que de costume',
    'Se sentir cansado/a ou com pouca energia',
    'Falta de apetite ou comendo demais',
    'Se sentir mal consigo mesmo/a — ou achar que você é um fracasso ou que decepcionou sua família ou você mesmo/a',
    'Dificuldade para se concentrar nas coisas, como ler o jornal ou ver televisão',
    'Lentidão para se movimentar ou falar, a ponto das outras pessoas perceberem? Ou o oposto – estar tão agitado/a ou '
        'irrequieto/a que você fica andando de um lado para o outro muito mais do que de costume',
    'Pensar em se ferir de alguma maneira ou que seria melhor estar morto/a',
  ],
  maxScore: 27,
);

const gad7 = Questionnaire(
  id: 'gad7',
  title: 'Questionário de ansiedade (GAD-7)',
  about: 'Sobre ansiedade e preocupação',
  prompt: 'Durante as últimas 2 semanas, com que frequência você foi incomodado/a pelos problemas abaixo?',
  items: [
    'Sentir-se nervoso(a), ansioso(a) ou muito tenso(a).',
    'Não ser capaz de impedir ou de controlar as preocupações.',
    'Preocupar-se muito com diversas coisas.',
    'Dificuldade para relaxar.',
    'Ficar tão agitado(a) que se torna difícil permanecer sentado(a).',
    'Ficar facilmente aborrecido(a) ou irritado(a).',
    'Sentir medo como se algo horrível fosse acontecer.',
  ],
  maxScore: 21,
);

const questionnaires = {'phq9': phq9, 'gad7': gad7};

/// O que o app diz da pontuação: só o ponto de corte que os autores usam
/// (10 nos dois — Kroenke et al., 2001; Spitzer et al., 2006), nunca
/// diagnóstico.
String scoreMessage(Questionnaire q, int score) => score >= 10
    ? 'Pontuação $score de ${q.maxScore}. Os autores do questionário consideram 10 ou mais um sinal para conversar '
        'com um profissional de saúde. Isto não é diagnóstico.'
    : 'Pontuação $score de ${q.maxScore}. Abaixo de 10, o ponto que os autores usam para sugerir conversar com um '
        'profissional. Isto não é diagnóstico; se algo incomoda, vale conversar mesmo assim.';

class QuestionnaireScreen extends StatefulWidget {
  final AppDependencies deps;
  final Questionnaire questionnaire;
  const QuestionnaireScreen({super.key, required this.deps, required this.questionnaire});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  late final List<int?> _answers = List.filled(widget.questionnaire.items.length, null);
  int? _difficulty;
  int? _score;

  Questionnaire get _q => widget.questionnaire;
  bool get _complete => _answers.every((a) => a != null);

  void _save() {
    final now = DateTime.now();
    final answers = [for (final a in _answers) a!];
    widget.deps.screeningLogger.log(
      instrument: _q.id,
      answers: answers,
      difficulty: answers.any((a) => a > 0) ? _difficulty : null,
      occurredAt: now.toUtc(),
      occurredAtTzOffsetMinutes: now.timeZoneOffset.inMinutes,
    );
    widget.deps.notifyDataChanged();
    setState(() => _score = answers.fold<int>(0, (s, a) => s + a));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final score = _score;
    // Item 9 do PHQ-9 (pensar em se ferir) com qualquer resposta acima de
    // "nenhuma vez": o aviso de ajuda vem primeiro, sempre.
    final selfHarm = _q.id == 'phq9' && (_answers[8] ?? 0) > 0;
    return Scaffold(
      appBar: AppBar(title: Text(_q.id == 'phq9' ? 'PHQ-9' : 'GAD-7')),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        if (score != null) ...[
          if (selfHarm) ...[const CrisisNotice(), const SizedBox(height: RltSpace.m)],
          Text('Respostas salvas em Saúde › Saúde mental.', style: t.titleMedium),
          const SizedBox(height: RltSpace.s),
          Text(scoreMessage(_q, score), key: const Key('questionnaire_result'), style: t.bodyLarge),
          const SizedBox(height: RltSpace.l),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Voltar')),
        ] else ...[
          Text(_q.title, style: t.titleMedium),
          const SizedBox(height: RltSpace.s),
          Text(_q.prompt, style: t.bodyLarge),
          for (var i = 0; i < _q.items.length; i++) ...[
            const SizedBox(height: RltSpace.l),
            Text('${i + 1}. ${_q.items[i]}', style: t.titleSmall),
            const SizedBox(height: RltSpace.xs),
            Wrap(spacing: RltSpace.xs, runSpacing: RltSpace.xs, children: [
              for (var v = 0; v < 4; v++)
                ChoiceChip(
                  key: Key('q_${i}_$v'),
                  label: Text(answerLabels[v]),
                  selected: _answers[i] == v,
                  onSelected: (_) => setState(() => _answers[i] = v),
                ),
            ]),
          ],
          if (selfHarm) ...[const SizedBox(height: RltSpace.l), const CrisisNotice()],
          if (_answers.any((a) => (a ?? 0) > 0)) ...[
            const SizedBox(height: RltSpace.l),
            Text(difficultyQuestion, style: t.titleSmall),
            const SizedBox(height: RltSpace.xs),
            Wrap(spacing: RltSpace.xs, runSpacing: RltSpace.xs, children: [
              for (var v = 0; v < 4; v++)
                ChoiceChip(
                  key: Key('q_difficulty_$v'),
                  label: Text(difficultyLabels[v]),
                  selected: _difficulty == v,
                  onSelected: (_) => setState(() => _difficulty = v),
                ),
            ]),
          ],
          const SizedBox(height: RltSpace.l),
          FilledButton(
            key: const Key('questionnaire_save'),
            onPressed: _complete ? _save : null,
            child: Text(_complete ? 'Salvar respostas' : 'Responda todas as perguntas'),
          ),
        ],
        const SizedBox(height: RltSpace.l),
        Text(questionnaireCredit, style: t.bodySmall),
        const SizedBox(height: RltSpace.s),
        const HealthDisclaimer(),
      ]),
    );
  }
}

/// Linha da tela Saúde mental: abre o questionário e mostra a última
/// pontuação.
class QuestionnaireTile extends StatelessWidget {
  final AppDependencies deps;
  final Questionnaire questionnaire;
  const QuestionnaireTile({super.key, required this.deps, required this.questionnaire});

  @override
  Widget build(BuildContext context) {
    final last = deps.healthRead.screenings(questionnaire.id).firstOrNull;
    return ListTile(
      key: Key('questionnaire_${questionnaire.id}'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.assignment_outlined),
      title: Text(questionnaire.id == 'phq9' ? 'PHQ-9 · ${questionnaire.about}' : 'GAD-7 · ${questionnaire.about}'),
      subtitle: Text(last == null
          ? '${questionnaire.items.length} perguntas sobre as últimas 2 semanas'
          : 'Última: ${last.score} de ${questionnaire.maxScore} — ${relativeDayTime(last.local)}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => QuestionnaireScreen(deps: deps, questionnaire: questionnaire),
      )),
    );
  }
}
