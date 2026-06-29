import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  // Use a highly seeded test torrent (e.g. Big Buck Bunny) to ensure fast peer gathering
  const magnet = 'magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c&dn=Big+Buck+Bunny';
  const port = 8889;

  print('Testing WebTorrent CLI with magnet link...');
  print('Command: webtorrent "$magnet" -p $port -s 0 -q');

  final process = await Process.start(
    'webtorrent',
    [
      magnet,
      '-p', port.toString(),
      '-s', '0',
      '-q',
    ],
    runInShell: true,
  );

  // Monitor stdout
  final stdoutSub = process.stdout
      .transform(const SystemEncoding().decoder)
      .transform(const LineSplitter())
      .listen((line) {
        final clean = line.replaceAll(RegExp(r'\x1B\[[0-9;]*[a-zA-Z]'), '').trim();
        if (clean.isNotEmpty) {
          print('[STDOUT] $clean');
        }
      });

  // Monitor stderr
  final stderrSub = process.stderr
      .transform(const SystemEncoding().decoder)
      .transform(const LineSplitter())
      .listen((line) {
        print('[STDERR] $line');
      });

  // Wait to see if HTTP server starts up
  final client = HttpClient();
  bool connected = false;
  print('Waiting 20 seconds for WebTorrent server to start...');
  for (int i = 0; i < 20; i++) {
    await Future.delayed(const Duration(seconds: 1));
    try {
      final req = await client.get('127.0.0.1', port, '/').timeout(const Duration(seconds: 1));
      final resp = await req.close();
      print('[HTTP] Server responded: ${resp.statusCode}');
      connected = true;
      break;
    } catch (_) {
      // Still starting
    }
  }

  client.close();
  stdoutSub.cancel();
  stderrSub.cancel();
  process.kill();
  
  if (connected) {
    print('✅ SUCCESS: WebTorrent successfully started serving in-app!');
  } else {
    print('❌ FAILED: WebTorrent did not start serving (0 peers or port block)');
  }
}
