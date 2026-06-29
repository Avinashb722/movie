import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

String md5Hex(List<int> bytes) {
  return md5.convert(bytes).toString();
}

String md5String(String text) {
  return md5Hex(utf8.encode(text));
}

String buildCanonicalString({
  required String method,
  required String? accept,
  required String? contentType,
  required String pathWithQuery,
  required String? body,
  required int timestampMs,
}) {
  String bodyHash = '';
  String bodyLength = '';
  if (body != null) {
    final bodyBytes = utf8.encode(body);
    final truncated = bodyBytes.length > 131072 ? bodyBytes.sublist(0, 131072) : bodyBytes;
    bodyHash = md5Hex(truncated);
    bodyLength = bodyBytes.length.toString();
  }

  return '${method.toUpperCase()}\n'
      '${accept ?? ''}\n'
      '${contentType ?? ''}\n'
      '$bodyLength\n'
      '$timestampMs\n'
      '$bodyHash\n'
      '$pathWithQuery';
}

void main() {
  test('Compare signatures', () {
    final method = "POST";
    final body = '{"keyword": "Avatar", "page": 1, "perPage": 15, "subjectType": 0, "tabId": "All"}';
    final ts = 1782396300000;
    final path = "/wefeed-mobile-bff/subject-api/search/v2";

    final canonical = buildCanonicalString(
      method: method,
      accept: "application/json",
      contentType: "application/json",
      pathWithQuery: path,
      body: body,
      timestampMs: ts,
    );

    print("=== DART CANONICAL STRING ===");
    print(canonical.replaceAll('\n', '\\n'));

    // Calculate signature
    final secretBytes = base64.decode('76iRl07s0xSN9jqmEWAt79EBJZulIQIsV64FZr2O');
    final hmacMd5 = Hmac(md5, secretBytes);
    final digest = hmacMd5.convert(utf8.encode(canonical));
    final sigB64 = base64.encode(digest.bytes);
    
    print("\n=== DART SIGNATURE ===");
    print("$ts|2|$sigB64");

    // Calculate client token
    final reversedTs = ts.toString().split('').reversed.join();
    final hashVal = md5String(reversedTs);
    print("\n=== DART CLIENT TOKEN ===");
    print("$ts,$hashVal");
  });
}
