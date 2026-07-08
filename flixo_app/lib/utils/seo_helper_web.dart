import 'dart:js' as js;

void updateWebSeo(String title, String description, String canonicalUrl, String ogImage, String schemaJson) {
  try {
    js.context.callMethod('updateSeoMeta', [
      title,
      description,
      canonicalUrl,
      ogImage,
      schemaJson,
    ]);
  } catch (_) {}
}

bool isSearchBot() {
  try {
    final navigator = js.context['navigator'];
    if (navigator != null) {
      final userAgent = navigator['userAgent'] as String?;
      if (userAgent != null) {
        final uaLower = userAgent.toLowerCase();
        return uaLower.contains('googlebot') ||
               uaLower.contains('bingbot') ||
               uaLower.contains('slurp') ||
               uaLower.contains('duckduckbot') ||
               uaLower.contains('baiduspider') ||
               uaLower.contains('yandexbot');
      }
    }
  } catch (_) {}
  return false;
}
