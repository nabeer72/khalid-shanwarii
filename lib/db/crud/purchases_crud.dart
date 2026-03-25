import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'common_crud.dart';

mixin PurchasesCrud on CommonCrud {
  // Purchases
  Future<List<Map<String, dynamic>>> getPurchases() async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    final branchFilter = getBranchFilter().replaceAll('branch_id', 'p.branch_id');
    final branchArgs = getBranchArgs();
    
    final args = [bid, aid, ...branchArgs];

    return await db.rawQuery('''
      SELECT p.*, s.name as supplier_name 
      FROM purchases p
      LEFT JOIN suppliers s ON p.supplier_id = s.id
      WHERE p.status = 1 AND p.business_id = ? AND p.admin_id = ?$branchFilter
      ORDER BY p.purchase_date DESC
    ''', args);
  }

  Future<int> insertPurchase(Map<String, dynamic> purchase, List<Map<String, dynamic>> items) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    final brid = purchase['branch_id'] ?? getCurrentBranchId();

    return await db.transaction((txn) async {
      final generatedPurchaseId = await txn.insert('purchases', {
        ...purchase,
        'business_id': bid,
        'admin_id': aid,
        'branch_id': brid,
        'is_synced': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final pid = purchase['id'] ?? generatedPurchaseId;

      // Insert Items and Update Inventory
      for (var item in items) {
        // 1. Insert Purchase Item
        final itemData = Map<String, dynamic>.from(item);
        itemData.remove('product_name'); // Remove UI-only field

        await txn.insert('purchase_items', {
          ...itemData,
          'purchase_id': pid,
          'branch_id': brid,
          'is_synced': 0,
        });

        // 2. Update Product Inventory & Prices (SMART STOCK UPDATE)
        final productId = item['product_id'];
        final qtyToAdd = (item['quantity'] as num).toDouble();
        final newPurchasePrice = (item['purchase_price'] as num).toDouble();
        final newSellingPrice = (item['selling_price'] as num).toDouble();
        final newWholesalePrice = (item['wholesale_price'] as num? ?? 0).toDouble();
        final now = DateTime.now().toIso8601String();

        // Check if a matching stock batch exists with the same EXACT prices IN THIS BRANCH
        final matchingStocks = await txn.rawQuery(
          '''SELECT * FROM stocks 
             WHERE product_id = ? AND branch_id = ? AND status = 1 
             AND CAST(cost_price AS REAL) = CAST(? AS REAL) 
             AND CAST(sale_price AS REAL) = CAST(? AS REAL) 
             AND CAST(wholesale_price AS REAL) = CAST(? AS REAL)
             ORDER BY created_at DESC LIMIT 1''',
          [productId, brid, newPurchasePrice, newSellingPrice, newWholesalePrice],
        );

        if (matchingStocks.isNotEmpty) {
          // Prices match an existing batch → just add quantity to THAT batch
          final matchingId = matchingStocks.first['id'];
          await txn.rawUpdate(
            'UPDATE stocks SET quantity = quantity + ?, is_synced = 0, updated_at = ? WHERE id = ?',
            [qtyToAdd, now, matchingId],
          );
        } else {
          // No match or prices changed → create a NEW stock batch
          await txn.insert('stocks', {
            'id': null,
            'business_id': bid,
            'branch_id': brid,
            'product_id': productId,
            'barcode': item['barcode'],
            'quantity': qtyToAdd,
            'cost_price': newPurchasePrice,
            'sale_price': newSellingPrice,
            'wholesale_price': newWholesalePrice,
            'status': 1,
            'is_synced': 0,
            'created_at': now,
            'updated_at': now,
          });
        }

        // Update the product's updated_at timestamp
        await txn.update(
          'products', 
          {
            'updated_at': now,
            'is_synced': 0,
          },
          where: 'id = ?',
          whereArgs: [productId]
        );
      }
      return pid;
    });
  }

  Future<List<Map<String, dynamic>>> getPurchaseItems(dynamic purchaseId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT pi.*, p.name as product_name 
      FROM purchase_items pi
      LEFT JOIN products p ON pi.product_id = p.id
      WHERE pi.purchase_id = ?
    ''', [purchaseId]);
  }

  Future<void> deletePurchase(dynamic id) async {
    final db = await database;
    await db.update('purchases', {
      'status': 0,
      'is_synced': 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }

}
