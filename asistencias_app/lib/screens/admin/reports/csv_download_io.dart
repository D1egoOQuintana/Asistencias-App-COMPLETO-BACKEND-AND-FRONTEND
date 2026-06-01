// Fallback no-web: no hay descarga directa fuera del navegador.
// (El panel admin es web; este stub solo existe para que compile en todas
// las plataformas sin importar dart:html.)
void downloadCsv(String filename, String content) {
  // No-op en plataformas no-web.
}
