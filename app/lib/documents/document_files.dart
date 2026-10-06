import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_health_records/health_records.dart';
import 'package:image_picker/image_picker.dart';

/// Arquivo escolhido pela pessoa (foto da câmera, da galeria ou PDF), ainda
/// não guardado.
class PickedDocument {
  final Uint8List bytes;
  final String name;
  final String mimeType;
  const PickedDocument({required this.bytes, required this.name, required this.mimeType});
}

String _extensionFor(String mimeType, String name) {
  if (mimeType == 'application/pdf') return 'pdf';
  if (mimeType == 'image/png') return 'png';
  if (mimeType == 'image/webp') return 'webp';
  if (mimeType == 'image/heic') return 'heic';
  final dot = name.lastIndexOf('.');
  if (mimeType.startsWith('image/') && dot >= 0) return name.substring(dot + 1).toLowerCase();
  return 'jpg';
}

String mimeTypeForName(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.pdf')) return 'application/pdf';
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.heic')) return 'image/heic';
  return 'image/jpeg';
}

/// Onde ficam as fotos e PDFs de receitas e exames: pasta privada do app,
/// fora do banco. Nada sai do aparelho por aqui.
abstract class DocumentFileStore {
  Future<HealthDocumentFile> store(PickedDocument picked);
  Future<Uint8List?> readBytes(String storedName);

  /// Caminho no disco (para o leitor de PDF do Android); `null` em memória.
  String? pathOf(String storedName);
  Future<void> delete(String storedName);
  Future<void> deleteAll();
}

class DiskDocumentFileStore implements DocumentFileStore {
  final Directory dir;
  DiskDocumentFileStore(String path) : dir = Directory(path);

  @override
  Future<HealthDocumentFile> store(PickedDocument picked) async {
    await dir.create(recursive: true);
    final storedName = '${HealthDataCore.newId()}.${_extensionFor(picked.mimeType, picked.name)}';
    await File('${dir.path}/$storedName').writeAsBytes(picked.bytes, flush: true);
    return HealthDocumentFile(
      storedName: storedName,
      originalName: picked.name,
      mimeType: picked.mimeType,
      sizeBytes: picked.bytes.length,
    );
  }

  @override
  Future<Uint8List?> readBytes(String storedName) async {
    final f = File('${dir.path}/$storedName');
    return f.existsSync() ? f.readAsBytes() : null;
  }

  @override
  String? pathOf(String storedName) => '${dir.path}/$storedName';

  @override
  Future<void> delete(String storedName) async {
    final f = File('${dir.path}/$storedName');
    if (f.existsSync()) await f.delete();
  }

  @override
  Future<void> deleteAll() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}

class MemoryDocumentFileStore implements DocumentFileStore {
  final Map<String, Uint8List> files = {};
  var _seq = 0;

  @override
  Future<HealthDocumentFile> store(PickedDocument picked) async {
    final storedName = 'mem${_seq++}.${_extensionFor(picked.mimeType, picked.name)}';
    files[storedName] = picked.bytes;
    return HealthDocumentFile(
      storedName: storedName,
      originalName: picked.name,
      mimeType: picked.mimeType,
      sizeBytes: picked.bytes.length,
    );
  }

  @override
  Future<Uint8List?> readBytes(String storedName) async => files[storedName];

  @override
  String? pathOf(String storedName) => null;

  @override
  Future<void> delete(String storedName) async => files.remove(storedName);

  @override
  Future<void> deleteAll() async => files.clear();
}

/// De onde vem o arquivo: câmera, galeria ou PDF. Sempre por ação da
/// pessoa.
abstract class DocumentPicker {
  Future<PickedDocument?> takePhoto();
  Future<PickedDocument?> pickImage();
  Future<PickedDocument?> pickPdf();
}

/// Câmera/galeria pelo `image_picker` (BSD-3) e PDF pelo seletor de
/// arquivos do Android via `file_selector` (BSD-3). Foto reduzida para
/// caber bem no aparelho e continuar legível.
class NativeDocumentPicker implements DocumentPicker {
  final ImagePicker _images = ImagePicker();

  Future<PickedDocument?> _image(ImageSource source) async {
    final x = await _images.pickImage(source: source, maxWidth: 2400, maxHeight: 2400, imageQuality: 85);
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    return PickedDocument(bytes: bytes, name: x.name, mimeType: x.mimeType ?? mimeTypeForName(x.name));
  }

  @override
  Future<PickedDocument?> takePhoto() => _image(ImageSource.camera);

  @override
  Future<PickedDocument?> pickImage() => _image(ImageSource.gallery);

  @override
  Future<PickedDocument?> pickPdf() async {
    final x = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'PDF', extensions: ['pdf'], mimeTypes: ['application/pdf']),
    ]);
    if (x == null) return null;
    return PickedDocument(bytes: await x.readAsBytes(), name: x.name, mimeType: 'application/pdf');
  }
}

/// Para testes: devolve o que estiver em [next] e esvazia.
class FakeDocumentPicker implements DocumentPicker {
  PickedDocument? next;
  String? lastSource;

  PickedDocument? _take(String source) {
    lastSource = source;
    final n = next;
    next = null;
    return n;
  }

  @override
  Future<PickedDocument?> takePhoto() async => _take('camera');
  @override
  Future<PickedDocument?> pickImage() async => _take('gallery');
  @override
  Future<PickedDocument?> pickPdf() async => _take('pdf');
}

/// Desenha páginas de PDF como imagem, pelo `PdfRenderer` do próprio
/// Android (`PdfPages.kt`) — sem biblioteca de PDF.
abstract class PdfPageRenderer {
  /// `null` quando não dá para ler (protegido por senha, danificado, ou
  /// fora do Android).
  Future<int?> pageCount(String path);
  Future<Uint8List?> renderPage(String path, int index, {int widthPx = 1600});
}

class NoopPdfPageRenderer implements PdfPageRenderer {
  @override
  Future<int?> pageCount(String path) async => null;
  @override
  Future<Uint8List?> renderPage(String path, int index, {int widthPx = 1600}) async => null;
}

class AndroidPdfPageRenderer implements PdfPageRenderer {
  static const _channel = MethodChannel('rlt/pdf');

  @override
  Future<int?> pageCount(String path) async {
    try {
      return await _channel.invokeMethod<int>('pageCount', {'path': path});
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<Uint8List?> renderPage(String path, int index, {int widthPx = 1600}) async {
    try {
      return await _channel.invokeMethod<Uint8List>('renderPage', {'path': path, 'index': index, 'width': widthPx});
    } on PlatformException {
      return null;
    }
  }
}

PdfPageRenderer defaultPdfPageRenderer() => !kIsWeb && Platform.isAndroid ? AndroidPdfPageRenderer() : NoopPdfPageRenderer();

/// Texto para quando abrir a câmera, a galeria ou o seletor de arquivos
/// falha (pranchetas ReceitasEstados e CodigoBarras: "Permita o uso da
/// câmera"). O `image_picker` avisa a permissão negada pelos códigos
/// `camera_access_denied` e `photo_access_denied`.
String pickerErrorMessage(Object e) {
  final code = e is PlatformException ? e.code : '';
  if (code == 'camera_access_denied') {
    return 'Permita o uso da câmera nas configurações do Android. A câmera é usada só para fotografar receitas, exames e '
        'pratos. As fotos ficam no celular.';
  }
  if (code == 'photo_access_denied') {
    return 'Permita o acesso às fotos nas configurações do Android para escolher da galeria.';
  }
  return 'Não foi possível abrir: $e';
}
