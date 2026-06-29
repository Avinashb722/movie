import 'dart:io';
import 'dart:convert';

// Vidnest custom base-64 alphabet for decryption
const _vidnestAlphabet = 'RB0fpH8ZEyVLkv7c2i6MAJ5u3IKFDxlS1NTsnGaqmXYdUrtzjwObCgQP94hoeW+/=';

String _decryptVidnest(String cipherText) {
  final Map<String, int> lookup = {};
  for (int i = 0; i < _vidnestAlphabet.length; i++) {
    lookup[_vidnestAlphabet[i]] = i;
  }
  
  final cipherChars = cipherText.split('');
  final List<int> result = [];
  
  for (int t = 0; t < cipherChars.length; t += 4) {
    var chunk = cipherText.substring(t, (t + 4).clamp(0, cipherText.length));
    while (chunk.length < 4) { chunk += '='; }

    final indices = <int>[];
    for (int e = 0; e < 4; e++) {
      indices.add(lookup[chunk[e]] ?? 64);
    }

    result.add((indices[0] << 2) | (indices[1] >> 4));
    if (indices[2] != 64) {
      result.add(((indices[1] & 15) << 4) | (indices[2] >> 2));
    }
    if (indices[3] != 64) {
      result.add(((indices[2] & 3) << 6) | indices[3]);
    }
  }

  return utf8.decode(result, allowMalformed: true);
}

void main() async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..badCertificateCallback = (cert, host, port) => true;

  // IPv4 Connection Factory
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

  try {
    print('1. Resolving stream URL from Vidnest API...');
    final req = await client.getUrl(Uri.parse('https://new.vidnest.fun/allmovies/movie/1103473'));
    req.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
    req.headers.set('Referer', 'https://vidnest.fun/');
    req.headers.set('Origin', 'https://vidnest.fun');
    final resp = await req.close();
    print('API Response Status: ${resp.statusCode}');
    if (resp.statusCode != 200) {
      print('Failed to resolve stream');
      return;
    }
    final body = await resp.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    
    String decryptedData = '';
    if (json['encrypted'] == true && json['data'] is String) {
      decryptedData = _decryptVidnest(json['data'] as String);
    } else {
      decryptedData = jsonEncode(json);
    }
    
    final decoded = jsonDecode(decryptedData) as Map<String, dynamic>;
    final streamUrl = decoded['streams'][0]['url'] as String;
    print('Resolved Master Stream URL: $streamUrl');

    print('\n2. Fetching Master Playlist...');
    final playlistReq = await client.getUrl(Uri.parse(streamUrl));
    playlistReq.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
    playlistReq.headers.set('Referer', 'https://gemma416okl.com');
    playlistReq.headers.set('Origin', 'https://gemma416okl.com');
    final playlistResp = await playlistReq.close();
    print('Master Playlist Status: ${playlistResp.statusCode}');
    final playlistBody = await playlistResp.transform(utf8.decoder).join();
    
    // Find a sub-playlist URL (e.g. 360/index.m3u8 or 480/index.m3u8)
    final subRegex = RegExp(r'(?:https?://[^\s\r\n]+|\.[^\s\r\n]+\.m3u8)');
    final subMatch = subRegex.firstMatch(playlistBody);
    if (subMatch == null) {
      print('No sub-playlist found in master playlist:\n$playlistBody');
      return;
    }
    var subUrl = subMatch.group(0)!;
    if (!subUrl.startsWith('http')) {
      final baseUri = Uri.parse(streamUrl);
      final basePathSegments = List<String>.from(baseUri.pathSegments)..removeLast();
      final relativePathSegments = subUrl.replaceAll('./', '').split('/');
      basePathSegments.addAll(relativePathSegments);
      subUrl = baseUri.replace(pathSegments: basePathSegments).toString();
    }
    print('Sub-playlist URL: $subUrl');

    print('\n3. Fetching Sub-playlist...');
    final subReq = await client.getUrl(Uri.parse(subUrl));
    subReq.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
    subReq.headers.set('Referer', 'https://gemma416okl.com');
    subReq.headers.set('Origin', 'https://gemma416okl.com');
    final subResp = await subReq.close();
    print('Sub-playlist Status: ${subResp.statusCode}');
    final subBody = await subResp.transform(utf8.decoder).join();

    // Find the first segment URL (with md5/expires parameters)
    final segRegex = RegExp(r'https?://[^\s\r\n]+\.ts[^\s\r\n]*');
    final segMatch = segRegex.firstMatch(subBody);
    if (segMatch == null) {
      print('No segments found in sub-playlist:\n$subBody');
      return;
    }
    var segUrl = segMatch.group(0)!;
    print('First Segment URL: $segUrl');

    print('\n4. Fetching First Segment...');
    final segReq = await client.getUrl(Uri.parse(segUrl));
    segReq.followRedirects = false;
    segReq.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
    segReq.headers.set('Referer', 'https://gemma416okl.com');
    segReq.headers.set('Origin', 'https://gemma416okl.com');
    segReq.headers.set('Accept', '*/*');
    segReq.headers.set('Accept-Encoding', 'identity');
    segReq.headers.set('Range', 'bytes=0-');
    
    var segResp = await segReq.close();
    print('Segment Initial Status: ${segResp.statusCode}');
    
    int redirectCount = 0;
    while (segResp.statusCode >= 300 && segResp.statusCode < 400 && redirectCount < 5) {
      final loc = segResp.headers.value('location');
      if (loc == null || loc.isEmpty) break;
      await segResp.drain();
      
      final nextUri = Uri.parse(loc);
      print('Following manual redirect to: $nextUri');
      final nextReq = await client.getUrl(nextUri);
      nextReq.followRedirects = false;
      nextReq.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
      nextReq.headers.set('Referer', 'https://gemma416okl.com');
      nextReq.headers.set('Origin', 'https://gemma416okl.com');
      nextReq.headers.set('Accept', '*/*');
      nextReq.headers.set('Accept-Encoding', 'identity');
      nextReq.headers.set('Range', 'bytes=0-');
      
      segResp = await nextReq.close();
      print('Redirect Status: ${segResp.statusCode}');
      redirectCount++;
    }
    
    if (segResp.statusCode == 200 || segResp.statusCode == 206) {
      print('SUCCESS! Segment fetched successfully!');
    } else {
      print('FAILED with status: ${segResp.statusCode}');
      final errBody = await segResp.transform(utf8.decoder).join();
      print('Error body:\n$errBody');
    }
  } catch (e) {
    print('Error: $e');
  }
}
