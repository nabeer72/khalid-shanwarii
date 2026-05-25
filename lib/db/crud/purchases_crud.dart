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

        // ── Capture OLD prices from the latest stock BEFORE any update ────────
        final prevStockRows = await txn.rawQuery(
          '''SELECT cost_price, sale_price, wholesale_price FROM stocks
             WHERE product_id = ? AND branch_id = ? AND status = 1
             ${getBusinessFilter()}
             ORDER BY id DESC LIMIT 1''',
          [productId, brid, ...businessArgs],
        );
        final double oldCostPrice    = prevStockRows.isNotEmpty ? (prevStockRows.first['cost_price']      as num?)?.toDouble() ?? 0.0 : 0.0;
        final double oldSalePrice    = prevStockRows.isNotEmpty ? (prevStockRows.first['sale_price']       as num?)?.toDouble() ?? 0.0 : 0.0;
        final double oldWholesalePrice = prevStockRows.isNotEmpty ? (prevStockRows.first['wholesale_price'] as num?)?.toDouble() ?? 0.0 : 0.0;

        // Insert Purchase Item (with old prices & quantities recorded for history)
        final itemData = Map<String, dynamic>.from(item);
        itemData.remove('product_name');
        
        final double existingStockForProduct = (itemData['existing_stock'] as num?)?.toDouble() ?? 0.0;
        final double itemQtyToPurchase = (itemData['quantity'] as num?)?.toDouble() ?? 0.0;

        await txn.insert('purchase_items', {
          ...itemData,
          ...Map.fromIterables(['business_id', 'user_id'], businessArgs),
          'product_id': productId,
          'purchase_id': pid,
          'branch_id': brid,
          'barcode': barcode,
          'old_quantity': existingStockForProduct,
          'new_quantity': existingStockForProduct + itemQtyToPurchase,
          'old_cost_price': oldCostPrice,
          'old_sale_price': oldSalePrice,
          'old_wholesale_price': oldWholesalePrice,
          'is_synced': 0,
        });

        // find existing stock batch with matching prices (matching logic as in products_crud)
        final nPid  = getSafeInt(productId);
        final nBrid = getSafeInt(brid);
        final nBid  = getSafeInt(businessArgs[0]);
        final nUid  = getSafeInt(businessArgs[1]);

        // [IMPROVED] Robust matching using integer comparison (cents/paisa) to avoid floating point issues
        final matchingStocks = await txn.rawQuery(
          '''SELECT * FROM stocks 
             WHERE product_id = ? 
             AND (branch_id = ? OR (branch_id IS NULL AND ? IS NULL)) 
             AND status = 1 
             AND business_id = ?
             AND CAST(ROUND(COALESCE(cost_price, 0) * 100) AS INTEGER) = CAST(ROUND(? * 100) AS INTEGER)
             AND CAST(ROUND(COALESCE(sale_price, 0) * 100) AS INTEGER) = CAST(ROUND(? * 100) AS INTEGER)
             AND CAST(ROUND(COALESCE(wholesale_price, 0) * 100) AS INTEGER) = CAST(ROUND(? * 100) AS INTEGER)
             ORDER BY id DESC LIMIT 1''',
          [nPid, nBrid, nBrid, nBid, newPurchasePrice, newSellingPrice, newWholesalePrice],
        );

        int finalStockId;
        double oldStockQty = 0;
        bool isNewBatch = false;

        if (matchingStocks.isNotEmpty) {
          final existingStock = matchingStocks.first;
          finalStockId = existingStock['id'] as int;
          oldStockQty = (existingStock['quantity'] as num).toDouble();
          final newQty = oldStockQty + qtyToAdd;

          await txn.update('stocks', {
            'quantity': newQty,
            'user_id': nUid,
            'is_synced': 0, 
            'updated_at': now,
          }, where: 'id = ? AND business_id = ?', whereArgs: [finalStockId, nBid]);
          isNewBatch = false;
        } else {
          // Price differs — create a NEW stock batch
          isNewBatch = true;
          finalStockId = await txn.insert('stocks', {
            'id': null,
            'business_id': nBid,
            'user_id': nUid,
            'branch_id': nBrid,
            'product_id': nPid,
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

        // Always create a Stock Audit entry
        await txn.insert('stock_audits', {
          'business_id': nBid,
          'user_id': nUid,
          'branch_id': nBrid,
          'stock_id': finalStockId,
          'product_id': nPid,
          'old_quantity': oldStockQty,
          'new_quantity': oldStockQty + qtyToAdd,
          'old_purchase_price': oldCostPrice,
          'new_purchase_price': newPurchasePrice,
          'old_sale_price': oldSalePrice,
          'new_sale_price': newSellingPrice,
          'remarks': isNewBatch 
              ? 'Purchase entry (New Batch): ${purchase['invoice_number'] ?? 'INV'}'
              : 'Purchase entry (Restock): ${purchase['invoice_number'] ?? 'INV'}',
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
    final branchFilter = getBranchFilter().replaceAll('branch_id', 'pur.branch_id');
    final branchArgs = getBranchArgs();
    
    return await db.rawQuery('''
      SELECT pi.*, p.name as product_name 
      FROM purchase_items pi
      INNER JOIN purchases pur ON pi.purchase_id = pur.id
      LEFT JOIN products p ON pi.product_id = p.id
      WHERE pi.purchase_id = ? 
      AND pi.business_id = ? AND pi.user_id = ?
      AND (p.id IS NULL OR (p.business_id = ? AND p.user_id = ?))
      $branchFilter
    ''', [purchaseId, ...getBusinessArgs(), ...getBusinessArgs(), ...branchArgs]);
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
