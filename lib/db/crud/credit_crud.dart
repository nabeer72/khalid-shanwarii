import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import '../database_helper.dart';
import 'common_crud.dart';

mixin CreditCrud on CommonCrud {

  // ========== Credit System ==========

  // Credit Sales
  Future<List<Map<String, dynamic>>> getCreditSales({dynamic customerId}) async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();

    final baseArgs = [...getBusinessArgs(), ...branchArgs];
    
    if (customerId != null) {
      return await db.rawQuery(
        'SELECT * FROM credit_sales WHERE customer_id = ? ${getBusinessFilter()} AND status = 1$branchFilter ORDER BY created_at DESC',
        [customerId, ...baseArgs],
      );
    }
    return await db.rawQuery(
      'SELECT * FROM credit_sales WHERE 1=1 ${getBusinessFilter()} AND status = 1$branchFilter ORDER BY created_at DESC',
      baseArgs,
    );
  }

  Future<int> insertCreditSale(Map<String, dynamic> creditSale) async {
    final db = await database;
    final result = await db.insert('credit_sales', {
      ...creditSale,
      ...Map.fromIterables(['business_id', 'user_id'], getBusinessArgs()),
      'branch_id': creditSale['branch_id'] ?? getCurrentBranchId(),
      'is_synced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    
    DatabaseHelper.notifyDataChanged();
    return result;
  }

  Future<void> updateCreditSale(dynamic id, Map<String, dynamic> data) async {
    final db = await database;
    await db.update(
      'credit_sales', 
      data, 
      where: 'id = ?${getBusinessFilter()}', 
      whereArgs: [id, ...getBusinessArgs()]
    );
  }

  // Credit Payments
  Future<List<Map<String, dynamic>>> getCreditPayments({dynamic customerId, dynamic creditSaleId}) async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();

    final baseArgs = [...getBusinessArgs(), ...branchArgs];
    
    if (creditSaleId != null) {
      return await db.rawQuery(
        'SELECT * FROM credit_payments WHERE credit_sale_id = ?${getBusinessFilter()}$branchFilter ORDER BY payment_date DESC',
        [creditSaleId, ...baseArgs],
      );
    }
    if (customerId != null) {
      return await db.rawQuery(
        'SELECT * FROM credit_payments WHERE customer_id = ?${getBusinessFilter()}$branchFilter ORDER BY payment_date DESC',
        [customerId, ...baseArgs],
      );
    }
    return await db.rawQuery(
      'SELECT * FROM credit_payments WHERE 1=1${getBusinessFilter()}$branchFilter ORDER BY payment_date DESC',
      baseArgs,
    );
  }

  Future<int> insertCreditPayment(Map<String, dynamic> payment) async {
    int insertedId = 0;
    final db = await database;
    // ignore: unused_local_variable
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    // ignore: unused_local_variable
    final uid = getSafeInt(BusinessConfig.instance.userId);
    
    await db.transaction((txn) async {
      final customerId = payment['customer_id'];
      double amountLeftToApply = (payment['amount'] as num).toDouble();

      // 2. Update credit sale(s) remaining balance & Insert payment records
      if (payment['credit_sale_id'] != null) {
        // Specific sale targeted
        insertedId = await txn.insert('credit_payments', {
          ...payment,
          ...Map.fromIterables(['business_id', 'user_id'], getBusinessArgs()),
          'branch_id': payment['branch_id'] ?? getCurrentBranchId(),
          'is_synced': 0,
        });

        await txn.rawUpdate(
          'UPDATE credit_sales SET remaining_balance = remaining_balance - ?, is_synced = 0 WHERE id = ?${getBusinessFilter()}',
          [amountLeftToApply, payment['credit_sale_id'], ...getBusinessArgs()],
        );
      } else {
        // "Floating" payment: apply to oldest open credit sales for this customer IN THIS BRANCH
        final branchId = payment['branch_id'] ?? getCurrentBranchId();
        final List<Map<String, dynamic>> openSales = await txn.query(
          'credit_sales',
          where: 'customer_id = ? AND branch_id = ? AND remaining_balance > 0 AND status = 1${getBusinessFilter()}',
          whereArgs: [customerId, branchId, ...getBusinessArgs()],
          orderBy: 'created_at ASC',
        );

        for (var sale in openSales) {
          if (amountLeftToApply <= 0) break;

          final saleId = sale['id'];
          final remaining = (sale['remaining_balance'] as num).toDouble();
          final applyAmount = amountLeftToApply > remaining ? remaining : amountLeftToApply;

          // Insert specific payment record for this portion
          final portionPayment = Map<String, dynamic>.from(payment);
          portionPayment['amount'] = applyAmount;
          portionPayment['credit_sale_id'] = saleId;

          insertedId = await txn.insert('credit_payments', {
            ...portionPayment,
            ...Map.fromIterables(['business_id', 'user_id'], getBusinessArgs()),
            'branch_id': payment['branch_id'] ?? getCurrentBranchId(),
            'is_synced': 0,
          });

          await txn.rawUpdate(
            'UPDATE credit_sales SET remaining_balance = remaining_balance - ?, is_synced = 0 WHERE id = ?${getBusinessFilter()}',
            [applyAmount, saleId, ...getBusinessArgs()],
          );
          
          amountLeftToApply -= applyAmount;
        }

        // If for some reason there's still amount left, keep it as floating
        if (amountLeftToApply > 0) {
          final remainderPayment = Map<String, dynamic>.from(payment);
          remainderPayment['amount'] = amountLeftToApply;
          insertedId = await txn.insert('credit_payments', {
            ...remainderPayment,
            ...Map.fromIterables(['business_id', 'user_id'], getBusinessArgs()),
            'branch_id': payment['branch_id'] ?? getCurrentBranchId(),
            'is_synced': 0,
          });
        }
      }

      // 3. Update customer credit balance (Master source of truth for UI speed)
      final totalPaidAmount = (payment['amount'] as num).toDouble();
      await txn.rawUpdate(
        'UPDATE customers SET credit_balance = COALESCE(credit_balance, 0) - ?, is_synced = 0 WHERE id = ?${getBusinessFilter()}',
        [totalPaidAmount, customerId, ...getBusinessArgs()],
      );
    });
    
    DatabaseHelper.notifyDataChanged();
    return insertedId;
  }

  Future<void> updateCreditPayment(int paymentId, Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Get the old payment record
      final List<Map<String, dynamic>> oldRecords = await txn.query(
        'credit_payments',
        where: 'id = ?${getBusinessFilter()}',
        whereArgs: [paymentId, ...getBusinessArgs()],
      );
      if (oldRecords.isEmpty) return;
      final old = oldRecords.first;
      final double oldAmount = (old['amount'] as num).toDouble();
      final int customerId = old['customer_id'];
      final int? saleId = old['credit_sale_id'];

      // 2. Revert the old amount
      if (saleId != null) {
        await txn.rawUpdate(
          'UPDATE credit_sales SET remaining_balance = remaining_balance + ?, is_synced = 0 WHERE id = ?${getBusinessFilter()}',
          [oldAmount, saleId, ...getBusinessArgs()],
        );
      }
      await txn.rawUpdate(
        'UPDATE customers SET credit_balance = COALESCE(credit_balance, 0) + ?, is_synced = 0 WHERE id = ?${getBusinessFilter()}',
        [oldAmount, customerId, ...getBusinessArgs()],
      );

      // 3. Apply the new amount
      final double newAmount = (data['amount'] as num).toDouble();
      if (saleId != null) {
        await txn.rawUpdate(
          'UPDATE credit_sales SET remaining_balance = remaining_balance - ?, is_synced = 0 WHERE id = ?${getBusinessFilter()}',
          [newAmount, saleId, ...getBusinessArgs()],
        );
      }
      await txn.rawUpdate(
        'UPDATE customers SET credit_balance = COALESCE(credit_balance, 0) - ?, is_synced = 0 WHERE id = ?${getBusinessFilter()}',
        [newAmount, customerId, ...getBusinessArgs()],
      );

      // 4. Update the payment record
      await txn.update(
        'credit_payments', 
        {
          ...data,
          'is_synced': 0,
          'updated_at': DateTime.now().toIso8601String(),
        }, 
        where: 'id = ?', 
        whereArgs: [paymentId]
      );
    });
    DatabaseHelper.notifyDataChanged();
  }

  Future<void> deleteCreditPayment(int paymentId) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Get the payment record
      final List<Map<String, dynamic>> payments = await txn.query(
        'credit_payments',
        where: 'id = ?${getBusinessFilter()}',
        whereArgs: [paymentId, ...getBusinessArgs()],
      );
      if (payments.isEmpty) return;
      final payment = payments.first;
      final double amount = (payment['amount'] as num).toDouble();
      final int customerId = payment['customer_id'];
      final int? saleId = payment['credit_sale_id'];

      // 2. Reverse effect on credit_sales if applicable
      if (saleId != null) {
        await txn.rawUpdate(
          'UPDATE credit_sales SET remaining_balance = remaining_balance + ?, is_synced = 0 WHERE id = ?${getBusinessFilter()}',
          [amount, saleId, ...getBusinessArgs()],
        );
      }

      // 3. Reverse effect on customer balance
      await txn.rawUpdate(
        'UPDATE customers SET credit_balance = COALESCE(credit_balance, 0) + ?, is_synced = 0 WHERE id = ?${getBusinessFilter()}',
        [amount, customerId, ...getBusinessArgs()],
      );

      // 4. Delete the record
      await txn.delete('credit_payments', where: 'id = ?${getBusinessFilter()}', whereArgs: [paymentId, ...getBusinessArgs()]);
    });
    DatabaseHelper.notifyDataChanged();
  }

  // Get customer's total credit balance
  Future<double> getCustomerCreditBalance(dynamic customerId) async {
    final db = await database;
    final result = await db.query(
      'customers',
      columns: ['credit_balance'],
      where: 'id = ?${getBusinessFilter()}',
      whereArgs: [customerId, ...getBusinessArgs()],
    );
    if (result.isNotEmpty) {
      return (result.first['credit_balance'] as num?)?.toDouble() ?? 0.0;
    }
    return 0.0;
  }

  // Get all customers with outstanding credit
  Future<List<Map<String, dynamic>>> getCustomersWithCredit() async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();

    final args = [...getBusinessArgs(), ...branchArgs];

    return await db.rawQuery(
      'SELECT * FROM customers WHERE COALESCE(credit_balance, 0) > 0${getBusinessFilter()} AND status = 1$branchFilter ORDER BY credit_balance DESC',
      args,
    );
  }

  Future<List<Map<String, dynamic>>> getCreditPaymentsWithCustomer() async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    final businessArgs = getBusinessArgs();
    
    final bid = businessArgs[0];
    final uid = businessArgs[1];
    
    String bFilter = branchFilter.replaceAll('branch_id', 'cp.branch_id');

    return await db.rawQuery('''
      SELECT cp.*, c.name as customer_name, c.phone as customer_phone
      FROM credit_payments cp
      JOIN customers c ON cp.customer_id = c.id
      WHERE cp.business_id = ? AND cp.user_id = ? $bFilter
      ORDER BY cp.payment_date DESC
    ''', [bid, uid, ...branchArgs]);
  }

  // Update customer credit balance (used when creating credit sale)
  Future<void> updateCustomerCreditBalance(dynamic customerId, double amount) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE customers SET credit_balance = COALESCE(credit_balance, 0) + ?, is_synced = 0 WHERE id = ?${getBusinessFilter()}',
      [amount, customerId, ...getBusinessArgs()],
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
    // ignore: unused_local_variable
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    // ignore: unused_local_variable
    final uid = getSafeInt(BusinessConfig.instance.userId);

    // 1. Reset credit balances to 0 for current tenant
    final businessArgs = getBusinessArgs();
    final hasContext = businessArgs.every((arg) => arg != null);
    
    if (hasContext) {
      await txn.update(
        'customers', 
        {'credit_balance': 0}, 
        where: '1=1${getBusinessFilter()}', 
        whereArgs: businessArgs
      );
    } else {
      // If we don't have bId/uId context yet (e.g. during initial sync),
      // reset all customers on the device to avoid crashing.
      await txn.update('customers', {'credit_balance': 0});
    }

    // 2. Aggregate remaining balances from credit_sales, filtered by branch if applicable
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final List<Map<String, dynamic>> results = await txn.rawQuery('''
      SELECT customer_id, SUM(remaining_balance) as calculated_balance
      FROM credit_sales
      WHERE status = 1${hasContext ? getBusinessFilter() : ''} $branchFilter
      GROUP BY customer_id
    ''', [...(hasContext ? businessArgs : []), ...branchArgs]);

    // 3. Update each customer with their calculated balance
    for (var row in results) {
      final customerId = row['customer_id'];
      final balance = (row['calculated_balance'] as num?)?.toDouble() ?? 0.0;
      if (customerId != null) {
        await txn.update(
          'customers',
          {'credit_balance': balance},
          where: 'id = ?${hasContext ? getBusinessFilter() : ''}',
          whereArgs: [customerId, ...(hasContext ? businessArgs : [])],
        );
      }
    }
  }

}
