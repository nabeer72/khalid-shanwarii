import 'dart:io';

void main() {
  final lines = File('lib/db/database_helper.dart').readAsLinesSync();
  
  // Lines are 0-indexed in Dart list.
  // We want to extract lines 29-530. So index 28 to 530.
  final createDB = lines.sublist(28, 530);
  // Lines 532-1206. So index 531 to 1206.
  final upgradeDB = lines.sublist(531, 1206);
  // Lines 2972-2997. So index 2971 to 2997.
  final seedPerms = lines.sublist(2971, 2997);

  final tablesOut = StringBuffer();
  tablesOut.writeln("import 'package:flutter/foundation.dart';");
  tablesOut.writeln("import 'package:sqflite/sqflite.dart';");
  tablesOut.writeln("");
  tablesOut.writeln("class DbTables {");
  for (var line in createDB) {
    line = line.replaceAll('Future<void> _createDB', 'static Future<void> createDB');
    line = line.replaceAll('await seedPermissions(db);', 'await DbTables.seedPermissions(db);');
    tablesOut.writeln(line);
  }
  tablesOut.writeln("");
  for (var line in seedPerms) {
    line = line.replaceAll('Future<void> seedPermissions', 'static Future<void> seedPermissions');
    tablesOut.writeln(line);
  }
  tablesOut.writeln("}");
  File('lib/db/tables.dart').writeAsStringSync(tablesOut.toString());

  final migrationsOut = StringBuffer();
  migrationsOut.writeln("import 'package:flutter/foundation.dart';");
  migrationsOut.writeln("import 'package:sqflite/sqflite.dart';");
  migrationsOut.writeln("import 'tables.dart';");
  migrationsOut.writeln("");
  migrationsOut.writeln("class DbMigrations {");
  for (var line in upgradeDB) {
    line = line.replaceAll('Future<void> _upgradeDB', 'static Future<void> upgradeDB');
    line = line.replaceAll('await seedPermissions(db);', 'await DbTables.seedPermissions(db);');
    migrationsOut.writeln(line);
  }
  migrationsOut.writeln("}");
  File('lib/db/migrations.dart').writeAsStringSync(migrationsOut.toString());
}
