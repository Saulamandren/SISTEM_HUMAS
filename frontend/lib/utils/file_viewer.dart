import 'file_viewer_stub.dart'
    if (dart.library.html) 'file_viewer_web.dart';

/// Open a document in a new tab (web) or throw UnsupportedError (non-web).
Future<void> openDocumentFromBase64({
  required String base64Data,
  required String fileName,
  required String mimeType,
}) async {
  return openDocumentFromBase64Impl(
    base64Data: base64Data,
    fileName: fileName,
    mimeType: mimeType,
  );
}
