import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';

mixin DealsCrud {
  Future<Database> get database;

  int? _safeInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  String _bidWhereClause({String alias = ''}) {
    final col = alias.isEmpty ? 'business_id' : '$alias.business_id';
    final bid = _safeInt(BusinessConfig.instance.businessId);
    return bid == null ? '$col IS NULL' : '$col = ?';
  }

  List<dynamic> _bidWhereArgs() {
    final bid = _safeInt(BusinessConfig.instance.businessId);
    return bid == null ? const [] : [bid];
  }

  Future<int> insertDeal(
      Map<String, dynamic> deal, List<Map<String, dynamic>> items) async {
    final db = await database;
    int dealId = 0;

    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      final dealData = {
        ...deal,
        'business_id': _safeInt(BusinessConfig.instance.businessId),
        'created_at': now,
        'updated_at': now,
      };

      dealId = await txn.insert('deals', dealData);

      for (var item in items) {
        final itemData = {
          ...item,
          'deal_id': dealId,
          'created_at': now,
          'updated_at': now,
        };
        await txn.insert('deal_items', itemData);
      }
    });

    DatabaseHelper.notifyDataChanged();
    return dealId;
  }

  Future<int> updateDeal(int dealId, Map<String, dynamic> deal,
      List<Map<String, dynamic>> items) async {
    final db = await database;

    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      final dealData = {
        ...deal,
        'updated_at': now,
      };

      final bidArgs = _bidWhereArgs();
      await txn.update(
        'deals',
        dealData,
        where: 'id = ? AND ${_bidWhereClause()}',
        whereArgs: [dealId, ...bidArgs],
      );

      await txn.delete('deal_items', where: 'deal_id = ?', whereArgs: [dealId]);

      for (var item in items) {
        final itemData = {
          ...item,
          'deal_id': dealId,
          'created_at': now,
          'updated_at': now,
        };
        await txn.insert('deal_items', itemData);
      }
    });

    DatabaseHelper.notifyDataChanged();
    return dealId;
  }

  Future<int> deleteDeal(int dealId) async {
    final db = await database;
    int result = 0;

    await db.transaction((txn) async {
      await txn.delete('deal_items', where: 'deal_id = ?', whereArgs: [dealId]);
      final bidArgs = _bidWhereArgs();
      result = await txn.delete(
        'deals',
        where: 'id = ? AND ${_bidWhereClause()}',
        whereArgs: [dealId, ...bidArgs],
      );
    });

    DatabaseHelper.notifyDataChanged();
    return result;
  }

  Future<int> toggleDealStatus(int dealId, int newStatus) async {
    final db = await database;
    final bidArgs = _bidWhereArgs();
    final result = await db.update(
      'deals',
      {
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND ${_bidWhereClause()}',
      whereArgs: [dealId, ...bidArgs],
    );

    DatabaseHelper.notifyDataChanged();
    return result;
  }

  Future<List<Map<String, dynamic>>> getAllDeals(
      {bool activeOnly = false}) async {
    final db = await database;

    String whereClause = _bidWhereClause();
    List<dynamic> whereArgs = List.from(_bidWhereArgs());

    if (activeOnly) {
      whereClause += ' AND status = 1';
    }

    return await db.query(
      'deals',
      where: whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getDealItems(int dealId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT di.*,
             COALESCE(p.name, 'Product #' || di.product_id) as product_name,
             COALESCE(di.unit_price, 0) as product_price,
             (SELECT MIN(s2.barcode) FROM stocks s2 WHERE s2.product_id = di.product_id) as barcode,
             COALESCE((SELECT SUM(s2.quantity) FROM stocks s2 WHERE s2.product_id = di.product_id), 0) as current_stock
      FROM deal_items di
      LEFT JOIN products p ON di.product_id = p.id
      WHERE di.deal_id = ?
    ''', [dealId]);
    debugPrint('getDealItems($dealId): ${rows.length} rows fetched');
    return rows;
  }
}
