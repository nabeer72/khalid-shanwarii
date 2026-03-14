import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'tables.dart';
import 'migrations.dart';

class DbInitializer {
  static Database? _database;

  static Future<Database> getDatabase() async {
    if (_database != null) return _database!;
    _database = await _initDB('sata_pos.db');
    return _database!;
  }

  static Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path, 
      version: 38, 
      onCreate: DbTables.createDB, 
      onUpgrade: DbMigrations.upgradeDB,
    );
  }
}
