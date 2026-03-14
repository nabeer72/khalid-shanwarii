import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'common_crud.dart';

mixin SalesCrud on CommonCrud {
  // Sales
  Future<List<Map<String, dynamic>>> getSales({int? limit}) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final args = [bid, aid, ...branchArgs];

    return await db.rawQuery(
      'SELECT * FROM sales WHERE business_id = ? AND admin_id = ?$branchFilter ORDER BY created_at DESC${limit != null ? ' LIMIT $limit' : ''}',
      args,
    );
  }

  Future<int> insertSale(Map<String, dynamic> sale, List<Map<String, dynamic>> items) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    final brid = sale['branch_id'] ?? getCurrentBranchId();
    
    return await db.transaction((txn) async {
      final generatedSaleId = await txn.insert('sales', {
        ...sale,
        'business_id': bid,
        'admin_id': aid,
        'branch_id': brid,
        'is_synced': 0
      });
      
      final sid = sale['id'] ?? generatedSaleId;

      for (var item in items) {
        final stockId = item['stock_id'];
        final quantity = (item['quantity'] as num? ?? 0).toDouble();
        final isReturn = sale['is_return'] == 1;

        await txn.insert('sale_items', {
          ...item,
          'sale_id': sid,
          'branch_id': brid,
          'is_synced': 0
        });

        // Update Stock (Batch-specific)
        if (stockId != null) {
          final List<Map<String, dynamic>> stocks = await txn.query(
            'stocks',
            columns: ['quantity'],
            where: 'id = ?',
            whereArgs: [stockId],
          );

          if (stocks.isNotEmpty) {
            final currentStock = (stocks.first['quantity'] as num? ?? 0).toDouble();
            final newStock = isReturn 
                ? currentStock + quantity 
                : currentStock - quantity;

            await txn.update(
              'stocks',
              {
                'quantity': newStock,
                'is_synced': 0,
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [stockId],
            );
          }
        }
      }

      // Update Customer Stats
      final customerId = sale['customer_id'];
      if (customerId != null) {
        final total = (sale['total'] as num).toDouble();
        
        await txn.rawUpdate(
          'UPDATE customers SET total_spent = total_spent + ?, visit_count = visit_count + 1 WHERE id = ?',
          [total, customerId]
        );
      }
      return sid;
    });
  }

  Future<List<Map<String, dynamic>>> getSaleItems(dynamic saleId) async {
    final db = await database;
    return await db.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
  }

  // Held Orders
  Future<List<Map<String, dynamic>>> getHeldOrders() async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final args = [bid, aid, ...branchArgs];

    return await db.rawQuery(
      'SELECT * FROM held_orders WHERE business_id = ? AND admin_id = ?$branchFilter ORDER BY created_at DESC',
      args,
    );
  }

  Future<void> insertHeldOrder(Map<String, dynamic> order) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    await db.insert('held_orders', {
      ...order,
      'business_id': bid,
      'admin_id': aid,
      'branch_id': order['branch_id'] ?? getCurrentBranchId(),
    });
  }

  Future<void> deleteHeldOrder(dynamic id) async {
    final db = await database;
    await db.delete('held_orders', where: 'id = ?', whereArgs: [id]);
  }

  // Gift Cards
  Future<List<Map<String, dynamic>>> getGiftCards() async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final args = [bid, aid, ...branchArgs];

    return await db.rawQuery(
      'SELECT * FROM gift_cards WHERE status = 1 AND business_id = ? AND admin_id = ?$branchFilter',
      args,
    );
  }

  Future<void> insertGiftCard(Map<String, dynamic> card) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    await db.insert('gift_cards', {
      ...card,
      'business_id': bid,
      'admin_id': aid,
      'branch_id': card['branch_id'] ?? getCurrentBranchId(),
      'is_synced': 0
    });
  }
}
