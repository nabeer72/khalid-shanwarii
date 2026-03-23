import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'common_crud.dart';

mixin ProductsCrud on CommonCrud {
  // Products
  Future<List<Map<String, dynamic>>> getProducts({dynamic categoryId}) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);

    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();

    final baseArgs = [bid, aid, ...branchArgs];

    List<Map<String, dynamic>> productMaps;
    if (categoryId != null) {
      if (categoryId == 'cat-fav') {
        productMaps = await db.rawQuery(
          'SELECT * FROM products WHERE is_favorite = 1 AND status = 1 AND business_id = ? AND admin_id = ?$branchFilter',
          baseArgs,
        );
      } else {
        productMaps = await db.rawQuery(
          'SELECT * FROM products WHERE category_id = ? AND status = 1 AND business_id = ? AND admin_id = ?$branchFilter',
          [categoryId, ...baseArgs],
        );
      }
    } else {
      productMaps = await db.rawQuery(
        'SELECT * FROM products WHERE status = 1 AND business_id = ? AND admin_id = ?$branchFilter',
        baseArgs,
      );
    }

    if (productMaps.isEmpty) return [];

    // Fetch all stocks for these products in one go, filtered by branch
    final productIds = productMaps.map((p) => p['id']).toList();
    final idPlaceholders = List.filled(productIds.length, '?').join(', ');
    
    final stockMaps = await db.rawQuery(
      'SELECT * FROM stocks WHERE product_id IN ($idPlaceholders) AND status = 1 $branchFilter',
      [...productIds, ...branchArgs],
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
      mutable['stocks'] = stocksByProduct[p['id']?.toString()] ?? [];
      return mutable;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getStocksForProduct(dynamic productId) async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    return await db.rawQuery(
      'SELECT * FROM stocks WHERE product_id = ? AND status = 1 $branchFilter',
      [productId?.toString(), ...branchArgs]
    );
  }

  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);

    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final args = [bid, aid, ...branchArgs];

    // Search by product name or stock barcode
    final productMaps = await db.rawQuery(
      '''
      SELECT DISTINCT p.* FROM products p
      LEFT JOIN stocks s ON p.id = s.product_id
      WHERE p.status = 1 AND p.business_id = ? AND p.admin_id = ? $branchFilter 
      AND (p.name LIKE ? OR s.barcode LIKE ?)
      ''',
      [...args, '%$query%', '%$query%'],
    );

    if (productMaps.isEmpty) return [];

    // Fetch stocks for these products, filtered by branch
    final productIds = productMaps.map((p) => p['id']).toList();
    final idPlaceholders = List.filled(productIds.length, '?').join(', ');
    
    final stockMaps = await db.rawQuery(
      'SELECT * FROM stocks WHERE product_id IN ($idPlaceholders) AND status = 1 $branchFilter',
      [...productIds, ...branchArgs],
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
      mutable['stocks'] = stocksByProduct[p['id']?.toString()] ?? [];
      return mutable;
    }).toList();
  }

  Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final args = [barcode, bid, aid, ...branchArgs];

    final results = await db.rawQuery(
      'SELECT * FROM products WHERE barcode = ? AND business_id = ? AND admin_id = ?$branchFilter LIMIT 1',
      args,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    final brid = product['branch_id'] ?? getCurrentBranchId();

    // 1. Separate Metadata
    final metadata = Map<String, dynamic>.from(product);
    // Keep pricing/stock in metadata for denormalization in the products table
    // final stockFields = ['stock_quantity', 'price', 'purchase_price', 'wholesale_price', 'barcode', 'manufacture_date', 'expire_date'];
    // metadata.removeWhere((key, value) => stockFields.contains(key) && key != 'barcode');

    await db.transaction((txn) async {
      // 2. Insert/Update Product Metadata
      final generatedProductId = await txn.insert('products', {
        ...metadata,
        'business_id': bid,
        'admin_id': aid,
        'branch_id': brid,
        'is_synced': 0, // Mark as unsynced
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // 3. Handle Stock (Batch)
      final barcode = product['barcode']?.toString();
      final pid = product['id'] ?? generatedProductId;
      
      final currentPrice = (product['price'] as num?)?.toDouble() ?? 0.0;
      final currentCost = (product['purchase_price'] as num?)?.toDouble() ?? 0.0;
      final currentWholesale = (product['wholesale_price'] as num?)?.toDouble() ?? 0.0;

      // Check if an EXACT price-matching stock entry exists for this product IN THIS BRANCH
      final matchingStocks = await txn.rawQuery(
        '''SELECT * FROM stocks 
           WHERE product_id = ? AND branch_id = ? AND status = 1 
           AND sale_price = ? AND cost_price = ? AND wholesale_price = ?
           ORDER BY created_at DESC LIMIT 1''',
        [pid, brid, currentPrice, currentCost, currentWholesale],
      );

      if (matchingStocks.isNotEmpty) {
        // EXACT PRICE MATCH -> Update existing batch
        final matchingId = matchingStocks.first['id'];
        await txn.update('stocks', {
          'barcode': barcode ?? matchingStocks.first['barcode'],
          'quantity': product['stock_quantity'] ?? matchingStocks.first['quantity'],
          'updated_at': DateTime.now().toIso8601String(),
          'is_synced': 0,
        }, where: 'id = ?', whereArgs: [matchingId]);
      } else {
        // PRICE CHANGED or NO BATCH -> Create new batch
        await txn.insert('stocks', {
          'id': null,
          'business_id': bid,
          'branch_id': brid,
          'product_id': pid,
          'barcode': barcode,
          'quantity': product['stock_quantity'] ?? 0,
          'sale_price': currentPrice,
          'cost_price': currentCost,
          'wholesale_price': currentWholesale,
          'status': 1,
          'is_synced': 0,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<void> toggleProductFavorite(dynamic productId, bool currentStatus) async {
    final db = await database;
    await db.update(
      'products',
      {'is_favorite': currentStatus ? 0 : 1},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }
}
