import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mobile_app/db/crud/common_crud.dart';
import '../database_helper.dart';

mixin CurrencyNotesCrud on CommonCrud {
  Future<Database> get database;

  Future<List<Map<String, dynamic>>> getCurrencyNotes() async {
    final db = await database;
    return await db.query(
      'currency_notes', 
      where: 'status = 1${getBusinessFilter()}', 
      whereArgs: getBusinessArgs(),
      orderBy: 'value ASC'
    );
  }

  Future<int> insertCurrencyNote(Map<String, dynamic> note) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final result = await db.insert('currency_notes', {
      ...note,
      ...getBusinessArgsMap(),
      'branch_id': note['branch_id'] ?? getCurrentBranchId(),
      'is_synced': 0,
      'created_at': now,
      'updated_at': now,
    });
    DatabaseHelper.notifyDataChanged();
    return result;
  }

  Future<int> updateCurrencyNote(int id, Map<String, dynamic> note) async {
    final db = await database;
    final result = await db.update(
      'currency_notes',
      {
        ...note,
        'is_synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?${getBusinessFilter()}',
      whereArgs: [id, ...getBusinessArgs()],
    );
    DatabaseHelper.notifyDataChanged();
    return result;
  }

  Future<int> deleteCurrencyNote(int id) async {
    final db = await database;
    final result = await db.update(
      'currency_notes',
      {
        'status': 0,
        'is_synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?${getBusinessFilter()}',
      whereArgs: [id, ...getBusinessArgs()],
    );
    DatabaseHelper.notifyDataChanged();
    return result;
  }

  Future<void> batchInsertCurrencyNotes(List<Map<String, dynamic>> notes) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var note in notes) {
        await txn.insert('currency_notes', note, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}
