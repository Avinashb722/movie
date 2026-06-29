import 'dart:io';
import 'dart:convert';

Future<void> testDartWorker() async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..badCertificateCallback = (cert, host, port) => true;

  try {
    const tiktokUrl = 'https://p19-ad-site-sign-sg.tiktokcdn.com/ad-site-i18n-sg/202605145d0dcefb51083bd341318647~tplv-d5opwmad15-ttam-origin.image?lk3s=6d71dd51&x-expires=1810324624&x-signature=72VG3SDcxLBag8B5MdcGYjGzBCQ%3D';
    final proxyUrl = 'https://long-wind-ad98.avinashbiradar722.workers.dev/?url=${Uri.encodeComponent(tiktokUrl)}';
    
    print('Requesting Cloudflare Worker via Dart HttpClient: $proxyUrl');
    final req = await client.getUrl(Uri.parse(proxyUrl));
    
    // Set headers exactly as the player does
    req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
    req.headers.set('Accept', '*/*');
    req.headers.set('Accept-Language', 'en-US,en;q=0.9');
    req.headers.set('Range', 'bytes=0-');
    req.headers.set('Accept-Encoding', 'identity');

    final res = await req.close();
    print('Response Status: ${res.statusCode}');
    print('Response Headers:');
    res.headers.forEach((name, values) => print('  $name: $values'));
    
    final body = await res.transform(utf8.decoder).join();
    print('Body length: ${body.length}');
    if (res.statusCode != 200 && res.statusCode != 206) {
      print('Error Body: $body');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}

void main() async {
  await testDartWorker();
}
