import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'common_crud.dart';

mixin SuppliersCrud on CommonCrud {
  // Suppliers
  Future<List<Map<String, dynamic>>> getSuppliers() async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final args = [bid, aid, ...branchArgs];

    return await db.rawQuery(
      'SELECT * FROM suppliers WHERE status = 1 AND business_id = ? AND admin_id = ?$branchFilter ORDER BY name ASC',
      args,
    );
  }

  Future<void> insertSupplier(Map<String, dynamic> supplier) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    await db.insert('suppliers', {
      ...supplier,
      'business_id': bid,
      'admin_id': aid,
      'branch_id': supplier['branch_id'] ?? getCurrentBranchId(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSupplier(dynamic id) async {
    final db = await database;
    await db.update('suppliers', {'status': 0}, where: 'id = ?', whereArgs: [id]);
  }

  // ========== Supplier Payback Operations ==========

  Future<List<Map<String, dynamic>>> getSuppliersWithCredit() async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();

    final args = [bid, aid, ...branchArgs];

    return await db.rawQuery(
      'SELECT * FROM suppliers WHERE credit_balance > 0 AND status = 1 AND business_id = ? AND admin_id = ?$branchFilter ORDER BY credit_balance DESC',
      args,
    );
  }

  Future<List<Map<String, dynamic>>> getSupplierCreditPurchases({dynamic supplierId, dynamic purchaseId}) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();

    final baseArgs = [bid, aid, ...branchArgs];

    if (purchaseId != null) {
      return await db.rawQuery(
        'SELECT * FROM supplier_credit_purchases WHERE purchase_id = ? AND business_id = ? AND admin_id = ? AND status = 1$branchFilter',
        [purchaseId, ...baseArgs],
      );
    }
    if (supplierId != null) {
      return await db.rawQuery(
        'SELECT * FROM supplier_credit_purchases WHERE supplier_id = ? AND business_id = ? AND admin_id = ? AND status = 1$branchFilter ORDER BY created_at DESC',
        [supplierId, ...baseArgs],
      );
    }
    return await db.rawQuery(
      'SELECT * FROM supplier_credit_purchases WHERE business_id = ? AND admin_id = ? AND status = 1$branchFilter ORDER BY created_at DESC',
      baseArgs,
    );
  }

  Future<void> insertSupplierCreditPurchase(Map<String, dynamic> creditPurchase) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    await db.insert('supplier_credit_purchases', {
      ...creditPurchase,
      'business_id': bid,
      'admin_id': aid,
      'branch_id': creditPurchase['branch_id'] ?? getCurrentBranchId(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getSupplierPaybacks({dynamic supplierId, dynamic creditPurchaseId}) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();

    final baseArgs = [bid, aid, ...branchArgs];

    if (creditPurchaseId != null) {
      return await db.rawQuery(
        'SELECT * FROM supplier_paybacks WHERE supplier_credit_purchase_id = ? AND business_id = ? AND admin_id = ?$branchFilter ORDER BY payment_date DESC',
        [creditPurchaseId, ...baseArgs],
      );
    }
    if (supplierId != null) {
      return await db.rawQuery(
        'SELECT * FROM supplier_paybacks WHERE supplier_id = ? AND business_id = ? AND admin_id = ?$branchFilter ORDER BY payment_date DESC',
        [supplierId, ...baseArgs],
      );
    }
    return await db.rawQuery(
      'SELECT * FROM supplier_paybacks WHERE business_id = ? AND admin_id = ?$branchFilter ORDER BY payment_date DESC',
      baseArgs,
    );
  }

  Future<void> insertSupplierPayback(Map<String, dynamic> payback) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    await db.transaction((txn) async {
      await txn.insert('supplier_paybacks', {
        ...payback,
        'business_id': bid,
        'admin_id': aid,
        'branch_id': payback['branch_id'] ?? getCurrentBranchId(),
        'is_synced': 0,
      });

      if (payback['supplier_credit_purchase_id'] != null) {
        await txn.rawUpdate(
          'UPDATE supplier_credit_purchases SET remaining_balance = remaining_balance - ?, is_synced = 0 WHERE id = ?',
          [payback['amount'], payback['supplier_credit_purchase_id']],
        );
      }

      await txn.rawUpdate(
        'UPDATE suppliers SET credit_balance = credit_balance - ?, is_synced = 0 WHERE id = ?',
        [payback['amount'], payback['supplier_id']],
      );
    });
  }

  Future<void> updateSupplierCreditBalance(dynamic supplierId, double amount) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE suppliers SET credit_balance = COALESCE(credit_balance, 0) + ? WHERE id = ?',
      [amount, supplierId],
    );
  }

  Future<double> getSupplierCreditBalance(dynamic supplierId) async {
    final db = await database;
    final res = await db.query('suppliers', columns: ['credit_balance'], where: 'id = ?', whereArgs: [supplierId]);
    if (res.isNotEmpty) {
      return (res.first['credit_balance'] as num?)?.toDouble() ?? 0.0;
    }
    return 0.0;
  }

}
