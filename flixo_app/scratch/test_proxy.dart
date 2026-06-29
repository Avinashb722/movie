import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final targetUrl = 'https://archive.org/advancedsearch.php?q=title:(Kantara)+AND+mediatype:movies&fl[]=identifier,title,downloads&sort[]=downloads+desc&output=json';
  
  print('Target URL: $targetUrl\n');

  // Test 1: Direct connection
  try {
    print('Testing Direct Connection...');
    final resp = await http.get(Uri.parse(targetUrl)).timeout(Duration(seconds: 5));
    print('  Direct status: ${resp.statusCode}');
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      final docs = data['response']?['docs'] as List?;
      print('  Direct success! Found ${docs?.length} documents.');
    }
  } catch (e) {
    print('  Direct Connection failed: $e');
  }

  // Test 2: Vercel Proxy
  final vercelUrl = 'https://ver-orcin-alpha.vercel.app/api?url=${Uri.encodeComponent(targetUrl)}';
  try {
    print('\nTesting Vercel Proxy ($vercelUrl)...');
    final resp = await http.get(Uri.parse(vercelUrl)).timeout(Duration(seconds: 5));
    print('  Vercel status: ${resp.statusCode}');
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      final docs = data['response']?['docs'] as List?;
      print('  Vercel success! Found ${docs?.length} documents.');
    }
  } catch (e) {
    print('  Vercel Proxy failed: $e');
  }

  // Test 3: Corsproxy.io
  final corsProxyUrl = 'https://corsproxy.io/?${Uri.encodeComponent(targetUrl)}';
  try {
    print('\nTesting Corsproxy.io ($corsProxyUrl)...');
    final resp = await http.get(Uri.parse(corsProxyUrl)).timeout(Duration(seconds: 5));
    print('  Corsproxy status: ${resp.statusCode}');
    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      final docs = data['response']?['docs'] as List?;
      print('  Corsproxy success! Found ${docs?.length} documents.');
    }
  } catch (e) {
    print('  Corsproxy failed: $e');
  }
}
