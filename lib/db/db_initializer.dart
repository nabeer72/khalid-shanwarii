import 'package:sqflite_sqlcipher/sqflite.dart' hide databaseFactory, openDatabase;
import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher show databaseFactory, openDatabase;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'tables.dart';
import 'migrations.dart';

class DbInitializer {
  static Database? _database;
  static const _secureStorage = FlutterSecureStorage();
  static const _dbKeyName = 'db_encryption_key';

  static Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  static Future<void> resetDatabase() async {
    await closeDatabase();
    await getDatabase();
  }

  static Future<Database> getDatabase() async {
    if (_database != null) return _database!;
    _database = await _initDB('khalid_shinwari.db');
    return _database!;
  }

  static Future<String> _getEncryptionKey() async {
    String? key = await _secureStorage.read(key: _dbKeyName);
    if (key == null) {
      final random = Random.secure();
      final values = List<int>.generate(32, (i) => random.nextInt(256));
      key = base64UrlEncode(values);
      await _secureStorage.write(key: _dbKeyName, value: key);
    }
    return key;
  }

  static Future<Database> _initDB(String filePath) async {
    final password = await _getEncryptionKey();

    // On Windows/Desktop, we must use databaseFactoryFfi explicitly because sqflite_sqlcipher
    // overrides the global databaseFactory with one that lacks Windows support.
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // Initialize FFI
      sqfliteFfiInit();
      final dbFactory = databaseFactoryFfi;

      final dbPath = await dbFactory.getDatabasesPath();
      final path = join(dbPath, filePath);

    // For now, skip encryption on desktop (to avoid OpenSSL dependency)
    final db = await dbFactory.openDatabase(
      path, 
      options: OpenDatabaseOptions(
        version: 85,
        onCreate: DbTables.createDB,
        onUpgrade: DbMigrations.upgradeDB,
      ),
    );
    await DbTables.seedDefaultAdmin(db);
    return db;
    }

    // On mobile platforms (Android/iOS), we use SQLCipher encryption via sqflite_sqlcipher.
    final dbPath = await sqlcipher.databaseFactory.getDatabasesPath();
    final path = join(dbPath, filePath);
    final db = await sqlcipher.openDatabase(
      path, 
      version: 85,
      password: password,
      onCreate: DbTables.createDB, 
      onUpgrade: DbMigrations.upgradeDB,
    );
    await DbTables.seedDefaultAdmin(db);
    return db;
  }
}
