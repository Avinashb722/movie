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
