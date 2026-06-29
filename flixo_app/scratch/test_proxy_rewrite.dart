import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../lib/services/local_streaming_proxy.dart';

void main() {
  test('Verify LocalStreamingProxy rewrites playlists and downloads video segments successfully', () async {
    print('1. Starting LocalStreamingProxy...');
    final proxy = LocalStreamingProxy.instance;
    await proxy.start();
    final port = proxy.port;
    print('   Proxy running on port: $port');

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..badCertificateCallback = (cert, host, port) => true;

    try {
      // 1. Resolve LookMovie direct stream URL via local Node proxy
      print('\n2. Querying resolve-2embed to get LookMovie stream...');
      final resolveReq = await client.getUrl(Uri.parse('http://localhost:3009/resolve-2embed?imdbId=tt33988385'));
      final resolveRes = await resolveReq.close();
      final resolveBody = await resolveRes.transform(utf8.decoder).join();
      final data = json.decode(resolveBody);
      final String masterUrl = data['url'];
      print('   Resolved Stream: $masterUrl');

      // 2. Request master.m3u8 through LocalStreamingProxy
      print('\n3. Requesting master.m3u8 through LocalStreamingProxy...');
      final playUrl = 'http://127.0.0.1:$port/play?url=${Uri.encodeComponent(masterUrl)}&referer=${Uri.encodeComponent('https://lookmovie2.skin/')}';
      final proxyMasterReq = await client.getUrl(Uri.parse(playUrl));
      final proxyMasterRes = await proxyMasterReq.close();
      
      expect(proxyMasterRes.statusCode, 200);
      final masterBody = await proxyMasterRes.transform(utf8.decoder).join();
      final relativePlaylistName = masterBody.split('\n').firstWhere((l) => l.trim().endsWith('.m3u8'));
      print('   Resolved subplaylist: $relativePlaylistName');

      // 3. Request index-v1-a1.m3u8 through LocalStreamingProxy
      print('\n4. Requesting relative playlist index-v1-a1.m3u8...');
      final subplaylistReqUrl = 'http://127.0.0.1:$port/$relativePlaylistName';
      final subplaylistReq = await client.getUrl(Uri.parse(subplaylistReqUrl));
      final subplaylistRes = await subplaylistReq.close();

      expect(subplaylistRes.statusCode, 200);
      final playlistBody = await subplaylistRes.transform(utf8.decoder).join();
      
      // 4. Extract rewritten segment URL from playlist
      final lines = playlistBody.split('\n');
      final segmentUrl = lines.firstWhere((l) => l.trim().startsWith('http://127.0.0.1:$port/play.ts?url='));
      print('\n5. Extracted rewritten segment URL:');
      print('   $segmentUrl');

      // 5. Request the rewritten segment URL via Range request
      print('\n6. Requesting the segment through the proxy chain...');
      final segmentReq = await client.getUrl(Uri.parse(segmentUrl));
      segmentReq.headers.set('Range', 'bytes=0-100');
      segmentReq.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
      segmentReq.headers.set('Accept', '*/*');
      segmentReq.headers.set('Accept-Encoding', 'identity');

      final segmentRes = await segmentReq.close();
      print('   Status: ${segmentRes.statusCode}');
      print('   Content-Length: ${segmentRes.headers.value('content-length')}');
      print('   Content-Type: ${segmentRes.headers.value('content-type')}');

      expect(segmentRes.statusCode, anyOf(200, 206));
      expect(int.parse(segmentRes.headers.value('content-length')!), isPositive);
      
      final firstBytes = await segmentRes.take(1).first;
      print('   Successfully retrieved ${firstBytes.length} bytes of the video segment!');
      print('   First 10 bytes hex: ${firstBytes.take(10).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      
    } catch (e) {
      print('❌ Test failed: $e');
      fail('Test failed: $e');
    } finally {
      client.close();
      await proxy.stop();
      print('\n7. LocalStreamingProxy stopped.');
    }
  });
}
