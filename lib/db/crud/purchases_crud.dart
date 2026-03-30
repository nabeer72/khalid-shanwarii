import 'package:sqflite_sqlcipher/sqflite.dart';
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

      for (var item in items) {
        // 2. Separate Product Entry for Price Changes
        var productId = item['product_id'];
        final qtyToAdd = (item['quantity'] as num).toDouble();
        final newPurchasePrice = (item['purchase_price'] as num).toDouble();
        final newSellingPrice = (item['selling_price'] as num).toDouble();
        final newWholesalePrice = (item['wholesale_price'] as num? ?? 0).toDouble();
        final now = DateTime.now().toIso8601String();

        // Check if price changed compared to master record
        final prodResult = await txn.query('products', where: 'id = ?', whereArgs: [productId]);
        if (prodResult.isNotEmpty) {
          final p = prodResult.first;
          final oldCost = (p['purchase_price'] as num? ?? 0).toDouble();
          final oldSale = (p['price'] as num? ?? 0).toDouble();
          final oldWholesale = (p['wholesale_price'] as num? ?? 0).toDouble();

          // If ANY price has changed, create a NEW product entry in the product table
          // This ensures the live database also shows multiple entries of the same product with different prices.
          if (newPurchasePrice != oldCost || newSellingPrice != oldSale || newWholesalePrice != oldWholesale) {
            final newProdMap = Map<String, dynamic>.from(p);
            newProdMap.remove('id'); // Let it autoincrement for a separate entry
            newProdMap['purchase_price'] = newPurchasePrice;
            newProdMap['price'] = newSellingPrice;
            newProdMap['wholesale_price'] = newWholesalePrice;
            newProdMap['is_synced'] = 0;
            newProdMap['updated_at'] = now;
            // newProdMap['created_at'] = now; // optional if adding created_at to schema later
            
            productId = await txn.insert('products', newProdMap);
          }
        }

        // 3. Insert Purchase Item (Linked to potentially new productId)
        final itemData = Map<String, dynamic>.from(item);
        itemData.remove('product_name');
        await txn.insert('purchase_items', {
          ...itemData,
          'product_id': productId,
          'purchase_id': pid,
          'branch_id': brid,
          'is_synced': 0,
        });

        // 4. Create Stock Batch entry (Always separate)
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
