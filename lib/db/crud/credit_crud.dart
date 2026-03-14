import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'common_crud.dart';

mixin CreditCrud on CommonCrud {

  // ========== Credit System ==========

  // Credit Sales
  Future<List<Map<String, dynamic>>> getCreditSales({dynamic customerId}) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();

    final baseArgs = [bid, aid, ...branchArgs];
    
    if (customerId != null) {
      return await db.rawQuery(
        'SELECT * FROM credit_sales WHERE customer_id = ? AND business_id = ? AND admin_id = ? AND status = 1$branchFilter ORDER BY created_at DESC',
        [customerId, ...baseArgs],
      );
    }
    return await db.rawQuery(
      'SELECT * FROM credit_sales WHERE business_id = ? AND admin_id = ? AND status = 1$branchFilter ORDER BY created_at DESC',
      baseArgs,
    );
  }

  Future<int> insertCreditSale(Map<String, dynamic> creditSale) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    return await db.insert('credit_sales', {
      ...creditSale,
      'business_id': bid,
      'admin_id': aid,
      'branch_id': creditSale['branch_id'] ?? getCurrentBranchId(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateCreditSale(dynamic id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update('credit_sales', data, where: 'id = ?', whereArgs: [id]);
  }

  // Credit Payments
  Future<List<Map<String, dynamic>>> getCreditPayments({dynamic customerId, dynamic creditSaleId}) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();

    final baseArgs = [bid, aid, ...branchArgs];
    
    if (creditSaleId != null) {
      return await db.rawQuery(
        'SELECT * FROM credit_payments WHERE credit_sale_id = ? AND business_id = ? AND admin_id = ?$branchFilter ORDER BY payment_date DESC',
        [creditSaleId, ...baseArgs],
      );
    }
    if (customerId != null) {
      return await db.rawQuery(
        'SELECT * FROM credit_payments WHERE customer_id = ? AND business_id = ? AND admin_id = ?$branchFilter ORDER BY payment_date DESC',
        [customerId, ...baseArgs],
      );
    }
    return await db.rawQuery(
      'SELECT * FROM credit_payments WHERE business_id = ? AND admin_id = ?$branchFilter ORDER BY payment_date DESC',
      baseArgs,
    );
  }

  Future<int> insertCreditPayment(Map<String, dynamic> payment) async {
    int insertedId = 0;
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    await db.transaction((txn) async {
      // 1. Insert payment record
      insertedId = await txn.insert('credit_payments', {
        ...payment,
        'business_id': bid,
        'admin_id': aid,
        'branch_id': payment['branch_id'] ?? getCurrentBranchId(),
        'is_synced': 0, // Ensure it's marked for sync
      });

      final customerId = payment['customer_id'];
      double amountLeftToApply = (payment['amount'] as num).toDouble();

      // 2. Update credit sale(s) remaining balance
      if (payment['credit_sale_id'] != null) {
        // Specific sale targeted
        await txn.rawUpdate(
          'UPDATE credit_sales SET remaining_balance = remaining_balance - ?, is_synced = 0 WHERE id = ?',
          [amountLeftToApply, payment['credit_sale_id']],
        );
      } else {
        // "Floating" payment: apply to oldest open credit sales for this customer IN THIS BRANCH
        final branchId = payment['branch_id'] ?? getCurrentBranchId();
        final List<Map<String, dynamic>> openSales = await txn.query(
          'credit_sales',
          where: 'customer_id = ? AND branch_id = ? AND remaining_balance > 0 AND status = 1',
          whereArgs: [customerId, branchId],
          orderBy: 'created_at ASC',
        );

        for (var sale in openSales) {
          if (amountLeftToApply <= 0) break;

          final saleId = sale['id'];
          final remaining = (sale['remaining_balance'] as num).toDouble();
          final applyAmount = amountLeftToApply > remaining ? remaining : amountLeftToApply;

          await txn.rawUpdate(
            'UPDATE credit_sales SET remaining_balance = remaining_balance - ?, is_synced = 0 WHERE id = ?',
            [applyAmount, saleId],
          );
          amountLeftToApply -= applyAmount;
        }
      }

      // 3. Update customer credit balance (Master source of truth for UI speed)
      final totalPaidAmount = (payment['amount'] as num).toDouble();
      await txn.rawUpdate(
        'UPDATE customers SET credit_balance = COALESCE(credit_balance, 0) - ?, is_synced = 0 WHERE id = ?',
        [totalPaidAmount, customerId],
      );
    });
    return insertedId;
  }

  // Get customer's total credit balance
  Future<double> getCustomerCreditBalance(dynamic customerId) async {
    final db = await database;
    final result = await db.query(
      'customers',
      columns: ['credit_balance'],
      where: 'id = ?',
      whereArgs: [customerId],
    );
    if (result.isNotEmpty) {
      return (result.first['credit_balance'] as num?)?.toDouble() ?? 0.0;
    }
    return 0.0;
  }

  // Get all customers with outstanding credit
  Future<List<Map<String, dynamic>>> getCustomersWithCredit() async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();

    final args = [bid, aid, ...branchArgs];

    return await db.rawQuery(
      'SELECT * FROM customers WHERE credit_balance > 0 AND business_id = ? AND admin_id = ? AND status = 1$branchFilter ORDER BY credit_balance DESC',
      args,
    );
  }

  // Update customer credit balance (used when creating credit sale)
  Future<void> updateCustomerCreditBalance(dynamic customerId, double amount) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE customers SET credit_balance = COALESCE(credit_balance, 0) + ? WHERE id = ?',
      [amount, customerId],
    );
  }

  // Reconcile all customer balances based on active credit sales
  Future<void> reconcileCustomerBalances([DatabaseExecutor? executor]) async {
    if (executor != null) {
      await _executeReconciliation(executor);
    } else {
      final db = await database;
      await db.transaction((txn) async {
        await _executeReconciliation(txn);
      });
    }
  }

  Future<void> _executeReconciliation(DatabaseExecutor txn) async {
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);

    // 1. Reset credit balances to 0 for current tenant
    if (bid != null && aid != null) {
      await txn.update(
        'customers', 
        {'credit_balance': 0}, 
        where: 'business_id = ? AND admin_id = ?', 
        whereArgs: [bid, aid]
      );
    } else {
      // If we don't have bid/aid, reset all (safety fallback for edge cases)
      await txn.update('customers', {'credit_balance': 0});
    }

    // 2. Aggregate remaining balances from credit_sales, filtered by branch if applicable
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final List<Map<String, dynamic>> results = await txn.rawQuery('''
      SELECT customer_id, SUM(remaining_balance) as calculated_balance
      FROM credit_sales
      WHERE status = 1 AND business_id = ? AND admin_id = ? $branchFilter
      GROUP BY customer_id
    ''', [bid, aid, ...branchArgs]);

    // 3. Update each customer with their calculated balance
    for (var row in results) {
      final customerId = row['customer_id'];
      final balance = (row['calculated_balance'] as num?)?.toDouble() ?? 0.0;
      if (customerId != null) {
        await txn.update(
          'customers',
          {'credit_balance': balance},
          where: 'id = ?',
          whereArgs: [customerId],
        );
      }
    }
  }

}
