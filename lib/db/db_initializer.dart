import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show databaseFactoryFfi, OpenDatabaseOptions;
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

  static Future<Database> getDatabase() async {
    if (_database != null) return _database!;
    _database = await _initDB('sata_pos.db');
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
    // On Windows/Desktop, we must use databaseFactoryFfi explicitly because sqflite_sqlcipher
    // overrides the global databaseFactory with one that lacks Windows support.
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final dbPath = await databaseFactoryFfi.getDatabasesPath();
      final path = join(dbPath, filePath);
      return await databaseFactoryFfi.openDatabase(
        path, 
        options: OpenDatabaseOptions(
          version: 67,

          onCreate: DbTables.createDB,
          onUpgrade: DbMigrations.upgradeDB,
        ),
      );
    }

    // On mobile platforms (Android/iOS), we use the secure concept with SQLCipher encryption.
    final dbPath = await databaseFactory.getDatabasesPath();
    final path = join(dbPath, filePath);
    final password = await _getEncryptionKey();
    return await openDatabase(
      path, 
      version: 67,
      password: password,
      onCreate: DbTables.createDB, 
      onUpgrade: DbMigrations.upgradeDB,
    );
  }
}
