import 'dart:convert';
import 'dart:io';

void main() {
  final dir = Directory('assets/data');
  final files = dir.listSync().where((f) => f.path.endsWith('.json'));
  for (var file in files) {
    print('Checking ${file.path}');
    final content = File(file.path).readAsStringSync();
    final List<dynamic> data = json.decode(content);
    if (data.isNotEmpty) {
      print('Keys: ${data[0].keys.toList()}');
      for (var i = 0; i < (data.length < 3 ? data.length : 3); i++) {
        final d = data[i]['description']?.toString() ?? '';
        print('Item $i description: ${d.substring(0, d.length > 50 ? 50 : d.length)}');
      }
    }
    print('---');
  }
}
