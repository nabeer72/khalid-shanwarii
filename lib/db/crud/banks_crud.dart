import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../models/bank.dart';
import '../../models/bank_detail.dart';
import '../database_helper.dart';
import '../mock_data.dart';

mixin BanksCrud {
  Future<Database> get database;
  
  // Standard filters from CommonCrud (will be mixed in)
  String getBusinessFilter();
  List<dynamic> getBusinessArgs();

  // Banks (Master)
  Future<List<Map<String, dynamic>>> getBanks() async {
    final db = await database;
    return await db.query(
      'banks',
      where: 'status = 1 ${getBusinessFilter()}',
      whereArgs: getBusinessArgs(),
      orderBy: 'name ASC',
    );
  }

  Future<int> insertBank(Map<String, dynamic> bank) async {
    final db = await database;
    final id = await db.insert('banks', {
      ...bank,
      'business_id': BusinessConfig.instance.businessId,
      'user_id': BusinessConfig.instance.userId,
      'is_synced': 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    DatabaseHelper.notifyDataChanged();
    return id;
  }

  Future<void> deleteBank(int id) async {
    final db = await database;
    await db.update('banks', {'status': 0, 'is_synced': 0}, where: 'id = ?${getBusinessFilter()}', whereArgs: [id, ...getBusinessArgs()]);
    DatabaseHelper.notifyDataChanged();
  }

  // Bank Details (Accounts Master)
  Future<List<Map<String, dynamic>>> getBankDetails({int? bankId}) async {
    final db = await database;
    String where = 'status = 1 ${getBusinessFilter()}';
    List<dynamic> args = getBusinessArgs();
    
    if (bankId != null) {
      where += ' AND bank_id = ?';
      args.add(bankId);
    }
    
    return await db.query(
      'bank_details',
      where: where,
      whereArgs: args,
      orderBy: 'account_title ASC',
    );
  }

  Future<int> insertBankDetail(Map<String, dynamic> detail) async {
    final db = await database;
    final id = await db.insert('bank_details', {
      ...detail,
      'business_id': BusinessConfig.instance.businessId,
      'user_id': BusinessConfig.instance.userId,
      'is_synced': 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    DatabaseHelper.notifyDataChanged();
    return id;
  }

  Future<void> deleteBankDetail(int id) async {
    final db = await database;
    await db.update('bank_details', {'status': 0, 'is_synced': 0}, where: 'id = ?${getBusinessFilter()}', whereArgs: [id, ...getBusinessArgs()]);
    DatabaseHelper.notifyDataChanged();
  }
}
