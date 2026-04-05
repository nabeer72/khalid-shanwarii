import 'package:sqflite_sqlcipher/sqflite.dart';
import '../database_helper.dart';
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

    final result = await db.transaction((txn) async {
      final generatedPurchaseId = await txn.insert('purchases', {
        ...purchase,
        ...Map.fromIterables(['business_id', 'admin_id'], businessArgs),
        'branch_id': brid,
        'is_synced': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final pid = purchase['id'] ?? generatedPurchaseId;

      for (var item in items) {
        // 2. [ALWAYS CREATE NEW PRODUCT ENTRY] as per user request
        var productId = item['product_id'];
        final productName = item['product_name'] ?? 'Unknown Item';
        final qtyToAdd = (item['quantity'] as num).toDouble();
        final newPurchasePrice = (item['purchase_price'] as num).toDouble();
        final newSellingPrice = (item['selling_price'] as num).toDouble();
        final newWholesalePrice = (item['wholesale_price'] as num? ?? 0).toDouble();
        final barcode = item['barcode'];
        final now = DateTime.now().toIso8601String();

        // 2a. Fetch template data if it's an existing product, or use defaults
        final prodResult = productId != null ? await txn.query(
          'products', 
          where: 'id = ?${getBusinessFilter()}', 
          whereArgs: [productId, ...businessArgs]
        ) : [];

        Map<String, dynamic> newProdMap;
        if (prodResult.isNotEmpty) {
          // CLONE existing product metadata but refresh prices and reset stock
          newProdMap = Map<String, dynamic>.from(prodResult.first);
          newProdMap.remove('id');
        } else {
          // BRAND NEW PRODUCT - Setup basic metadata
          newProdMap = {
            ...Map.fromIterables(['business_id', 'admin_id'], businessArgs),
            'branch_id': brid,
            'name': productName,
            'barcode': barcode,
            'category_id': item['category_id'] ?? 1, // Fallback to category 1
            'sku': barcode ?? productName.toLowerCase().replaceAll(' ', '_'),
            'status': 1,
            'created_at': now,
          };
        }

        // Apply purchase pricing to this specific new product entry
        newProdMap['purchase_price'] = newPurchasePrice;
        newProdMap['price'] = newSellingPrice;
        newProdMap['wholesale_price'] = newWholesalePrice;
        newProdMap['stock_quantity'] = 0.0; // Initial stock is 0, will be updated by batch logic below
        newProdMap['is_synced'] = 0;
        newProdMap['updated_at'] = now;
        
        // INSERT as a fresh product entry (Every purchase = new entry)
        productId = await txn.insert('products', newProdMap);

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
        final existingStock = await txn.rawQuery(
          '''SELECT * FROM stocks 
             WHERE product_id = ? AND branch_id = ? AND status = 1 
             AND ROUND(cost_price, 2) = ROUND(?, 2) 
             AND ROUND(sale_price, 2) = ROUND(?, 2) 
             AND ROUND(wholesale_price, 2) = ROUND(?, 2)
             ${getBusinessFilter()}
             ORDER BY id DESC LIMIT 1''',
          [productId, brid, newPurchasePrice, newSellingPrice, newWholesalePrice, ...businessArgs],
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
    
    DatabaseHelper.notifyDataChanged();
    return result;
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
    
    DatabaseHelper.notifyDataChanged();
  }

  Future<bool> checkInvoiceNumberExists(String invoiceNumber) async {
    final db = await database;
    final result = await db.query(
      'purchases',
      where: 'invoice_number = ? AND status = 1${getBusinessFilter()}',
      whereArgs: [invoiceNumber, ...getBusinessArgs()],
      limit: 1,
    );
    return result.isNotEmpty;
  }

}
