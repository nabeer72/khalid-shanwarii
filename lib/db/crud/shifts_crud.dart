import 'package:sqflite_sqlcipher/sqflite.dart';
import '../database_helper.dart';
import 'common_crud.dart';
mixin ShiftsCrud on CommonCrud {
  // ========== Shift Operations ==========

  Future<Map<String, dynamic>?> getActiveShift() async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();

    final args = [...getBusinessArgs(), ...branchArgs];

    final results = await db.query(
      'shifts',
      where: 'status = 1${getBusinessFilter()}$branchFilter',
      whereArgs: args,
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> startShift(Map<String, dynamic> shiftData) async {
    final db = await database;
    await db.insert('shifts', {
      ...shiftData,
      ...Map.fromIterables(['business_id', 'admin_id'], getBusinessArgs()),
      'branch_id': getCurrentBranchId(),
      'is_synced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    
    DatabaseHelper.notifyDataChanged();
  }

  Future<void> endShift(dynamic id, Map<String, dynamic> closingData) async {
    final db = await database;
    await db.update(
      'shifts',
      {
        ...closingData,
        'status': 0,
        'updated_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ?${getBusinessFilter()}',
      whereArgs: [id, ...getBusinessArgs()],
    );
    
    DatabaseHelper.notifyDataChanged();
  }

  Future<Map<String, double>> getShiftTotals(String startTime, String endTime) async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    final businessArgs = getBusinessArgs();
    
    final args = [startTime, endTime, ...businessArgs, ...branchArgs];

    // Get sales totals grouped by payment method
    final results = await db.rawQuery('''
      SELECT payment_method, SUM(total) as total_amount
      FROM sales
      WHERE created_at BETWEEN ? AND ? 
      ${getBusinessFilter()} AND status = 1$branchFilter
      GROUP BY payment_method
    ''', args);

    double cashSales = 0, onlineMobile = 0, onlineCard = 0, creditSalesTotal = 0, totalRevenue = 0;

    for (var row in results) {
      final method = (row['payment_method'] as String).toLowerCase();
      final amount = (row['total_amount'] as num?)?.toDouble() ?? 0.0;
      totalRevenue += amount;
      
      if (method == 'cash') {
        cashSales += amount;
      } else if (method == 'mobile' || method == 'transfer') {
        onlineMobile += amount;
      } else if (method == 'card' || method == 'debit' || method == 'credit card') {
        onlineCard += amount;
      } else if (method == 'credit') {
        creditSalesTotal += amount;
      }
    }

    // Get credit payments (recovery/partial) during shift
    final recoveryResults = await db.rawQuery('''
      SELECT SUM(amount) as total_recovery
      FROM credit_payments
      WHERE payment_date BETWEEN ? AND ?
      ${getBusinessFilter()}$branchFilter
    ''', args);

    final creditReceived = (recoveryResults.first['total_recovery'] as num?)?.toDouble() ?? 0.0;

    // Get total expenses during shift
    final expenseResults = await db.rawQuery('''
      SELECT SUM(amount) as total_expenses
      FROM expenses
      WHERE date BETWEEN ? AND ?
      ${getBusinessFilter()} AND status = 1$branchFilter
      ''', args);
    
    final totalExpenses = (expenseResults.first['total_expenses'] as num?)?.toDouble() ?? 0.0;

    // Get total purchases during shift
    final purchaseResults = await db.rawQuery('''
      SELECT SUM(total_amount) as total_purchases
      FROM purchases
      WHERE purchase_date BETWEEN ? AND ?
      ${getBusinessFilter()} AND status = 1$branchFilter
      ''', args);

    final totalPurchases = (purchaseResults.first['total_purchases'] as num?)?.toDouble() ?? 0.0;

    return {
      'cash_sales': cashSales,
      'mobile_sales': onlineMobile,
      'card_sales': onlineCard,
      'credit_sales_total': creditSalesTotal,
      'credit_received': creditReceived,
      'total_expenses': totalExpenses,
      'total_purchases': totalPurchases,
      'total_revenue': totalRevenue + creditReceived, // Total value processed
    };
  }

}
