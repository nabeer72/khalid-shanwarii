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
      WHERE p.status = 1${getBusinessFilter().replaceAll('business_id', 'p.business_id').replaceAll('user_id', 'p.user_id')}$branchFilter
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
        ...Map.fromIterables(['business_id', 'user_id'], businessArgs),
        'branch_id': brid,
        'is_synced': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final pid = purchase['id'] ?? generatedPurchaseId;

      for (var item in items) {
        var productId = item['product_id'];
        final productName = item['product_name'] ?? 'Unknown Item';
        final qtyToAdd = (item['quantity'] as num).toDouble();
        final newPurchasePrice = (item['purchase_price'] as num).toDouble();
        final newSellingPrice = (item['selling_price'] as num).toDouble();
        final newWholesalePrice = (item['wholesale_price'] as num? ?? 0).toDouble();
        final barcode = item['barcode'];
        final now = DateTime.now().toIso8601String();

        // Products must already exist before purchase (as per new requirements)
        if (productId == null) {
          throw Exception('Product must be selected before making a purchase.');
        }

        // Insert Purchase Item
        final itemData = Map<String, dynamic>.from(item);
        itemData.remove('product_name');
        await txn.insert('purchase_items', {
          ...itemData,
          ...Map.fromIterables(['business_id', 'user_id'], businessArgs),
          'product_id': productId,
          'purchase_id': pid,
          'branch_id': brid,
          'barcode': barcode,
          'is_synced': 0,
        });

        // Find existing stock batch with matching prices
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

        int finalStockId;
        double oldQty = 0;
        double newQty = qtyToAdd;

        if (existingStock.isNotEmpty) {
          // Prices match — just add quantity to existing stock batch
          final s = existingStock.first;
          finalStockId = getSafeInt(s['id']) ?? 0;
          oldQty = (s['quantity'] as num).toDouble();
          newQty = oldQty + qtyToAdd;

          await txn.update('stocks', {
            'quantity': newQty,
            'is_synced': 0, 
            'updated_at': now,
          }, where: 'id = ?${getBusinessFilter()}', whereArgs: [s['id'], ...getBusinessArgs()]);
        } else {
          // Prices differ — create a NEW stock batch entry
          finalStockId = await txn.insert('stocks', {
            'id': null,
            ...Map.fromIterables(['business_id', 'user_id'], businessArgs),
            'branch_id': brid,
            'product_id': productId,
            'barcode': barcode,
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

        // Create Stock Audit entry
        await txn.insert('stock_audits', {
          ...Map.fromIterables(['business_id', 'user_id'], businessArgs),
          'branch_id': brid,
          'stock_id': finalStockId,
          'product_id': productId,
          'old_quantity': oldQty,
          'new_quantity': newQty,
          'old_purchase_price': existingStock.isNotEmpty ? (existingStock.first['cost_price'] as num).toDouble() : newPurchasePrice,
          'new_purchase_price': newPurchasePrice,
          'old_sale_price': existingStock.isNotEmpty ? (existingStock.first['sale_price'] as num).toDouble() : newSellingPrice,
          'new_sale_price': newSellingPrice,
          'remarks': 'Purchase entry: ${purchase['invoice_number'] ?? 'New Purchase'}',
          'is_synced': 0,
          'created_at': now,
          'updated_at': now,
        });

        // Denormalized product stock update is no longer needed 
        // as the Product model computes it from the stocks table.
        // The stocks table was already updated above.
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
