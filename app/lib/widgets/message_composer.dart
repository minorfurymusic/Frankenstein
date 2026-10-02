import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/rlt_colors.dart';
import '../theme/rlt_theme.dart';

/// Com IA (chave configurada, ADR-11) o campo aceita anexos, foto e voz; no
/// modo básico só aceita comandos de texto do roteador determinístico.
enum ComposerMode { ai, basic }

/// Campo de mensagem do Cérebro (prancheta Componentes, "Campo de mensagem —
/// normal / com texto / gravando / modo básico").
///
/// O componente só desenha e avisa: quem grava áudio, abre câmera ou
/// anexa arquivo é quem passa os callbacks — nenhuma permissão é pedida
/// aqui dentro.
class MessageComposer extends StatefulWidget {
  final ComposerMode mode;
  final TextEditingController? controller;
  final ValueChanged<String> onSend;
  final VoidCallback? onAttach;
  final VoidCallback? onCamera;
  final VoidCallback? onRecordStart;
  final ValueChanged<Duration>? onRecordEnd;
  final VoidCallback? onRecordCancel;

  const MessageComposer({
    super.key,
    required this.mode,
    required this.onSend,
    this.controller,
    this.onAttach,
    this.onCamera,
    this.onRecordStart,
    this.onRecordEnd,
    this.onRecordCancel,
  });

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  late final TextEditingController _controller = widget.controller ?? TextEditingController();
  bool _hasText = false;
  bool _recording = false;
  bool _cancelHint = false;
  DateTime? _recordStartedAt;
  Duration _elapsed = Duration.zero;
  Timer? _ticker;

  /// O layout troca inteiro ao começar a gravar; sem a mesma chave global o
  /// botão do microfone seria recriado no meio do toque longo e o "soltar"
  /// (que entrega o áudio) nunca chegaria.
  final _micKey = GlobalKey(debugLabel: 'composer_mic');

  @override
  void initState() {
    super.initState();
    _hasText = _controller.text.trim().isNotEmpty;
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _controller.removeListener(_onTextChanged);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final has = _controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  void _startRecording() {
    widget.onRecordStart?.call();
    _recordStartedAt = DateTime.now();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed = DateTime.now().difference(_recordStartedAt!));
    });
    setState(() {
      _recording = true;
      _cancelHint = false;
      _elapsed = Duration.zero;
    });
  }

  void _stopRecording({required bool cancel}) {
    _ticker?.cancel();
    final elapsed = _recordStartedAt == null ? Duration.zero : DateTime.now().difference(_recordStartedAt!);
    setState(() => _recording = false);
    if (cancel) {
      widget.onRecordCancel?.call();
    } else {
      widget.onRecordEnd?.call(elapsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;

    if (widget.mode == ComposerMode.basic) {
      return _Bar(children: [
        Expanded(child: _field(c, t, hint: 'Comando, ex.: registrar água 500ml', withCamera: false)),
        const SizedBox(width: RltSpace.s),
        IconButton.filledTonal(
          onPressed: _hasText ? _send : null,
          tooltip: 'Enviar',
          icon: const Icon(Icons.send_outlined),
        ),
      ]);
    }

    if (_recording) {
      final secs = _elapsed.inSeconds;
      return _Bar(
        vertical: true,
        children: [
          Row(children: [
            Icon(Icons.close, size: 18, color: c.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(_cancelHint ? 'Solte para cancelar' : 'Arraste para a esquerda para cancelar', style: t.bodyMedium),
          ]),
          const SizedBox(height: RltSpace.s),
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c.error, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Text('${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}', style: RltTheme.tabular(t.titleSmall!)),
            const Spacer(),
            Semantics(
              label: 'Gravando — solte para enviar',
              child: _micButton(c, recording: true),
            ),
          ]),
        ],
      );
    }

    return _Bar(children: [
      IconButton(
        onPressed: widget.onAttach,
        tooltip: 'Anexar foto, arquivo, áudio ou vídeo',
        icon: const Icon(Icons.add),
      ),
      Expanded(child: _field(c, t, hint: 'Escreva ou fale…', withCamera: true)),
      const SizedBox(width: RltSpace.s),
      if (_hasText)
        IconButton.filled(onPressed: _send, tooltip: 'Enviar', icon: const Icon(Icons.send_outlined))
      else
        Tooltip(message: 'Segure para gravar voz', child: _micButton(c, recording: false)),
    ]);
  }

  Widget _micButton(RltColors c, {required bool recording}) {
    final size = recording ? 64.0 : 48.0;
    return GestureDetector(
      key: _micKey,
      onLongPressStart: (_) => _startRecording(),
      onLongPressMoveUpdate: (d) {
        final cancel = d.offsetFromOrigin.dx < -80;
        if (cancel != _cancelHint) setState(() => _cancelHint = cancel);
      },
      onLongPressEnd: (_) => _stopRecording(cancel: _cancelHint),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: recording ? c.error : c.primary,
          shape: BoxShape.circle,
          boxShadow: recording ? [BoxShadow(color: c.errorContainer, spreadRadius: 8)] : null,
        ),
        child: Icon(Icons.mic_none_rounded, color: recording ? c.onError : c.onPrimary),
      ),
    );
  }

  Widget _field(RltColors c, TextTheme t, {required String hint, required bool withCamera}) {
    return TextField(
      controller: _controller,
      minLines: 1,
      maxLines: 5,
      textInputAction: TextInputAction.send,
      onSubmitted: (_) => _send(),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: c.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(RltRadius.button), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(RltRadius.button), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(RltRadius.button), borderSide: BorderSide(color: c.primary)),
        suffixIcon: withCamera
            ? IconButton(onPressed: widget.onCamera, tooltip: 'Tirar foto', icon: const Icon(Icons.photo_camera_outlined))
            : null,
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final List<Widget> children;
  final bool vertical;
  const _Bar({required this.children, this.vertical = false});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: RltSpace.s, vertical: RltSpace.s),
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.outlineVariant))),
      child: SafeArea(
        top: false,
        child: vertical
            ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children)
            : Row(crossAxisAlignment: CrossAxisAlignment.end, children: children),
      ),
    );
  }
}
