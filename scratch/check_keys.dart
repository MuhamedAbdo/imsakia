import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('assets/data/muslim.json');
  final content = file.readAsStringSync();
  final List<dynamic> data = json.decode(content);
  if (data.isNotEmpty) {
    print('Keys: ${data[0].keys.toList()}');
    final desc = data[0]['description'] as String?;
    print('Description length: ${desc?.length}');
    print('First 100 chars of description: ${desc?.substring(0, desc.length > 100 ? 100 : desc.length)}');
    final st = data[0]['searchTerm'] as String?;
    print('SearchTerm length: ${st?.length}');
    print('First 100 chars of SearchTerm: ${st?.substring(0, st.length > 100 ? 100 : st.length)}');
  }
}
