import 'dart:convert';
import 'dart:html' as html;

Future<void> openDocumentFromBase64Impl({
  required String base64Data,
  required String fileName,
  required String mimeType,
}) async {
  final bytes = base64Decode(base64Data);
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);

  // Open in new tab for viewing (PDF) or download (doc/docx).
  html.window.open(url, '_blank');

  // Cleanup
  html.Url.revokeObjectUrl(url);
}
