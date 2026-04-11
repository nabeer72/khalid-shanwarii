
import 'package:mobile_app/db/mock_data.dart';
import '../database_helper.dart';
import 'common_crud.dart';

mixin SalesCrud on CommonCrud {
  // Sales
  Future<List<Map<String, dynamic>>> getSales({int? limit, String? startTime, String? endTime, int? shiftId}) async {
    final db = await database;
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
    args.addAll([...getBusinessArgs(), ...branchArgs]);
    if (shiftId != null) {
      args.add(shiftId);
    } else if (startTime != null && endTime != null) {
      args.addAll([startTime, endTime]);
    }

    // Args for SELECT 2 (returns)
    args.addAll([...getBusinessArgs(), ...branchArgs]);
    if (shiftId != null) {
      args.add(shiftId);
    } else if (startTime != null && endTime != null) {
      args.addAll([startTime, endTime]);
    }

    return await db.rawQuery(
      '''
      SELECT 
        s.id, s.business_id, s.branch_id, s.user_id, s.customer_id, s.staff_id, s.sub_total as subtotal, s.tax, s.discount, s.total, s.payment_method, s.is_return, s.total_tip as tip, s.status, s.is_synced, s.created_at as created_at, s.updated_at, s.shift_id,
        c.name as customer_name, 
        c.phone as customer_phone,
        u.name as employee_name
      FROM sales s
      LEFT JOIN customers c ON s.customer_id = c.id
      LEFT JOIN users u ON s.staff_id = u.id
      WHERE ${getBusinessFilter().replaceAll('business_id', 's.business_id').replaceAll('user_id', 's.user_id').replaceFirst(' AND ', '')}$branchFilterS$extraFilterS 
      
      UNION ALL
      
      SELECT
        r.id, r.business_id, r.branch_id, r.user_id, r.customer_id, r.staff_id, r.total_amount as subtotal, 0 as tax, 0 as discount, r.total_amount as total, 'cash' as payment_method, 1 as is_return, 0 as tip, r.status, r.is_synced, r.created_at as created_at, r.updated_at, rs.shift_id as shift_id,
        c.name as customer_name,
        c.phone as customer_phone,
        u.name as employee_name
      FROM returns r
      LEFT JOIN sales rs ON r.sale_id = rs.id
      LEFT JOIN customers c ON r.customer_id = c.id
      LEFT JOIN users u ON r.staff_id = u.id
      WHERE ${getBusinessFilter().replaceAll('business_id', 'r.business_id').replaceAll('user_id', 'r.user_id').replaceFirst(' AND ', '')}$branchFilterR$extraFilterR
      
      ORDER BY 16 DESC${limit != null ? ' LIMIT $limit' : ''}
      ''',
      args,
    );
  }

  Future<int> insertSale(Map<String, dynamic> sale, List<Map<String, dynamic>> items) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final uid = getSafeInt(BusinessConfig.instance.userId);
    final brid = sale['branch_id'] ?? getCurrentBranchId();
    
    final result = await db.transaction((txn) async {
      final generatedSaleId = await txn.insert('sales', {
        ...sale,
        'business_id': bid,
        'user_id': uid,
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
          'user_id': uid,
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
          'UPDATE customers SET total_spent = total_spent + ?, visit_count = visit_count + 1 WHERE id = ? ${getBusinessFilter()}',
          [total, customerId, ...getBusinessArgs()]
        );
      }
      return sid;
    });

    DatabaseHelper.notifyDataChanged();
    return result;
  }

  Future<List<Map<String, dynamic>>> getSaleItems(dynamic saleId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT si.*, si.sub_total as subtotal, p.name as product_name
      FROM sale_items si
      LEFT JOIN products p ON si.product_id = p.id
      WHERE si.sale_id = ?
    ''', [saleId]);
  }

  // --- Reporting Methods ---

  Future<List<Map<String, dynamic>>> getDetailedSaleItems({int? userId, int? categoryId, String? startTime, String? endTime}) async {
    final db = await database;
    final branchFilter = getBranchFilter().replaceAll('branch_id', 's.branch_id');
    final branchArgs = getBranchArgs();

    String dateFilter = '';
    String userFilter = '';
    String catFilter = '';
    final List<dynamic> args = [...getBusinessArgs(), ...branchArgs];

    if (startTime != null && endTime != null) {
      dateFilter = ' AND s.created_at BETWEEN ? AND ?';
      args.addAll([startTime, endTime]);
    }
    
    if (userId != null) {
      userFilter = ' AND s.staff_id = ?';
      args.add(userId);
    }

    if (categoryId != null) {
      catFilter = ' AND p.category_id = ?';
      args.add(categoryId);
    }

    return await db.rawQuery('''
      SELECT 
        si.id, si.sale_id, si.product_id, si.stock_id, si.business_id, si.user_id,
        si.quantity, si.price,
        COALESCE(si.sub_total, si.price * si.quantity) as subtotal,
        COALESCE(si.discount, 0) as discount,
        si.branch_id, si.is_synced,
        p.name as product_name, 
        COALESCE(st.cost_price, 0) as purchase_price,
        COALESCE(c.name, 'Uncategorized') as category_name,
        s.created_at,
        COALESCE(u.name, 'Unknown') as employee_name
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id AND s.is_return = 0 AND s.status = 1
      LEFT JOIN products p ON si.product_id = p.id
      LEFT JOIN stocks st ON si.stock_id = st.id
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN users u ON s.staff_id = u.id
      WHERE ${getBusinessFilter().replaceAll('business_id', 's.business_id').replaceAll('user_id', 's.user_id').replaceFirst(' AND ', '')}$branchFilter$dateFilter$userFilter$catFilter
      ORDER BY s.created_at DESC
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getCategorySalesSummary({int? categoryId, String? startTime, String? endTime}) async {
    final db = await database;
    // ignore: unused_local_variable
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    // ignore: unused_local_variable
    final uid = getSafeInt(BusinessConfig.instance.userId);
    final branchFilter = getBranchFilter().replaceAll('branch_id', 's.branch_id');
    final branchArgs = getBranchArgs();

    String dateFilter = '';
    final List<dynamic> args = [...getBusinessArgs(), ...branchArgs];

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
        COALESCE(c.name, 'Uncategorized') as category_name,
        SUM(si.quantity) as total_qty,
        SUM(COALESCE(si.sub_total, si.price * si.quantity)) as total_amount,
        SUM(COALESCE(si.discount, 0)) as total_discount,
        SUM(COALESCE(si.sub_total, si.price * si.quantity) - COALESCE(si.discount, 0)) as total_net
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      LEFT JOIN products p ON si.product_id = p.id
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE ${getBusinessFilter().replaceAll('business_id', 's.business_id').replaceAll('user_id', 's.user_id').replaceFirst(' AND ', '')}$branchFilter$dateFilter$catFilter
        AND s.is_return = 0 AND s.status = 1
      GROUP BY c.id, c.name
      ORDER BY total_amount DESC
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getEmployeeSalesSummary({int? userId, String? startTime, String? endTime}) async {
    final db = await database;
    final branchFilter = getBranchFilter().replaceAll('branch_id', 's.branch_id');
    final branchArgs = getBranchArgs();

    String dateFilter = '';
    final List<dynamic> args = [...getBusinessArgs(), ...branchArgs];

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
        COALESCE(u.name, 'Unknown') as employee_name,
        COUNT(DISTINCT s.id) as total_sales_count,
        SUM(COALESCE(s.sub_total, 0)) as total_gross,
        SUM(COALESCE(s.discount, 0)) as total_discount,
        SUM(COALESCE(s.total, 0)) as total_amount
      FROM sales s
      LEFT JOIN users u ON s.staff_id = u.id
      WHERE ${getBusinessFilter().replaceAll('business_id', 's.business_id').replaceAll('user_id', 's.user_id').replaceFirst(' AND ', '')}$branchFilter$dateFilter$userFilter
        AND s.is_return = 0 AND s.status = 1
      GROUP BY u.id, u.name
      ORDER BY total_amount DESC
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getTopSellingItems({String? startTime, String? endTime, int limit = 20}) async {
    final db = await database;
    final branchFilter = getBranchFilter().replaceAll('branch_id', 's.branch_id');
    final branchArgs = getBranchArgs();

    String dateFilter = '';
    final List<dynamic> args = [...getBusinessArgs(), ...branchArgs];

    if (startTime != null && endTime != null) {
      dateFilter = ' AND s.created_at BETWEEN ? AND ?';
      args.addAll([startTime, endTime]);
    }

    return await db.rawQuery('''
      SELECT 
        COALESCE(p.name, 'Unknown Product') as product_name,
        SUM(si.quantity) as total_qty,
        SUM(COALESCE(si.sub_total, si.price * si.quantity)) as total_amount
      FROM sale_items si
      JOIN sales s ON si.sale_id = s.id
      LEFT JOIN products p ON si.product_id = p.id
      WHERE ${getBusinessFilter().replaceAll('business_id', 's.business_id').replaceAll('user_id', 's.user_id').replaceFirst(' AND ', '')}$branchFilter$dateFilter
        AND s.is_return = 0 AND s.status = 1
      GROUP BY p.id, p.name
      ORDER BY total_qty DESC
      LIMIT $limit
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getPaymentMethodSummary({String? startTime, String? endTime, int? userId, int? categoryId}) async {
    final db = await database;
    final branchFilter = getBranchFilter().replaceAll('branch_id', 's.branch_id');
    final branchArgs = getBranchArgs();

    String dateFilter = '';
    final List<dynamic> salesArgs = [...getBusinessArgs(), ...branchArgs];

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
      WHERE ${getBusinessFilter().replaceAll('business_id', 's.business_id').replaceAll('user_id', 's.user_id').replaceFirst(' AND ', '')}$branchFilter$dateFilter$userFilter
      GROUP BY s.payment_method
      ORDER BY total_amount DESC
    ''', salesArgs);

    // Returns total
    final branchFilterR = getBranchFilter().replaceAll('branch_id', 'r.branch_id');
    String dateFilterR = '';
    final List<dynamic> returnArgs = [...getBusinessArgs(), ...branchArgs];

    if (startTime != null && endTime != null) {
      dateFilterR = ' AND r.created_at BETWEEN ? AND ?';
      returnArgs.addAll([startTime, endTime]);
    }

    final returnsSummary = await db.rawQuery('''
      SELECT 
        COUNT(DISTINCT r.id) as total_count,
        SUM(r.total_amount) as total_amount
      FROM returns r
      WHERE ${getBusinessFilter().replaceAll('business_id', 'r.business_id').replaceAll('user_id', 'r.user_id').replaceFirst(' AND ', '')}$branchFilterR$dateFilterR
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
    final branchFilter = getBranchFilter().replaceAll('branch_id', 's.branch_id');
    final branchArgs = getBranchArgs();

    String dateFilter = '';
    final List<dynamic> args = [...getBusinessArgs(), ...branchArgs];

    if (startTime != null && endTime != null) {
      dateFilter = ' AND s.created_at BETWEEN ? AND ?';
      args.addAll([startTime, endTime]);
    }

    return await db.rawQuery('''
      SELECT 
        DATE(s.created_at) as sale_date,
        COUNT(DISTINCT s.id) as total_sales_count,
        SUM(COALESCE(s.total, 0)) as total_amount
      FROM sales s
      WHERE ${getBusinessFilter().replaceAll('business_id', 's.business_id').replaceAll('user_id', 's.user_id').replaceFirst(' AND ', '')}$branchFilter$dateFilter
        AND s.is_return = 0 AND s.status = 1
      GROUP BY DATE(s.created_at)
      ORDER BY sale_date DESC
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getCategoryReturnsSummary({int? categoryId, String? startTime, String? endTime}) async {
    final db = await database;
    final branchFilter = getBranchFilter().replaceAll('branch_id', 'r.branch_id');
    final branchArgs = getBranchArgs();

    String dateFilter = '';
    final List<dynamic> args = [...getBusinessArgs(), ...branchArgs];

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
        COALESCE(c.name, 'Uncategorized') as category_name,
        SUM(ri.quantity) as total_qty,
        SUM(COALESCE(ri.sub_total, ri.price * ri.quantity)) as total_amount,
        SUM(COALESCE(ri.discount, 0)) as total_discount,
        SUM(COALESCE(ri.sub_total, ri.price * ri.quantity) - COALESCE(ri.discount, 0)) as total_net
      FROM return_items ri
      JOIN returns r ON ri.return_id = r.id
      LEFT JOIN products p ON ri.product_id = p.id
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE ${getBusinessFilter().replaceAll('business_id', 'r.business_id').replaceAll('user_id', 'r.user_id').replaceFirst(' AND ', '')}$branchFilter$dateFilter$catFilter
        AND r.status = 1
      GROUP BY c.id, c.name
      ORDER BY total_amount DESC
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getEmployeeReturnsSummary({int? userId, String? startTime, String? endTime}) async {
    final db = await database;
    final branchFilter = getBranchFilter().replaceAll('branch_id', 'r.branch_id');
    final branchArgs = getBranchArgs();

    String dateFilter = '';
    final List<dynamic> args = [...getBusinessArgs(), ...branchArgs];

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
        COALESCE(u.name, 'Unknown') as employee_name,
        COUNT(DISTINCT r.id) as total_returns_count,
        SUM(COALESCE(r.total_amount, 0)) as total_amount
      FROM returns r
      LEFT JOIN users u ON r.staff_id = u.id
      WHERE ${getBusinessFilter().replaceAll('business_id', 'r.business_id').replaceAll('user_id', 'r.user_id').replaceFirst(' AND ', '')}$branchFilter$dateFilter$userFilter
        AND r.status = 1
      GROUP BY u.id, u.name
      ORDER BY total_amount DESC
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getDetailedReturnItems({String? startTime, String? endTime}) async {
    final db = await database;
    final branchFilter = getBranchFilter().replaceAll('branch_id', 'r.branch_id');
    final branchArgs = getBranchArgs();

    String dateFilter = '';
    final List<dynamic> args = [...getBusinessArgs(), ...branchArgs];

    if (startTime != null && endTime != null) {
      dateFilter = ' AND r.created_at BETWEEN ? AND ?';
      args.addAll([startTime, endTime]);
    }

    return await db.rawQuery('''
      SELECT 
        ri.id, ri.return_id, ri.product_id, ri.stock_id, ri.quantity, ri.price,
        COALESCE(ri.sub_total, ri.price * ri.quantity) as subtotal,
        COALESCE(ri.discount, 0) as discount,
        p.name as product_name, 
        c.name as category_name,
        r.created_at,
        u.name as employee_name
      FROM return_items ri
      JOIN returns r ON ri.return_id = r.id
      LEFT JOIN products p ON ri.product_id = p.id
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN users u ON r.staff_id = u.id
      WHERE ${getBusinessFilter().replaceAll('business_id', 'r.business_id').replaceAll('user_id', 'r.user_id').replaceFirst(' AND ', '')}$branchFilter$dateFilter
        AND r.status = 1
      ORDER BY r.created_at DESC
    ''', args);
  }
}
