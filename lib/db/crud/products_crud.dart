import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import '../database_helper.dart';
import 'common_crud.dart';

mixin ProductsCrud on CommonCrud {
  double _stockTaxFromMetadata(Map<String, dynamic> metadata) {
    final enabled = metadata['tax_enabled'] == 1 || metadata['tax_enabled'] == true;
    return enabled ? ((metadata['tax_rate'] as num?)?.toDouble() ?? 0.0) : 0.0;
  }

  // Products
  Future<List<Map<String, dynamic>>> getProducts({dynamic categoryId, bool includeInactive = false}) async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();

    final statusFilter = includeInactive ? '' : ' AND status = 1';
    final baseArgs = [...getBusinessArgs(), ...branchArgs];

    // Immediate Self-Healing: Repair orphaned stocks created without a user_id
    await db.update('stocks', {'user_id': baseArgs[1]}, 
      where: 'business_id = ? AND user_id IS NULL', 
      whereArgs: [baseArgs[0]]);

    // Repair missing columns for discount_limit
    final stockCols = await db.rawQuery('PRAGMA table_info(stocks)');
    if (!stockCols.any((c) => c['name'] == 'discount_limit_type')) {
      await db.execute("ALTER TABLE stocks ADD COLUMN discount_limit_type TEXT DEFAULT 'percentage'");
    }
    if (!stockCols.any((c) => c['name'] == 'discount_limit')) {
      await db.execute("ALTER TABLE stocks ADD COLUMN discount_limit REAL DEFAULT 0");
    }
    
    final prodCols = await db.rawQuery('PRAGMA table_info(products)');
    if (!prodCols.any((c) => c['name'] == 'discount_limit_type')) {
      await db.execute("ALTER TABLE products ADD COLUMN discount_limit_type TEXT DEFAULT 'percentage'");
    }
    if (!prodCols.any((c) => c['name'] == 'discount_limit')) {
      await db.execute("ALTER TABLE products ADD COLUMN discount_limit REAL DEFAULT 0");
    }
    if (!prodCols.any((c) => c['name'] == 'tax_enabled')) {
      await db.execute("ALTER TABLE products ADD COLUMN tax_enabled INTEGER DEFAULT 0");
    }
    if (!prodCols.any((c) => c['name'] == 'tax_rate')) {
      await db.execute("ALTER TABLE products ADD COLUMN tax_rate REAL DEFAULT 0");
    }

    // Backfill stock.tax from product tax when missing
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    if (bid != null) {
      await db.rawUpdate('''
        UPDATE stocks SET tax = (
          SELECT CASE WHEN products.tax_enabled = 1 THEN products.tax_rate ELSE 0 END
          FROM products WHERE products.id = stocks.product_id
        ), is_synced = 0
        WHERE (tax IS NULL OR tax = 0)
        AND product_id IN (SELECT id FROM products WHERE tax_enabled = 1 AND business_id = ?)
        AND business_id = ?
      ''', [bid, bid]);
    }

    List<Map<String, dynamic>> productMaps;
    if (categoryId != null) {
      if (categoryId == 'cat-fav') {
        productMaps = await db.rawQuery(
          'SELECT * FROM products WHERE is_favorite = 1$statusFilter${getBusinessFilter()}$branchFilter',
          baseArgs,
        );
      } else {
        productMaps = await db.rawQuery(
          'SELECT * FROM products WHERE category_id = ?$statusFilter${getBusinessFilter()}$branchFilter',
          [categoryId, ...baseArgs],
        );
      }
    } else {
      productMaps = await db.rawQuery(
        'SELECT * FROM products WHERE 1=1$statusFilter${getBusinessFilter()}$branchFilter',
        baseArgs,
      );
    }

    if (productMaps.isEmpty) return [];

    // Fetch all stocks for these products in one go, filtered by branch
    final productIds = productMaps.map((p) => p['id']).toList();
    final idPlaceholders = List.filled(productIds.length, '?').join(', ');
    
    final statusFilterStock = includeInactive ? '' : ' AND status = 1';
    final stockMaps = await db.rawQuery(
      'SELECT * FROM stocks WHERE product_id IN ($idPlaceholders)$statusFilterStock ${getBusinessFilter()} $branchFilter',
      [...productIds, ...getBusinessArgs(), ...branchArgs],
    );

    // Group stocks by product_id
    Map<String, List<Map<String, dynamic>>> stocksByProduct = {};
    for (var s in stockMaps) {
      final pid = s['product_id']?.toString();
      if (pid != null) {
        stocksByProduct.putIfAbsent(pid, () => []).add(s);
      }
    }

    // Attach stocks to product maps (using a mutable copy)
    return productMaps.map((p) {
      final mutable = Map<String, dynamic>.from(p);
      final productStocks = stocksByProduct[p['id']?.toString()] ?? [];
      mutable['stocks'] = productStocks;
      
      // Fallback barcode for legacy UI compatibility
      if (productStocks.isNotEmpty) {
        mutable['barcode'] = productStocks.last['barcode'];
      }
      
      return mutable;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getStocksForProduct(dynamic productId) async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    return await db.rawQuery(
      'SELECT * FROM stocks WHERE product_id = ? ${getBusinessFilter()} $branchFilter',
      [productId?.toString(), ...getBusinessArgs(), ...branchArgs]
    );
  }

  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    // Build table-qualified filters to avoid ambiguity in the JOIN
    final businessClause = getBusinessFilter()
        .replaceAll('business_id', 'p.business_id')
        .replaceAll('user_id', 'p.user_id');
    final branchClause = getBranchFilter().replaceAll('branch_id', 'p.branch_id');
    final args = [...getBusinessArgs(), ...branchArgs];

    // Search by product name or stock barcode
    final productMaps = await db.rawQuery(
      '''
      SELECT DISTINCT p.* FROM products p
      LEFT JOIN stocks s ON p.id = s.product_id
      WHERE p.status = 1$businessClause$branchClause
      AND (p.name LIKE ? OR s.barcode LIKE ?)
      ''',
      [...args, '%$query%', '%$query%'],
    );

    if (productMaps.isEmpty) return [];

    // Fetch stocks for these products, filtered by branch
    final productIds = productMaps.map((p) => p['id']).toList();
    final idPlaceholders = List.filled(productIds.length, '?').join(', ');
    
    final stockMaps = await db.rawQuery(
      'SELECT * FROM stocks WHERE product_id IN ($idPlaceholders) ${getBusinessFilter()} $branchFilter',
      [...productIds, ...getBusinessArgs(), ...branchArgs],
    );

    Map<String, List<Map<String, dynamic>>> stocksByProduct = {};
    for (var s in stockMaps) {
      final pid = s['product_id']?.toString();
      if (pid != null) {
        stocksByProduct.putIfAbsent(pid, () => []).add(s);
      }
    }

    return productMaps.map((p) {
      final mutable = Map<String, dynamic>.from(p);
      final productStocks = stocksByProduct[p['id']?.toString()] ?? [];
      mutable['stocks'] = productStocks;
      
      // Fallback barcode for legacy UI compatibility
      if (productStocks.isNotEmpty) {
        mutable['barcode'] = productStocks.last['barcode'];
      }
      
      return mutable;
    }).toList();
  }

  Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
    final db = await database;
    final branchFilter = getBranchFilter().replaceAll('branch_id', 'p.branch_id');
    final branchArgs = getBranchArgs();
    final businessFilter = getBusinessFilter()
        .replaceAll('business_id', 'p.business_id')
        .replaceAll('user_id', 'p.user_id');

    final args = [barcode, ...getBusinessArgs(), ...branchArgs];
    final results = await db.rawQuery(
      'SELECT p.* FROM products p JOIN stocks s ON p.id = s.product_id'
      ' WHERE s.barcode = ?$businessFilter$branchFilter LIMIT 1',
      args,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final uid = getSafeInt(BusinessConfig.instance.userId);
    final brid = product['branch_id'] ?? getCurrentBranchId();

    // Self-healing: Repair any orphaned stocks that were created without a user_id
    await db.update('stocks', {'user_id': uid}, 
      where: 'business_id = ? AND user_id IS NULL', 
      whereArgs: [bid]);

    final metadata = Map<String, dynamic>.from(product);
    final stockTax = _stockTaxFromMetadata(metadata);

    await db.transaction((txn) async {
      final productId = metadata['id'];
      final isEdit = productId != null;

      // ── Step 1: Handle product metadata ──────────────────────────────────
      int generatedProductId;

      if (isEdit) {
        // Only update the products table if something in the metadata actually changed.
        final existingRows = await txn.query('products', where: 'id = ?', whereArgs: [productId]);
        final existing = existingRows.isNotEmpty ? existingRows.first : null;

        final bool metadataChanged = existing == null ||
            existing['name']?.toString()            != metadata['name']?.toString() ||
            existing['category_id']?.toString()     != metadata['category_id']?.toString() ||
            existing['sub_category_id']?.toString() != metadata['sub_category_id']?.toString() ||
            existing['brand_id']?.toString()         != metadata['brand_id']?.toString() ||
            existing['unit_id']?.toString()          != metadata['unit_id']?.toString() ||
            existing['description']?.toString()      != metadata['description']?.toString() ||
            existing['status']?.toString()           != metadata['status']?.toString() ||
            existing['is_favorite']?.toString()      != metadata['is_favorite']?.toString() ||
            existing['stock_limit']?.toString()      != metadata['stock_limit']?.toString() ||
            existing['discount_limit']?.toString()   != metadata['discount_limit']?.toString() ||
            existing['discount_limit_type']?.toString() != metadata['discount_limit_type']?.toString() ||
            existing['tax_enabled']?.toString()      != metadata['tax_enabled']?.toString() ||
            existing['tax_rate']?.toString()         != metadata['tax_rate']?.toString();

        if (metadataChanged) {
          await txn.update(
            'products',
            {
              'business_id':      bid,
              'user_id':          uid,
              'branch_id':        brid,
              'category_id':      metadata['category_id'],
              'sub_category_id':  metadata['sub_category_id'],
              'brand_id':         metadata['brand_id'],
              'name':             metadata['name'],
              'image':            metadata['image'],
              'description':      metadata['description'],
              'status':           metadata['status'] ?? 1,
              'is_favorite':      metadata['is_favorite'] ?? 0,
              'unit_id':          metadata['unit_id'],
              'stock_limit':      metadata['stock_limit'] ?? 5,
              'discount_limit':   metadata['discount_limit'] ?? 0.0,
              'discount_limit_type': metadata['discount_limit_type'] ?? 'percentage',
              'tax_enabled':      metadata['tax_enabled'] ?? 0,
              'tax_rate':         metadata['tax_rate'] ?? 0.0,
              'is_synced':        0,
              'updated_at':       DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [productId],
          );
          await txn.update(
            'stocks',
            {
              'tax': stockTax,
              'is_synced': 0,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'product_id = ? AND business_id = ?',
            whereArgs: [productId, bid],
          );
        }
        generatedProductId = productId;
      } else {
        // New product: INSERT into products table
        generatedProductId = await txn.insert('products', {
          'id':             null,
          'business_id':    bid,
          'user_id':        uid,
          'branch_id':      brid,
          'category_id':    metadata['category_id'],
          'sub_category_id':metadata['sub_category_id'],
          'brand_id':       metadata['brand_id'],
          'name':           metadata['name'],
          'image':          metadata['image'],
          'description':    metadata['description'],
          'status':         metadata['status'] ?? 1,
          'is_favorite':    metadata['is_favorite'] ?? 0,
          'unit_id':        metadata['unit_id'],
          'stock_limit':    metadata['stock_limit'] ?? 5,
          'discount_limit': metadata['discount_limit'] ?? 0.0,
          'discount_limit_type': metadata['discount_limit_type'] ?? 'percentage',
          'tax_enabled':    metadata['tax_enabled'] ?? 0,
          'tax_rate':       metadata['tax_rate'] ?? 0.0,
          'is_synced':      0,
          'updated_at':     DateTime.now().toIso8601String(),
        });
      }

      // ── Step 2: Resolve current prices & qty ─────────────────────────────
      final pid          = isEdit ? productId : generatedProductId;
      final barcode      = product['barcode']?.toString();
      final currentPrice = (product['price']          as num?)?.toDouble() ?? 0.0;
      final currentCost  = (product['purchase_price'] as num?)?.toDouble() ?? 0.0;
      final currentWholesale = (product['wholesale_price'] as num?)?.toDouble() ?? 0.0;
      final newQty       = (product['stock_quantity'] as num?)?.toDouble() ?? 0;
      final alertQty     = (product['stock_limit'] as num?)?.toDouble() ?? 0.0;
      final discountLimit = (product['discount_limit'] as num?)?.toDouble() ?? 0.0;
      final discountLimitType = product['discount_limit_type']?.toString() ?? 'percentage';
      final piecesPerPack = product['pieces_per_pack']?.toString();
      final packing       = product['packing']?.toString();

      // Check whether an existing stock row already has these exact prices (don't filter by user_id here)
      final nPid  = getSafeInt(pid);
      final nBrid = getSafeInt(brid);
      final nBid  = getSafeInt(bid);

      final matchingStocks = await txn.rawQuery(
        '''SELECT * FROM stocks 
           WHERE product_id = ? 
           AND (branch_id = ? OR (branch_id IS NULL AND ? IS NULL)) 
           AND business_id = ? AND status = 1 
           AND CAST(ROUND(COALESCE(sale_price, 0) * 100) AS INTEGER) = CAST(ROUND(? * 100) AS INTEGER) 
           AND CAST(ROUND(COALESCE(cost_price, 0) * 100) AS INTEGER) = CAST(ROUND(? * 100) AS INTEGER) 
           AND CAST(ROUND(COALESCE(wholesale_price, 0) * 100) AS INTEGER) = CAST(ROUND(? * 100) AS INTEGER)
           ORDER BY id DESC LIMIT 1''',
        [nPid, nBrid, nBrid, nBid, currentPrice, currentCost, currentWholesale],
      );

      // Also get the latest overall stock for this product to capture previous prices for the audit
      final latestStockResults = await txn.rawQuery(
        '''SELECT * FROM stocks 
           WHERE product_id = ? 
           AND (branch_id = ? OR (branch_id IS NULL AND ? IS NULL)) 
           AND business_id = ? AND status = 1
           ORDER BY id DESC LIMIT 1''',
        [nPid, nBrid, nBrid, nBid],
      );
      final latestStock = latestStockResults.isNotEmpty ? latestStockResults.first : null;

      int    finalStockId;
      double oldQty        = 0;
      bool   priceChanged  = false;

      if (matchingStocks.isNotEmpty) {
        // ── Case A: Same prices → only update quantity (& barcode) ──────────
        final matchingId = matchingStocks.first['id'];
        finalStockId = getSafeInt(matchingId) ?? 0;
        oldQty = (matchingStocks.first['quantity'] as num?)?.toDouble() ?? 0;

        await txn.update(
          'stocks',
          {
            'barcode':    barcode ?? matchingStocks.first['barcode'],
            'quantity':   newQty,
            'alert_quantity': alertQty,
            'discount_limit': discountLimit,
            'discount_limit_type': discountLimitType,
            'tax': stockTax,
            'pieces_per_pack': piecesPerPack ?? matchingStocks.first['pieces_per_pack'],
            'packing':    packing ?? matchingStocks.first['packing'],
            'user_id':    uid,
            'updated_at': DateTime.now().toIso8601String(),
            'is_synced':  0,
          },
          where: 'id = ?',
          whereArgs: [matchingId],
        );
      } else {
        // ── Case B: Price changed (or first stock row) → new batch row ───────
        priceChanged = isEdit; // only meaningful on edit; new products always create a row
        finalStockId = await txn.insert('stocks', {
          'id':              null,
          'business_id':     bid,
          'user_id':         uid,
          'branch_id':       brid,
          'product_id':      pid,
          'barcode':         barcode,
          'quantity':        newQty,
          'sale_price':      currentPrice,
          'cost_price':      currentCost,
          'wholesale_price': currentWholesale,
          'alert_quantity':  alertQty,
          'discount_limit':  discountLimit,
          'discount_limit_type': discountLimitType,
          'tax':             stockTax,
          'pieces_per_pack': piecesPerPack,
          'packing':         packing,
          'status':          1,
          'is_synced':       0,
          'created_at':      DateTime.now().toIso8601String(),
          'updated_at':      DateTime.now().toIso8601String(),
        });
      }

      // ── Step 3: Always write a stock_audit entry ──────────────────────────
      final String remarks;
      if (!isEdit) {
        remarks = 'Initial product creation';
      } else if (priceChanged) {
        remarks = 'New price batch created';
      } else {
        remarks = 'Stock quantity updated';
      }

      await txn.insert('stock_audits', {
        'business_id':       bid,
        'user_id':           uid,
        'branch_id':         brid,
        'stock_id':          finalStockId,
        'product_id':        pid,
        'old_quantity':      oldQty,
        'new_quantity':      newQty,
        'old_purchase_price': (latestStock?['cost_price'] as num?)?.toDouble() ?? 0.0,
        'new_purchase_price': currentCost,
        'old_sale_price':    (latestStock?['sale_price'] as num?)?.toDouble() ?? 0.0,
        'new_sale_price':    currentPrice,
        'remarks':           remarks,
        'is_synced':         0,
        'created_at':        DateTime.now().toIso8601String(),
        'updated_at':        DateTime.now().toIso8601String(),
      });
    });

    DatabaseHelper.notifyDataChanged();
  }

  Future<void> toggleProductFavorite(dynamic productId, bool currentStatus) async {
    final db = await database;
    await db.update(
      'products',
      {'is_favorite': currentStatus ? 0 : 1},
      where: 'id = ?${getBusinessFilter()}',
      whereArgs: [productId?.toString(), ...getBusinessArgs()],
    );
  }
  Future<void> toggleProductStatus(dynamic productId, int currentStatus) async {
    final db = await database;
    final args = [productId?.toString(), ...getBusinessArgs()];
    await db.rawUpdate(
      'UPDATE products SET status = ?, is_synced = 0, updated_at = ? WHERE id = ? ${getBusinessFilter()}',
      [currentStatus == 1 ? 0 : 1, DateTime.now().toIso8601String(), productId?.toString(), ...getBusinessArgs()]
    );
    DatabaseHelper.notifyDataChanged();
  }

  Future<void> toggleStockStatus(dynamic stockId, int currentStatus) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE stocks SET status = ?, is_synced = 0, updated_at = ? WHERE id = ? ${getBusinessFilter()}',
      [currentStatus == 1 ? 0 : 1, DateTime.now().toIso8601String(), stockId?.toString(), ...getBusinessArgs()]
    );
    DatabaseHelper.notifyDataChanged();
  }

  Future<bool> checkBarcodeExists(String barcode) async {
    final db = await database;
    // Barcode is now only in stocks table
    final stockResults = await db.query(
      'stocks',
      where: 'barcode = ? ${getBusinessFilter()}',
      whereArgs: [barcode, ...getBusinessArgs()],
    );
    return stockResults.isNotEmpty;
  }

  Future<int> getProductCount() async {
    final db = await database;
    final results = await db.rawQuery(
      'SELECT COUNT(*) as total FROM products WHERE status = 1 ${getBusinessFilter()}',
      getBusinessArgs(),
    );
    return Sqflite.firstIntValue(results) ?? 0;
  }
}
