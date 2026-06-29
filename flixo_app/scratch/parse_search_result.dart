import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('scratch/search_result.json');
  // Read as bytes to handle UTF-16LE safely if needed, or convert
  final bytes = file.readAsBytesSync();
  String content = '';
  try {
    content = utf16.decode(bytes); // Try UTF-16 decoding
  } catch (_) {
    try {
      content = utf8.decode(bytes); // Fallback to UTF-8
    } catch (e) {
      // If both fail, try decoding system default
      content = String.fromCharCodes(bytes);
    }
  }

  // Clean up content to extract JSON (remove prefix header if any)
  if (content.contains('{')) {
    content = content.substring(content.indexOf('{'));
  }

  try {
    final data = json.decode(content);
    final dataList = data['response']?['data'] as List? ?? [];
    print('Found ${dataList.length} sections in search results:');
    
    for (final section in dataList) {
      final sectionInfo = section['section']?['sectionInfo'];
      final sectionData = section['section']?['sectionData']?['data'] as List? ?? [];
      
      print('\n- Section: ${sectionInfo?['name']} (Count: ${sectionData.length})');
      
      for (final item in sectionData) {
        final title = item['display']?['title'] ?? '';
        final target = item['target'] ?? {};
        final path = target['path'] ?? '';
        final pageType = target['pageType'] ?? '';
        
        print('  * $title => Path: $path, Type: $pageType');
      }
    }
  } catch (e) {
    print('Error parsing JSON: $e');
    // Let's print a small snippet of the file
    print('Content preview: ${content.substring(0, content.length > 500 ? 500 : content.length)}');
  }
}

// Simple UTF-16 converter
class UTF16 {
  String decode(List<int> bytes) {
    // Basic UTF-16LE conversion
    final list = <int>[];
    // Skip BOM if present
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
final utf16 = UTF16();
