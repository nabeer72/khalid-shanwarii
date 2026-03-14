import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/services/api_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:uuid/uuid.dart';

class SyncService {
  final ApiService _api = ApiService();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  double _parseNum(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  /// Full sync - pull then push 
  Future<SyncResult> syncAll() async {
    final result = SyncResult();
    
    // Check if we have a token before syncing
    final token = await _storage.read(key: 'auth_token');
    if (token == null) {
      result.pullError = 'Authentication token missing. Please log in again.';
      result.pushError = 'Authentication token missing. Please log in again.';
      return result;
    }

    try {
      await syncPull();
      result.pullSuccess = true;
    } catch (e) {
      result.pullError = e.toString();
    }
    try {
      await syncPush();
      result.pushSuccess = true;
    } catch (e) {
      if (e is DioException) {
        if (kDebugMode) print('Sync Push Error Body: ${e.response?.data}');
      }
      result.pushError = e.toString();
    }
    return result;
  }

  Future<Map<String, dynamic>?> syncPull({bool forceFull = false}) async {
    try {
      String? lastSyncedAt = await _storage.read(key: 'last_synced_at');

      // CRITICAL: If the local database is empty (no users or businesses), 
      // we must ignore last_synced_at even if it was restored from a backup.
      final db = await _dbHelper.database;
      final localCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM users'));
      if (localCount == 0 || forceFull) {
        lastSyncedAt = null;
        if (kDebugMode) print('🔄 [SYNC] Forcing full sync (local database is empty)');
      }

      final queryParams = {
        'last_synced_at': lastSyncedAt,
        'branch_id': BusinessConfig.instance.branchId,
      };
      if (kDebugMode) print('🔍 [SYNC] Pulling data with params: $queryParams');

      final response = await _api.get('/sync/pull', queryParameters: queryParams);

      if (response.statusCode == 200) {
        final data = response.data['changes'];
        final serverTime = response.data['timestamp'];
        final db = await _dbHelper.database;
        
        // Use user/business info from response if available (for initial sync)
        final respUser = response.data['user'];
        final respBusiness = response.data['business'];
        
        // Use current session IDs as fallbacks. If it's a staff member, we want to associate data with the admin's context.
        final aid = (respUser != null && respUser['admin_id'] != null && respUser['admin_id'].toString().isNotEmpty) 
            ? respUser['admin_id'] 
            : (respUser != null ? respUser['id'] : null);
            
        final brid = respUser != null ? respUser['branch_id'] : null;
        final fallbackBusinessId = (BusinessConfig.instance.businessId ?? respBusiness?['id']?.toString())?.toLowerCase();
        
        var currentAdminId = BusinessConfig.instance.adminId;
        if (currentAdminId != null && currentAdminId.isEmpty) currentAdminId = null;
        
        final fallbackAdminId = (currentAdminId ?? aid?.toString())?.toLowerCase();
        final fallbackBranchId = (BusinessConfig.instance.branchId ?? brid?.toString())?.toLowerCase();

        int _parseStatus(dynamic v) {
          if (v == null || v == true || v == 1 || v.toString().toLowerCase() == 'active' || v.toString() == '1') return 1;
          return 0;
        }

        if (kDebugMode) {
          print('🔍 [SYNC] Fallback IDs: admin=$fallbackAdminId, business=$fallbackBusinessId');
          print('🔍 [SYNC] Data Keys: ${data.keys.toList()}');
        }

        // Helper: returns the server's branch_id if non-null, else
        // the fallback, else looks up the existing local row to preserve its branch_id.
        Future<String?> _safeBranchId(Transaction t, String table, String? rowId, String? serverBranchId) async {
          final resolved = (serverBranchId ?? fallbackBranchId)?.toString().toLowerCase();
          if (resolved != null && resolved.isNotEmpty) return resolved;
          // Preserve existing local branch_id
          if (rowId != null) {
            final rows = await t.query(table, columns: ['branch_id'], where: 'id = ?', whereArgs: [rowId], limit: 1);
            if (rows.isNotEmpty && rows.first['branch_id'] != null) {
              return rows.first['branch_id'].toString();
            }
          }
          return null;
        }

        await db.transaction((txn) async {
          // Categories
          if (data['categories'] != null) {
            for (var c in data['categories']) {
              final catId = c['id']?.toString().toLowerCase();
              await txn.insert(
                'categories',
                {
                  'id': catId,
                  'business_id': (c['business_id'] ?? fallbackBusinessId)?.toString().toLowerCase(),
                  'branch_id': await _safeBranchId(txn, 'categories', catId, c['branch_id']?.toString()),
                  'admin_id': (c['admin_id'] ?? fallbackAdminId)?.toString().toLowerCase(),
                  'name': c['name'] ?? 'Unknown',
                  'icon': c['icon'],
                  'status': _parseStatus(c['status']),
                  'is_synced': 1,
                  'updated_at': c['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            if (kDebugMode) print('Synced ${data['categories'].length} categories');
          }

          // Products & Stocks
          if (data['products'] != null) {
            for (var i = 0; i < data['products'].length; i++) {
              var p = data['products'][i];
              final productId = p['id']?.toString().toLowerCase();
              
              // 1. Insert Product Metadata
              final safeProdBranch = await _safeBranchId(txn, 'products', productId, p['branch_id']?.toString());
              final productRow = {
                'id': productId,
                'business_id': (p['business_id'] ?? fallbackBusinessId)?.toString().toLowerCase(),
                'branch_id': safeProdBranch,
                'admin_id': (p['admin_id'] ?? fallbackAdminId)?.toString().toLowerCase(),
                'category_id': p['category_id']?.toString().toLowerCase(),
                'name': p['name'] ?? 'Unknown',
                'image': p['image'],
                'description': p['description'],
                'barcode': p['barcode'] ?? p['sku'],
                'is_price_per_weight': (p['is_price_per_weight'] == true || p['is_price_per_weight'] == 1) ? 1 : 0,
                'is_favorite': (p['is_favorite'] == true || p['is_favorite'] == 1) ? 1 : 0,
                'status': _parseStatus(p['status']),
                'is_synced': 1,
                'updated_at': p['updated_at'],
              };
              
              await txn.insert('products', productRow, conflictAlgorithm: ConflictAlgorithm.replace);

              // 2. Insert Stocks (if provided by server)
              if (p['stocks'] != null && (p['stocks'] as List).isNotEmpty) {
                for (var s in p['stocks']) {
                  await txn.insert('stocks', {
                    'id': s['id']?.toString().toLowerCase(),
                    'business_id': productRow['business_id'],
                    'branch_id': (s['branch_id'] ?? productRow['branch_id'])?.toString().toLowerCase(),
                    'product_id': productId,
                    'barcode': s['barcode'] ?? productRow['barcode'],
                    'quantity': _parseNum(s['quantity']),
                    'cost_price': _parseNum(s['cost_price'] ?? s['purchase_price']),
                    'sale_price': _parseNum(s['sale_price'] ?? s['price']),
                    'wholesale_price': _parseNum(s['wholesale_price'] ?? s['whole_sale_price']), // Renamed
                    'status': _parseStatus(s['status'] ?? 1),
                    'is_synced': 1,
                    'updated_at': s['updated_at'] ?? productRow['updated_at'],
                  }, conflictAlgorithm: ConflictAlgorithm.replace);
                }
              } else {
                // FALLBACK: Create an initial stock batch if server doesn't provide them yet
                final price = _parseNum(p['price'] ?? p['sale_price']);
                final qty = _parseNum(p['stock_quantity'] ?? p['quantity'] ?? 0);
                
                // Only create a batch if there is price or quantity
                if (price > 0 || qty > 0) {
                  // We need a stable ID for this "default" stock to avoid duplicates on every sync
                  // Let's use a hash of the product ID or just check if any stock exists
                  final existingStocks = await txn.query('stocks', where: 'product_id = ?', whereArgs: [productId]);
                  if (existingStocks.isEmpty) {
                    await txn.insert('stocks', {
                      'id': const Uuid().v4(),
                      'business_id': productRow['business_id'],
                      'branch_id': productRow['branch_id'],
                      'product_id': productId,
                      'barcode': productRow['barcode'],
                      'quantity': qty,
                      'cost_price': _parseNum(p['purchase_price'] ?? p['cost_price']),
                      'sale_price': price,
                      'wholesale_price': _parseNum(p['wholesale_price'] ?? p['whole_sale_price']), // Renamed
                      'status': 1,
                      'is_synced': 1,
                      'updated_at': productRow['updated_at'],
                    });
                  } else {
                    // Update the first existing stock's quantity/price if we are doing a "legacy" pull
                    await txn.update('stocks', {
                      'quantity': qty,
                      'sale_price': price,
                      'cost_price': _parseNum(p['purchase_price'] ?? p['cost_price']),
                      'updated_at': productRow['updated_at'],
                    }, where: 'id = ?', whereArgs: [existingStocks.first['id']]);
                  }
                }
              }
            }
            if (kDebugMode) print('Synced ${data['products'].length} products (and their stocks)');
          }

          // Customers
          if (data['customers'] != null) {
            for (var c in data['customers']) {
              final custId = c['id']?.toString().toLowerCase();
              await txn.insert(
                'customers',
                {
                  'id': custId,
                  'business_id': (c['business_id'] ?? fallbackBusinessId)?.toString().toLowerCase(),
                  'branch_id': await _safeBranchId(txn, 'customers', custId, c['branch_id']?.toString()),
                  'admin_id': (c['admin_id'] ?? fallbackAdminId)?.toString().toLowerCase(),
                  'name': c['name'] ?? 'Unknown',
                  'phone': c['phone'],
                  'email': c['email'],
                  'notes': c['notes'],
                  'total_spent': _parseNum(c['total_spent']),
                  'visit_count': c['visit_count'] ?? 0,
                  'credit_balance': _parseNum(c['credit_balance'] ?? c['balance']),
                  'status': _parseStatus(c['status']),
                  'is_synced': 1,
                  'updated_at': c['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            if (kDebugMode) print('Synced ${data['customers'].length} customers');
          }

          // Employees
          if (data['employees'] != null) {
            for (var e in data['employees']) {
              await txn.insert(
                'employees',
                {
                  'id': e['id']?.toString().toLowerCase(),
                  'business_id': (e['business_id'] ?? fallbackBusinessId)?.toString().toLowerCase(),
                  'branch_id': (e['branch_id'] ?? fallbackBranchId)?.toString().toLowerCase(),
                  'admin_id': (e['admin_id'] ?? fallbackAdminId)?.toString().toLowerCase(),
                  'name': e['name'] ?? 'Unknown',
                  'email': e['email'],
                  'phone': e['phone'],
                  'role': e['role'] ?? 'cashier',
                  'role_id': e['role_id'],
                  'pin': e['pin'],
                  'permissions': (e['permissions'] is List || e['permissions'] is Map) ? jsonEncode(e['permissions']) : e['permissions'],
                  'status': _parseStatus(e['status']),
                  'is_synced': 1,
                  'updated_at': e['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            if (kDebugMode) print('Synced ${data['employees'].length} employees');
          }

          // Roles
          if (data['roles'] != null) {
            for (var r in data['roles']) {
              await txn.insert(
                'roles',
                {
                  'id': r['id']?.toString().toLowerCase(),
                  'business_id': (r['business_id'] ?? fallbackBusinessId)?.toString().toLowerCase(),
                  'branch_id': (r['branch_id'] ?? fallbackBranchId)?.toString().toLowerCase(),
                  'name': r['name'] ?? 'Unknown',
                  'description': r['description'],
                  'status': _parseStatus(r['status']),
                  'is_synced': 1,
                  'updated_at': r['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );

              // Role Permissions Pivot
              if (r['permissions'] != null) {
                // Clear old permissions for this role first
                await txn.delete('role_permissions', where: 'role_id = ?', whereArgs: [r['id']?.toString().toLowerCase()]);
                for (var p in r['permissions']) {
                  await txn.insert(
                    'role_permissions',
                    {
                      'role_id': r['id']?.toString().toLowerCase(),
                      'permission_id': p['id']?.toString().toLowerCase(),
                    },
                    conflictAlgorithm: ConflictAlgorithm.replace,
                  );
                }
              }
            }
            if (kDebugMode) print('Synced ${data['roles'].length} roles');
          }

          // Permissions (Offline reference)
          if (data['permissions'] != null) {
            for (var p in data['permissions']) {
              await txn.insert(
                'permissions',
                {
                  'id': p['id']?.toString().toLowerCase(),
                  'name': p['name'] ?? 'Unknown',
                  'label': p['label'] ?? p['name'] ?? 'Unknown',
                  'updated_at': p['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            if (kDebugMode) print('Synced ${data['permissions'].length} permissions');
          }

          // Sales
          if (data['sales'] != null) {
            for (var s in data['sales']) {
              final saleId = s['id']?.toString().toLowerCase();
              await txn.insert(
                'sales',
                {
                  'id': saleId,
                  'business_id': (s['business_id'] ?? fallbackBusinessId)?.toString().toLowerCase(),
                  'branch_id': await _safeBranchId(txn, 'sales', saleId, s['branch_id']?.toString()),
                  'admin_id': (s['admin_id'] ?? fallbackAdminId)?.toString().toLowerCase(),
                  'customer_id': s['customer_id']?.toString().toLowerCase(),
                  'user_id': s['user_id']?.toString().toLowerCase(),
                  'subtotal': _parseNum(s['subtotal']),
                  'tax': _parseNum(s['tax']),
                  'discount': _parseNum(s['discount']),
                  'total': _parseNum(s['total']),
                  'payment_method': s['payment_method'] ?? 'cash',
                  'is_return': (s['is_return'] == true || s['is_return'] == 1) ? 1 : 0,
                  'tip': _parseNum(s['tip']),
                  'status': _parseStatus(s['status']),
                  'is_synced': 1,
                  'created_at': s['created_at'],
                  'updated_at': s['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );

              // Sale items
              if (s['sale_details'] != null) {
                for (var item in s['sale_details']) {
                  await txn.insert(
                    'sale_items',
                    {
                      'id': item['id']?.toString().toLowerCase(),
                      'sale_id': s['id']?.toString().toLowerCase(),
                      'product_id': item['product_id']?.toString().toLowerCase(),
                      'branch_id': (s['branch_id'] ?? fallbackBranchId)?.toString().toLowerCase(),
                      'quantity': _parseNum(item['quantity']),
                      'price': _parseNum(item['price']),
                      'subtotal': _parseNum(item['subtotal']),
                      'is_synced': 1,
                    },
                    conflictAlgorithm: ConflictAlgorithm.replace,
                  );
                }
              }
            }
            if (kDebugMode) print('Synced ${data['sales'].length} sales');
          }

          // Credit Sales
          if (data['credit_sales'] != null) {
            for (var cs in data['credit_sales']) {
              await txn.insert(
                'credit_sales',
                {
                  'id': cs['id']?.toString().toLowerCase(),
                  'business_id': (cs['business_id'] ?? fallbackBusinessId)?.toString().toLowerCase(),
                  'branch_id': (cs['branch_id'] ?? fallbackBranchId)?.toString().toLowerCase(),
                  'admin_id': (cs['admin_id'] ?? fallbackAdminId)?.toString().toLowerCase(),
                  'customer_id': cs['customer_id']?.toString().toLowerCase(),
                  'sale_id': cs['sale_id']?.toString().toLowerCase(),
                  'amount': _parseNum(cs['amount']),
                  'remaining_balance': _parseNum(cs['remaining_balance']),
                  'status': _parseStatus(cs['status']),
                  'is_synced': 1,
                  'created_at': cs['created_at'],
                  'updated_at': cs['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            if (kDebugMode) print('Synced ${data['credit_sales'].length} credit sales');
          }

          // Credit Payments
          if (data['credit_payments'] != null) {
            for (var cp in data['credit_payments']) {
              await txn.insert(
                'credit_payments',
                {
                  'id': cp['id']?.toString().toLowerCase(),
                  'business_id': (cp['business_id'] ?? fallbackBusinessId)?.toString().toLowerCase(),
                  'branch_id': (cp['branch_id'] ?? fallbackBranchId)?.toString().toLowerCase(),
                  'admin_id': (cp['admin_id'] ?? fallbackAdminId)?.toString().toLowerCase(),
                  'credit_sale_id': cp['credit_sale_id']?.toString().toLowerCase(),
                  'customer_id': cp['customer_id']?.toString().toLowerCase(),
                  'amount': _parseNum(cp['amount']),
                  'received_by': cp['received_by']?.toString(), // Don't lowercase name
                  'payment_date': cp['payment_date'],
                  'notes': cp['notes'],
                  'is_synced': 1,
                  'created_at': cp['created_at'],
                  'updated_at': cp['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            if (kDebugMode) print('Synced ${data['credit_payments'].length} credit payments');
          }

          // Trigger reconciliation of customer balances after ALL sync data is inserted
          await _dbHelper.reconcileCustomerBalances(txn);

          // Suppliers
          if (data['suppliers'] != null) {
            for (var s in data['suppliers']) {
              await txn.insert(
                'suppliers',
                {
                  'id': s['id']?.toString().toLowerCase(),
                  'business_id': (s['business_id'] ?? fallbackBusinessId)?.toString().toLowerCase(),
                  'branch_id': (s['branch_id'] ?? fallbackBranchId)?.toString().toLowerCase(),
                  'admin_id': (s['admin_id'] ?? fallbackAdminId)?.toString().toLowerCase(),
                  'name': s['name'] ?? 'Unknown',
                  'contact_person': s['contact_person'],
                  'phone': s['cell_number'], // Backend calls it cell_number
                  'email': s['email'],
                  'address': s['address'],
                  'status': _parseStatus(s['status']),
                  'created_at': s['created_at'],
                  'updated_at': s['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            if (kDebugMode) print('Synced ${data['suppliers'].length} suppliers');
          }

          // Purchases
          if (data['purchases'] != null) {
            for (var p in data['purchases']) {
              await txn.insert(
                'purchases',
                {
                  'id': p['id']?.toString().toLowerCase(),
                  'business_id': (p['business_id'] ?? fallbackBusinessId)?.toString().toLowerCase(),
                  'branch_id': (p['branch_id'] ?? fallbackBranchId)?.toString().toLowerCase(),
                  'admin_id': (p['admin_id'] ?? fallbackAdminId)?.toString().toLowerCase(),
                  'supplier_id': p['vendor_id']?.toString().toLowerCase(),
                  'invoice_number': p['invoice_number'],
                  'purchase_date': p['date'],
                  'notes': p['notes'],
                  'payment_type': p['payment_type_id']?.toString(),
                  'payment_reference': p['payment_reference'],
                  'total_amount': _parseNum(p['grand_total']),
                  'status': (p['status'] == null || p['status'] == true || p['status'] == 1) ? 1 : 0,
                  'is_synced': 1,
                  'created_at': p['created_at'],
                  'updated_at': p['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );

              if (p['purchasing_details'] != null) {
                for (var item in p['purchasing_details']) {
                  await txn.insert(
                    'purchase_items',
                    {
                      'id': item['id']?.toString().toLowerCase(),
                      'purchase_id': p['id']?.toString().toLowerCase(),
                      'product_id': item['product_id']?.toString().toLowerCase(),
                      'branch_id': (p['branch_id'] ?? fallbackBranchId)?.toString().toLowerCase(),
                      'quantity': _parseNum(item['quantity']),
                      'purchase_price': _parseNum(item['cost_price']),
                      'wholesale_price': _parseNum(item['whole_sale_price']),
                      'selling_price': _parseNum(item['sale_price']),
                      'is_synced': 1,
                    },
                    conflictAlgorithm: ConflictAlgorithm.replace,
                  );
                }
              }
            }
            if (kDebugMode) print('Synced ${data['purchases'].length} purchases');
          }

          // Expense Heads
          if (data['expense_heads'] != null) {
            for (var eh in data['expense_heads']) {
              await txn.insert(
                'expense_heads',
                {
                  'id': eh['id']?.toString().toLowerCase(),
                  'business_id': (eh['business_id'] ?? fallbackBusinessId)?.toString().toLowerCase(),
                  'branch_id': (eh['branch_id'] ?? fallbackBranchId)?.toString().toLowerCase(),
                  'admin_id': (eh['admin_id'] ?? fallbackAdminId)?.toString().toLowerCase(),
                  'name': eh['name'] ?? 'Unknown',
                  'status': (eh['status'] == null || eh['status'] == true || eh['status'] == 1) ? 1 : 0,
                  'created_at': eh['created_at'],
                  'updated_at': eh['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            if (kDebugMode) print('Synced ${data['expense_heads'].length} expense heads');
          }

          // Expenses
          if (data['expenses'] != null) {
            for (var e in data['expenses']) {
              await txn.insert(
                'expenses',
                {
                  'id': e['id']?.toString().toLowerCase(),
                  'business_id': (e['business_id'] ?? fallbackBusinessId)?.toString().toLowerCase(),
                  'branch_id': (e['branch_id'] ?? fallbackBranchId)?.toString().toLowerCase(),
                  'admin_id': (e['admin_id'] ?? fallbackAdminId)?.toString().toLowerCase(),
                  'expense_head_id': e['expense_head_id']?.toString().toLowerCase(),
                  'amount': _parseNum(e['amount']),
                  'description': e['title'], // Backend calls it title
                  'date': e['date'],
                  'status': (e['status'] == null || e['status'] == true || e['status'] == 1) ? 1 : 0,
                  'created_at': e['created_at'],
                  'updated_at': e['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            if (kDebugMode) print('Synced ${data['expenses'].length} expenses');
          }

          // Shifts
          if (data['shifts'] != null) {
            for (var s in data['shifts']) {
              await txn.insert(
                'shifts',
                {
                  'id': s['id']?.toString().toLowerCase(),
                  'business_id': (s['business_id'] ?? fallbackBusinessId)?.toString().toLowerCase(),
                  'branch_id': (s['branch_id'] ?? fallbackBranchId)?.toString().toLowerCase(),
                  'admin_id': (s['admin_id'] ?? fallbackAdminId)?.toString().toLowerCase(),
                  'user_id': s['user_id']?.toString().toLowerCase(),
                  'staff_id': s['staff_id'],
                  'start_time': s['start_time'],
                  'end_time': s['end_time'],
                  'opening_cash': _parseNum(s['opening_cash']),
                  'opening_denominations': (s['opening_denominations'] is List || s['opening_denominations'] is Map) ? jsonEncode(s['opening_denominations']) : s['opening_denominations'],
                  'closing_cash': _parseNum(s['closing_cash']),
                  'closing_denominations': (s['closing_denominations'] is List || s['closing_denominations'] is Map) ? jsonEncode(s['closing_denominations']) : s['closing_denominations'],
                  'total_sales': _parseNum(s['total_sales']),
                  'total_cash_received': _parseNum(s['total_cash_received']),
                  'total_online_received': _parseNum(s['total_online_received']),
                  'total_credit_received': _parseNum(s['total_credit_received']),
                  'status': s['status'] ?? 0,
                  'is_synced': 1,
                  'created_at': s['created_at'],
                  'updated_at': s['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            if (kDebugMode) print('Synced ${data['shifts'].length} shifts');
          }

          // Branches
          if (data['branches'] != null) {
            for (var b in data['branches']) {
              final branchId = b['id']?.toString().toLowerCase();
              if (kDebugMode) print('🔄 [SYNC] Pulling Branch: $branchId - ${b['branch_title'] ?? b['name']} (Code: ${b['branch_code']})');
              
              // Preserve local status: if server sends null/0/false, keep local status
              // so a locally-active branch is NOT deactivated by the server.
              // Only trust the server status if it explicitly says active (1).
              final serverStatus = _parseStatus(b['status']);
              
              // Check if branch already exists locally
              final existingBranch = await txn.query('branches', where: 'id = ?', whereArgs: [branchId], limit: 1);
              final localStatus = existingBranch.isNotEmpty ? (existingBranch.first['status'] as int? ?? 1) : 1;
              
              // Use server status only if server explicitly sends active (1).
              // If server sends null/0, keep the local status to avoid overwriting user's choice.
              final statusToUse = (serverStatus == 1) ? 1 : localStatus;

              await txn.insert(
                'branches',
                {
                  'id': branchId,
                  'business_id': (b['business_id'] ?? fallbackBusinessId)?.toString().toLowerCase(),
                  'user_id': b['user_id']?.toString().toLowerCase(),
                  'branch_title': b['branch_title'] ?? b['name'] ?? 'Unknown',
                  'branch_code': b['branch_code'],
                  'branch_address': b['branch_address'] ?? b['address'],
                  'contact_number': b['contact_number'] ?? b['cell_number'],
                  'status': statusToUse,
                  'is_synced': 1,
                  'created_at': b['created_at'],
                  'updated_at': b['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            if (kDebugMode) print('Synced ${data['branches'].length} branches');
          }

          // Bank Accounts
          if (data['bank_accounts'] != null) {
            for (var b in data['bank_accounts']) {
              await txn.insert(
                'bank_accounts',
                {
                  'id': b['id']?.toString().toLowerCase(),
                  'business_id': (b['business_id'] ?? fallbackBusinessId)?.toString().toLowerCase(),
                  'admin_id': (b['admin_id'] ?? fallbackAdminId)?.toString().toLowerCase(),
                  'branch_id': (b['branch_id'] ?? fallbackBranchId)?.toString().toLowerCase(),
                  'bank_name': b['bank_name'] ?? 'Unknown',
                  'account_type': b['account_type'],
                  'account_title': b['account_title'],
                  'account_number': b['account_number'],
                  'amount': _parseNum(b['amount']),
                  'transaction_type': b['transaction_type'],
                  'remarks': b['remarks'],
                  'date': b['date'],
                  'status': (b['status'] == null || b['status'] == true || b['status'] == 1) ? 1 : 0,
                  'is_synced': 1,
                  'created_at': b['created_at'],
                  'updated_at': b['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            if (kDebugMode) print('Synced ${data['bank_accounts'].length} bank accounts');
          }

        });


        if (serverTime != null) {
          await _storage.write(key: 'last_synced_at', value: serverTime);
        }
        return response.data;
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Sync Pull Error: $e');
      rethrow;
    }
  }

  /// Push local changes to server
  Future<void> syncPush() async {
    try {
      final db = await _dbHelper.database;
      Map<String, dynamic> changes = {};

      List<Map<String, dynamic>> unsyncedSales = [];
      List<Map<String, dynamic>> unsyncedCategories = [];
      List<Map<String, dynamic>> unsyncedCustomers = [];
      List<Map<String, dynamic>> unsyncedProducts = [];
      List<Map<String, dynamic>> unsyncedStocksForSyncedProducts = [];
      List<Map<String, dynamic>> unsyncedUsers = [];
      List<Map<String, dynamic>> unsyncedBusinesses = [];
      List<Map<String, dynamic>> unsyncedEmployees = [];
      List<Map<String, dynamic>> unsyncedCreditSales = [];
      List<Map<String, dynamic>> unsyncedCreditPayments = [];
      List<Map<String, dynamic>> unsyncedSuppliers = [];
      List<Map<String, dynamic>> unsyncedExpenseHeads = [];
      List<Map<String, dynamic>> unsyncedExpenses = [];
      List<Map<String, dynamic>> unsyncedPurchases = [];
      List<Map<String, dynamic>> unsyncedShifts = [];
      List<Map<String, dynamic>> unsyncedBranches = [];
      List<Map<String, dynamic>> unsyncedRoles = [];

      // Unsynced Sales
      unsyncedSales = await db.query('sales', where: 'is_synced = 0');
      if (unsyncedSales.isNotEmpty) {
        changes['sales'] = [];
        for (var sale in unsyncedSales) {
          final items = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [sale['id']]);
          Map<String, dynamic> saleData = Map.from(sale);
          saleData.remove('is_synced');
          saleData['items'] = items.map((i) {
            var m = Map.from(i);
            m.remove('is_synced');
            return m;
          }).toList();
          changes['sales']?.add(saleData);
        }
      }

      // Unsynced Categories
      unsyncedCategories = await db.query('categories', where: 'is_synced = 0');
      if (unsyncedCategories.isNotEmpty) {
        changes['categories'] = unsyncedCategories.map((c) {
          var m = Map.from(c);
          m.remove('is_synced');
          return m;
        }).toList();
      }

      // Unsynced Customers
      unsyncedCustomers = await db.query('customers', where: 'is_synced = 0');
      if (unsyncedCustomers.isNotEmpty) {
        changes['customers'] = unsyncedCustomers.map((c) {
          var m = Map.from(c);
          m.remove('is_synced');
          return m;
        }).toList();
      }

      // Unsynced Products & their Stocks
      unsyncedProducts = await db.query('products', where: 'is_synced = 0');
      if (unsyncedProducts.isNotEmpty) {
        List<Map<String, dynamic>> productsList = [];
        for (var p in unsyncedProducts) {
          var productMap = Map<String, dynamic>.from(p);
          productMap.remove('is_synced');
          
          // Get ALL stocks for this unsynced product (we push them all)
          final stocks = await db.query('stocks', where: 'product_id = ?', whereArgs: [p['id']]);
          productMap['stocks'] = stocks.map((s) {
            var sMap = Map<String, dynamic>.from(s);
            sMap.remove('is_synced');
            return sMap;
          }).toList();
          
          productsList.add(productMap);
        }
        changes['products'] = productsList;
      }

      // Unsynced Stocks for ALREADY SYNCED products
      unsyncedStocksForSyncedProducts = await db.rawQuery('''
        SELECT s.* FROM stocks s
        JOIN products p ON s.product_id = p.id
        WHERE s.is_synced = 0 AND p.is_synced = 1
      ''');
      
      if (unsyncedStocksForSyncedProducts.isNotEmpty) {
        // Group these by product ID to fit the nested structure the backend now expects (or just push as separate key)
        // Let's push as a separate 'stocks' key and handle it in backend push() too.
        changes['stocks'] = unsyncedStocksForSyncedProducts.map((s) {
          var m = Map<String, dynamic>.from(s);
          m.remove('is_synced');
          return m;
        }).toList();
      }

      // Unsynced Users (from signup)
      unsyncedUsers = await _dbHelper.getUnsyncedUsers();
      if (unsyncedUsers.isNotEmpty) {
        changes['users'] = unsyncedUsers.map((u) {
          var m = Map.from(u);
          m.remove('is_synced');
          m.remove('password'); // Don't sync password hash to server (handled separately)
          return m;
        }).toList();
      }

      // Unsynced Businesses (from signup)
      unsyncedBusinesses = await _dbHelper.getUnsyncedBusinesses();
      if (unsyncedBusinesses.isNotEmpty) {
        changes['businesses'] = unsyncedBusinesses.map((b) {
          var m = Map.from(b);
          m.remove('is_synced');
          return m;
        }).toList();
      }

      // Unsynced Employees
      unsyncedEmployees = await db.query('employees', where: 'is_synced = 0');
      if (unsyncedEmployees.isNotEmpty) {
      changes['employees'] = unsyncedEmployees.map((e) {
          var m = Map.from(e);
          m.remove('is_synced');
          // Permissions are already JSON string in DB, usually server expects them as List or String
          // If server expects List, we should decode here. Let's assume server handles it or decode if it's a string.
          if (m['permissions'] is String) {
            try {
              m['permissions'] = jsonDecode(m['permissions']);
            } catch (_) {}
          }

          // FALLBACK: If permissions are empty but role_id exists, calculate effective permissions from role
          if ((m['permissions'] == null || (m['permissions'] is List && (m['permissions'] as List).isEmpty)) && m['role_id'] != null) {
            try {
              // Note: we can't do async inside map easily, but we can do it here if we use a for loop or await Future.wait
              // For now, let's keep it simple and rely on the backend fallback I added, or convert this to await for loop.
            } catch (err) { }
          }

          if (kDebugMode) print('📤 [SYNC] Pushing Employee: ${m['id']} - ${m['name']} (Permissions: ${m['permissions']})');
          return m;
        }).toList();
      }

      // Unsynced Credit Sales
      unsyncedCreditSales = await db.query('credit_sales', where: 'is_synced = 0');
      if (unsyncedCreditSales.isNotEmpty) {
        changes['credit_sales'] = unsyncedCreditSales.map((cs) {
          var m = Map.from(cs);
          m.remove('is_synced');
          return m;
        }).toList();
      }

      // Unsynced Credit Payments
      unsyncedCreditPayments = await db.query('credit_payments', where: 'is_synced = 0');
      if (unsyncedCreditPayments.isNotEmpty) {
        changes['credit_payments'] = unsyncedCreditPayments.map((cp) {
          var m = Map.from(cp);
          m.remove('is_synced');
          return m;
        }).toList();
      }

      // Unsynced Suppliers
      unsyncedSuppliers = await db.query('suppliers', where: 'is_synced = 0');
      if (unsyncedSuppliers.isNotEmpty) {
        changes['suppliers'] = unsyncedSuppliers.map((s) {
          var m = Map.from(s);
          m.remove('is_synced');
          return m;
        }).toList();
      }

      // Unsynced Expense Heads
      unsyncedExpenseHeads = await db.query('expense_heads', where: 'is_synced = 0');
      if (unsyncedExpenseHeads.isNotEmpty) {
        changes['expense_heads'] = unsyncedExpenseHeads.map((eh) {
          var m = Map.from(eh);
          m.remove('is_synced');
          return m;
        }).toList();
      }

      // Unsynced Expenses
      unsyncedExpenses = await db.query('expenses', where: 'is_synced = 0');
      if (unsyncedExpenses.isNotEmpty) {
        changes['expenses'] = unsyncedExpenses.map((e) {
          var m = Map.from(e);
          m.remove('is_synced');
          return m;
        }).toList();
      }

      // Unsynced Purchases
      unsyncedPurchases = await db.query('purchases', where: 'is_synced = 0');
      if (unsyncedPurchases.isNotEmpty) {
        List<Map<String, dynamic>> purchasesList = [];
        for (var p in unsyncedPurchases) {
          var m = Map<String, dynamic>.from(p);
          m.remove('is_synced');
          
          // Get items for this purchase
          final items = await db.query('purchase_items', where: 'purchase_id = ?', whereArgs: [p['id']]);
          m['items'] = items.map((item) {
            var itemMap = Map<String, dynamic>.from(item);
            itemMap.remove('is_synced');
            return itemMap;
          }).toList();
          
          purchasesList.add(m);
        }
        changes['purchases'] = purchasesList;
      }

      // Unsynced Shifts
      unsyncedShifts = await db.query('shifts', where: 'is_synced = 0');
      if (unsyncedShifts.isNotEmpty) {
        changes['shifts'] = unsyncedShifts.map((s) {
          var m = Map<String, dynamic>.from(s);
          m.remove('is_synced');
          // Denominations are JSON strings in local DB, server expects them as Map/List
          if (m['opening_denominations'] is String) {
            try { m['opening_denominations'] = jsonDecode(m['opening_denominations']); } catch (_) {}
          }
          if (m['closing_denominations'] is String) {
            try { m['closing_denominations'] = jsonDecode(m['closing_denominations']); } catch (_) {}
          }
          return m;
        }).toList();
      }

      // Unsynced Branches
      unsyncedBranches = await db.query('branches', where: 'is_synced = 0');
      if (unsyncedBranches.isNotEmpty) {
        changes['branches'] = unsyncedBranches.map((b) {
          var m = Map<String, dynamic>.from(b);
          m.remove('is_synced');
          return m;
        }).toList();
      }

      // Unsynced Roles
      unsyncedRoles = await db.query('roles', where: 'is_synced = 0');
      if (unsyncedRoles.isNotEmpty) {
        List<Map<String, dynamic>> rolesList = [];
        for (var r in unsyncedRoles) {
          var m = Map<String, dynamic>.from(r);
          m.remove('is_synced');
          
          // Get permissions for this role
          final perms = await db.rawQuery('''
            SELECT p.id FROM permissions p
            JOIN role_permissions rp ON p.id = rp.permission_id
            WHERE rp.role_id = ?
          ''', [r['id']]);
          
          m['permissions'] = perms.map((p) => p['id']).toList();
          rolesList.add(m);
        }
        changes['roles'] = rolesList;
      }

      if (changes.isEmpty) {
        if (kDebugMode) print('No changes to push');
        return;
      }

      final response = await _api.post('/sync/push', data: {'changes': changes});

      if (response.statusCode == 200 && response.data['success'] == true) {
        await db.transaction((txn) async {
          // Mark sales as synced
          for (var s in unsyncedSales) {
            await txn.update('sales', {'is_synced': 1}, where: 'id = ?', whereArgs: [s['id']]);
          }
          // Mark categories as synced
          if (unsyncedCategories.isNotEmpty) {
            for (var c in unsyncedCategories) {
              await txn.update('categories', {'is_synced': 1}, where: 'id = ?', whereArgs: [c['id']]);
            }
          }
          // Mark customers as synced
          for (var c in unsyncedCustomers) {
            await txn.update('customers', {'is_synced': 1}, where: 'id = ?', whereArgs: [c['id']]);
          }
          // Mark products as synced
          for (var p in unsyncedProducts) {
            await txn.update('products', {'is_synced': 1}, where: 'id = ?', whereArgs: [p['id']]);
            await txn.update('stocks', {'is_synced': 1}, where: 'product_id = ?', whereArgs: [p['id']]);
          }
          // Mark loose stocks as synced
          if (unsyncedStocksForSyncedProducts.isNotEmpty) {
            for (var s in unsyncedStocksForSyncedProducts) {
              await txn.update('stocks', {'is_synced': 1}, where: 'id = ?', whereArgs: [s['id']]);
            }
          }
          // Mark users as synced
          for (var u in unsyncedUsers) {
            await txn.update('users', {'is_synced': 1}, where: 'id = ?', whereArgs: [u['id']]);
          }
          // Mark businesses as synced
          for (var b in unsyncedBusinesses) {
            await txn.update('businesses', {'is_synced': 1}, where: 'id = ?', whereArgs: [b['id']]);
          }
          // Mark employees as synced
          for (var e in unsyncedEmployees) {
            await txn.update('employees', {'is_synced': 1}, where: 'id = ?', whereArgs: [e['id']]);
          }
          // Mark credit sales as synced
          for (var cs in unsyncedCreditSales) {
            await txn.update('credit_sales', {'is_synced': 1}, where: 'id = ?', whereArgs: [cs['id']]);
          }
          // Mark credit payments as synced
          for (var cp in unsyncedCreditPayments) {
            await txn.update('credit_payments', {'is_synced': 1}, where: 'id = ?', whereArgs: [cp['id']]);
          }
          // Mark suppliers as synced
          for (var s in unsyncedSuppliers) {
            await txn.update('suppliers', {'is_synced': 1}, where: 'id = ?', whereArgs: [s['id']]);
          }
          // Mark expense heads as synced
          for (var eh in unsyncedExpenseHeads) {
            await txn.update('expense_heads', {'is_synced': 1}, where: 'id = ?', whereArgs: [eh['id']]);
          }
          // Mark expenses as synced
          for (var e in unsyncedExpenses) {
            await txn.update('expenses', {'is_synced': 1}, where: 'id = ?', whereArgs: [e['id']]);
          }
          // Mark purchases as synced
          if (unsyncedPurchases.isNotEmpty) {
            for (var p in unsyncedPurchases) {
              await txn.update('purchases', {'is_synced': 1}, where: 'id = ?', whereArgs: [p['id']]);
              await txn.update('purchase_items', {'is_synced': 1}, where: 'purchase_id = ?', whereArgs: [p['id']]);
            }
          }
          // Mark shifts as synced
          for (var s in unsyncedShifts) {
            await txn.update('shifts', {'is_synced': 1}, where: 'id = ?', whereArgs: [s['id']]);
          }
          // Mark branches as synced
          for (var b in unsyncedBranches) {
            await txn.update('branches', {'is_synced': 1}, where: 'id = ?', whereArgs: [b['id']]);
          }
          // Mark roles as synced
          for (var r in unsyncedRoles) {
            await txn.update('roles', {'is_synced': 1}, where: 'id = ?', whereArgs: [r['id']]);
          }
        });
        if (kDebugMode) print('Push complete: ${response.data['synced']}');
      }
    } catch (e) {
      if (kDebugMode) print('Sync Push Error: $e');
      rethrow;
    }
  }

  /// Get last sync time
  Future<String?> getLastSyncTime() async {
    return await _storage.read(key: 'last_synced_at');
  }

  /// Force full resync
  Future<void> forceResync() async {
    await _storage.delete(key: 'last_synced_at');
    await syncPull();
  }
  /// Clear all sync state (for logout)
  Future<void> logout() async {
    await _api.logout();
    // KEEP last_synced_at to avoid full re-sync on next login,
    // which would replace local unsynced data.
    // await _storage.delete(key: 'last_synced_at');
  }
}

class SyncResult {
  bool pullSuccess = false;
  bool pushSuccess = false;
  String? pullError;
  String? pushError;

  bool get success => pullSuccess && pushSuccess;
}
