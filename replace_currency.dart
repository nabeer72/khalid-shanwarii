import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  int totalReplacements = 0;

  for (final file in files) {
    String content = file.readAsStringSync();
    String original = content;

    // Pattern: ${BusinessConfig.instance.currency}${...}
    content = content.replaceAll(
        '\${BusinessConfig.instance.currency}\${',
        '\${BusinessConfig.instance.currency}. \${');

    // Pattern: ${BusinessConfig.instance.currency}$var
    content = content.replaceAllMapped(
        RegExp(r'\$\{BusinessConfig\.instance\.currency\}\$([a-zA-Z0-9_]+)'),
        (match) => '\${BusinessConfig.instance.currency}. \$${match.group(1)}');
        
    // Pattern for isolated string literals: prefixText: '${BusinessConfig.instance.currency} ' -> '${BusinessConfig.instance.currency}. '
    content = content.replaceAll(
        "'\${BusinessConfig.instance.currency} '",
        "'\${BusinessConfig.instance.currency}. '");

    // Pattern: $currency${...}
    content = content.replaceAllMapped(
        RegExp(r'\$currency\$\{'),
        (match) => '\$currency. \${');

    // Pattern: $currency$var
    content = content.replaceAllMapped(
        RegExp(r'\$currency\$([a-zA-Z0-9_]+)'),
        (match) => '\$currency. \$${match.group(1)}');

    if (content != original) {
      file.writeAsStringSync(content);
      totalReplacements++;
      print('Updated \${file.path}');
    }
  }
  
  print('Updated \$totalReplacements files in total.');
}
