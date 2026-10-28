import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'money_repository.dart';

/// Saves receipt PDFs on the phone and opens or shares them.
abstract interface class ReceiptFiles {
  /// Saves to the app's documents and opens it in the PDF viewer.
  /// Returns false when no app can open PDFs.
  Future<bool> download(String paymentId);

  Future<void> share(String paymentId, {required String message});
}

class DeviceReceiptFiles implements ReceiptFiles {
  DeviceReceiptFiles(this._repository);

  final MoneyRepository _repository;

  Future<File> _save(String paymentId, Directory base) async {
    final (bytes, fileName) = await _repository.receiptPdf(paymentId);
    final dir = Directory('${base.path}${Platform.pathSeparator}receipts');
    await dir.create(recursive: true);
    return _write(File('${dir.path}${Platform.pathSeparator}$fileName'), bytes);
  }

  Future<File> _write(File file, Uint8List bytes) => file.writeAsBytes(bytes, flush: true);

  @override
  Future<bool> download(String paymentId) async {
    final file = await _save(paymentId, await getApplicationDocumentsDirectory());
    final result = await OpenFilex.open(file.path, type: 'application/pdf');
    return result.type != ResultType.noAppToOpen;
  }

  @override
  Future<void> share(String paymentId, {required String message}) async {
    final file = await _save(paymentId, await getTemporaryDirectory());
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'application/pdf')], text: message),
    );
  }
}

final receiptFilesProvider = Provider<ReceiptFiles>((ref) => DeviceReceiptFiles(ref.watch(moneyRepositoryProvider)));
