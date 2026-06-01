// Descarga de CSV en el navegador sin paquetes (usa dart:html del SDK).
// Este archivo SOLO se importa en web vía import condicional (dart.library.html),
// por eso es seguro usar dart:html aquí.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

void downloadCsv(String filename, String content) {
  final blob = html.Blob(<Object>[content], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
