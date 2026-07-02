import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  for (final file in files) {
    String content = file.readAsStringSync();
    if (content.contains('DropdownButtonFormField') || content.contains('DropdownButton<')) {
      // We will do a regex replacement.
      // We want to add `isExpanded: true, menuMaxHeight: 400,` after `DropdownButtonFormField<...>(` or `DropdownButton<...>(`
      
      final exp = RegExp(r'(DropdownButton(?:FormField)?<[^>]+>\()');
      
      String newContent = content.replaceAllMapped(exp, (match) {
        return match.group(1)! + '\nisExpanded: true,\nmenuMaxHeight: 400,';
      });
      
      if (newContent != content) {
        file.writeAsStringSync(newContent);
        print('Updated ${file.path}');
      }
    }
  }
}