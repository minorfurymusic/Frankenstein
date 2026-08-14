import 'package:xml/xml.dart';

import 'run_point.dart';

/// Exportação/importação GPX — obrigatória
/// (`.claude/rules/activity.md:19`: "Exportação/importação GPX
/// obrigatória", LGPD art. 18 via `.claude/rules/00-inviolaveis.md`:
/// "Exportação de dados nunca é paga nem limitada"). GPX 1.1
/// (`http://www.topografix.com/GPX/1/1`), um `<trk>`/`<trkseg>` por
/// rota — sem extensões proprietárias.
///
/// Usa `package:xml` (MIT) — só pra montar/ler XML bem formado, não
/// interpreta semântica de GPX além de `trkpt`/`lat`/`lon`/`ele`/`time`.

String exportGpx(List<RunPointInput> points, {String creator = 'Frankstein'}) {
  final builder = XmlBuilder();
  builder.processing('xml', 'version="1.0" encoding="UTF-8"');
  builder.element('gpx', nest: () {
    builder.attribute('version', '1.1');
    builder.attribute('creator', creator);
    builder.attribute('xmlns', 'http://www.topografix.com/GPX/1/1');
    builder.element('trk', nest: () {
      builder.element('trkseg', nest: () {
        for (final p in points) {
          builder.element('trkpt', nest: () {
            builder.attribute('lat', p.latitude.toString());
            builder.attribute('lon', p.longitude.toString());
            if (p.elevationMeters != null) {
              builder.element('ele', nest: p.elevationMeters!.toString());
            }
            builder.element('time', nest: p.recordedAt.toIso8601String());
          });
        }
      });
    });
  });
  return builder.buildDocument().toXmlString(pretty: true);
}

/// Lançada quando o XML não é um GPX válido pro que o Frankstein precisa
/// (falta `<time>` num `trkpt`, por exemplo — `occurredAt` é obrigatório
/// em todo `HealthEvent`, `.claude/rules/00-inviolaveis.md`).
class InvalidGpxException implements Exception {
  final String message;
  InvalidGpxException(this.message);

  @override
  String toString() => message;
}

List<RunPointInput> importGpx(String gpxXml) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse(gpxXml);
  } on XmlException catch (e) {
    throw InvalidGpxException('GPX malformado: ${e.message}');
  }

  return document.findAllElements('trkpt').map((el) {
    final latRaw = el.getAttribute('lat');
    final lonRaw = el.getAttribute('lon');
    if (latRaw == null || lonRaw == null) {
      throw InvalidGpxException('trkpt sem atributo lat/lon');
    }
    final timeEl = el.getElement('time');
    if (timeEl == null) {
      throw InvalidGpxException('trkpt sem <time> — obrigatório para reconstruir occurredAt');
    }
    final eleEl = el.getElement('ele');

    return RunPointInput(
      latitude: double.parse(latRaw),
      longitude: double.parse(lonRaw),
      elevationMeters: eleEl != null ? double.parse(eleEl.innerText) : null,
      recordedAt: DateTime.parse(timeEl.innerText).toUtc(),
    );
  }).toList();
}
