import 'dart:io';

void main() {
  final file = File('lib/services/two_embed_service.dart');
  var content = file.readAsStringSync();
  
  // Replace debugPrint with _log
  content = content.replaceAll('debugPrint', '_log');
  
  // Insert _log helper at the top of the class definition
  final target = 'class TwoEmbedService {\n  static final TwoEmbedService instance = TwoEmbedService._internal();';
  final replacement = 'class TwoEmbedService {\n  static final TwoEmbedService instance = TwoEmbedService._internal();\n  void _log(String msg) { print(msg); }';
  content = content.replaceAll(target, replacement);
  
  file.writeAsStringSync(content);
  print('Successfully replaced debugPrint with _log inside two_embed_service.dart!');
}
