import 'dart:io';

void main() {
  final crudDir = Directory('lib/db/crud');
  for (final file in crudDir.listSync()) {
    if (file is File && file.path.endsWith('.dart')) {
      var content = file.readAsStringSync();
      content = content.replaceAll("import 'package:mobile_app/models/business_config.dart';\n", '');
      file.writeAsStringSync(content);
    }
  }
  print('Done removing bogus imports');
}
