import 'package:sqflite_sqlcipher/sqflite.dart';
import 'common_crud.dart';

mixin PurchasesCrud on CommonCrud {
  // Purchases
  Future<List<Map<String, dynamic>>> getPurchases() async {
    final db = await database;
    final branchFilter = getBranchFilter().replaceAll('branch_id', 'p.branch_id');
    final branchArgs = getBranchArgs();
    
    final args = [...getBusinessArgs(), ...branchArgs];

    return await db.rawQuery('''
      SELECT p.*, s.name as supplier_name 
      FROM purchases p
      LEFT JOIN suppliers s ON p.supplier_id = s.id
      WHERE p.status = 1${getBusinessFilter().replaceAll('business_id', 'p.business_id').replaceAll('admin_id', 'p.admin_id')}$branchFilter
      ORDER BY p.purchase_date DESC
    ''', args);
  }

  Future<int> insertPurchase(Map<String, dynamic> purchase, List<Map<String, dynamic>> items) async {
    final db = await database;
    final businessArgs = getBusinessArgs();
    final brid = purchase['branch_id'] ?? getCurrentBranchId();

    return await db.transaction((txn) async {
      final generatedPurchaseId = await txn.insert('purchases', {
        ...purchase,
        ...Map.fromIterables(['business_id', 'admin_id'], businessArgs),
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
        final prodResult = await txn.query(
          'products', 
          where: 'id = ?${getBusinessFilter()}', 
          whereArgs: [productId, ...businessArgs]
        );
        if (prodResult.isNotEmpty) {
          final p = prodResult.first;
          final oldCost = (p['purchase_price'] as num? ?? 0).toDouble();
          final oldSale = (p['price'] as num? ?? 0).toDouble();
          final oldWholesale = (p['wholesale_price'] as num? ?? 0).toDouble();

          // 2a. Search for an EXISTING product variant with the SAME NAME and SAME NEW PRICES
          // This prevents creating a brand new product entry for every purchase item.
          final productName = p['name'];
          final existingVariant = await txn.query('products', 
            where: 'name = ? AND ROUND(purchase_price, 2) = ROUND(?, 2) AND ROUND(price, 2) = ROUND(?, 2) AND ROUND(wholesale_price, 2) = ROUND(?, 2) AND status = 1${getBusinessFilter()}',
            whereArgs: [productName, newPurchasePrice, newSellingPrice, newWholesalePrice, ...businessArgs],
            limit: 1
          );

          if (existingVariant.isNotEmpty) {
            // MATCH FOUND -> Use this existing product ID
            productId = existingVariant.first['id'];
          } else if (newPurchasePrice != oldCost || newSellingPrice != oldSale || newWholesalePrice != oldWholesale) {
            // NO MATCH AND PRICE CHANGED -> Create a NEW product entry/variant
            final newProdMap = Map<String, dynamic>.from(p);
            newProdMap.remove('id'); 
            newProdMap['purchase_price'] = newPurchasePrice;
            newProdMap['price'] = newSellingPrice;
            newProdMap['wholesale_price'] = newWholesalePrice;
            
            // Reset stock counters for the new isolated variant
            newProdMap['stock_quantity'] = 0.0;
            newProdMap['is_synced'] = 0;
            newProdMap['updated_at'] = now;
            
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

        // 4. Manage Stock Batch
        // Check if we already have a stock record with this product ID and SAME PRICES
        final existingStock = await txn.query('stocks', 
          where: 'product_id = ? AND cost_price = ? AND sale_price = ? AND wholesale_price = ? AND branch_id = ? AND status = 1${getBusinessFilter()}',
          whereArgs: [productId, newPurchasePrice, newSellingPrice, newWholesalePrice, brid, ...businessArgs],
          orderBy: 'id DESC',
          limit: 1
        );

        if (existingStock.isNotEmpty) {
          // If price is NOT changed (or we matched the exact prices), just update quantity in existing stock entry
          final s = existingStock.first;
          final currentQty = (s['quantity'] as num).toDouble();
          await txn.update('stocks', {
            'quantity': currentQty + qtyToAdd,
            'is_synced': 1, 
            'updated_at': now,
          }, where: 'id = ?${getBusinessFilter()}', whereArgs: [s['id'], ...getBusinessArgs()]);
        } else {
          // If price IS changed (which resulted in a new productId or no matching price batch), create a NEW stock entry
          await txn.insert('stocks', {
            'id': null,
            ...Map.fromIterables(['business_id', 'admin_id'], businessArgs),
            'branch_id': brid,
            'product_id': productId,
            'barcode': item['barcode'],
            'quantity': qtyToAdd,
            'cost_price': newPurchasePrice,
            'sale_price': newSellingPrice,
            'wholesale_price': newWholesalePrice,
            'status': 1,
            'is_synced': 1, // DO NOT Sync absolute stock batch separately (it is handled by the purchase sync)
            'created_at': now,
            'updated_at': now,
          });
        }

        // 5. Update Denormalized Product Stock Total (Local Convenience)
        // We do NOT mark 'is_synced': 0 here because the actual inventory change 
        // is already represented in the 'purchase_items' and 'stocks' tables.
        // Marking the product as unsynced here causes the server to double-count 
        // the stock update from the product's denormalized total.
        final allStock = await txn.rawQuery(
          'SELECT SUM(quantity) as total FROM stocks WHERE product_id = ? AND branch_id = ?${getBusinessFilter()}',
          [productId, brid, ...getBusinessArgs()]
        );
        final newTotal = (allStock.first['total'] as num? ?? 0).toDouble();
        await txn.update('products', {
          'stock_quantity': newTotal,
          'updated_at': now,
          // 'is_synced': 0, // DO NOT Trigger redundant product sync for stock levels
        }, where: 'id = ?${getBusinessFilter()}', whereArgs: [productId, ...getBusinessArgs()]);
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
    }, where: 'id = ?${getBusinessFilter()}', whereArgs: [id, ...getBusinessArgs()]);
  }

}
