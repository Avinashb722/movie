/**
 * Test using SecureSocket for HTTPS inside connectionFactory
 */
const { execSync } = require('child_process');
const fs = require('fs');

const testDartCode = `
import 'dart:io';

void main() async {
  final client = HttpClient()
    ..connectionFactory = (uri, proxyHost, proxyPort) {
      final host = proxyHost ?? uri.host;
      final port = proxyPort ?? uri.port;
      print('ConnectionFactory called for: \${uri.scheme}://\$host:\$port');
      if (uri.scheme == 'https') {
        return SecureSocket.startConnect(host, port, onBadCertificate: (cert) => true);
      }
      return Socket.startConnect(host, port);
    };

  try {
    final req = await client.getUrl(Uri.parse('https://www.google.com'));
    final resp = await req.close();
    print('Response status: \${resp.statusCode}');
    await resp.drain();
  } catch (e) {
    print('Error: \$e');
  }
}
`;

fs.writeFileSync('scratch/test_factory.dart', testDartCode);

try {
  console.log('Running SecureSocket test...');
  const out = execSync('dart scratch/test_factory.dart', { encoding: 'utf-8' });
  console.log('Output:\n', out);
} catch (e) {
  console.error('Execution failed:', e.message);
}
