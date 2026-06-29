import 'dart:convert';
import 'dart:io';

class UTF16 {
  String decode(List<int> bytes) {
    final list = <int>[];
    int start = 0;
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      start = 2;
    }
    for (int i = start; i < bytes.length - 1; i += 2) {
      final code = bytes[i] | (bytes[i + 1] << 8);
      list.add(code);
    }
    return String.fromCharCodes(list);
  }
}

void main() {
  final file = File('scratch/watcho_search_detail.json');
  final bytes = file.readAsBytesSync();
  
  String content = UTF16().decode(bytes);
  if (content.contains('{')) {
    content = content.substring(content.indexOf('{'));
  }

  try {
    final data = json.decode(content);
    final responseObj = data['response'] ?? {};
    final searchResults = responseObj['searchResults'] ?? {};
    final dataList = searchResults['data'] as List? ?? [];
    
    print('Found ${dataList.length} search results:');
    
    for (final item in dataList) {
      final title = item['display']?['title'] ?? '';
      final target = item['target'] ?? {};
      final path = target['path'] ?? '';
      final pageType = target['pageType'] ?? '';
      
      print('  * Title: "$title" => Path: "$path" (Type: "$pageType")');
    }
  } catch (e) {
    print('Error parsing JSON: $e');
    print('Preview: ${content.substring(0, content.length > 500 ? 500 : content.length)}');
  }
}
