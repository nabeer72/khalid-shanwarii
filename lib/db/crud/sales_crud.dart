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
    
    final branchFilterS = getBranchFilter().replaceAll('branch_id', 's.branch_id');
    final branchFilterR = getBranchFilter().replaceAll('branch_id', 'r.branch_id');
    final branchArgs = getBranchArgs();
    
    String extraFilterS = '';
    String extraFilterR = '';
    final List<dynamic> args = [];

    if (shiftId != null) {
      extraFilterS = ' AND s.shift_id = ?';
      extraFilterR = ' AND rs.shift_id = ?';
    } else if (startTime != null && endTime != null) {
      extraFilterS = ' AND s.created_at BETWEEN ? AND ?';
      extraFilterR = ' AND r.created_at BETWEEN ? AND ?';
    }

    // Args for SELECT 1 (sales)
    args.addAll([bid, aid, ...branchArgs]);
    if (shiftId != null) {
      args.add(shiftId);
    } else if (startTime != null && endTime != null) {
      args.addAll([startTime, endTime]);
    }

    // Args for SELECT 2 (returns)
    args.addAll([bid, aid, ...branchArgs]);
    if (shiftId != null) {
      args.add(shiftId);
    } else if (startTime != null && endTime != null) {
      args.addAll([startTime, endTime]);
    }

    return await db.rawQuery(
      '''
      SELECT 
        s.id, s.business_id, s.branch_id, s.admin_id, s.customer_id, s.user_id, s.subtotal, s.tax, s.discount, s.total, s.payment_method, s.is_return, s.tip, s.status, s.is_synced, s.created_at as created_at, s.updated_at, s.shift_id,
        c.name as customer_name, 
        c.phone as customer_phone,
        u.name as employee_name
      FROM sales s
      LEFT JOIN customers c ON s.customer_id = c.id
      LEFT JOIN users u ON s.user_id = u.id
      WHERE s.business_id = ? AND s.admin_id = ?$branchFilterS$extraFilterS 
      
      UNION ALL
      
      SELECT
        r.id, r.business_id, r.branch_id, r.admin_id, r.customer_id, r.user_id, r.total_amount as subtotal, 0 as tax, 0 as discount, r.total_amount as total, 'cash' as payment_method, 1 as is_return, 0 as tip, r.status, r.is_synced, r.created_at as created_at, r.updated_at, rs.shift_id as shift_id,
        c.name as customer_name,
        c.phone as customer_phone,
        u.name as employee_name
      FROM returns r
      LEFT JOIN sales rs ON r.sale_id = rs.id
      LEFT JOIN customers c ON r.customer_id = c.id
      LEFT JOIN users u ON r.user_id = u.id
      WHERE r.business_id = ? AND r.admin_id = ?$branchFilterR$extraFilterR
      
      ORDER BY 16 DESC${limit != null ? ' LIMIT $limit' : ''}
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
    return await db.rawQuery('''
      SELECT si.*, p.name as product_name
      FROM sale_items si
      LEFT JOIN products p ON si.product_id = p.id
      WHERE si.sale_id = ?
    ''', [saleId]);
  }
}
