import 'dart:io';
import 'dart:convert';

void main() async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..badCertificateCallback = (cert, host, port) => true;

  // Let's resolve the host to IPv4 manually
  client.connectionFactory = (uri, proxyHost, proxyPort) async {
    final host = proxyHost ?? uri.host;
    final port = proxyPort ?? uri.port;
    final addresses = await InternetAddress.lookup(host, type: InternetAddressType.IPv4);
    print('Connecting to IPv4: ${addresses.first.address} on port $port');
    if (uri.scheme == 'https') {
      return SecureSocket.startConnect(addresses.first, port, onBadCertificate: (cert) => true);
    }
    return Socket.startConnect(addresses.first, port);
  };

  final target = 'https://i-cdn-0.korso420dim.com/vod/55caabe75ba4b02b91fcb37134cba7f6/360/segment15.ts';
  final referer = 'https://gemma416okl.com';
  
  try {
    print('Sending initial request to redirector...');
    final req = await client.getUrl(Uri.parse(target));
    req.followRedirects = false;
    req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
    req.headers.set('Referer', referer);
    req.headers.set('Origin', referer);
    req.headers.set('Accept', '*/*');
    req.headers.set('Accept-Language', 'en-US,en;q=0.9');
    req.headers.set('Accept-Encoding', 'identity');
    
    final resp = await req.close();
    print('Initial Status: ${resp.statusCode}');
    final loc = resp.headers.value('location');
    print('Redirect location: $loc');
    await resp.drain();
    
    if (loc != null) {
      print('Following manual redirect...');
      final nextUri = Uri.parse(loc);
      final nextReq = await client.getUrl(nextUri);
      nextReq.followRedirects = false;
      nextReq.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
      nextReq.headers.set('Referer', referer);
      nextReq.headers.set('Origin', referer);
      nextReq.headers.set('Accept', '*/*');
      nextReq.headers.set('Accept-Language', 'en-US,en;q=0.9');
      nextReq.headers.set('Accept-Encoding', 'identity');
      
      final nextResp = await nextReq.close();
      print('Redirect Status: ${nextResp.statusCode}');
      final body = await nextResp.transform(utf8.decoder).join();
      print('Body length: ${body.length}');
      if (body.length < 500) {
        print('Body: $body');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
