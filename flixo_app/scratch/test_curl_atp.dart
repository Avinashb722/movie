import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  const deviceId = 'a1b2c3d4e5f67890';
  const ua = 'Mozilla/5.0 (Android) AppleWebKit/537.36 Chrome/137 Mobile Safari/537.36';
  const referer = 'https://www.movieboxpro.app/';
  final body = json.encode({'keyword': 'test_${DateTime.now().millisecondsSinceEpoch}', 'perPage': 0});
  
  // Write body to temp file to avoid escaping issues
  final tempFile = File('${Directory.systemTemp.path}/mb_body.json');
  await tempFile.writeAsString(body);
  
  final headerFile = File('${Directory.systemTemp.path}/mb_headers.txt');
  if (await headerFile.exists()) await headerFile.delete();
  
  print('Testing curl.exe TLS fingerprint...');
  final result = await Process.run('curl.exe', [
    '-s',
    '-X', 'POST',
    'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/search-suggest',
    '-H', 'Accept: application/json',
    '-H', 'Content-Type: application/json',
    '-H', 'User-Agent: $ua',
    '-H', 'Referer: $referer',
    '-H', 'X-Client-Info: {"timezone":"Asia/Kolkata","device_id":"$deviceId"}',
    '-d', '@${tempFile.path}',   // read body from file to avoid escaping
    '-D', headerFile.path,       // dump response headers to file
    '--tlsv1.2',
    '--tls-max', '1.3',
    '--connect-timeout', '10',
    '--max-time', '12',
  ]);
  
  print('Exit code: ${result.exitCode}');
  if (result.stderr.toString().isNotEmpty) print('Stderr: ${result.stderr}');
  
  if (await headerFile.exists()) {
    final headerContent = await headerFile.readAsString();
    print('Response headers:\n$headerContent');
    
    // Find x-user header
    final xUserLine = headerContent.split('\n').firstWhere(
      (l) => l.toLowerCase().startsWith('x-user'),
      orElse: () => '',
    );
    if (xUserLine.isNotEmpty) {
      final xUserValue = xUserLine.split(':').skip(1).join(':').trim();
      final xUserData = json.decode(xUserValue);
      final token = xUserData['token'] as String?;
      if (token != null) {
        final parts = token.split('.');
        final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
        final payloadData = json.decode(payload);
        print('\n=== TOKEN ANALYSIS ===');
        print('atp: ${payloadData['atp']}');
        print('Full payload: $payload');
        if (payloadData['atp'] != 3) {
          print('\n✅ GOT NON-WEB TOKEN! Trying play endpoint...');
          // Try play endpoint with this token
          final playResult = await Process.run('curl.exe', [
            '-s',
            'https://h5-api.aoneroom.com/wefeed-h5api-bff/subject/play?subjectId=1247971396999862152&se=0&ep=0&resolution=360',
            '-H', 'Authorization: Bearer $token',
            '-H', 'User-Agent: $ua',
          ]);
          print('Play response: ${playResult.stdout}');
        } else {
          print('\n❌ Still atp:3 (web) token — curl.exe has same TLS fingerprint as Dart');
        }
      }
    } else {
      print('No x-user header in response');
    }
  }
  
  print('\nResponse body: ${result.stdout}');
  await tempFile.delete();
}
