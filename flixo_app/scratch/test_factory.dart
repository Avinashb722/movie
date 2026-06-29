
import 'dart:io';

void main() async {
  final client = HttpClient()
    ..connectionFactory = (uri, proxyHost, proxyPort) {
      final host = proxyHost ?? uri.host;
      final port = proxyPort ?? uri.port;
      print('ConnectionFactory called for: ${uri.scheme}://$host:$port');
      if (uri.scheme == 'https') {
        return SecureSocket.startConnect(host, port, onBadCertificate: (cert) => true);
      }
      return Socket.startConnect(host, port);
    };

  try {
    final req = await client.getUrl(Uri.parse('https://www.google.com'));
    final resp = await req.close();
    print('Response status: ${resp.statusCode}');
    await resp.drain();
  } catch (e) {
    print('Error: $e');
  }
}
