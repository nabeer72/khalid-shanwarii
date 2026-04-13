import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/services/api_service.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_app/db/mock_data.dart';

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
      final pullResponse = await syncPull();
      result.pullSuccess = true;
      
      await syncPush();
      result.pushSuccess = true;

      // EXTREMELY CRITICAL: Only update the last sync timestamp AFTER push is complete.
      if (pullResponse != null && pullResponse['timestamp'] != null) {
        await _storage.write(key: 'last_synced_at', value: pullResponse['timestamp']);
      }
    } catch (e) {
      if (e is DioException) {
        if (kDebugMode) print('Sync Push Error Body: ${e.response?.data}');
      }
      result.pushError = e.toString();
    }
    return result;
  }

  Future<Map<String, dynamic>?> syncPull({bool forceFull = false, bool saveTimestamp = true}) async {
    try {
      String? lastSyncedAt = await _storage.read(key: 'last_synced_at');

      // CRITICAL: If the local database is missing essential transactional data (products),
      // or if it has no users/businesses, we must ignore last_synced_at.
      final db = await _dbHelper.database;
      final userCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM users')) ?? 0;
      final bizCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM businesses')) ?? 0;
      final productCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM products')) ?? 0;
      
      if (userCount == 0 || bizCount == 0 || productCount == 0 || forceFull) {
        lastSyncedAt = null;
        if (kDebugMode) {
          String reason = forceFull ? 'Manual Force' : (productCount == 0 ? 'Empty Inventory' : 'Empty Identity');
          print('🔄 [SYNC] Forcing full sync ($reason)');
        }
      }

      final queryParams = {
        'last_synced_at': lastSyncedAt,
        'branch_id': BusinessConfig.instance.branchId,
        'business_id': BusinessConfig.instance.businessId,
      };
      if (kDebugMode) print('🔍 [SYNC] Pulling data with params: $queryParams');

      final response = await _api.get('/sync/pull', queryParameters: queryParams);

      if (response.statusCode == 200) {
        final data = response.data['changes'];
        final serverTime = response.data['timestamp'];
        if (saveTimestamp && serverTime != null) {
          await _storage.write(key: 'last_synced_at', value: serverTime);
        }
        final db = await _dbHelper.database;
        
        // Use user/business info from response if available (for initial sync)
        final respUser = response.data['user'];
        final respBusiness = response.data['business'];
        
        // Use current session IDs as fallbacks. If it's a staff member, we want to associate data with the admin's context.
        dynamic pId(dynamic v) => v is int ? v : (int.tryParse(v?.toString() ?? '') ?? v);

        final aid = (respUser != null && respUser['admin_id'] != null && respUser['admin_id'].toString().isNotEmpty) 
            ? respUser['admin_id'] 
            : (respUser != null ? respUser['id'] : null);
            
        final brid = respUser != null ? respUser['branch_id'] : null;
        final fallbackBusinessId = BusinessConfig.instance.businessId ?? pId(respBusiness?['id']);
        
        var currentUserId = BusinessConfig.instance.userId;
        
        final fallbackUserId = currentUserId ?? pId(aid);
        final fallbackBranchId = BusinessConfig.instance.branchId ?? pId(brid);

        // [FIX] Initialize BusinessConfig early so that background logic (like reconciliation)
        // has access to the correct context even before the UI updates.
        if (BusinessConfig.instance.businessId == null && fallbackBusinessId != null) {
          BusinessConfig.instance.businessId = fallbackBusinessId;
        }
        if (BusinessConfig.instance.userId == null && fallbackUserId != null) {
          BusinessConfig.instance.userId = fallbackUserId;
        }
        if (BusinessConfig.instance.branchId == null && fallbackBranchId != null) {
          BusinessConfig.instance.branchId = fallbackBranchId;
        }

        int _parseStatus(dynamic v) {
          if (v == null || v == true || v == 1 || v.toString().toLowerCase() == 'active' || v.toString() == '1') return 1;
          return 0;
        }

        if (kDebugMode) {
          print('🔍 [SYNC] Fallback IDs: user=$fallbackUserId, business=$fallbackBusinessId');
          print('🔍 [SYNC] Data Keys: ${data.keys.toList()}');
        }

        // Helper: returns the server's branch_id if non-null, else
        // the fallback, else looks up the existing local row to preserve its branch_id.
        Future<dynamic> _safeBranchId(Transaction t, String table, dynamic rowId, dynamic serverBranchId) async {
          final resolved = serverBranchId is int ? serverBranchId : int.tryParse(serverBranchId?.toString() ?? '');
          final finalBranchId = resolved ?? fallbackBranchId;
          if (finalBranchId != null) return finalBranchId;
          // Preserve existing local branch_id
          if (rowId != null) {
            final rows = await t.query(table, columns: ['branch_id'], where: 'id = ?', whereArgs: [rowId], limit: 1);
            if (rows.isNotEmpty && rows.first['branch_id'] != null) {
              return rows.first['branch_id'];
            }
          }
          return null;
        }

        await db.transaction((txn) async {
          // Businesses 
          if (data['businesses'] != null) {
            for (var b in data['businesses']) {
              await txn.insert('businesses', {
                'id': b['id'] is int ? b['id'] : int.tryParse(b['id']?.toString() ?? ''),
                'name': b['name'] ?? 'Unknown',
                'business_type': b['business_type'],
                'owner_user_id': b['owner_user_id'] ?? b['admin_id'] ?? b['user_id'],
                'status': _parseStatus(b['status']),
                'is_synced': 1,
                'created_at': b['created_at'],
                'updated_at': b['updated_at'],
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
            if (kDebugMode) print('Synced ${data['businesses'].length} businesses');
          }

          // User-Business Mapping
          if (data['user_businesses'] != null) {
            for (var ub in data['user_businesses']) {
              await txn.insert('user_businesses', {
                'user_id': ub['user_id'] is int ? ub['user_id'] : int.tryParse(ub['user_id']?.toString() ?? ''),
                'business_id': ub['business_id'] is int ? ub['business_id'] : int.tryParse(ub['business_id']?.toString() ?? ''),
                'is_synced': 1,
                'created_at': ub['created_at'] ?? DateTime.now().toIso8601String(),
                'updated_at': ub['updated_at'] ?? DateTime.now().toIso8601String(),
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
            if (kDebugMode) print('Synced ${data['user_businesses'].length} user-business mappings');
          }

          // Categories
          if (data['categories'] != null) {
            for (var c in data['categories']) {
              final catId = c['id'] is int ? c['id'] : int.tryParse(c['id']?.toString() ?? '');
              await txn.insert(
                'categories',
                {
                  'id': catId,
                  'business_id': c['business_id'] is int ? c['business_id'] : int.tryParse(c['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                  'branch_id': await _safeBranchId(txn, 'categories', catId, c['branch_id']),
                  'user_id': c['admin_id'] is int ? c['admin_id'] : int.tryParse(c['admin_id']?.toString() ?? '') ?? fallbackUserId,
                  'name': c['name'] ?? 'Unknown',
                  'icon': c['icon'],
                  'parent_id': c['parent_id'] is int ? c['parent_id'] : int.tryParse(c['parent_id']?.toString() ?? ''),
                  'status': _parseStatus(c['status']),
                  'is_synced': 1,
                  'updated_at': c['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            if (kDebugMode) print('Synced ${data['categories'].length} categories');
          }
          
          // Subcategories
          if (data['sub_categories'] != null) {
            for (var sc in data['sub_categories']) {
              final subCatId = sc['id'] is int ? sc['id'] : int.tryParse(sc['id']?.toString() ?? '');
              await txn.insert(
                'subcategories',
                {
                  'id': subCatId,
                  'category_id': sc['category_id'] is int ? sc['category_id'] : int.tryParse(sc['category_id']?.toString() ?? ''),
                  'business_id': sc['business_id'] is int ? sc['business_id'] : int.tryParse(sc['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                  'branch_id': await _safeBranchId(txn, 'subcategories', subCatId, sc['branch_id']),
                  'user_id': sc['admin_id'] is int ? sc['admin_id'] : int.tryParse(sc['admin_id']?.toString() ?? '') ?? fallbackUserId,
                  'name': sc['name'] ?? 'Unknown',
                  'code': sc['code'],
                  'status': _parseStatus(sc['status']),
                  'is_synced': 1,
                  'updated_at': sc['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            if (kDebugMode) print('Synced ${data['sub_categories'].length} subcategories');
          }

          // Products & Stocks
          if (data['products'] != null) {
            for (var i = 0; i < data['products'].length; i++) {
              var p = data['products'][i];
              final productId = p['id'] is int ? p['id'] : int.tryParse(p['id']?.toString() ?? '');
              
              // 1. Insert Product Metadata
              final safeProdBranch = await _safeBranchId(txn, 'products', productId, p['branch_id']);
              final productRow = {
                'id': productId,
                'business_id': p['business_id'] is int ? p['business_id'] : int.tryParse(p['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                'branch_id': safeProdBranch,
                'user_id': p['admin_id'] is int ? p['admin_id'] : int.tryParse(p['admin_id']?.toString() ?? '') ?? fallbackUserId,
                'staff_id': p['user_id'] is int ? p['user_id'] : int.tryParse(p['user_id']?.toString() ?? ''),
                'category_id': p['category_id'] is int ? p['category_id'] : int.tryParse(p['category_id']?.toString() ?? ''),
                'sub_category_id': p['sub_category_id'] is int ? p['sub_category_id'] : int.tryParse(p['sub_category_id']?.toString() ?? ''),
                'name': p['name'] ?? 'Unknown',
                'image': p['image'],
                'description': p['description'],
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
                    'id': s['id'] is int ? s['id'] : int.tryParse(s['id']?.toString() ?? ''),
                    'business_id': productRow['business_id'],
                    'branch_id': s['branch_id'] is int ? s['branch_id'] : int.tryParse(s['branch_id']?.toString() ?? '') ?? productRow['branch_id'],
                    'product_id': productId,
                    'barcode': s['barcode'] ?? productRow['barcode'],
                    'quantity': _parseNum(s['quantity']),
                    'cost_price': _parseNum(s['cost_price'] ?? s['purchase_price']),
                    'sale_price': _parseNum(s['sale_price'] ?? s['price']),
                    'wholesale_price': _parseNum(s['wholesale_price'] ?? s['whole_sale_price']),
                    'alert_quantity': _parseNum(s['alert_quantity'] ?? s['alert_limit'] ?? s['stock_limit']),
                    'discount_limit': _parseNum(s['discount_limit'] ?? s['discount']),
                    'status': _parseStatus(s['status'] ?? 1),
                    'is_synced': 1,
                    'updated_at': s['updated_at'] ?? productRow['updated_at'],
                    'user_id': s['admin_id'] is int ? s['admin_id'] : int.tryParse(s['admin_id']?.toString() ?? '') ?? productRow['user_id'],
                  }, conflictAlgorithm: ConflictAlgorithm.replace);
                }
              } else {
              }
            }
            if (kDebugMode) print('Synced ${data['products'].length} products (and their stocks)');
          }

          // Customers
          if (data['customers'] != null) {
            for (var c in data['customers']) {
              final custId = c['id'] is int ? c['id'] : int.tryParse(c['id']?.toString() ?? '');
              await txn.insert(
                'customers',
                {
                  'id': custId,
                  'business_id': c['business_id'] is int ? c['business_id'] : int.tryParse(c['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                  'branch_id': await _safeBranchId(txn, 'customers', custId, c['branch_id']),
                  'user_id': c['admin_id'] is int ? c['admin_id'] : int.tryParse(c['admin_id']?.toString() ?? '') ?? fallbackUserId,
                  'name': c['name'] ?? 'Unknown',
                  'phone': c['phone'] ?? c['cell_number'],
                  'email': c['email'],
                  'notes': c['notes'],
                  'discount': _parseNum(c['discount'] ?? c['discount_percent'] ?? c['discount_limit']),
                  'credit_balance': _parseNum(c['credit_balance'] ?? c['balance']),
                  'credit_limit': _parseNum(c['credit_limit']),
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
              final employeeId = e['id'] is int ? e['id'] : int.tryParse(e['id']?.toString() ?? '');
              await txn.insert(
                'employees',
                {
                  'id': employeeId,
                  'business_id': e['business_id'] is int ? e['business_id'] : int.tryParse(e['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                  'branch_id': e['branch_id'] is int ? e['branch_id'] : int.tryParse(e['branch_id']?.toString() ?? '') ?? fallbackBranchId,
                  'user_id': e['admin_id'] is int ? e['admin_id'] : int.tryParse(e['admin_id']?.toString() ?? '') ?? fallbackUserId,
                  'name': e['name'] ?? 'Unknown',
                  'email': e['email'],
                  'phone': e['phone'],
                  'role': e['role'] ?? 'cashier',
                  'role_id': e['role_id'] is int ? e['role_id'] : int.tryParse(e['role_id']?.toString() ?? ''),
                  'pin': e['pin'],
                  'permissions': (e['permissions'] is List || e['permissions'] is Map) ? jsonEncode(e['permissions']) : e['permissions'],
                  'status': _parseStatus(e['status']),
                  'is_synced': 1,
                  'updated_at': e['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );

              // Sync Employee Roles (Multi-Role Support)
              if (e['roles'] != null && e['roles'] is List) {
                // Clear existing roles for this employee to avoid duplicates
                await txn.delete('employee_roles', where: 'employee_id = ?', whereArgs: [employeeId]);
                for (var role in e['roles']) {
                  final rid = role['id'] is int ? role['id'] : int.tryParse(role['id']?.toString() ?? '');
                  if (rid != null) {
                    await txn.insert('employee_roles', {
                      'employee_id': employeeId,
                      'role_id': rid,
                    });
                  }
                }
              }
            }
            if (kDebugMode) print('Synced ${data['employees'].length} employees');
          }

          // Roles
          if (data['roles'] != null) {
            for (var r in data['roles']) {
              final rid = r['id'] is int ? r['id'] : int.tryParse(r['id']?.toString() ?? '');
              await txn.insert(
                'roles',
                {
                  'id': rid,
                  'business_id': r['business_id'] is int ? r['business_id'] : int.tryParse(r['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                  'user_id': r['admin_id'] is int ? r['admin_id'] : int.tryParse(r['admin_id']?.toString() ?? '') ?? fallbackUserId,
                  'branch_id': r['branch_id'] is int ? r['branch_id'] : int.tryParse(r['branch_id']?.toString() ?? '') ?? fallbackBranchId,
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
                await txn.delete('role_permissions', where: 'role_id = ?', whereArgs: [rid]);
                for (var p in r['permissions']) {
                  final pid = p['id'] is int ? p['id'] : int.tryParse(p['id']?.toString() ?? '');
                  await txn.insert(
                    'role_permissions',
                    {
                      'role_id': rid,
                      'permission_id': pid,
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
                  'id': p['id'] is int ? p['id'] : int.tryParse(p['id']?.toString() ?? ''),
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
              final saleId = s['id'] is int ? s['id'] : int.tryParse(s['id']?.toString() ?? '');
              await txn.insert(
                'sales',
                {
                  'id': saleId,
                  'business_id': s['business_id'] is int ? s['business_id'] : int.tryParse(s['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                  'branch_id': await _safeBranchId(txn, 'sales', saleId, s['branch_id']),
                  'user_id': s['admin_id'] is int ? s['admin_id'] : int.tryParse(s['admin_id']?.toString() ?? '') ?? fallbackUserId,
                  'customer_id': s['customer_id'] is int ? s['customer_id'] : int.tryParse(s['customer_id']?.toString() ?? ''),
                  'staff_id': s['user_id'] is int ? s['user_id'] : int.tryParse(s['user_id']?.toString() ?? ''),
                  'sub_total': _parseNum(s['sub_total'] ?? s['subtotal']),
                  'tax': _parseNum(s['tax']),
                  'discount': _parseNum(s['discount']),
                  'total': _parseNum(s['total']),
                  'payment_method': s['payment_method'] ?? 'cash',
                  'payment_type_id': s['payment_type_id'] is int ? s['payment_type_id'] : int.tryParse(s['payment_type_id']?.toString() ?? ''),
                  'is_return': (s['is_return'] == true || s['is_return'] == 1) ? 1 : 0,
                  'total_tip': _parseNum(s['total_tip'] ?? s['tip']),
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
                      'id': item['id'] is int ? item['id'] : int.tryParse(item['id']?.toString() ?? ''),
                      'sale_id': saleId,
                      'product_id': item['product_id'] is int ? item['product_id'] : int.tryParse(item['product_id']?.toString() ?? ''),
                      'branch_id': s['branch_id'] is int ? s['branch_id'] : int.tryParse(s['branch_id']?.toString() ?? '') ?? fallbackBranchId,
                      'user_id': item['user_id'] ?? item['admin_id'] ?? s['admin_id'] ?? s['user_id'] ?? fallbackUserId,
                      'quantity': _parseNum(item['quantity']),
                      'price': _parseNum(item['price'] ?? item['sale_price'] ?? item['unit_price'] ?? item['selling_price']),
                      'sub_total': _parseNum(item['sub_total'] ?? item['subtotal'] ?? item['total']),
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
              final csId = cs['id'] is int ? cs['id'] : int.tryParse(cs['id']?.toString() ?? '');

              // CRITICAL: If this credit_sale has local unsynced changes (e.g. a recovery
              // payment reduced its remaining_balance), do NOT overwrite it with the
              // server's stale value. Otherwise reconcileCustomerBalances() will reinflate
              // the customer's credit balance, reversing the recovery.
              if (csId != null) {
                final localRows = await txn.query(
                  'credit_sales',
                  columns: ['is_synced'],
                  where: 'id = ?',
                  whereArgs: [csId],
                  limit: 1,
                );
                if (localRows.isNotEmpty && localRows.first['is_synced'] == 0) {
                  if (kDebugMode) print('⚠️ [SYNC] Skipping pull for credit_sale $csId (local payment pending push)');
                  continue;
                }
              }

              await txn.insert(
                'credit_sales',
                {
                  'id': csId,
                  'business_id': cs['business_id'] is int ? cs['business_id'] : int.tryParse(cs['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                  'branch_id': cs['branch_id'] is int ? cs['branch_id'] : int.tryParse(cs['branch_id']?.toString() ?? '') ?? fallbackBranchId,
                  'user_id': cs['admin_id'] is int ? cs['admin_id'] : int.tryParse(cs['admin_id']?.toString() ?? '') ?? fallbackUserId,
                  'customer_id': cs['customer_id'] is int ? cs['customer_id'] : int.tryParse(cs['customer_id']?.toString() ?? ''),
                  'sale_id': cs['sale_id'] is int ? cs['sale_id'] : int.tryParse(cs['sale_id']?.toString() ?? ''),
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
                  'id': cp['id'] is int ? cp['id'] : int.tryParse(cp['id']?.toString() ?? ''),
                  'business_id': cp['business_id'] is int ? cp['business_id'] : int.tryParse(cp['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                  'branch_id': cp['branch_id'] is int ? cp['branch_id'] : int.tryParse(cp['branch_id']?.toString() ?? '') ?? fallbackBranchId,
                  'user_id': cp['admin_id'] is int ? cp['admin_id'] : int.tryParse(cp['admin_id']?.toString() ?? '') ?? fallbackUserId,
                  'credit_sale_id': cp['credit_sale_id'] is int ? cp['credit_sale_id'] : int.tryParse(cp['credit_sale_id']?.toString() ?? ''),
                  'customer_id': cp['customer_id'] is int ? cp['customer_id'] : int.tryParse(cp['customer_id']?.toString() ?? ''),
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
          await _dbHelper.reconcileSupplierBalances(txn);

          // Suppliers
          if (data['suppliers'] != null) {
            for (var s in data['suppliers']) {
              await txn.insert(
                'suppliers',
                {
                  'id': s['id'] is int ? s['id'] : int.tryParse(s['id']?.toString() ?? ''),
                  'business_id': s['business_id'] is int ? s['business_id'] : int.tryParse(s['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                  'branch_id': s['branch_id'] is int ? s['branch_id'] : int.tryParse(s['branch_id']?.toString() ?? '') ?? fallbackBranchId,
                  'user_id': s['admin_id'] is int ? s['admin_id'] : int.tryParse(s['admin_id']?.toString() ?? '') ?? fallbackUserId,
                  'name': s['name'] ?? 'Unknown',
                  'contact_person': s['contact_person'],
                  'phone': s['cell_number'], // Backend calls it cell_number
                  'email': s['email'],
                  'address': s['address'],
                  'opening_amount': _parseNum(s['opening_amount'] ?? s['opening_balance']), 
                  'credit_balance': _parseNum(s['credit_balance'] ?? s['balance']),  // Keep visible balance in sync
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
              final pid = p['id'] is int ? p['id'] : int.tryParse(p['id']?.toString() ?? '');
              await txn.insert(
                'purchases',
                {
                  'id': pid,
                  'business_id': p['business_id'] is int ? p['business_id'] : int.tryParse(p['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                  'branch_id': p['branch_id'] is int ? p['branch_id'] : int.tryParse(p['branch_id']?.toString() ?? '') ?? fallbackBranchId,
                  'user_id': p['admin_id'] is int ? p['admin_id'] : int.tryParse(p['admin_id']?.toString() ?? '') ?? fallbackUserId,
                  'supplier_id': p['vendor_id'] is int ? p['vendor_id'] : int.tryParse(p['vendor_id']?.toString() ?? ''),
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
                      'id': item['id'] is int ? item['id'] : int.tryParse(item['id']?.toString() ?? ''),
                      'purchase_id': pid,
                      'product_id': item['product_id'] is int ? item['product_id'] : int.tryParse(item['product_id']?.toString() ?? ''),
                      'branch_id': p['branch_id'] is int ? p['branch_id'] : int.tryParse(p['branch_id']?.toString() ?? '') ?? fallbackBranchId,
                      'user_id': p['admin_id'] is int ? p['admin_id'] : int.tryParse(p['admin_id']?.toString() ?? '') ?? fallbackUserId,
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
                  'id': eh['id'] is int ? eh['id'] : int.tryParse(eh['id']?.toString() ?? ''),
                  'business_id': eh['business_id'] is int ? eh['business_id'] : int.tryParse(eh['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                  'branch_id': eh['branch_id'] is int ? eh['branch_id'] : int.tryParse(eh['branch_id']?.toString() ?? '') ?? fallbackBranchId,
                  'user_id': eh['admin_id'] is int ? eh['admin_id'] : int.tryParse(eh['admin_id']?.toString() ?? '') ?? fallbackUserId,
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
                  'id': e['id'] is int ? e['id'] : int.tryParse(e['id']?.toString() ?? ''),
                  'business_id': e['business_id'] is int ? e['business_id'] : int.tryParse(e['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                  'branch_id': e['branch_id'] is int ? e['branch_id'] : int.tryParse(e['branch_id']?.toString() ?? '') ?? fallbackBranchId,
                  'user_id': e['admin_id'] is int ? e['admin_id'] : int.tryParse(e['admin_id']?.toString() ?? '') ?? fallbackUserId,
                  'expense_head_id': e['expense_head_id'] is int ? e['expense_head_id'] : int.tryParse(e['expense_head_id']?.toString() ?? ''),
                  'amount': _parseNum(e['amount']),
                  'description': e['remarks'] ?? e['remark'] ?? e['title'], // Prioritize 'remarks' from backend migration
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
                  'id': s['id'] is int ? s['id'] : int.tryParse(s['id']?.toString() ?? ''),
                  'business_id': s['business_id'] is int ? s['business_id'] : int.tryParse(s['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                  'branch_id': s['branch_id'] is int ? s['branch_id'] : int.tryParse(s['branch_id']?.toString() ?? '') ?? fallbackBranchId,
                  'user_id': s['admin_id'] is int ? s['admin_id'] : int.tryParse(s['admin_id']?.toString() ?? '') ?? fallbackUserId,
                  'staff_id': s['user_id'] is int ? s['user_id'] : int.tryParse(s['user_id']?.toString() ?? ''),
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
              final branchId = b['id'] is int ? b['id'] : int.tryParse(b['id']?.toString() ?? '');
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
                  'business_id': b['business_id'] is int ? b['business_id'] : int.tryParse(b['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                  'user_id': b['admin_id'] is int ? b['admin_id'] : int.tryParse(b['admin_id']?.toString() ?? '') ?? fallbackUserId,
                  'branch_id': b['branch_id'] is int ? b['branch_id'] : int.tryParse(b['branch_id']?.toString() ?? '') ?? branchId,
                  'staff_id': b['user_id'] is int ? b['user_id'] : int.tryParse(b['user_id']?.toString() ?? ''),
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
              final bankId = b['id'] is int ? b['id'] : int.tryParse(b['id']?.toString() ?? '');
              
              // CRITICAL: Avoid overwriting local records that have unsynced changes.
              // If the record exists locally and is_synced = 0, we skip the pull update for this row.
              if (bankId != null) {
                final localRows = await txn.query('bank_accounts', columns: ['is_synced'], where: 'id = ?', whereArgs: [bankId], limit: 1);
                if (localRows.isNotEmpty && localRows.first['is_synced'] == 0) {
                  if (kDebugMode) print('⚠️ [SYNC] Skipping pull for bank account $bankId (local changes pending push)');
                  continue;
                }
              }

              await txn.insert(
                'bank_accounts',
                {
                  'id': bankId,
                  'business_id': b['business_id'] is int ? b['business_id'] : int.tryParse(b['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                  'user_id': b['admin_id'] is int ? b['admin_id'] : int.tryParse(b['admin_id']?.toString() ?? '') ?? fallbackUserId,
                  'branch_id': b['branch_id'] is int ? b['branch_id'] : int.tryParse(b['branch_id']?.toString() ?? '') ?? fallbackBranchId,
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

          // Returns
          if (data['returns'] != null) {
            for (var r in data['returns']) {
              final returnId = r['id'] is int ? r['id'] : int.tryParse(r['id']?.toString() ?? '');
              await txn.insert(
                'returns',
                {
                  'id': returnId,
                  'business_id': r['business_id'] is int ? r['business_id'] : int.tryParse(r['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                  'branch_id': await _safeBranchId(txn, 'returns', returnId, r['branch_id']),
                  'user_id': r['admin_id'] is int ? r['admin_id'] : int.tryParse(r['admin_id']?.toString() ?? '') ?? fallbackUserId,
                  'sale_id': r['sale_id'] is int ? r['sale_id'] : int.tryParse(r['sale_id']?.toString() ?? ''),
                  'customer_id': r['customer_id'] is int ? r['customer_id'] : int.tryParse(r['customer_id']?.toString() ?? ''),
                  'staff_id': r['user_id'] is int ? r['user_id'] : int.tryParse(r['user_id']?.toString() ?? ''),
                  'payment_type_id': r['payment_type_id'] is int ? r['payment_type_id'] : int.tryParse(r['payment_type_id']?.toString() ?? ''),
                  'total': _parseNum(r['total_amount'] ?? r['total']),
                  'sub_total': _parseNum(r['subtotal'] ?? r['sub_total']),
                  'tax': _parseNum(r['tax']),
                  'discount': _parseNum(r['discount']),
                  'reason': r['reason'],
                  'status': _parseStatus(r['status']),
                  'is_synced': 1,
                  'created_at': r['created_at'],
                  'updated_at': r['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );

              if (r['return_items'] != null) {
                for (var item in r['return_items']) {
                  await txn.insert(
                    'return_items',
                    {
                      'id': item['id'] is int ? item['id'] : int.tryParse(item['id']?.toString() ?? ''),
                      'return_id': returnId,
                      'sale_item_id': item['sale_item_id'] is int ? item['sale_item_id'] : int.tryParse(item['sale_item_id']?.toString() ?? ''),
                      'product_id': item['product_id'] is int ? item['product_id'] : int.tryParse(item['product_id']?.toString() ?? ''),
                      'stock_id': item['stock_id'] is int ? item['stock_id'] : int.tryParse(item['stock_id']?.toString() ?? ''),
                      'business_id': item['business_id'] is int ? item['business_id'] : int.tryParse(item['business_id']?.toString() ?? ''),
                      'user_id': item['user_id'] is int ? item['user_id'] : int.tryParse(item['user_id']?.toString() ?? ''),
                      'quantity': _parseNum(item['quantity']),
                      'price': _parseNum(item['price']),
                      'sub_total': _parseNum(item['sub_total'] ?? item['subtotal']),
                      'discount': _parseNum(item['discount']),
                    },
                    conflictAlgorithm: ConflictAlgorithm.replace,
                  );
                }
              }
            }
            if (kDebugMode) print('Synced ${data['returns'].length} returns');
          }

          // Supplier Credit Purchases
          if (data['supplier_credit_purchases'] != null) {
            for (var scp in data['supplier_credit_purchases']) {
              await txn.insert(
                'supplier_credit_purchases',
                {
                  'id': scp['id'] is int ? scp['id'] : int.tryParse(scp['id']?.toString() ?? ''),
                  'business_id': scp['business_id'] is int ? scp['business_id'] : int.tryParse(scp['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                  'branch_id': scp['branch_id'] is int ? scp['branch_id'] : int.tryParse(scp['branch_id']?.toString() ?? '') ?? fallbackBranchId,
                  'user_id': scp['admin_id'] is int ? scp['admin_id'] : int.tryParse(scp['admin_id']?.toString() ?? '') ?? fallbackUserId,
                  'supplier_id': scp['supplier_id'] is int ? scp['supplier_id'] : int.tryParse(scp['supplier_id']?.toString() ?? ''),
                  'purchase_id': scp['purchase_id'] is int ? scp['purchase_id'] : int.tryParse(scp['purchase_id']?.toString() ?? ''),
                  'amount': _parseNum(scp['amount']),
                  'remaining_balance': _parseNum(scp['remaining_balance']),
                  'status': scp['status'] ?? 1,
                  'is_synced': 1,
                  'created_at': scp['created_at'],
                  'updated_at': scp['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            if (kDebugMode) print('Synced ${data['supplier_credit_purchases'].length} supplier credit purchases');
          }

           // Stock Audits
           if (data['stock_audits'] != null) {
             for (var sa in data['stock_audits']) {
               final saId = sa['id'] is int ? sa['id'] : int.tryParse(sa['id']?.toString() ?? '');
               await txn.insert(
                 'stock_audits',
                 {
                   'id': saId,
                   'business_id': sa['business_id'] is int ? sa['business_id'] : int.tryParse(sa['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                   'user_id': sa['admin_id'] is int ? sa['admin_id'] : int.tryParse(sa['admin_id']?.toString() ?? '') ?? fallbackUserId,
                   'staff_id': sa['user_id'] is int ? sa['user_id'] : int.tryParse(sa['user_id']?.toString() ?? ''),
                   'branch_id': sa['branch_id'] is int ? sa['branch_id'] : int.tryParse(sa['branch_id']?.toString() ?? '') ?? fallbackBranchId,
                   'stock_id': sa['stock_id'] is int ? sa['stock_id'] : int.tryParse(sa['stock_id']?.toString() ?? ''),
                   'product_id': sa['product_id'] is int ? sa['product_id'] : int.tryParse(sa['product_id']?.toString() ?? ''),
                   'old_quantity': _parseNum(sa['old_quantity']),
                   'new_quantity': _parseNum(sa['new_quantity']),
                   'old_purchase_price': _parseNum(sa['old_purchase_price']),
                   'new_purchase_price': _parseNum(sa['new_purchase_price']),
                   'old_sale_price': _parseNum(sa['old_sale_price']),
                   'new_sale_price': _parseNum(sa['new_sale_price']),
                   'remarks': sa['remarks'],
                   'is_synced': 1,
                   'created_at': sa['created_at'],
                   'updated_at': sa['updated_at'],
                 },
                 conflictAlgorithm: ConflictAlgorithm.replace,
               );
             }
             if (kDebugMode) print('Synced ${data['stock_audits'].length} stock audits');
           }
 
           // [NEW] Top-level Stocks pull (for cases where stocks are sent as standalone entities)
           if (data['stocks'] != null) {
             for (var s in data['stocks']) {
               final sId = s['id'] is int ? s['id'] : int.tryParse(s['id']?.toString() ?? '');
               final productId = s['product_id'] is int ? s['product_id'] : int.tryParse(s['product_id']?.toString() ?? '');
               
               await txn.insert('stocks', {
                 'id': sId,
                 'business_id': s['business_id'] is int ? s['business_id'] : int.tryParse(s['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                 'branch_id': s['branch_id'] is int ? s['branch_id'] : int.tryParse(s['branch_id']?.toString() ?? '') ?? fallbackBranchId,
                 'product_id': productId,
                 'user_id': s['admin_id'] is int ? s['admin_id'] : int.tryParse(s['admin_id']?.toString() ?? '') ?? fallbackUserId,
                 'barcode': s['barcode'] ?? s['code'],
                 'quantity': _parseNum(s['quantity']),
                 'cost_price': _parseNum(s['cost_price'] ?? s['purchase_price']),
                 'sale_price': _parseNum(s['sale_price'] ?? s['price']),
                 'wholesale_price': _parseNum(s['wholesale_price'] ?? s['whole_sale_price']),
                 'alert_quantity': _parseNum(s['alert_quantity'] ?? s['alert_limit'] ?? s['stock_limit']),
                 'discount_limit': _parseNum(s['discount_limit'] ?? s['discount']),
                 'status': _parseStatus(s['status'] ?? 1),
                 'is_synced': 1,
                 'updated_at': s['updated_at'],
               }, conflictAlgorithm: ConflictAlgorithm.replace);
             }
             if (kDebugMode) print('Synced ${data['stocks'].length} standalone stocks');
           }

          // Supplier Paybacks
          if (data['supplier_paybacks'] != null) {
            for (var sp in data['supplier_paybacks']) {
              await txn.insert(
                'supplier_paybacks',
                {
                  'id': sp['id'] is int ? sp['id'] : int.tryParse(sp['id']?.toString() ?? ''),
                  'business_id': sp['business_id'] is int ? sp['business_id'] : int.tryParse(sp['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                  'branch_id': sp['branch_id'] is int ? sp['branch_id'] : int.tryParse(sp['branch_id']?.toString() ?? '') ?? fallbackBranchId,
                  'user_id': sp['admin_id'] is int ? sp['admin_id'] : int.tryParse(sp['admin_id']?.toString() ?? '') ?? fallbackUserId,
                  'supplier_credit_purchase_id': sp['supplier_credit_purchase_id'] is int ? sp['supplier_credit_purchase_id'] : int.tryParse(sp['supplier_credit_purchase_id']?.toString() ?? ''),
                  'supplier_id': sp['supplier_id'] is int ? sp['supplier_id'] : int.tryParse(sp['supplier_id']?.toString() ?? ''),
                  'amount': _parseNum(sp['amount']),
                  'paid_by': sp['paid_by'],
                  'payment_date': sp['payment_date'],
                  'notes': sp['notes'],
                  'is_synced': 1,
                  'created_at': sp['created_at'],
                  'updated_at': sp['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            if (kDebugMode) print('Synced ${data['supplier_paybacks'].length} supplier paybacks');
          }
          
        // Currency Notes
          if (data['currency_notes'] != null) {
            for (var cn in data['currency_notes']) {
              await txn.insert(
                'currency_notes',
                {
                  'id': cn['id'] is int ? cn['id'] : int.tryParse(cn['id']?.toString() ?? ''),
                  'business_id': cn['business_id'] is int ? cn['business_id'] : int.tryParse(cn['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                  'user_id': cn['admin_id'] is int ? cn['admin_id'] : int.tryParse(cn['admin_id']?.toString() ?? '') ?? fallbackUserId,
                  'branch_id': cn['branch_id'] is int ? cn['branch_id'] : int.tryParse(cn['branch_id']?.toString() ?? '') ?? fallbackBranchId,
                  'value': _parseNum(cn['value']),
                  'label': cn['label'],
                  'status': cn['status'] ?? 1,
                  'is_synced': 1,
                  'created_at': cn['created_at'],
                  'updated_at': cn['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            if (kDebugMode) print('Synced ${data['currency_notes'].length} currency notes');
          }

          // Brands
          if (data['brands'] != null) {
            for (var b in data['brands']) {
              await txn.insert(
                'brands',
                {
                  'id': b['id'] is int ? b['id'] : int.tryParse(b['id']?.toString() ?? ''),
                  'business_id': b['business_id'] is int ? b['business_id'] : int.tryParse(b['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                  'branch_id': b['branch_id'] is int ? b['branch_id'] : int.tryParse(b['branch_id']?.toString() ?? '') ?? fallbackBranchId,
                  'user_id': b['admin_id'] is int ? b['admin_id'] : int.tryParse(b['admin_id']?.toString() ?? '') ?? fallbackUserId,
                  'name': b['name'] ?? 'Unknown',
                  'code': b['code'],
                  'status': b['status'] ?? 1,
                  'is_synced': 1,
                  'created_at': b['created_at'],
                  'updated_at': b['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            if (kDebugMode) print('Synced ${data['brands'].length} brands');
          }

          // Units
          if (data['units'] != null) {
            for (var u in data['units']) {
              final uid = u['id'] is int ? u['id'] : int.tryParse(u['id']?.toString() ?? '');
              await txn.insert(
                'units',
                {
                  'id': uid,
                  'business_id': u['business_id'] is int ? u['business_id'] : int.tryParse(u['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                  'user_id': u['admin_id'] is int ? u['admin_id'] : int.tryParse(u['admin_id']?.toString() ?? '') ?? fallbackUserId,
                  'branch_id': await _safeBranchId(txn, 'units', uid, u['branch_id']),
                  'staff_id': u['user_id'] is int ? u['user_id'] : int.tryParse(u['user_id']?.toString() ?? ''),
                  'name': u['name'] ?? 'Unknown',
                  'short_name': u['short_name'],
                  'status': _parseStatus(u['status']),
                  'is_synced': 1,
                  'created_at': u['created_at'],
                  'updated_at': u['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            if (kDebugMode) print('Synced ${data['units'].length} units');
          }

          // Payment Types
          if (data['payment_types'] != null) {
            for (var pt in data['payment_types']) {
              final ptId = pt['id'] is int ? pt['id'] : int.tryParse(pt['id']?.toString() ?? '');
              await txn.insert(
                'payment_types',
                {
                  'id': ptId,
                  'business_id': pt['business_id'] is int ? pt['business_id'] : int.tryParse(pt['business_id']?.toString() ?? '') ?? fallbackBusinessId,
                  'user_id': pt['admin_id'] is int ? pt['admin_id'] : int.tryParse(pt['admin_id']?.toString() ?? '') ?? fallbackUserId,
                  'name': pt['name'] ?? 'Unknown',
                  'code': pt['code'],
                  'status': _parseStatus(pt['status']),
                  'is_synced': 1,
                  'created_at': pt['created_at'],
                  'updated_at': pt['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            if (kDebugMode) print('Synced ${data['payment_types'].length} payment_types');
          }

          // [NEW] Businesses
          if (data['businesses'] != null) {
            for (var b in data['businesses']) {
              await txn.insert(
                'businesses',
                {
                  'id': b['id'] is int ? b['id'] : int.tryParse(b['id']?.toString() ?? ''),
                  'name': b['name'] ?? 'Unknown',
                  'business_type': b['business_type'],
                  'owner_user_id': b['owner_user_id'] is int ? b['owner_user_id'] : int.tryParse(b['owner_user_id']?.toString() ?? ''),
                  'status': _parseStatus(b['status']),
                  'is_synced': 1,
                  'created_at': b['created_at'],
                  'updated_at': b['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            if (kDebugMode) print('Synced ${data['businesses'].length} businesses');
          }

          // [NEW] User Businesses
          if (data['user_businesses'] != null) {
            for (var ub in data['user_businesses']) {
              await txn.insert(
                'user_businesses',
                {
                  'id': ub['id'] is int ? ub['id'] : int.tryParse(ub['id']?.toString() ?? ''),
                  'user_id': ub['user_id'] is int ? ub['user_id'] : int.tryParse(ub['user_id']?.toString() ?? ''),
                  'business_id': ub['business_id'] is int ? ub['business_id'] : int.tryParse(ub['business_id']?.toString() ?? ''),
                  'is_synced': 1,
                  'created_at': ub['created_at'],
                  'updated_at': ub['updated_at'],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            if (kDebugMode) print('Synced ${data['user_businesses'].length} user_businesses');
          }


        });


        // REMOVED: await _storage.write(key: 'last_synced_at', value: serverTime);
        // We now return the full response to be processed (timerstamp saved after push).
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
      List<Map<String, dynamic>> unsyncedBankAccounts = [];
      List<Map<String, dynamic>> unsyncedSupplierPaybacks = [];
      List<Map<String, dynamic>> unsyncedSupplierCreditPurchases = [];
      List<Map<String, dynamic>> unsyncedGiftCards = [];
      List<Map<String, dynamic>> unsyncedCurrencyNotes = [];
      List<Map<String, dynamic>> unsyncedUserBusinesses = [];
      List<Map<String, dynamic>> unsyncedBrands = [];

      final bid = _parseNum(BusinessConfig.instance.businessId).toInt();
      final uid = _parseNum(BusinessConfig.instance.userId).toInt();
      final businessFilter = 'business_id = ? AND user_id = ?';
      final businessArgs = [bid, uid];

       // Unsynced Sales
       unsyncedSales = await db.query('sales', where: 'is_synced = 0 AND $businessFilter', whereArgs: businessArgs);
       if (unsyncedSales.isNotEmpty) {
         changes['sales'] = [];
         for (var sale in unsyncedSales) {
           final items = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [sale['id']]);
           Map<String, dynamic> saleData = Map.from(sale);
           saleData.remove('is_synced');
           
           // Standardize IDs for server
           saleData['user_id'] = saleData['user_id'] ?? uid;
           // staff_id remains as is in the map
           
           // Naming harmonization for server
           saleData['tip'] = saleData['total_tip'];
           saleData['subtotal'] = saleData['sub_total'];
           saleData.remove('total_tip');
           saleData.remove('sub_total');
           
           // Re-inject payment_type_id if it was renamed/nested by server legacy logic
           saleData['payment_type_id'] = saleData['payment_type_id'];
           
           // [FIX] Backend expects 'items' key, not 'sale_details'
           // and expects 'price' and 'subtotal' fields within each item.
           saleData['items'] = items.map((i) {
             var m = Map.from(i);
             m.remove('is_synced');
            m['remarks'] = m['description'];
            
            // Send redundant keys for better server compatibility
            m['description'] = m['description'];
            
            // Send redundant keys for better server compatibility
            m['description'] = m['description'];
             
             // Item naming harmonization
             m['price'] = m['price']; // Keep 'price' for server
             m['subtotal'] = m['sub_total'];
             // m.remove('price'); // Do NOT remove 'price'
             m.remove('sub_total');
             
             m['business_id'] ??= bid;
             m['user_id'] = m['user_id'] ?? uid;
             
             return m;
           }).toList();
           
           changes['sales']?.add(saleData);
         }
       }

       // Unsynced Returns
       List<Map<String, dynamic>> unsyncedReturns = await db.query('returns', where: 'is_synced = 0 AND $businessFilter', whereArgs: businessArgs);
       if (unsyncedReturns.isNotEmpty) {
         changes['returns'] = [];
         for (var ret in unsyncedReturns) {
           final items = await db.query('return_items', where: 'return_id = ?', whereArgs: [ret['id']]);
           Map<String, dynamic> retData = Map.from(ret);
           retData.remove('is_synced');
           
           // Standardize IDs for server
           retData['user_id'] = retData['user_id'] ?? uid;
           
           // Map local names to server names
           retData['total_amount'] = retData['total'];
           retData['subtotal'] = retData['sub_total'];
           retData['payment_type_id'] = retData['payment_type_id'];
           retData['sale_id'] = retData['sale_id'];

           retData.remove('total');
           retData.remove('sub_total');
           
           retData['items'] = items.map((i) {
             var m = Map.from(i);
             m['business_id'] ??= bid;
             m['user_id'] = m['user_id'] ?? uid;
             m['subtotal'] = m['sub_total'];
             m.remove('sub_total');
             return m;
           }).toList();
           changes['returns']?.add(retData);
         }
       }

      // Unsynced Categories
      unsyncedCategories = await db.query('categories', where: 'is_synced = 0 AND $businessFilter', whereArgs: businessArgs);
      if (unsyncedCategories.isNotEmpty) {
        changes['categories'] = unsyncedCategories.map((c) {
          var m = Map.from(c);
          m.remove('is_synced');
          m['user_id'] = m['user_id'];
          return m;
        }).toList();
      }

       // Unsynced Subcategories
       final unsyncedSubCategories = await db.query('subcategories', where: 'is_synced = 0 AND $businessFilter', whereArgs: businessArgs);
       if (unsyncedSubCategories.isNotEmpty) {
         changes['sub_categories'] = unsyncedSubCategories.map((sc) {
           var m = Map<String, dynamic>.from(sc);
           m.remove('is_synced');
           
           // Ensure naming consistency
           m['category_id'] = _parseNum(m['category_id']).toInt();
           m['business_id'] ??= bid;
           m['user_id'] = m['user_id'] ?? uid;
           // m.remove('user_id');
           
           return m;
         }).toList();
       }

       // Unsynced Brands
       unsyncedBrands = await db.query('brands', where: 'is_synced = 0 AND $businessFilter', whereArgs: businessArgs);
       if (unsyncedBrands.isNotEmpty) {
         changes['brands'] = unsyncedBrands.map((b) {
           var m = Map<String, dynamic>.from(b);
           m.remove('is_synced');
           m['business_id'] ??= bid;
           m['user_id'] = m['user_id'] ?? uid;
           // m.remove('user_id');
           return m;
         }).toList();
       }

      // Unsynced Customers
      unsyncedCustomers = await db.query('customers', where: 'is_synced = 0 AND $businessFilter', whereArgs: businessArgs);
      if (unsyncedCustomers.isNotEmpty) {
        changes['customers'] = unsyncedCustomers.map((c) {
          var m = Map.from(c);
          m.remove('is_synced');
          // Defensive mapping for backend (mirroring syncPull fallbacks)
          m['cell_number'] = c['phone'];
          m['discount_percent'] = c['discount'];
          m['discount_limit'] = c['discount'];
          m['balance'] = c['credit_balance'];
          m['credit_limit'] = c['credit_limit'];
          m['user_id'] = m['user_id'] ?? uid;
          // m.remove('user_id');
          return m;
        }).toList();
      }

      // Unsynced Products & their Stocks
      unsyncedProducts = await db.query('products', where: 'is_synced = 0 AND $businessFilter', whereArgs: businessArgs);
      if (unsyncedProducts.isNotEmpty) {
        List<Map<String, dynamic>> productsList = [];
        for (var p in unsyncedProducts) {
          var productMap = Map<String, dynamic>.from(p);
          productMap.remove('is_synced');
          
          if (p['id'] == null) {
            if (kDebugMode) print('⚠️ [SYNC] Skipping product with null ID: ${p['name']}');
            continue;
          }

           if (kDebugMode) print('📤 [SYNC] Pushing new product: ${p['name']} (ID: ${p['id']})');
           
           // Map local IDs to server keys
           productMap['user_id'] = productMap['user_id'] ?? uid;
           // productMap.remove('user_id');
           // productMap['user_id'] = productMap['staff_id'];
           // productMap.remove('staff_id');
           
           // CRITICAL: Inject legacy stock/pricing fields for the server's sync logic.
           // These are calculated on-the-fly and not stored in the local products table.
           final stockResult = await db.rawQuery(
             'SELECT SUM(quantity) as total, MAX(sale_price) as max_price, MAX(cost_price) as max_cost FROM stocks WHERE product_id = ?',
             [p['id']]
           );
           productMap['stock_quantity'] = (stockResult.first['total'] as num? ?? 0).toDouble();
           productMap['price'] = (stockResult.first['max_price'] as num? ?? 0).toDouble();
           productMap['purchase_price'] = (stockResult.first['max_cost'] as num? ?? 0).toDouble();
           productMap['wholesale_price'] = 0.0; // Minimal default
           productMap['barcode'] ??= ''; // Ensure barcode exists
           
           productsList.add(productMap);
        }
        changes['products'] = productsList;
      }

      // Unsynced Stocks (All - including new and existing products)
      // We look for any stocks where is_synced = 0 that belong to THIS business context.
      final List<Map<String, dynamic>> unsyncedStocks = await db.query(
        'stocks', 
        where: 'is_synced = 0 AND $businessFilter', 
        whereArgs: businessArgs
      );
      
       if (unsyncedStocks.isNotEmpty) {
         changes['stocks'] = unsyncedStocks.map((s) {
           var m = Map<String, dynamic>.from(s);
           m.remove('is_synced');
           m['business_id'] ??= bid;
           m['user_id'] = m['user_id'] ?? uid;
           return m;
         }).toList();
         if (kDebugMode) print('📤 [SYNC] Pushing ${unsyncedStocks.length} total price/stock entries');
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

      // Unsynced Businesses (from signup or profile edit)
      unsyncedBusinesses = await _dbHelper.getUnsyncedBusinesses();
      if (unsyncedBusinesses.isNotEmpty) {
        changes['businesses'] = unsyncedBusinesses.map((b) {
          var m = Map.from(b);
          m.remove('is_synced');
          
          // Inject local settings into the business payload 
          // so the backend can update the business profile correctly.
          m['business_name'] = BusinessConfig.instance.businessName;
          m['name'] = BusinessConfig.instance.businessName;
          m['address'] = BusinessConfig.instance.businessAddress;
          m['business_address'] = BusinessConfig.instance.businessAddress;
          m['phone'] = BusinessConfig.instance.businessPhone;
          m['business_phone'] = BusinessConfig.instance.businessPhone;
          m['contact_number'] = BusinessConfig.instance.businessPhone;
          m['receipt_footer'] = BusinessConfig.instance.receiptFooter;
          
          return m;
        }).toList();
      }
       // [NEW] Unsynced Branches - MOVE BEFORE ROLES/EMPLOYEES so server can map branch IDs
       unsyncedBranches = await db.query('branches', where: 'is_synced = 0 AND $businessFilter', whereArgs: businessArgs);
       if (unsyncedBranches.isNotEmpty) {
         changes['branches'] = unsyncedBranches.map((b) {
           var m = Map<String, dynamic>.from(b);
           m.remove('is_synced');
           
           // Naming harmonization for server
           m['name'] = m['branch_title'];
           m['address'] = m['branch_address'];
           m['cell_number'] = m['contact_number'];
           
           return m;
         }).toList();
       }

      // [NEW] Unsynced Roles - MOVE BEFORE EMPLOYEES for backend dependency resolution
      unsyncedRoles = await db.query('roles', where: 'is_synced = 0 AND $businessFilter', whereArgs: businessArgs);
      if (unsyncedRoles.isNotEmpty) {
        List<Map<String, dynamic>> rolesList = [];
        for (var r in unsyncedRoles) {
          var m = Map<String, dynamic>.from(r);
          m.remove('is_synced');
          
          // Get permissions for this role (FETCH NAMES INSTEAD OF IDS)
          final perms = await db.rawQuery('''
            SELECT p.name FROM permissions p
            JOIN role_permissions rp ON p.id = rp.permission_id
            WHERE rp.role_id = ?
          ''', [r['id']]);
          
          m['permissions'] = perms.map((p) => p['name']).toList();
          rolesList.add(m);
        }
        changes['roles'] = rolesList;
      }

      // Unsynced Employees
      unsyncedEmployees = await db.query('employees', where: 'is_synced = 0 AND $businessFilter', whereArgs: businessArgs);
      if (unsyncedEmployees.isNotEmpty) {
        List<Map<String, dynamic>> employeesList = [];
        for (var e in unsyncedEmployees) {
          var m = Map<String, dynamic>.from(e);
          m.remove('is_synced');
          
          List<dynamic> perms = [];
          if (m['permissions'] != null && m['permissions'].toString().isNotEmpty) {
            try {
              final decoded = m['permissions'] is String ? jsonDecode(m['permissions']) : m['permissions'];
              if (decoded is List) perms.addAll(decoded);
            } catch (_) {}
          }

          // Process Multi-Roles - [FIX] Use role names instead of IDs for sync, 
          // because local IDs won't match server IDs during batch sync of new records.
          final roleData = await db.rawQuery('''
            SELECT r.id, r.name FROM roles r
            JOIN employee_roles er ON r.id = er.role_id
            WHERE er.employee_id = ?
          ''', [m['id']]);
          
          final roleIds = roleData.map((r) => r['id'] as int).toList();
          final roleNames = roleData.map((r) => r['name']?.toString()).whereType<String>().toList();
          
          m['roles'] = roleNames; // [CRITICAL] Send names to the server for batch sync stability
          m.remove('role_id'); // [FIX] Remove local role_id which doesn't exist on server yet

          // Merge role permissions (FETCH NAMES INSTEAD OF IDS) for all assigned roles
          if (roleIds.isNotEmpty) {
            final placeholders = List.filled(roleIds.length, '?').join(',');
            final rolePerms = await db.rawQuery('''
              SELECT p.name FROM permissions p
              JOIN role_permissions rp ON p.id = rp.permission_id
              WHERE rp.role_id IN ($placeholders)
            ''', roleIds);
            for (var rp in rolePerms) {
              final name = rp['name'];
              if (name != null && !perms.contains(name)) perms.add(name);
            }
          }
          
          m['permissions'] = perms;
          if (kDebugMode) print('📤 [SYNC] Pushing Employee: ${m['id']} - ${m['name']} (Merged Perms: ${perms})');
          employeesList.add(m);
        }
        changes['employees'] = employeesList;
      }

      // Unsynced Credit Sales
      unsyncedCreditSales = await db.query('credit_sales', where: 'is_synced = 0 AND $businessFilter', whereArgs: businessArgs);
      if (unsyncedCreditSales.isNotEmpty) {
        changes['credit_sales'] = unsyncedCreditSales.map((cs) {
          var m = Map.from(cs);
          m.remove('is_synced');
          // Standardize IDs for server
          m['user_id'] = m['user_id'] ?? uid;
          // staff_id is not mapped to user_id anymore
          return m;
        }).toList();
      }

      // Unsynced Credit Payments
      unsyncedCreditPayments = await db.query('credit_payments', where: 'is_synced = 0 AND $businessFilter', whereArgs: businessArgs);
      if (unsyncedCreditPayments.isNotEmpty) {
        changes['credit_payments'] = unsyncedCreditPayments.map((cp) {
          var m = Map.from(cp);
          m.remove('is_synced');
          // Standardize IDs for server
          m['user_id'] = m['user_id'] ?? uid;
          // staff_id is not mapped to user_id anymore
          return m;
        }).toList();
      }

       // Unsynced Suppliers
       unsyncedSuppliers = await db.query('suppliers', where: 'is_synced = 0 AND $businessFilter', whereArgs: businessArgs);
       if (unsyncedSuppliers.isNotEmpty) {
         changes['suppliers'] = unsyncedSuppliers.map((s) {
           var m = Map<String, dynamic>.from(s);
           m.remove('is_synced');
           
           // Server-side expectation mapping
           m['cell_number'] ??= s['phone']; 
           m['user_id'] = m['user_id'] ?? uid;
           m['business_id'] ??= bid;
           
           // BACKWARD COMPATIBILITY: Ensure server receives some form of balance/opening info
           m['balance'] = (m['credit_balance'] as num?)?.toDouble() ?? 0.0;
           return m;
         }).toList();
       }

      // Unsynced Expense Heads
      unsyncedExpenseHeads = await db.query('expense_heads', where: 'is_synced = 0 AND $businessFilter', whereArgs: businessArgs);
      if (unsyncedExpenseHeads.isNotEmpty) {
        changes['expense_heads'] = unsyncedExpenseHeads.map((eh) {
          var m = Map.from(eh);
          m.remove('is_synced');
          m['user_id'] = m['user_id'] ?? uid;
          // m.remove('user_id');
          return m;
        }).toList();
      }

       // Unsynced Expenses
       unsyncedExpenses = await db.query('expenses', where: 'is_synced = 0 AND $businessFilter', whereArgs: businessArgs);
       if (unsyncedExpenses.isNotEmpty) {
         changes['expenses'] = unsyncedExpenses.map((e) {
           var m = Map.from(e);
           m.remove('is_synced');
           

           
           m['business_id'] ??= bid;
           m['user_id'] = m['user_id'] ?? uid;
           return m;
         }).toList();
       }

       // Unsynced Purchases
       unsyncedPurchases = await db.query('purchases', where: 'is_synced = 0 AND $businessFilter', whereArgs: businessArgs);
       if (unsyncedPurchases.isNotEmpty) {
         List<Map<String, dynamic>> purchasesList = [];
         for (var p in unsyncedPurchases) {
           var m = Map<String, dynamic>.from(p);
           m.remove('is_synced');
           
           // Rename fields for server (legacy naming)
           m['date'] = m['purchase_date'];
           m['grand_total'] = m['total_amount'];
           // m.remove('supplier_id'); // Server actually expects 'supplier_id'
           m.remove('purchase_date');
           m.remove('total_amount');
           
           // Get items for this purchase - strictly isolated by purchase ID
           final items = await db.query('purchase_items', where: 'purchase_id = ?', whereArgs: [p['id']]);
           m['purchasing_details'] = items.map((item) {
             var itemMap = Map<String, dynamic>.from(item);
             itemMap.remove('is_synced');
             
             // Rename new price fields for server
             itemMap['cost_price']       = itemMap['purchase_price'];
             itemMap['whole_sale_price'] = itemMap['wholesale_price'];
             itemMap['sale_price']       = itemMap['selling_price'];
             itemMap.remove('purchase_price');
             itemMap.remove('wholesale_price');
             itemMap.remove('selling_price');

             // Include old price fields so the server can track price changes
             itemMap['old_cost_price']       = itemMap['old_cost_price'] ?? 0.0;
             itemMap['old_sale_price']       = itemMap['old_sale_price'] ?? 0.0;
             itemMap['old_wholesale_price']  = itemMap['old_wholesale_price'] ?? 0.0;
             
             // Ensure ID context
             itemMap['business_id'] ??= bid;
             itemMap['user_id'] = itemMap['user_id'] ?? uid;
             
             return itemMap;
           }).toList();
           
           purchasesList.add(m);
         }
         changes['purchases'] = purchasesList;
       }

      // Unsynced Shifts
      unsyncedShifts = await db.query('shifts', where: 'is_synced = 0 AND $businessFilter', whereArgs: businessArgs);
      if (unsyncedShifts.isNotEmpty) {
        changes['shifts'] = unsyncedShifts.map((s) {
          var m = Map<String, dynamic>.from(s);
          m.remove('is_synced');
          // Standardize IDs for server
          m['user_id'] = m['user_id'] ?? uid;
          // staff_id stands alone
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


      // [MOVED UP] Unsynced Roles collection

      // REMOVED: TEMPORARY hack that forced re-sync for all bank accounts
      // await db.update('bank_accounts', {'is_synced': 0});
      
      // Unsynced Bank Accounts
      unsyncedBankAccounts = await db.query('bank_accounts', where: 'is_synced = 0 AND $businessFilter', whereArgs: businessArgs);
      if (kDebugMode) print('🔍 [SYNC] Unsynced Bank accounts: ${unsyncedBankAccounts.length}');
      if (unsyncedBankAccounts.isNotEmpty) {
        changes['bank_accounts'] = unsyncedBankAccounts.map((b) {
          var m = Map<String, dynamic>.from(b);
          m.remove('is_synced');
          m['user_id'] = m['user_id'] ?? uid;
          // m.remove('user_id');
          return m;
        }).toList();
      }

      // Unsynced Supplier Credit Purchases
      unsyncedSupplierCreditPurchases = await db.query('supplier_credit_purchases', where: 'is_synced = 0 AND $businessFilter', whereArgs: businessArgs);
      if (unsyncedSupplierCreditPurchases.isNotEmpty) {
        changes['supplier_credit_purchases'] = unsyncedSupplierCreditPurchases.map((s) {
          var m = Map<String, dynamic>.from(s);
          m.remove('is_synced');
          m['user_id'] = m['user_id'] ?? uid;
          // m.remove('user_id');
          return m;
        }).toList();
      }

      // Unsynced Supplier Paybacks
      unsyncedSupplierPaybacks = await db.query('supplier_paybacks', where: 'is_synced = 0 AND $businessFilter', whereArgs: businessArgs);
      if (unsyncedSupplierPaybacks.isNotEmpty) {
        changes['supplier_paybacks'] = unsyncedSupplierPaybacks.map((s) {
          var m = Map<String, dynamic>.from(s);
          m.remove('is_synced');
          m['user_id'] = m['user_id'] ?? uid;
          // m.remove('user_id');
          return m;
        }).toList();
      }

      // Unsynced Gift Cards
      unsyncedGiftCards = await db.query('gift_cards', where: 'is_synced = 0 AND $businessFilter', whereArgs: businessArgs);
      if (unsyncedGiftCards.isNotEmpty) {
        changes['gift_cards'] = unsyncedGiftCards.map((g) {
          var m = Map<String, dynamic>.from(g);
          m.remove('is_synced');
          m['user_id'] = m['user_id'] ?? uid;
          // m.remove('user_id');
          return m;
        }).toList();
      }

      // Unsynced Currency Notes - Pushing all for this business/admin
      unsyncedCurrencyNotes = await db.query('currency_notes', where: 'is_synced = 0 AND (business_id = ? OR business_id IS NULL)', whereArgs: [bid]);
      if (unsyncedCurrencyNotes.isNotEmpty) {
        changes['currency_notes'] = unsyncedCurrencyNotes.map((cn) {
          var m = Map.from(cn);
          m.remove('is_synced');
          // [FIX] Ensure server gets non-null business/admin/branch IDs if missing locally
          m['business_id'] ??= bid;
          m['user_id'] = m['user_id'] ?? uid;
          // m.remove('user_id');
          m['branch_id'] ??= (BusinessConfig.instance.branchId == 'NONE' || BusinessConfig.instance.branchId == 0) ? null : BusinessConfig.instance.branchId;
          return m;
        }).toList();
      }

      // [NEW] Unsynced User Businesses
      unsyncedUserBusinesses = await db.query('user_businesses', where: 'is_synced = 0'); // User global, but linked to current user
      if (unsyncedUserBusinesses.isNotEmpty) {
        changes['user_businesses'] = unsyncedUserBusinesses.map((ub) {
          var m = Map.from(ub);
          m.remove('is_synced');
          return m;
        }).toList();
      }

      // Unsynced Units
      final unsyncedUnits = await db.query('units', where: 'is_synced = 0 AND business_id = ?', whereArgs: [bid]);
      if (unsyncedUnits.isNotEmpty) {
        changes['units'] = unsyncedUnits.map((u) {
          var m = Map.from(u);
          m.remove('is_synced');
          m['business_id'] ??= bid;
          m['user_id'] = m['user_id'] ?? uid;
          // m.remove('user_id');
          return m;
        }).toList();
      }

       // Unsynced Stock Audits (ENABLING for full inventory tracking)
       final unsyncedStockAudits = await db.query('stock_audits', where: 'is_synced = 0 AND business_id = ?', whereArgs: [bid]);
       if (unsyncedStockAudits.isNotEmpty) {
         changes['stock_audits'] = unsyncedStockAudits.map((sa) {
           var m = Map<String, dynamic>.from(sa);
           m.remove('is_synced');
           
           // Standardize IDs for server
           m['user_id'] = m['user_id'] ?? uid;
           // m.remove('user_id');
           // m['user_id'] = m['staff_id'];
           // m.remove('staff_id');
           
           // Ensure naming and types for server
           m['business_id'] = _parseNum(m['business_id']).toInt();
           // m['user_id'] is now staff_id from above
           m['branch_id'] = _parseNum(m['branch_id']).toInt();
           m['stock_id'] = _parseNum(m['stock_id']).toInt();
           m['product_id'] = _parseNum(m['product_id']).toInt();
           
           m['old_quantity'] = _parseNum(m['old_quantity']).toDouble();
           m['new_quantity'] = _parseNum(m['new_quantity']).toDouble();
           m['old_purchase_price'] = _parseNum(m['old_purchase_price']).toDouble();
           m['new_purchase_price'] = _parseNum(m['new_purchase_price']).toDouble();
           m['old_sale_price'] = _parseNum(m['old_sale_price']).toDouble();
           m['new_sale_price'] = _parseNum(m['new_sale_price']).toDouble();
           
           return m;
         }).toList();
       }

      // Unsynced Payment Types
      final unsyncedPaymentTypes = await db.query('payment_types', where: 'is_synced = 0 AND business_id = ?', whereArgs: [bid]);
      if (unsyncedPaymentTypes.isNotEmpty) {
        changes['payment_types'] = unsyncedPaymentTypes.map((pt) {
          var m = Map.from(pt);
          m.remove('is_synced');
          m['business_id'] ??= bid;
          m['user_id'] = m['user_id'] ?? uid;
          // m.remove('user_id');
          return m;
        }).toList();
      }


      if (changes.isEmpty) {
        if (kDebugMode) print('No changes to push');
        return;
      }

       if (kDebugMode) {
         print('📤 [SYNC] Pushing changes: ${changes.keys.toList()}');
         // print('DEBUG JSON: ${jsonEncode(changes)}'); // Useful for deep debugging if needed
       }
       
       Response response;
       try {
         response = await _api.post(
           '/sync/push', 
           data: {'changes': changes},
           queryParameters: {'business_id': BusinessConfig.instance.businessId},
         );
       } on DioException catch (de) {
         final errorBody = de.response?.data;
         final statusCode = de.response?.statusCode;
         if (kDebugMode) {
           print('❌ [SYNC] Push Failed ($statusCode): $errorBody');
           print('❌ [SYNC] Details: ${de.message}');
         }
         throw Exception('Sync Push Failed: ${errorBody ?? de.message}');
       } catch (e) {
         if (kDebugMode) print('❌ [SYNC] Unexpected Push Error: $e');
         rethrow;
       }
 
       if (response.statusCode == 200 && response.data['success'] == true) {
        await db.transaction((txn) async {
          // 1. Apply ID Mappings (CRITICAL: Do this before marking as synced)
          if (response.data['mappings'] != null && response.data['mappings'] is Map) {
            await _applyMappings(txn, response.data['mappings']);
          }

          // 2. Mark everything else as synced (that wasn't remapped)
          // Mark sales as synced
          for (var s in unsyncedSales) {
            if (s['id'] == null) continue;
            // If it was remapped, it's already updated and marked synced in _applyMappings
            await txn.update('sales', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [s['id']]);
          }
          // Mark categories as synced
          if (unsyncedCategories.isNotEmpty) {
            for (var c in unsyncedCategories) {
              if (c['id'] == null) continue;
              await txn.update('categories', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [c['id']]);
            }
          }
          // Mark customers as synced
          for (var c in unsyncedCustomers) {
            if (c['id'] == null) continue;
            await txn.update('customers', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [c['id']]);
          }
          // Mark products as synced
          for (var p in unsyncedProducts) {
            if (p['id'] == null) continue;
            await txn.update('products', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [p['id']]);
            await txn.update('stocks', {'is_synced': 1}, where: 'product_id = ?', whereArgs: [p['id']]);
          }
          // Mark loose stocks as synced
          if (unsyncedStocksForSyncedProducts.isNotEmpty) {
            for (var s in unsyncedStocksForSyncedProducts) {
              if (s['id'] == null) continue;
              await txn.update('stocks', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [s['id']]);
            }
          }
          // Mark users as synced
          for (var u in unsyncedUsers) {
            if (u['id'] == null) continue;
            await txn.update('users', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [u['id']]);
          }
          // Mark businesses as synced
          for (var b in unsyncedBusinesses) {
            if (b['id'] == null) continue;
            await txn.update('businesses', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [b['id']]);
          }
          // Mark employees as synced
          for (var e in unsyncedEmployees) {
            if (e['id'] == null) continue;
            await txn.update('employees', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [e['id']]);
          }
          // Mark credit sales as synced
          for (var cs in unsyncedCreditSales) {
            if (cs['id'] == null) continue;
            await txn.update('credit_sales', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [cs['id']]);
          }
          // Mark credit payments as synced
          for (var cp in unsyncedCreditPayments) {
            if (cp['id'] == null) continue;
            await txn.update('credit_payments', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [cp['id']]);
          }
          // Mark suppliers as synced
          for (var s in unsyncedSuppliers) {
            if (s['id'] == null) continue;
            await txn.update('suppliers', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [s['id']]);
          }
          // Mark expense heads as synced
          for (var eh in unsyncedExpenseHeads) {
            if (eh['id'] == null) continue;
            await txn.update('expense_heads', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [eh['id']]);
          }
          // Mark expenses as synced
          for (var e in unsyncedExpenses) {
            if (e['id'] == null) continue;
            await txn.update('expenses', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [e['id']]);
          }
          // Mark purchases as synced
          if (unsyncedPurchases.isNotEmpty) {
            for (var p in unsyncedPurchases) {
              if (p['id'] == null) continue;
              await txn.update('purchases', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [p['id']]);
              await txn.update('purchase_items', {'is_synced': 1}, where: 'purchase_id = ?', whereArgs: [p['id']]);
            }
          }
          // Mark shifts as synced
          for (var s in unsyncedShifts) {
             await txn.update('shifts', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [s['id']]);
          }
          // Mark returns as synced
          // NOTE: return_items has no is_synced column — only mark the parent returns record
          for (var r in unsyncedReturns) {
            if (r['id'] == null) continue;
            await txn.update('returns', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [r['id']]);
          }
          // Mark branches as synced
          for (var b in unsyncedBranches) {
             await txn.update('branches', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [b['id']]);
          }
          // Mark roles as synced
          for (var r in unsyncedRoles) {
             await txn.update('roles', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [r['id']]);
          }
          // Mark bank accounts as synced
          for (var b in unsyncedBankAccounts) {
            if (b['id'] == null) continue;
            await txn.update('bank_accounts', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [b['id']]);
          }
          // Mark paybacks as synced
          for (var s in unsyncedSupplierPaybacks) {
            if (s['id'] == null) continue;
            await txn.update('supplier_paybacks', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [s['id']]);
          }
          // Mark supplier credit purchases as synced
          for (var s in unsyncedSupplierCreditPurchases) {
            if (s['id'] == null) continue;
            await txn.update('supplier_credit_purchases', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [s['id']]);
          }
          // Mark gift cards as synced
          for (var g in unsyncedGiftCards) {
            if (g['id'] == null) continue;
            await txn.update('gift_cards', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [g['id']]);
          }
          // Mark currency notes as synced
          for (var cn in unsyncedCurrencyNotes) {
            if (cn['id'] == null) continue;
            await txn.update('currency_notes', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [cn['id']]);
          }
          // Mark subcategories as synced
          for (var sc in unsyncedSubCategories) {
            if (sc['id'] == null) continue;
            await txn.update('subcategories', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [sc['id']]);
          }
          // [NEW] Mark user businesses as synced
          for (var ub in unsyncedUserBusinesses) {
            if (ub['id'] == null) continue;
            await txn.update('user_businesses', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [ub['id']]);
          }
          // Mark brands as synced
          for (var b in unsyncedBrands) {
            if (b['id'] == null) continue;
            await txn.update('brands', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [b['id']]);
          }
          // Mark units as synced
          if (changes['units'] != null) {
             for (var u in changes['units']!) {
               if (u['id'] == null) continue;
               await txn.update('units', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [u['id']]);
             }
          }
          // Mark payment_types as synced
          if (changes['payment_types'] != null) {
             for (var pt in changes['payment_types']!) {
               if (pt['id'] == null) continue;
               await txn.update('payment_types', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [pt['id']]);
             }
          }

           // Mark stock audits as synced
           if (changes['stock_audits'] != null) {
             for (var sa in changes['stock_audits']!) {
               if (sa['id'] == null) continue;
               await txn.update('stock_audits', {'is_synced': 1}, where: 'id = ? AND is_synced = 0', whereArgs: [sa['id']]);
             }
           }

        });
        if (kDebugMode) {
          final mappingKeys = (response.data['mappings'] is Map) ? (response.data['mappings'] as Map).keys.toList() : [];
          print('Push complete: ${response.data['synced']} (Mappings: $mappingKeys)');
        }
      }
    } catch (e) {
      if (kDebugMode) print('Sync Push Error: $e');
      rethrow;
    }
  }

  /// Check if there is any unsynced data locally
  Future<bool> hasUnsyncedData() async {
    final db = await _dbHelper.database;
    final tables = [
      'sales', 'categories', 'customers', 'products', 'stocks', 'users', 'businesses', 
      'employees', 'credit_sales', 'credit_payments', 'suppliers', 'expense_heads', 
      'expenses', 'purchases', 'shifts', 'branches', 'roles', 'bank_accounts',
      'supplier_paybacks', 'supplier_credit_purchases', 'gift_cards', 'currency_notes',
      'subcategories', 'returns', 'user_businesses', 'units', 'payment_types', 'brands', 'stock_audits'
    ];

    for (var table in tables) {
      try {
        final bid = BusinessConfig.instance.businessId;
        final uid = BusinessConfig.instance.userId;
        
        String whereClause = 'is_synced = 0';
        List<dynamic> args = [];
        
        // Skip business isolation for tables that don't have these columns
        if (!['users', 'currency_notes', 'user_businesses', 'permissions', 'payment_types', 'units'].contains(table)) {
           whereClause += ' AND business_id = ? AND user_id = ?';
           args.addAll([bid, uid]);
        } else if (table == 'payment_types' || table == 'units') {
           whereClause += ' AND business_id = ?';
           args.addAll([bid]);
        }

        final List<Map<String, dynamic>> result = await db.query(table, where: whereClause, whereArgs: args, limit: 1);
        if (result.isNotEmpty) return true;
      } catch (e) {
        // Table might not exist or doesn't have is_synced (unlikely given schema)
      }
    }
    return false;
  }

  /// Search records on server (sales, purchases, expenses)
  Future<List<Map<String, dynamic>>> searchOnline(String query, String type) async {
    try {
      final response = await _api.get('/sync/search', queryParameters: {'query': query, 'type': type});
      if (response.statusCode == 200 && response.data['success'] == true) {
        return List<Map<String, dynamic>>.from(response.data['data']);
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('Search $type Online Error: $e');
      return [];
    }
  }

  /// Internal helper to update local IDs when server assigns a new ID due to collision
  Future<void> _applyMappings(Transaction txn, Map<String, dynamic> allMappings) async {
    // Note: server sends mappings like {"categories": {"1": 105}, "products": {"2": 106}}
    
    // 1. Categories
    if (allMappings['categories'] != null && allMappings['categories'] is Map) {
      final map = allMappings['categories'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.parse(entry.key);
        final newId = entry.value as int;
        if (kDebugMode) print('🔄 [MAPPING] Category: $oldId -> $newId');
        await txn.update('categories', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
        await txn.update('products', {'category_id': newId}, where: 'category_id = ?', whereArgs: [oldId]);
        await txn.update('subcategories', {'category_id': newId}, where: 'category_id = ?', whereArgs: [oldId]);
        await txn.update('categories', {'parent_id': newId}, where: 'parent_id = ?', whereArgs: [oldId]);
      }
    }

    // 1b. Subcategories Table
    if (allMappings['sub_categories'] != null && allMappings['sub_categories'] is Map) {
      final map = allMappings['sub_categories'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.parse(entry.key);
        final newId = entry.value as int;
        if (kDebugMode) print('🔄 [MAPPING] SubCategory: $oldId -> $newId');
        await txn.update('subcategories', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
        await txn.update('products', {'sub_category_id': newId}, where: 'sub_category_id = ?', whereArgs: [oldId]);
      }
    }

    // [NEW] 1c. Brands Table
    if (allMappings['brands'] != null && allMappings['brands'] is Map) {
      final map = allMappings['brands'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.parse(entry.key);
        final newId = entry.value as int;
        if (kDebugMode) print('🔄 [MAPPING] Brand: $oldId -> $newId');
        await txn.update('brands', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
        await txn.update('products', {'brand_id': newId}, where: 'brand_id = ?', whereArgs: [oldId]);
      }
    }

    // 2. Products
    if (allMappings['products'] != null && allMappings['products'] is Map) {
      final map = allMappings['products'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.parse(entry.key);
        final newId = entry.value as int;
        if (kDebugMode) print('🔄 [MAPPING] Product: $oldId -> $newId');
        await txn.update('products', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
        await txn.update('stocks', {'product_id': newId}, where: 'product_id = ?', whereArgs: [oldId]);
        await txn.update('sale_items', {'product_id': newId}, where: 'product_id = ?', whereArgs: [oldId]);
        await txn.update('purchase_items', {'product_id': newId}, where: 'product_id = ?', whereArgs: [oldId]);
      }
    }

    // 3. Customers
    if (allMappings['customers'] != null && allMappings['customers'] is Map) {
      final map = allMappings['customers'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.parse(entry.key);
        final newId = entry.value as int;
        if (kDebugMode) print('🔄 [MAPPING] Customer: $oldId -> $newId');
        await txn.update('customers', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
        await txn.update('sales', {'customer_id': newId}, where: 'customer_id = ?', whereArgs: [oldId]);
        await txn.update('credit_sales', {'customer_id': newId}, where: 'customer_id = ?', whereArgs: [oldId]);
        await txn.update('credit_payments', {'customer_id': newId}, where: 'customer_id = ?', whereArgs: [oldId]);
      }
    }

    // 4. Sales
    if (allMappings['sales'] != null && allMappings['sales'] is Map) {
      final map = allMappings['sales'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.parse(entry.key);
        final newId = entry.value as int;
        if (kDebugMode) print('🔄 [MAPPING] Sale: $oldId -> $newId');
        await txn.update('sales', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
        await txn.update('sale_items', {'sale_id': newId}, where: 'sale_id = ?', whereArgs: [oldId]);
        await txn.update('credit_sales', {'sale_id': newId}, where: 'sale_id = ?', whereArgs: [oldId]);
        await txn.update('returns', {'sale_id': newId}, where: 'sale_id = ?', whereArgs: [oldId]);
      }
    }

    // 5. Stocks
    if (allMappings['stocks'] != null && allMappings['stocks'] is Map) {
      final map = allMappings['stocks'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.parse(entry.key);
        final newId = entry.value as int;
        await txn.update('stocks', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
      }
    }

    // 6. Suppliers (Vendors)
    if (allMappings['suppliers'] != null && allMappings['suppliers'] is Map) {
      final map = allMappings['suppliers'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.parse(entry.key);
        final newId = entry.value as int;
        await txn.update('suppliers', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
        await txn.update('purchases', {'supplier_id': newId}, where: 'supplier_id = ?', whereArgs: [oldId]);
      }
    }

    // 7. Roles
    if (allMappings['roles'] != null && allMappings['roles'] is Map) {
      final map = allMappings['roles'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.parse(entry.key);
        final newId = entry.value as int;
        if (kDebugMode) print('🔄 [MAPPING] Role: $oldId -> $newId');
        await txn.update('roles', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
        await txn.update('employees', {'role_id': newId}, where: 'role_id = ?', whereArgs: [oldId]);
        // [FIX] Update role_permissions pivot table
        await txn.update('role_permissions', {'role_id': newId}, where: 'role_id = ?', whereArgs: [oldId]);
      }
    }

    // 8. Employees
    if (allMappings['employees'] != null && allMappings['employees'] is Map) {
      final map = allMappings['employees'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.parse(entry.key);
        final newId = entry.value as int;
        if (kDebugMode) print('🔄 [MAPPING] Employee: $oldId -> $newId');
        await txn.update('employees', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
        // [FIX] Update employee pivot tables
        // Note: employee_permissions doesn't exist on mobile (stored in 'permissions' column of employees)
        await txn.update('employee_roles', {'employee_id': newId}, where: 'employee_id = ?', whereArgs: [oldId]);
      }
    }

    // 9. Purchases
    if (allMappings['purchases'] != null && allMappings['purchases'] is Map) {
      final map = allMappings['purchases'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.parse(entry.key);
        final newId = entry.value as int;
        if (kDebugMode) print('🔄 [MAPPING] Purchase: $oldId -> $newId');
        await txn.update('purchases', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
        await txn.update('purchase_items', {'purchase_id': newId}, where: 'purchase_id = ?', whereArgs: [oldId]);
      }
    }

    // 9b. Purchase Items (remap their own IDs if different on server)
    if (allMappings['purchase_items'] != null && allMappings['purchase_items'] is Map) {
      final map = allMappings['purchase_items'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.tryParse(entry.key);
        if (oldId == null) continue;
        final newId = entry.value as int;
        await txn.update('purchase_items', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
      }
    }

    // 9c. Sale Items (remap their own IDs if different on server)
    if (allMappings['sale_items'] != null && allMappings['sale_items'] is Map) {
      final map = allMappings['sale_items'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.tryParse(entry.key);
        if (oldId == null) continue;
        final newId = entry.value as int;
        await txn.update('sale_items', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
      }
    }

    // 10. Credit Sales
    if (allMappings['credit_sales'] != null && allMappings['credit_sales'] is Map) {
      final map = allMappings['credit_sales'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.parse(entry.key);
        final newId = entry.value as int;
        await txn.update('credit_sales', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
        await txn.update('credit_payments', {'credit_sale_id': newId}, where: 'credit_sale_id = ?', whereArgs: [oldId]);
      }
    }

    // 11. Credit Payments
    if (allMappings['credit_payments'] != null && allMappings['credit_payments'] is Map) {
      final map = allMappings['credit_payments'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.parse(entry.key);
        final newId = entry.value as int;
        await txn.update('credit_payments', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
      }
    }

    // 12. Expenses
    if (allMappings['expenses'] != null && allMappings['expenses'] is Map) {
      final map = allMappings['expenses'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.parse(entry.key);
        final newId = entry.value as int;
        await txn.update('expenses', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
      }
    }

    // 13. Shifts
    if (allMappings['shifts'] != null && allMappings['shifts'] is Map) {
      final map = allMappings['shifts'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.parse(entry.key);
        final newId = entry.value as int;
        await txn.update('shifts', {'id': newId}, where: 'id = ?', whereArgs: [oldId]);
      }
    }

    // 14. Expense Heads
    if (allMappings['expense_heads'] != null && allMappings['expense_heads'] is Map) {
      final map = allMappings['expense_heads'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.parse(entry.key);
        final newId = entry.value as int;
        await txn.update('expense_heads', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
        await txn.update('expenses', {'expense_head_id': newId}, where: 'expense_head_id = ?', whereArgs: [oldId]);
      }
    }

    // 15. Branches
    if (allMappings['branches'] != null && allMappings['branches'] is Map) {
      final map = allMappings['branches'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.parse(entry.key);
        final newId = entry.value as int;
        await txn.update('branches', {'id': newId}, where: 'id = ?', whereArgs: [oldId]);
      }
    }

    // 16. Returns
    if (allMappings['returns'] != null && allMappings['returns'] is Map) {
      final map = allMappings['returns'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.parse(entry.key);
        final newId = entry.value as int;
        if (kDebugMode) print('🔄 [MAPPING] Return: $oldId -> $newId');
        await txn.update('returns', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
        await txn.update('return_items', {'return_id': newId}, where: 'return_id = ?', whereArgs: [oldId]);
      }
    }

    // 17. Supplier Credit Purchases
    if (allMappings['supplier_credit_purchases'] != null && allMappings['supplier_credit_purchases'] is Map) {
      final map = allMappings['supplier_credit_purchases'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.tryParse(entry.key);
        if (oldId == null) continue;
        final newId = entry.value as int;
        await txn.update('supplier_credit_purchases', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
        await txn.update('supplier_paybacks', {'supplier_credit_purchase_id': newId}, where: 'supplier_credit_purchase_id = ?', whereArgs: [oldId]);
      }
    }

    // 18. Supplier Paybacks
    if (allMappings['supplier_paybacks'] != null && allMappings['supplier_paybacks'] is Map) {
      final map = allMappings['supplier_paybacks'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.tryParse(entry.key);
        if (oldId == null) continue;
        final newId = entry.value as int;
        await txn.update('supplier_paybacks', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
      }
    }

    // [NEW] 19. Businesses
    if (allMappings['businesses'] != null && allMappings['businesses'] is Map) {
      final map = allMappings['businesses'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.tryParse(entry.key);
        if (oldId == null) continue;
        final newId = entry.value as int;
        if (kDebugMode) print('🔄 [MAPPING] Business: $oldId -> $newId');
        await txn.update('businesses', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
        await txn.update('user_businesses', {'business_id': newId}, where: 'business_id = ?', whereArgs: [oldId]);
      }
    }

    // 20. Units
    if (allMappings['units'] != null && allMappings['units'] is Map) {
      final map = allMappings['units'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.tryParse(entry.key);
        if (oldId == null) continue;
        final newId = entry.value as int;
        await txn.update('units', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
      }
    }

    // 21. Payment Types
    if (allMappings['payment_types'] != null && allMappings['payment_types'] is Map) {
      final map = allMappings['payment_types'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.tryParse(entry.key);
        if (oldId == null) continue;
        final newId = entry.value as int;
        await txn.update('payment_types', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
      }
    }

    // [NEW] 22. Currency Notes
    if (allMappings['currency_notes'] != null && allMappings['currency_notes'] is Map) {
      final map = allMappings['currency_notes'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.tryParse(entry.key);
        if (oldId == null) continue;
        final newId = entry.value as int;
        if (kDebugMode) print('🔄 [MAPPING] Currency Note: $oldId -> $newId');
        await txn.update('currency_notes', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
      }
    }

    // [NEW] 23. Stock Audits
    if (allMappings['stock_audits'] != null && allMappings['stock_audits'] is Map) {
      final map = allMappings['stock_audits'] as Map<String, dynamic>;
      for (var entry in map.entries) {
        final oldId = int.tryParse(entry.key);
        if (oldId == null) continue;
        final newId = entry.value as int;
        if (kDebugMode) print('🔄 [MAPPING] Stock Audit: $oldId -> $newId');
        await txn.update('stock_audits', {'id': newId, 'is_synced': 1}, where: 'id = ?', whereArgs: [oldId]);
      }
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
