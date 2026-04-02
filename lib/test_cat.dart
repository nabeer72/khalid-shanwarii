import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  var dbFactory = databaseFactoryFfi;
  final dbPath = r'D:\sata projects\pos2\mobile-pos\.dart_tool\sqflite_common_ffi\databases\sata_pos.db';
  var db = await dbFactory.openDatabase(dbPath);

  var cats = await db.rawQuery('SELECT id, name, business_id, admin_id FROM categories ORDER BY id DESC LIMIT 5');
  print('Categories:');
  for (var c in cats) {
    print(c);
  }

  var ub = await db.rawQuery('SELECT * FROM user_businesses');
  print('\nUserBusinesses:');
  for (var u in ub) {
    print(u);
  }

  var users = await db.rawQuery('SELECT id, business_id, name, email FROM users ORDER BY id DESC LIMIT 2');
  print('\nUsers:');
  for (var u in users) {
    print(u);
  }

  await db.close();
}
