import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import '../database_helper.dart';
import 'common_crud.dart';

mixin ProductsCrud on CommonCrud {
  // Products
  Future<List<Map<String, dynamic>>> getProducts({dynamic categoryId, bool includeInactive = false}) async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();

    final statusFilter = includeInactive ? '' : ' AND status = 1';
    final baseArgs = [...getBusinessArgs(), ...branchArgs];

    // Immediate Self-Healing: Repair orphaned stocks created without an admin_id
    await db.update('stocks', {'admin_id': baseArgs[1]}, 
      where: 'business_id = ? AND admin_id IS NULL', 
      whereArgs: [baseArgs[0]]);

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
    
    final stockMaps = await db.rawQuery(
      'SELECT * FROM stocks WHERE product_id IN ($idPlaceholders) AND status = 1 ${getBusinessFilter()} $branchFilter',
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
      mutable['stocks'] = stocksByProduct[p['id']?.toString()] ?? [];
      return mutable;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getStocksForProduct(dynamic productId) async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    return await db.rawQuery(
      'SELECT * FROM stocks WHERE product_id = ? AND status = 1 ${getBusinessFilter()} $branchFilter',
      [productId?.toString(), ...getBusinessArgs(), ...branchArgs]
    );
  }

  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final args = [...getBusinessArgs(), ...branchArgs];

    // Search by product name or stock barcode
    final productMaps = await db.rawQuery(
      '''
      SELECT DISTINCT p.* FROM products p
      LEFT JOIN stocks s ON p.id = s.product_id
      WHERE p.status = 1${getBusinessFilter().replaceAll('business_id', 'p.business_id').replaceAll('admin_id', 'p.admin_id')} $branchFilter 
      AND (p.name LIKE ? OR s.barcode LIKE ?)
      ''',
      [...args, '%$query%', '%$query%'],
    );

    if (productMaps.isEmpty) return [];

    // Fetch stocks for these products, filtered by branch
    final productIds = productMaps.map((p) => p['id']).toList();
    final idPlaceholders = List.filled(productIds.length, '?').join(', ');
    
    final stockMaps = await db.rawQuery(
      'SELECT * FROM stocks WHERE product_id IN ($idPlaceholders) AND status = 1 ${getBusinessFilter()} $branchFilter',
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
      mutable['stocks'] = stocksByProduct[p['id']?.toString()] ?? [];
      return mutable;
    }).toList();
  }

  Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final args = [barcode, ...getBusinessArgs(), ...branchArgs];

    final results = await db.rawQuery(
      'SELECT * FROM products WHERE barcode = ?${getBusinessFilter()}$branchFilter LIMIT 1',
      args,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    final brid = product['branch_id'] ?? getCurrentBranchId();

    // Self-healing: Repair any orphaned stocks that were created without an admin_id
    await db.update('stocks', {'admin_id': aid}, 
      where: 'business_id = ? AND admin_id IS NULL', 
      whereArgs: [bid]);

    // 1. Separate Metadata
    final metadata = Map<String, dynamic>.from(product);

    await db.transaction((txn) async {
      // 2. Insert/Update Product Metadata
      final generatedProductId = await txn.insert('products', {
        ...metadata,
        'business_id': bid,
        'admin_id': aid,
        'branch_id': brid,
        'is_synced': 0, // Mark as unsynced
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // 3. Handle Stock (Batch)
      final barcode = product['barcode']?.toString();
      final pid = product['id'] ?? generatedProductId;
      
      final currentPrice = (product['price'] as num?)?.toDouble() ?? 0.0;
      final currentCost = (product['purchase_price'] as num?)?.toDouble() ?? 0.0;
      final currentWholesale = (product['wholesale_price'] as num?)?.toDouble() ?? 0.0;

      // Check if an EXACT price-matching stock entry exists for this product
      final matchingStocks = await txn.rawQuery(
        '''SELECT * FROM stocks 
           WHERE product_id = ? AND branch_id = ? AND status = 1 
           AND ROUND(sale_price, 2) = ROUND(?, 2) 
           AND ROUND(cost_price, 2) = ROUND(?, 2) 
           AND ROUND(wholesale_price, 2) = ROUND(?, 2)
           ORDER BY created_at DESC LIMIT 1''',
        [pid, brid, currentPrice, currentCost, currentWholesale],
      );

      if (matchingStocks.isNotEmpty) {
        // EXACT PRICE MATCH -> Update existing batch
        final matchingId = matchingStocks.first['id'];
        await txn.update('stocks', {
          'barcode': barcode ?? matchingStocks.first['barcode'],
          'quantity': product['stock_quantity'] ?? matchingStocks.first['quantity'],
          'admin_id': aid, // Ensure admin_id is set
          'updated_at': DateTime.now().toIso8601String(),
          'is_synced': 0,
        }, where: 'id = ?', whereArgs: [matchingId]);
      } else {
        // PRICE CHANGED or NO BATCH -> Create new batch
        await txn.insert('stocks', {
          'id': null,
          'business_id': bid,
          'admin_id': aid, // [FIX] Added missing admin_id
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

    DatabaseHelper.notifyDataChanged();
  }

  Future<void> toggleProductFavorite(dynamic productId, bool currentStatus) async {
    final db = await database;
    await db.update(
      'products',
      {'is_favorite': currentStatus ? 0 : 1},
      where: 'id = ?${getBusinessFilter().replaceAll('business_id', 'business_id').replaceAll('admin_id', 'admin_id')}',
      whereArgs: [productId, ...getBusinessArgs()],
    );
  }
}
