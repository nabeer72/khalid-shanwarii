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

  // --- Reporting Methods ---

  Future<List<Map<String, dynamic>>> getDetailedSaleItems({int? userId, int? categoryId, String? startTime, String? endTime}) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    final branchFilter = getBranchFilter().replaceAll('branch_id', 's.branch_id');
    final branchArgs = getBranchArgs();

    String dateFilter = '';
    final List<dynamic> args = [bid, aid, ...branchArgs];

    if (startTime != null && endTime != null) {
      dateFilter = ' AND s.created_at BETWEEN ? AND ?';
      args.addAll([startTime, endTime]);
    }

    String userFilter = '';
    if (userId != null) {
      userFilter = ' AND s.user_id = ?';
      args.add(userId);
    }

    String catFilter = '';
    if (categoryId != null) {
      catFilter = ' AND c.id = ?';
      args.add(categoryId);
    }

    return await db.rawQuery('''
      SELECT 
        si.*,
        p.name as product_name, 
        COALESCE(st.cost_price, p.purchase_price) as purchase_price,
        c.name as category_name,
        s.created_at,
        u.name as employee_name
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      LEFT JOIN products p ON si.product_id = p.id
      LEFT JOIN stocks st ON si.stock_id = st.id
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN users u ON s.user_id = u.id
      WHERE s.business_id = ? AND s.admin_id = ?$branchFilter$dateFilter$userFilter$catFilter
      ORDER BY s.created_at DESC
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getCategorySalesSummary({int? categoryId, String? startTime, String? endTime}) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    final branchFilter = getBranchFilter().replaceAll('branch_id', 's.branch_id');
    final branchArgs = getBranchArgs();

    String dateFilter = '';
    final List<dynamic> args = [bid, aid, ...branchArgs];

    if (startTime != null && endTime != null) {
      dateFilter = ' AND s.created_at BETWEEN ? AND ?';
      args.addAll([startTime, endTime]);
    }

    String catFilter = '';
    if (categoryId != null) {
      catFilter = ' AND c.id = ?';
      args.add(categoryId);
    }

    return await db.rawQuery('''
      SELECT 
        c.name as category_name,
        SUM(si.quantity) as total_qty,
        SUM(si.subtotal) as total_amount,
        SUM(si.discount) as total_discount,
        SUM(si.subtotal - si.discount) as total_net
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      LEFT JOIN products p ON si.product_id = p.id
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE s.business_id = ? AND s.admin_id = ?$branchFilter$dateFilter$catFilter
      GROUP BY c.id, c.name
      ORDER BY total_amount DESC
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getEmployeeSalesSummary({int? userId, String? startTime, String? endTime}) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    final branchFilter = getBranchFilter().replaceAll('branch_id', 's.branch_id');
    final branchArgs = getBranchArgs();

    String dateFilter = '';
    final List<dynamic> args = [bid, aid, ...branchArgs];

    if (startTime != null && endTime != null) {
      dateFilter = ' AND s.created_at BETWEEN ? AND ?';
      args.addAll([startTime, endTime]);
    }

    String userFilter = '';
    if (userId != null) {
      userFilter = ' AND u.id = ?';
      args.add(userId);
    }

    return await db.rawQuery('''
      SELECT 
        u.name as employee_name,
        COUNT(DISTINCT s.id) as total_sales_count,
        SUM(s.subtotal) as total_gross,
        SUM(s.discount) as total_discount,
        SUM(s.total) as total_amount
      FROM sales s
      LEFT JOIN users u ON s.user_id = u.id
      WHERE s.business_id = ? AND s.admin_id = ?$branchFilter$dateFilter$userFilter
      GROUP BY u.id, u.name
      ORDER BY total_amount DESC
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getTopSellingItems({String? startTime, String? endTime, int limit = 20}) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    final branchFilter = getBranchFilter().replaceAll('branch_id', 's.branch_id');
    final branchArgs = getBranchArgs();

    String dateFilter = '';
    final List<dynamic> args = [bid, aid, ...branchArgs];

    if (startTime != null && endTime != null) {
      dateFilter = ' AND s.created_at BETWEEN ? AND ?';
      args.addAll([startTime, endTime]);
    }

    return await db.rawQuery('''
      SELECT 
        p.name as product_name,
        SUM(si.quantity) as total_qty,
        SUM(si.subtotal) as total_amount
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      LEFT JOIN products p ON si.product_id = p.id
      WHERE s.business_id = ? AND s.admin_id = ?$branchFilter$dateFilter
      GROUP BY p.id, p.name
      ORDER BY total_qty DESC
      LIMIT $limit
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getPaymentMethodSummary({String? startTime, String? endTime, int? userId, int? categoryId}) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    final branchFilter = getBranchFilter().replaceAll('branch_id', 's.branch_id');
    final branchArgs = getBranchArgs();

    String dateFilter = '';
    final List<dynamic> salesArgs = [bid, aid, ...branchArgs];

    if (startTime != null && endTime != null) {
      dateFilter = ' AND s.created_at BETWEEN ? AND ?';
      salesArgs.addAll([startTime, endTime]);
    }

    String userFilter = '';
    if (userId != null) {
      userFilter = ' AND s.user_id = ?';
      salesArgs.add(userId);
    }

    // Sales by payment method
    final salesByMethod = await db.rawQuery('''
      SELECT 
        s.payment_method,
        COUNT(DISTINCT s.id) as total_count,
        SUM(s.total) as total_amount
      FROM sales s
      WHERE s.business_id = ? AND s.admin_id = ?$branchFilter$dateFilter$userFilter
      GROUP BY s.payment_method
      ORDER BY total_amount DESC
    ''', salesArgs);

    // Returns total
    final branchFilterR = getBranchFilter().replaceAll('branch_id', 'r.branch_id');
    String dateFilterR = '';
    final List<dynamic> returnArgs = [bid, aid, ...branchArgs];

    if (startTime != null && endTime != null) {
      dateFilterR = ' AND r.created_at BETWEEN ? AND ?';
      returnArgs.addAll([startTime, endTime]);
    }

    final returnsSummary = await db.rawQuery('''
      SELECT 
        COUNT(DISTINCT r.id) as total_count,
        SUM(r.total_amount) as total_amount
      FROM returns r
      WHERE r.business_id = ? AND r.admin_id = ?$branchFilterR$dateFilterR
    ''', returnArgs);

    final List<Map<String, dynamic>> result = salesByMethod.map((r) => Map<String, dynamic>.from(r)).toList();

    if (returnsSummary.isNotEmpty && (returnsSummary.first['total_amount'] as num? ?? 0) > 0) {
      result.add({
        'payment_method': 'Returns',
        'total_count': returnsSummary.first['total_count'] ?? 0,
        'total_amount': returnsSummary.first['total_amount'] ?? 0,
      });
    }

    return result;
  }

  Future<List<Map<String, dynamic>>> getDateWiseSalesSummary({String? startTime, String? endTime}) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    final branchFilter = getBranchFilter().replaceAll('branch_id', 's.branch_id');
    final branchArgs = getBranchArgs();

    String dateFilter = '';
    final List<dynamic> args = [bid, aid, ...branchArgs];

    if (startTime != null && endTime != null) {
      dateFilter = ' AND s.created_at BETWEEN ? AND ?';
      args.addAll([startTime, endTime]);
    }

    return await db.rawQuery('''
      SELECT 
        DATE(s.created_at) as sale_date,
        COUNT(DISTINCT s.id) as total_sales_count,
        SUM(s.total) as total_amount
      FROM sales s
      WHERE s.business_id = ? AND s.admin_id = ?$branchFilter$dateFilter
      GROUP BY DATE(s.created_at)
      ORDER BY sale_date DESC
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getCategoryReturnsSummary({int? categoryId, String? startTime, String? endTime}) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    final branchFilter = getBranchFilter().replaceAll('branch_id', 'r.branch_id');
    final branchArgs = getBranchArgs();

    String dateFilter = '';
    final List<dynamic> args = [bid, aid, ...branchArgs];

    if (startTime != null && endTime != null) {
      dateFilter = ' AND r.created_at BETWEEN ? AND ?';
      args.addAll([startTime, endTime]);
    }

    String catFilter = '';
    if (categoryId != null) {
      catFilter = ' AND c.id = ?';
      args.add(categoryId);
    }

    return await db.rawQuery('''
      SELECT 
        c.name as category_name,
        SUM(ri.quantity) as total_qty,
        SUM(ri.subtotal) as total_amount,
        SUM(ri.discount) as total_discount,
        SUM(ri.subtotal - ri.discount) as total_net
      FROM return_items ri
      JOIN returns r ON ri.return_id = r.id
      LEFT JOIN products p ON ri.product_id = p.id
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE r.business_id = ? AND r.admin_id = ?$branchFilter$dateFilter$catFilter
      GROUP BY c.id, c.name
      ORDER BY total_amount DESC
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getEmployeeReturnsSummary({int? userId, String? startTime, String? endTime}) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    final branchFilter = getBranchFilter().replaceAll('branch_id', 'r.branch_id');
    final branchArgs = getBranchArgs();

    String dateFilter = '';
    final List<dynamic> args = [bid, aid, ...branchArgs];

    if (startTime != null && endTime != null) {
      dateFilter = ' AND r.created_at BETWEEN ? AND ?';
      args.addAll([startTime, endTime]);
    }

    String userFilter = '';
    if (userId != null) {
      userFilter = ' AND u.id = ?';
      args.add(userId);
    }

    return await db.rawQuery('''
      SELECT 
        u.name as employee_name,
        COUNT(DISTINCT r.id) as total_returns_count,
        SUM(r.total_amount) as total_amount
      FROM returns r
      LEFT JOIN users u ON r.user_id = u.id
      WHERE r.business_id = ? AND r.admin_id = ?$branchFilter$dateFilter$userFilter
      GROUP BY u.id, u.name
      ORDER BY total_amount DESC
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getDetailedReturnItems({String? startTime, String? endTime}) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    final branchFilter = getBranchFilter().replaceAll('branch_id', 'r.branch_id');
    final branchArgs = getBranchArgs();

    String dateFilter = '';
    final List<dynamic> args = [bid, aid, ...branchArgs];

    if (startTime != null && endTime != null) {
      dateFilter = ' AND r.created_at BETWEEN ? AND ?';
      args.addAll([startTime, endTime]);
    }

    return await db.rawQuery('''
      SELECT 
        ri.id, ri.return_id, ri.product_id, ri.stock_id, ri.quantity, ri.price, ri.subtotal, ri.discount,
        p.name as product_name, 
        c.name as category_name,
        r.created_at,
        u.name as employee_name
      FROM return_items ri
      JOIN returns r ON ri.return_id = r.id
      LEFT JOIN products p ON ri.product_id = p.id
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN users u ON r.user_id = u.id
      WHERE r.business_id = ? AND r.admin_id = ?$branchFilter$dateFilter
      ORDER BY r.created_at DESC
    ''', args);
  }
}
