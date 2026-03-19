import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'common_crud.dart';

mixin SalesCrud on CommonCrud {
  // Sales
  Future<List<Map<String, dynamic>>> getSales({int? limit, String? startTime, String? endTime, int? shiftId}) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    final branchFilter = getBranchFilter().replaceAll('branch_id', 's.branch_id');
    final branchArgs = getBranchArgs();
    
    String extraFilter = '';
    final List<dynamic> args = [bid, aid, ...branchArgs];

    if (shiftId != null) {
      extraFilter = ' AND s.shift_id = ?';
      args.add(shiftId);
    } else if (startTime != null && endTime != null) {
      extraFilter = ' AND s.created_at BETWEEN ? AND ?';
      args.add(startTime);
      args.add(endTime);
    }

    return await db.rawQuery(
      '''
      SELECT 
        s.*, 
        c.name as customer_name, 
        c.phone as customer_phone,
        u.name as employee_name
      FROM sales s
      LEFT JOIN customers c ON s.customer_id = c.id
      LEFT JOIN users u ON s.user_id = u.id
      WHERE s.business_id = ? AND s.admin_id = ?$branchFilter$extraFilter 
      ORDER BY s.created_at DESC${limit != null ? ' LIMIT $limit' : ''}
      ''',
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
        'shift_id': sale['shift_id'],
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
}
