import 'package:sqflite/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'common_crud.dart';

mixin PurchasesCrud on CommonCrud {
  // Purchases
  Future<List<Map<String, dynamic>>> getPurchases() async {
    final db = await database;
    final bid = BusinessConfig.instance.businessId;
    final aid = BusinessConfig.instance.adminId;
    
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

  Future<void> insertPurchase(Map<String, dynamic> purchase, List<Map<String, dynamic>> items) async {
    final db = await database;
    final bid = BusinessConfig.instance.businessId;
    final aid = BusinessConfig.instance.adminId;
    final brid = purchase['branch_id'] ?? getCurrentBranchId();
    const uuid = Uuid();

    await db.transaction((txn) async {
      await txn.insert('purchases', {
        ...purchase,
        'business_id': bid,
        'admin_id': aid,
        'branch_id': brid,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Insert Items and Update Inventory
      for (var item in items) {
        // 1. Insert Purchase Item
        final itemData = Map<String, dynamic>.from(item);
        itemData.remove('product_name'); // Remove UI-only field

        await txn.insert('purchase_items', {
          ...itemData,
          'purchase_id': purchase['id'],
          'branch_id': brid,
        });

        // 2. Update Product Inventory & Prices (SMART STOCK UPDATE)
        final productId = item['product_id'];
        final qtyToAdd = (item['quantity'] as num).toDouble();
        final newPurchasePrice = (item['purchase_price'] as num).toDouble();
        final newSellingPrice = (item['selling_price'] as num).toDouble();
        final newWholesalePrice = (item['wholesale_price'] as num? ?? 0).toDouble();
        final now = DateTime.now().toIso8601String();

        // Check if a matching stock batch exists with the same prices IN THIS BRANCH
        final existingStocks = await txn.rawQuery(
          '''SELECT * FROM stocks 
             WHERE product_id = ? AND branch_id = ? AND status = 1 
             ORDER BY created_at DESC LIMIT 1''',
          [productId, brid],
        );

        bool pricesChanged = true;
        if (existingStocks.isNotEmpty) {
          final latest = existingStocks.first;
          final oldCost = (latest['cost_price'] as num? ?? 0).toDouble();
          final oldSale = (latest['sale_price'] as num? ?? 0).toDouble();
          final oldWholesale = (latest['wholesale_price'] as num? ?? 0).toDouble();
          
          pricesChanged = (oldCost != newPurchasePrice) || 
                          (oldSale != newSellingPrice) || 
                          (oldWholesale != newWholesalePrice);
        }

        if (pricesChanged || existingStocks.isEmpty) {
          // Prices changed → create a NEW stock batch
          final stockId = uuid.v4();
          await txn.insert('stocks', {
            'id': stockId,
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
        } else {
          // Prices unchanged → just add quantity to existing batch
          final latestId = existingStocks.first['id'];
          await txn.rawUpdate(
            'UPDATE stocks SET quantity = quantity + ?, is_synced = 0, updated_at = ? WHERE id = ?',
            [qtyToAdd, now, latestId],
          );
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
    });
  }

  Future<List<Map<String, dynamic>>> getPurchaseItems(String purchaseId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT pi.*, p.name as product_name 
      FROM purchase_items pi
      LEFT JOIN products p ON pi.product_id = p.id
      WHERE pi.purchase_id = ?
    ''', [purchaseId]);
  }

  Future<void> deletePurchase(String id) async {
    final db = await database;
    await db.update('purchases', {
      'status': 0,
      'is_synced': 0,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }

}
