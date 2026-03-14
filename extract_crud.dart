import 'dart:io';

void main() {
  final lines = File('lib/db/database_helper.dart').readAsLinesSync();
  
  Map<String, List<String>> chunks = {};
  String currentFile = '_unassigned.dart';
  
  // Ordered from most specific to least specific!
  Map<String, String> sectionToFiles = {
    '// ========== Shift Operations ==========': 'shifts_crud.dart',
    '// ========== Branch Operations ==========': 'branches_crud.dart',
    '// ========== Bank Operations ==========': 'common_crud.dart',
    '// ========== Supplier Payback Operations ==========': 'suppliers_crud.dart',
    '// ========== Credit System ==========': 'credit_crud.dart',
    '// ========== CRUD Operations ==========': 'categories_crud.dart', // The first one
    '// Categories': 'categories_crud.dart',
    '// Products': 'products_crud.dart',
    '// Stocks': 'stocks_crud.dart',
    '// Customers': 'customers_crud.dart',
    '// Sales': 'sales_crud.dart',
    '// Sale Items': 'sales_crud.dart',
    '// Held Orders': 'sales_crud.dart',
    '// Gift Cards': 'sales_crud.dart',
    '// Employees': 'employees_crud.dart',
    '// Roles': 'employees_crud.dart',
    '// Users': 'common_crud.dart',
    '// Businesses': 'common_crud.dart',
    '// Settings': 'settings_crud.dart',
    '// Suppliers': 'suppliers_crud.dart',
    '// Purchases': 'purchases_crud.dart',
    '// Expense Heads': 'expenses_crud.dart',
    '// Expenses': 'expenses_crud.dart',
    '// Credit Sales': 'credit_crud.dart',
    '// Credit Payments': 'credit_crud.dart',
    '// Supplier Credit Purchases': 'suppliers_crud.dart',
  };

  for (int i = 1208; i < lines.length - 2; i++) {
    String line = lines[i];
    
    // Switch active file based on section header
    for (final entry in sectionToFiles.entries) {
      if (line.trim().startsWith(entry.key)) {
        currentFile = entry.value;
        break;
      }
    }
    
    if (currentFile != '_unassigned.dart') {
      chunks.putIfAbsent(currentFile, () => []).add(line);
    }
  }

  Directory('lib/db/crud').createSync(recursive: true);

  chunks.forEach((fileName, fileLines) {
    if (fileName == '_unassigned.dart') return;

    final mixinName = fileName
        .replaceAll('.dart', '')
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join('');

    final out = StringBuffer();
    out.writeln("import 'package:sqflite/sqflite.dart';");
    out.writeln("import 'package:mobile_app/models/business_config.dart';");
    out.writeln("import 'package:mobile_app/db/mock_data.dart';");
    out.writeln("import 'package:uuid/uuid.dart';");
    out.writeln("import 'dart:convert';");
    out.writeln("import 'package:flutter_secure_storage/flutter_secure_storage.dart';");
    out.writeln("");
    out.writeln("mixin $mixinName {");
    out.writeln("  Future<Database> get database;");
    out.writeln("");
    for (final l in fileLines) {
      out.writeln(l);
    }
    out.writeln("}");
    
    File('lib/db/crud/$fileName').writeAsStringSync(out.toString());
  });
}
