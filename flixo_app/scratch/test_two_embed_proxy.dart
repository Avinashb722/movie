import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('--- Testing Complete Lookmovie Swish via AllOrigins ---');
  final imdbId = 'tt23865918';
  
  // 1. Fetch 2embed page
  final embedUrl = 'https://www.2embed.cc/embed/$imdbId';
  final proxyEmbedUrl = 'https://api.allorigins.win/get?url=${Uri.encodeComponent(embedUrl)}';
  
  String embedBody = '';
  try {
    final response = await http.get(Uri.parse(proxyEmbedUrl));
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    embedBody = json['contents'] ?? '';
  } catch (e) {
    print('Failed to fetch embed: $e');
    return;
  }

  final swishRegex = RegExp(
    r'''(?:data-src|src)=["'](https://streamsrcs\.2embed\.cc/swish\?id=([^&"']+)[^"']*)['"]]?''',
    caseSensitive: false,
  );
  final swishMatch = swishRegex.firstMatch(embedBody);
  if (swishMatch == null) {
    print('No swish match!');
    return;
  }
  
  final streamId = swishMatch.group(2)!;
  print('Found streamId: $streamId');

  // 2. Fetch lookmovie page
  final lookmovieUrl = 'https://lookmovie2.skin/e/$streamId';
  final proxyLookUrl = 'https://api.allorigins.win/get?url=${Uri.encodeComponent(lookmovieUrl)}';
  
  String lookmovieBody = '';
  try {
    final response = await http.get(Uri.parse(proxyLookUrl));
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    lookmovieBody = json['contents'] ?? '';
  } catch (e) {
    print('Lookmovie fetch error: $e');
    return;
  }

  final evalRegex = RegExp(r"eval\(function\(p,a,c,k,e,d\)[\s\S]+?\.split\('\|'\)\)\)");
  final evalMatch = evalRegex.firstMatch(lookmovieBody);
  if (evalMatch == null) {
    print('Packed JS not found in LookMovie page!');
    return;
  }
  
  final packedJs = evalMatch.group(0)!;
  final unpacked = _unpackJs(packedJs);
  if (unpacked == null) {
    print('Failed to unpack JS!');
    return;
  }
  
  // Find hls4
  final hls4Match = RegExp(r'"hls4"\s*:\s*"([^"]+)"').firstMatch(unpacked);
  if (hls4Match != null) {
    final url = 'https://lookmovie2.skin${hls4Match.group(1)!}';
    print('Found direct HLS4 url: $url');
    return;
  }

  final hls2Match = RegExp(r'"hls2"\s*:\s*"([^"]+)"').firstMatch(unpacked);
  if (hls2Match != null) {
    print('Found direct HLS2 url: ${hls2Match.group(1)!}');
    return;
  }

  final m3u8Match = RegExp(r'https?://[^\s"]+\.m3u8[^\s"]*', caseSensitive: false).firstMatch(unpacked);
  if (m3u8Match != null) {
    print('Found direct fallback m3u8 url: ${m3u8Match.group(0)!}');
    return;
  }

  print('No stream url found in unpacked JS!');
}

String? _unpackJs(String packedCode) {
  try {
    final argsRegex = RegExp(
      r"\}\s*\(\s*'([\s\S]*)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'([\s\S]*)'\s*\.\s*split\s*\(\s*'\|'\s*\)\s*\)",
    );
    final match = argsRegex.firstMatch(packedCode);
    if (match == null) return null;

    final payload = match.group(1)!;
    final int radix = int.parse(match.group(2)!);
    final wordsList = match.group(4)!.split('|');

    String unbase(String str) {
      const chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
      var result = 0;
      for (int i = 0; i < str.length; i++) {
        final c = str[str.length - 1 - i];
        final pos = chars.indexOf(c);
        if (pos < 0) return str;
        result += pos * _pow(radix, i);
      }
      return result.toString();
    }

    final tokenRegex = RegExp(r'\b\w+\b');
    return payload.replaceAllMapped(tokenRegex, (m) {
      final token = m.group(0)!;
      final idx = int.tryParse(unbase(token));
      if (idx != null && idx < wordsList.length && wordsList[idx].isNotEmpty) {
        return wordsList[idx];
      }
      return token;
    });
  } catch (e) {
    return null;
  }
}

int _pow(int base, int exponent) {
  if (exponent == 0) return 1;
  int result = 1;
  for (int i = 0; i < exponent; i++) { result *= base; }
  return result;
}
