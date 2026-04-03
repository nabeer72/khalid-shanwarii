import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'common_crud.dart';

mixin SuppliersCrud on CommonCrud {
  // Suppliers
  Future<List<Map<String, dynamic>>> getSuppliers() async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final args = [...getBusinessArgs(), ...branchArgs];

    return await db.rawQuery(
      'SELECT * FROM suppliers WHERE status = 1${getBusinessFilter()}$branchFilter ORDER BY name ASC',
      args,
    );
  }

  Future<void> insertSupplier(Map<String, dynamic> supplier) async {
    final db = await database;
    await db.insert('suppliers', {
      ...supplier,
      ...Map.fromIterables(['business_id', 'admin_id'], getBusinessArgs()),
      'branch_id': supplier['branch_id'] ?? getCurrentBranchId(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSupplier(dynamic id) async {
    final db = await database;
    await db.update(
      'suppliers', 
      {'status': 0}, 
      where: 'id = ?${getBusinessFilter()}', 
      whereArgs: [id, ...getBusinessArgs()]
    );
  }

  // ========== Supplier Payback Operations ==========

  Future<List<Map<String, dynamic>>> getSuppliersWithCredit() async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();

    final args = [...getBusinessArgs(), ...branchArgs];

    return await db.rawQuery(
      'SELECT * FROM suppliers WHERE credit_balance > 0 AND status = 1${getBusinessFilter()}$branchFilter ORDER BY credit_balance DESC',
      args,
    );
  }

  Future<List<Map<String, dynamic>>> getSupplierCreditPurchases({dynamic supplierId, dynamic purchaseId}) async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();

    final baseArgs = [...getBusinessArgs(), ...branchArgs];

    if (purchaseId != null) {
      return await db.rawQuery(
        'SELECT * FROM supplier_credit_purchases WHERE purchase_id = ?${getBusinessFilter()} AND status = 1$branchFilter',
        [purchaseId, ...baseArgs],
      );
    }
    if (supplierId != null) {
      return await db.rawQuery(
        'SELECT * FROM supplier_credit_purchases WHERE supplier_id = ?${getBusinessFilter()} AND status = 1$branchFilter ORDER BY created_at DESC',
        [supplierId, ...baseArgs],
      );
    }
    return await db.rawQuery(
      'SELECT * FROM supplier_credit_purchases WHERE status = 1${getBusinessFilter()}$branchFilter ORDER BY created_at DESC',
      baseArgs,
    );
  }

  Future<void> insertSupplierCreditPurchase(Map<String, dynamic> creditPurchase) async {
    final db = await database;
    await db.insert('supplier_credit_purchases', {
      ...creditPurchase,
      ...Map.fromIterables(['business_id', 'admin_id'], getBusinessArgs()),
      'branch_id': creditPurchase['branch_id'] ?? getCurrentBranchId(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getSupplierPaybacks({dynamic supplierId, dynamic creditPurchaseId}) async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();

    final baseArgs = [...getBusinessArgs(), ...branchArgs];

    if (creditPurchaseId != null) {
      return await db.rawQuery(
        'SELECT * FROM supplier_paybacks WHERE supplier_credit_purchase_id = ?${getBusinessFilter()}$branchFilter ORDER BY payment_date DESC',
        [creditPurchaseId, ...baseArgs],
      );
    }
    if (supplierId != null) {
      return await db.rawQuery(
        'SELECT * FROM supplier_paybacks WHERE supplier_id = ?${getBusinessFilter()}$branchFilter ORDER BY payment_date DESC',
        [supplierId, ...baseArgs],
      );
    }
    return await db.rawQuery(
      'SELECT * FROM supplier_paybacks WHERE 1=1${getBusinessFilter()}$branchFilter ORDER BY payment_date DESC',
      baseArgs,
    );
  }

  Future<void> insertSupplierPayback(Map<String, dynamic> payback) async {
    final db = await database;
    // ignore: unused_local_variable
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    // ignore: unused_local_variable
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    await db.transaction((txn) async {
      await txn.insert('supplier_paybacks', {
        ...payback,
        ...Map.fromIterables(['business_id', 'admin_id'], getBusinessArgs()),
        'branch_id': payback['branch_id'] ?? getCurrentBranchId(),
        'is_synced': 0,
      });

      double amountLeftToApply = (payback['amount'] as num).toDouble();

      if (payback['supplier_credit_purchase_id'] != null) {
        // Specific purchase targeted
        await txn.rawUpdate(
          'UPDATE supplier_credit_purchases SET remaining_balance = remaining_balance - ?, is_synced = 0 WHERE id = ?${getBusinessFilter()}',
          [amountLeftToApply, payback['supplier_credit_purchase_id'], ...getBusinessArgs()],
        );
      } else {
        // "Floating" payback: apply to oldest open credit purchases for this supplier IN THIS BRANCH
        final supplierId = payback['supplier_id'];
        final branchId = payback['branch_id'] ?? getCurrentBranchId();
        
        final List<Map<String, dynamic>> openPurchases = await txn.query(
          'supplier_credit_purchases',
          where: 'supplier_id = ? AND branch_id = ? AND remaining_balance > 0 AND status = 1${getBusinessFilter()}',
          whereArgs: [supplierId, branchId, ...getBusinessArgs()],
          orderBy: 'created_at ASC',
        );

        for (var purchase in openPurchases) {
          if (amountLeftToApply <= 0) break;

          final purchaseId = purchase['id'];
          final remaining = (purchase['remaining_balance'] as num).toDouble();
          final applyAmount = amountLeftToApply > remaining ? remaining : amountLeftToApply;

          await txn.rawUpdate(
            'UPDATE supplier_credit_purchases SET remaining_balance = remaining_balance - ?, is_synced = 0 WHERE id = ?${getBusinessFilter()}',
            [applyAmount, purchaseId, ...getBusinessArgs()],
          );
          amountLeftToApply -= applyAmount;
        }
      }

      final totalPaybackAmount = (payback['amount'] as num).toDouble();
      await txn.rawUpdate(
        'UPDATE suppliers SET credit_balance = COALESCE(credit_balance, 0) - ?, is_synced = 0 WHERE id = ? ${getBusinessFilter()}',
        [totalPaybackAmount, payback['supplier_id'], ...getBusinessArgs()],
      );
    });
  }

  Future<void> updateSupplierCreditBalance(dynamic supplierId, double amount) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE suppliers SET credit_balance = COALESCE(credit_balance, 0) + ?, is_synced = 0 WHERE id = ?${getBusinessFilter()}',
      [amount, supplierId, ...getBusinessArgs()],
    );
  }

  Future<double> getSupplierCreditBalance(dynamic supplierId) async {
    final db = await database;
    final res = await db.query(
      'suppliers', 
      columns: ['credit_balance'], 
      where: 'id = ?${getBusinessFilter()}', 
      whereArgs: [supplierId, ...getBusinessArgs()]
    );
    if (res.isNotEmpty) {
      return (res.first['credit_balance'] as num?)?.toDouble() ?? 0.0;
    }
    return 0.0;
  }

  // Reconcile all supplier balances based on active credit purchases
  Future<void> reconcileSupplierBalances([DatabaseExecutor? executor]) async {
    if (executor != null) {
      await _executeSupplierReconciliation(executor);
    } else {
      final db = await database;
      await db.transaction((txn) async {
        await _executeSupplierReconciliation(txn);
      });
    }
  }

  Future<void> _executeSupplierReconciliation(DatabaseExecutor txn) async {
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);

    // 1. Reset credit balances to 0 for current tenant
    if (bid != null && aid != null) {
      await txn.update(
        'suppliers', 
        {'credit_balance': 0}, 
        where: 'business_id = ? AND admin_id = ?', 
        whereArgs: [bid, aid]
      );
    } else {
      await txn.update('suppliers', {'credit_balance': 0});
    }

    // 2. Aggregate remaining balances from supplier_credit_purchases AND add opening_amount
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    final businessArgs = getBusinessArgs();

    List<Map<String, dynamic>> results = [];
    try {
      // Try query with opening_amount (requires v50 schema)
      results = await txn.rawQuery('''
        SELECT s.id as supplier_id, (SUM(IFNULL(scp.remaining_balance, 0)) + IFNULL(s.opening_amount, 0)) as calculated_balance
        FROM suppliers s
        LEFT JOIN supplier_credit_purchases scp ON s.id = scp.supplier_id AND scp.status = 1
        WHERE s.status = 1${getBusinessFilter().replaceAll('business_id', 's.business_id').replaceAll('admin_id', 's.admin_id')} $branchFilter
        GROUP BY s.id
      ''', [...businessArgs, ...branchArgs]);
    } catch (_) {
      // Fallback: opening_amount column not yet migrated — only sum credit purchases
      results = await txn.rawQuery('''
        SELECT supplier_id, SUM(remaining_balance) as calculated_balance
        FROM supplier_credit_purchases
        WHERE status = 1${getBusinessFilter()} $branchFilter
        GROUP BY supplier_id
      ''', [...businessArgs, ...branchArgs]);
    }

    // 3. Update each supplier with their calculated balance
    for (var row in results) {
      final supplierId = row['supplier_id'];
      final balance = (row['calculated_balance'] as num?)?.toDouble() ?? 0.0;
      if (supplierId != null) {
        await txn.update(
          'suppliers',
          {'credit_balance': balance},
          where: 'id = ?${getBusinessFilter()}',
          whereArgs: [supplierId, ...getBusinessArgs()],
        );
      }
    }
  }

}
