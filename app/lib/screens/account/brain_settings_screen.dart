import 'package:flutter/material.dart';
import 'package:frankstein_ai/ai.dart';

import '../../ai/ai_settings.dart';
import '../../app_dependencies.dart';
import '../../format.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/badges.dart';
import '../../widgets/common.dart';

/// Conta › Cérebro (IA) (prancheta ContaCerebro): modo básico × IA ativa,
/// provedor, chave (testar e salvar / apagar), o que é enviado e o
/// consentimento. A chave só é usada quando a pessoa age; testar a chave
/// manda só "Responda apenas: ok", nenhum dado de saúde.
class BrainSettingsScreen extends StatefulWidget {
  final AppDependencies deps;
  const BrainSettingsScreen({super.key, required this.deps});

  @override
  State<BrainSettingsScreen> createState() => _BrainSettingsScreenState();
}

class _BrainSettingsScreenState extends State<BrainSettingsScreen> {
  final _key = TextEditingController();
  late final _model = TextEditingController(text: widget.deps.ai.model);
  bool _busy = false;
  String? _error;
  bool _obscure = true;

  AiSettings get _ai => widget.deps.ai;

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    _ai.setModel(_model.text);
    try {
      await _ai.testAndSaveKey(_key.text);
      _key.clear();
      if (mounted) showRltSaved(context, 'Chave testada e guardada só neste celular. IA ativa.');
    } on AiException catch (e) {
      _error = e.failure == AiFailure.badKey || e.failure == AiFailure.noKey
          ? 'O provedor recusou esta chave. Confira se copiou inteira.'
          : aiFailureMessage(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _remove() async {
    await _ai.removeKey();
    if (mounted) {
      setState(() {});
      showRltSaved(context, 'Chave apagada. O Cérebro voltou ao modo básico.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    Widget bullet(String s, {IconData icon = Icons.circle, Color? color}) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 3), child: Icon(icon, size: icon == Icons.circle ? 6 : 16, color: color)),
            const SizedBox(width: RltSpace.s),
            Expanded(child: Text(s, style: t.bodyMedium)),
          ]),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Cérebro (IA)')),
      body: ValueListenableBuilder<bool>(
        valueListenable: _ai.hasKey,
        builder: (context, active, _) {
          final tested = _ai.lastTestedAt;
          final consent = _ai.consentedAt;
          return ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
            Card(
              key: Key(active ? 'ai_active' : 'ai_basic'),
              color: active ? c.successContainer : c.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(RltSpace.l),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(active ? 'IA ativa' : 'Modo básico ativo', style: t.titleMedium),
                  const SizedBox(height: RltSpace.xs),
                  Text(
                    active
                        ? 'Chave testada${tested == null ? '' : ' em ${ddmmyyyy(tested)} às ${hhmm(tested)}'}. '
                            'Lê exames, fotos de prato e planos de refeição quando você pede.'
                        : 'Sem chave, o Cérebro entende comandos simples como "registrar água 500ml" e "resumo de hoje". Funciona offline.',
                    style: t.bodyMedium,
                  ),
                ]),
              ),
            ),
            const RltSectionHeader('Provedor de IA'),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.auto_awesome_outlined),
              title: Text(AiSettings.providerName),
              subtitle: Text('Com a sua própria chave. Você paga o uso direto ao provedor.'),
            ),
            if (!active) ...[
              TextField(
                key: const Key('ai_key_field'),
                controller: _key,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Chave de API',
                  errorText: _error,
                  errorMaxLines: 3,
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Mostrar' : 'Esconder',
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
              ),
              const SizedBox(height: RltSpace.s),
              Text('A chave fica guardada só neste celular, cifrada pelo Android.', style: t.bodySmall),
              const SizedBox(height: RltSpace.m),
              FilledButton(
                key: const Key('ai_test_save'),
                onPressed: _busy ? null : _testAndSave,
                child: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Testar e salvar'),
              ),
              const SizedBox(height: RltSpace.s),
              Text(
                'Como conseguir uma chave: entre no Google AI Studio com a sua conta Google, abra "Get API key" e crie '
                'uma chave. Copie e cole aqui.',
                style: t.bodySmall,
              ),
            ] else ...[
              OutlinedButton.icon(
                key: const Key('ai_remove_key'),
                onPressed: _remove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Apagar chave'),
              ),
            ],
            const SizedBox(height: RltSpace.m),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Modelo', style: t.titleSmall),
              subtitle: Text(_ai.model, style: t.bodySmall),
              children: [
                TextField(
                  key: const Key('ai_model'),
                  controller: _model,
                  decoration: const InputDecoration(labelText: 'Nome do modelo', helperText: 'Padrão: ${GeminiClient.defaultModel}'),
                  onSubmitted: (v) => setState(() => _ai.setModel(v)),
                ),
              ],
            ),
            const RltSectionHeader('O que é enviado'),
            bullet('Só o que você mandar, quando você mandar: a foto ou o PDF do exame que você anexou, a foto do prato, '
                'o plano de refeições que você importou, ou o pedido de sugestão com suas metas e preferências.',
                icon: Icons.check, color: c.success),
            bullet('Nunca vai: seu histórico de saúde guardado, outras conversas, sua conta e sua localização.',
                icon: Icons.block, color: c.error),
            bullet('Tudo o que a IA devolve chega como estimativa: você confere e confirma antes de salvar.',
                icon: Icons.fact_check_outlined, color: c.primary),
            const RltSectionHeader('Termo de consentimento'),
            Text(
              consent == null
                  ? 'Ainda não aceito. O app pergunta antes do primeiro envio.'
                  : 'Aceito em ${ddmmyyyy(consent)}. Apagar a chave também retira o aceite.',
              key: const Key('ai_consent_status'),
              style: t.bodyMedium,
            ),
            const SizedBox(height: RltSpace.l),
            const HealthDisclaimer(),
          ]);
        },
      ),
    );
  }
}
