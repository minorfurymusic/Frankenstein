import 'package:flutter/material.dart';
import 'package:frankstein_health_records/health_records.dart';

import '../../app_dependencies.dart';
import '../../widgets/state_views.dart';
import '../../data/health_read_model.dart';
import '../../format.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/badges.dart';
import '../../widgets/common.dart';
import 'body_screen.dart';
import 'documents_screens.dart';
import 'medications_screen.dart';
import 'sleep_screen.dart';
import 'symptoms_screen.dart';
import 'vitals_screen.dart';
import 'medication_form_screen.dart';

/// Aba Saúde (prancheta Saude): resumo (próximo remédio, último sintoma,
/// última pressão, peso atual), seções e o aviso fixo no rodapé.
class HealthTab extends StatelessWidget {
  final AppDependencies deps;
  const HealthTab({super.key, required this.deps});

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: deps.dataVersion,
      builder: (context, _, _) => GuardedView(
        errorTitle: 'Não foi possível carregar o resumo',
        errorMessage: 'Seus dados estão salvos no celular. Tente de novo.',
        builder: (context) {
        final c = RltColors.of(context);
        final read = deps.healthRead;
        final next = read.nextDose();
        final symptoms = read.symptoms(days: 90);
        final pressure = read.vitals(VitalKind.bloodPressure, days: 90);
        final weights = read.weights();
        final active = read.activeMedications();
        final today = LocalDate.fromDateTime(DateTime.now());
        final prescriptions = deps.documents.list(HealthDocumentKind.prescription);
        final valid = prescriptions.where((p) => p.validUntil == null || p.validUntil!.compareTo(today) >= 0).length;
        final exams = deps.documents.list(HealthDocumentKind.exam);
        final lastExam = exams.map((e) => e.date).whereType<LocalDate>().fold<LocalDate?>(null, (a, b) => a == null || b.compareTo(a) > 0 ? b : a);
        final nothingYet = active.isEmpty && symptoms.isEmpty && pressure.isEmpty && weights.isEmpty && prescriptions.isEmpty && exams.isEmpty;
        return Column(
          children: [
            Expanded(
              child: ListView(
                key: const Key('tab_saude'),
                padding: const EdgeInsets.only(bottom: RltSpace.l),
                children: [
                  const RltPageTitle('Saúde'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: RltSpace.l),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (nothingYet)
                        StateCard(
                          key: const Key('health_empty'),
                          icon: Icons.favorite_outline,
                          title: 'Seu histórico começa aqui',
                          message: 'Cadastre um remédio, registre a pressão ou mande a foto de uma receita para o Cérebro.',
                          actionLabel: 'Cadastrar remédio',
                          actionIcon: Icons.add,
                          onAction: () => _open(context, MedicationFormScreen(deps: deps)),
                          secondaryLabel: 'Fotografar receita',
                          secondaryIcon: Icons.photo_camera_outlined,
                          onSecondary: () => _open(context, PrescriptionsScreen(deps: deps)),
                        )
                      else
                      RltTwoColumnGrid(children: [
                        RltStatTile(
                          icon: Icons.medication_outlined,
                          iconColor: c.error,
                          label: 'Próximo remédio',
                          value: next == null ? '—' : '${next.medication.name} ${doseLabel(next.medication)}',
                          caption: next == null
                              ? (active.isEmpty ? 'Nenhum cadastrado' : 'Nada pendente hoje')
                              : (next.overdue ? 'Atrasado · ${next.time}' : 'Hoje às ${next.time}'),
                          onTap: () => _open(context, MedicationsScreen(deps: deps)),
                        ),
                        RltStatTile(
                          icon: Icons.sentiment_dissatisfied_outlined,
                          iconColor: c.tertiary,
                          label: 'Último sintoma',
                          value: symptoms.isEmpty ? '—' : symptoms.first.name,
                          caption: symptoms.isEmpty ? 'Nenhum nos últimos 90 dias' : relativeDayTime(symptoms.first.startedLocal),
                          onTap: () => _open(context, SymptomsScreen(deps: deps)),
                        ),
                        RltStatTile(
                          icon: Icons.monitor_heart_outlined,
                          iconColor: c.error,
                          label: 'Última pressão',
                          value: pressure.isEmpty ? '—' : pressure.first.display,
                          unit: pressure.isEmpty ? null : 'mmHg',
                          caption: pressure.isEmpty ? 'Sem medida' : relativeDayTime(pressure.first.local),
                          onTap: () => _open(context, VitalsScreen(deps: deps)),
                        ),
                        RltStatTile(
                          icon: Icons.monitor_weight_outlined,
                          iconColor: c.secondary,
                          label: 'Peso atual',
                          value: weights.isEmpty ? '—' : formatNumber(weights.first.value, decimals: 1),
                          unit: weights.isEmpty ? null : 'kg',
                          caption: weights.isEmpty ? 'Sem pesagem' : relativeDayTime(weights.first.local),
                          onTap: () => _open(context, BodyScreen(deps: deps)),
                        ),
                      ]),
                      const RltSectionHeader('Seções'),
                      RltSectionTile(
                        key: const Key('section_remedios'),
                        icon: Icons.medication_outlined,
                        iconColor: c.error,
                        title: 'Remédios',
                        subtitle: active.isEmpty
                            ? 'Nenhum ativo'
                            : '${active.length} ${active.length == 1 ? 'ativo' : 'ativos'}${next == null ? '' : ' · próximo às ${next.time}'}',
                        onTap: () => _open(context, MedicationsScreen(deps: deps)),
                      ),
                      RltSectionTile(
                        key: const Key('section_receitas'),
                        icon: Icons.description_outlined,
                        iconColor: c.protein,
                        title: 'Receitas médicas',
                        subtitle: prescriptions.isEmpty
                            ? 'Foto ou PDF da receita'
                            : '$valid ${valid == 1 ? 'receita válida' : 'receitas válidas'}',
                        onTap: () => _open(context, PrescriptionsScreen(deps: deps)),
                      ),
                      RltSectionTile(
                        key: const Key('section_historico'),
                        icon: Icons.medical_information_outlined,
                        iconColor: c.primary,
                        title: 'Histórico médico',
                        subtitle: 'Sintomas, condições, consultas',
                        onTap: () => _open(context, SymptomsScreen(deps: deps)),
                      ),
                      RltSectionTile(
                        key: const Key('section_exames'),
                        icon: Icons.science_outlined,
                        iconColor: c.protein,
                        title: 'Exames e documentos',
                        subtitle: exams.isEmpty
                            ? 'Foto ou PDF de exames'
                            : '${exams.length} ${exams.length == 1 ? 'exame' : 'exames'}${lastExam == null ? '' : ' · último ${two(lastExam.day)}/${two(lastExam.month)}'}',
                        onTap: () => _open(context, ExamsScreen(deps: deps)),
                      ),
                      RltSectionTile(
                        key: const Key('section_vitais'),
                        icon: Icons.monitor_heart_outlined,
                        iconColor: c.error,
                        title: 'Sinais vitais',
                        subtitle: 'Pressão, glicemia, coração…',
                        onTap: () => _open(context, VitalsScreen(deps: deps)),
                      ),
                      RltSectionTile(
                        key: const Key('section_corpo'),
                        icon: Icons.monitor_weight_outlined,
                        iconColor: c.secondary,
                        title: 'Corpo',
                        subtitle: 'Peso, gordura, medidas',
                        onTap: () => _open(context, BodyScreen(deps: deps)),
                      ),
                      RltSectionTile(
                        icon: Icons.bedtime_outlined,
                        iconColor: c.sleep,
                        title: 'Sono',
                        subtitle: 'Da pulseira, via Health Connect',
                        onTap: () => _open(context, SleepScreen(deps: deps)),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
            // Rodapé fixo da aba (PROMPT-CLAUDE-DESIGN.md, seção 2).
            const Padding(
              padding: EdgeInsets.fromLTRB(RltSpace.l, 0, RltSpace.l, RltSpace.s),
              child: HealthDisclaimer(),
            ),
          ],
        );
      }),
    );
  }
}
