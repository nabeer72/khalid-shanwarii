
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  var dbFactory = databaseFactoryFfi;
  final dbPath = r'D:\sata projects\pos2\mobile-pos\.dart_tool\sqflite_common_ffi\databases\sata_pos.db';
  var db = await dbFactory.openDatabase(dbPath);

  var branches = await db.rawQuery('SELECT id, business_id, admin_id, name FROM branches ORDER BY id DESC LIMIT 5');
  print('Branches:');
  for (var b in branches) {
    print(b);
  }

  var businesses = await db.rawQuery('SELECT id, owner_user_id, name FROM businesses ORDER BY id DESC LIMIT 5');
  print('\nBusinesses:');
  for (var b in businesses) {
    print(b);
  }

  await db.close();
}
