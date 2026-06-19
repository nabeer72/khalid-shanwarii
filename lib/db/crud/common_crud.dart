import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import '../database_helper.dart';
import 'package:bcrypt/bcrypt.dart';

mixin CommonCrud {
  Future<Database> get database;

  // Branch Isolation Helpers
  String getBranchFilter() {
    final activeBranches = BusinessConfig.instance.activeBranchIds;
    final brid = BusinessConfig.instance.branchId;
    final staffId = BusinessConfig.instance.staffId;

    // Staff are strictly isolated to their own branch
    if (staffId != null) {
      if (brid != null && brid != 'NONE' && brid != 0) {
        return ' AND (branch_id = ?)';
      } else {
        // If staff has no branch assigned, they should see NOTHING, not all branches.
        return ' AND (1 = 0)';
      }
    }

    // [FIX] Prioritize current branch ID over the list of all active branches.
    // This prevents sub-branch data from leaking into the main branch view for admins.
    if (brid != null && brid != 'NONE' && brid != 0) {
      return ' AND (branch_id = ?)';
    }

    if (activeBranches.isNotEmpty) {
      final placeholders = List.filled(activeBranches.length, '?').join(', ');
      return ' AND (branch_id IN ($placeholders))';
    }
    // No branch context = show all data
    return '';
  }

  List<dynamic> getBranchArgs() {
    final activeBranches = BusinessConfig.instance.activeBranchIds;
    final brid = BusinessConfig.instance.branchId;
    final staffId = BusinessConfig.instance.staffId;

    // Staff are strictly isolated to their own branch
    if (staffId != null) {
      if (brid != null && brid != 'NONE' && brid != 0) {
        return [getSafeInt(brid)];
      } else {
        // If staff has no branch assigned, they see nothing.
        return [];
      }
    }

    // [FIX] Prioritize current branch ID over the list of all active branches.
    if (brid != null && brid != 'NONE' && brid != 0) {
      return [getSafeInt(brid)];
    }

    if (activeBranches.isNotEmpty) {
      return activeBranches.map((b) => getSafeInt(b)).toList();
    }
    return [];
  }

  // Business Isolation Helpers
  String getBusinessFilter() {
    return ' AND business_id = ? AND user_id = ?';
  }

  List<dynamic> getBusinessArgs() {
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final uid = getSafeInt(BusinessConfig.instance.userId);
    return [bid, uid];
  }

  Map<String, dynamic> getBusinessArgsMap() {
    return {
      'business_id': getSafeInt(BusinessConfig.instance.businessId),
      'user_id': getSafeInt(BusinessConfig.instance.userId),
    };
  }

  dynamic getCurrentBranchId() {
    // Priority:
    // 1. Specific branchId set in context (e.g. for assignment)
    final brid = BusinessConfig.instance.branchId;
    if (brid != null) {
      return brid;
    }

    // 2. Fallback to first active branch
    final activeBranches = BusinessConfig.instance.activeBranchIds;
    if (activeBranches.isNotEmpty) {
      return activeBranches.first;
    }

    return null;
  }

  int? getSafeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  // Users
  Future<int> insertUser(Map<String, dynamic> user, {int? isSynced}) async {
    final db = await database;
    // Sanitize user data to match schema
    String? hashedPassword;
    if (user['password'] != null && user['password'].toString().isNotEmpty) {
      // Check if password is already hashed (to avoid double hashing)
      if (!user['password'].toString().startsWith(r'$2a$')) {
        hashedPassword =
            BCrypt.hashpw(user['password'].toString(), BCrypt.gensalt());
      } else {
        hashedPassword = user['password'].toString();
      }
    }
    final sanitized = {
      'id': user['id'],
      'business_id': user['business_id'],
      'branch_id': user['branch_id'],
      'name': user['name'] ?? '',
      'email': user['email']?.toString().toLowerCase().trim(),
      'password': hashedPassword,
      'pin': user['pin'],
      'role': user['role'] ?? 'admin',
      'status': (user['status'] == true || user['status'] == 1) ? 1 : 0,
      'phone': user['phone'],
      'cnic': user['cnic'],
      'is_synced':
          isSynced ?? (user['is_synced'] ?? 1), // Default to 1 if not specified
      'created_at': user['created_at'],
      'updated_at': user['updated_at'],
    };
    final result = await db.insert('users', sanitized,
        conflictAlgorithm: ConflictAlgorithm.replace);

    DatabaseHelper.notifyDataChanged();
    return result;
  }

  Future<Map<String, dynamic>?> getUser(dynamic id) async {
    final db = await database;
    final results = await db.query('users',
        where: 'id = ? AND business_id = ?',
        whereArgs: [id, getSafeInt(BusinessConfig.instance.businessId)],
        limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    final cleanEmail = email.toLowerCase().trim();
    final results = await db.query('users',
        where: 'LOWER(email) = ?', whereArgs: [cleanEmail], limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getUserByEmailAndPassword(
      String email, String password) async {
    final db = await database;
    final cleanEmail = email.toLowerCase().trim();
    final results = await db.query('users',
        where: 'LOWER(email) = ? AND status = 1',
        whereArgs: [cleanEmail],
        limit: 1);
    if (results.isEmpty) return null;
    final user = results.first;
    final storedHash = user['password']?.toString() ?? '';
    // Check if stored hash is a valid bcrypt hash
    if (storedHash.startsWith(r'$2a$')) {
      // Verify password with bcrypt
      if (BCrypt.checkpw(password, storedHash)) {
        return user;
      }
    } else {
      // Fallback for existing plaintext passwords (for migration)
      if (storedHash == password) {
        // Optional: Rehash password and update in DB here
        return user;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedUsers() async {
    final db = await database;
    return await db.query('users', where: 'is_synced = 0');
  }

  Future<void> updateUserPin(dynamic id, String pin) async {
    final db = await database;
    await db.update(
        'users',
        {
          'pin': pin,
          'is_synced': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND business_id = ?',
        whereArgs: [id, getSafeInt(BusinessConfig.instance.businessId)]);
  }

  Future<void> updateUserSyncStatus(dynamic id, int synced) async {
    final db = await database;
    await db.update('users', {'is_synced': synced},
        where: 'id = ? AND business_id = ?',
        whereArgs: [id, getSafeInt(BusinessConfig.instance.businessId)]);
  }

  Future<void> updateUserFields(dynamic id, Map<String, dynamic> fields) async {
    final db = await database;
    await db.update(
        'users',
        {
          ...fields,
          'is_synced': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND business_id = ?',
        whereArgs: [id, getSafeInt(BusinessConfig.instance.businessId)]);
    DatabaseHelper.notifyDataChanged();
  }

  // Businesses
  Future<int> insertBusiness(Map<String, dynamic> business,
      {int? isSynced}) async {
    final db = await database;
    // Sanitize business data to match schema
    final sanitized = {
      'id': business['id'],
      'name': business['name'] ?? '',
      'business_type_id': business['business_type_id'],
      'owner_user_id': business['owner_user_id'] ?? business['user_id'],
      'status': (business['status'] == true || business['status'] == 1) ? 1 : 0,
      'is_synced': isSynced ?? (business['is_synced'] ?? 1),
      'created_at': business['created_at'],
      'updated_at': business['updated_at'],
    };
    final result = await db.insert('businesses', sanitized,
        conflictAlgorithm: ConflictAlgorithm.replace);

    DatabaseHelper.notifyDataChanged();
    return result;
  }

  Future<Map<String, dynamic>?> getBusiness(dynamic id) async {
    final db = await database;
    final results = await db.query('businesses',
        where: 'id = ?', whereArgs: [id], limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getUnsyncedBusinesses() async {
    final db = await database;
    return await db.query('businesses', where: 'is_synced = 0');
  }

  Future<void> updateBusinessSyncStatus(dynamic id, int synced) async {
    final db = await database;
    await db.update('businesses', {'is_synced': synced},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getBusinesses() async {
    final db = await database;
    return await db.query('businesses', where: 'status = 1');
  }

  Future<List<Map<String, dynamic>>> getBusinessesForUser(
      dynamic userId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT DISTINCT b.* FROM businesses b
      LEFT JOIN user_businesses ub ON b.id = ub.business_id AND ub.user_id = ?
      WHERE b.status = 1
        AND (ub.user_id IS NOT NULL OR b.owner_user_id = ?)
    ''', [userId, userId]);
  }

  /// Persist a business row from API/sync and link it to the admin user.
  Future<void> saveBusinessFromServer(
      Map<String, dynamic> b, dynamic userId) async {
    final db = await database;
    final id = b['id'];
    if (id == null) return;

    final status = b['status'];
    final active = status == null ||
        status == true ||
        status == 1 ||
        status.toString() == '1';

    await db.insert(
      'businesses',
      {
        'id': id is int ? id : int.tryParse(id.toString()),
        'name': b['name'] ?? 'Unknown',
        'business_type_id': b['business_type_id'],
        'owner_user_id': b['owner_user_id'] ?? b['user_id'],
        'subscription_status': b['subscription_status'],
        'subscription_plan_id': b['subscription_plan_id'],
        'subscription_plan_name': b['subscription_plan_name'],
        'subscription_end_date': b['subscription_end_date'],
        'max_branches': b['max_branches'],
        'max_products': b['max_products'],
        'status': active ? 1 : 0,
        'is_synced': 1,
        'created_at': b['created_at'],
        'updated_at': b['updated_at'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (userId != null) {
      await addUserBusiness(userId, id);
    }
    DatabaseHelper.notifyDataChanged();
  }

  Future<void> addUserBusiness(dynamic userId, dynamic businessId) async {
    final db = await database;

    // [FIX] Check for existing link to prevent duplicates
    final existing = await db.query('user_businesses',
        where: 'user_id = ? AND business_id = ?',
        whereArgs: [userId, businessId],
        limit: 1);

    if (existing.isEmpty) {
      await db.insert(
          'user_businesses',
          {
            'user_id': userId,
            'business_id': businessId,
            'is_synced': 0,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ========== Bank Operations ==========

  Future<List<Map<String, dynamic>>> getBankTransactions() async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final uid = getSafeInt(BusinessConfig.instance.userId);

    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();

    final args = [bid, uid, ...branchArgs];

    return await db.rawQuery(
      'SELECT * FROM bank_accounts WHERE status = 1 AND business_id IS ? AND user_id IS ?$branchFilter ORDER BY date DESC',
      args,
    );
  }

  Future<void> insertBankTransaction(Map<String, dynamic> transaction) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final uid = getSafeInt(BusinessConfig.instance.userId);

    // Check if record exists to preserve created_at
    final List<Map<String, dynamic>> existing = transaction['id'] != null
        ? await db.query(
            'bank_accounts',
            where: 'id = ?',
            whereArgs: [transaction['id']],
          )
        : [];

    final data = {
      ...transaction,
      'business_id': bid,
      'user_id': uid,
      'branch_id': transaction['branch_id'] ?? getCurrentBranchId(),
      'is_synced': 0,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (existing.isEmpty) {
      data['created_at'] = DateTime.now().toIso8601String();
      await db.insert('bank_accounts', data,
          conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      // Preserve created_at from existing record
      data['created_at'] = existing.first['created_at'];
      await db.update('bank_accounts', data,
          where: 'id = ?', whereArgs: [transaction['id']]);
    }

    DatabaseHelper.notifyDataChanged();
  }

  Future<void> deleteBankTransaction(dynamic id,
      {bool hardDelete = false}) async {
    if (id == null) return;
    final db = await database;
    if (hardDelete) {
      await db.delete('bank_accounts', where: 'id = ?', whereArgs: [id]);
    } else {
      await db.update('bank_accounts', {'status': 0, 'is_synced': 0},
          where: 'id = ?', whereArgs: [id]);
    }
    DatabaseHelper.notifyDataChanged();
  }

  // ========== Cleanup Operations ==========

  Future<int> cleanupSyncedRecords({int daysOld = 7}) async {
    final db = await database;
    final dateThreshold =
        DateTime.now().subtract(Duration(days: daysOld)).toIso8601String();

    int totalDeleted = 0;
    final tables = [
      'sales',
      'sale_items',
      'returns',
      'return_items',
      'expenses',
      'purchases',
      'purchase_items',
      'bank_accounts',
      'credit_sales',
      'credit_payments',
      'supplier_paybacks',
      'supplier_credit_purchases'
    ];

    await db.transaction((txn) async {
      for (var table in tables) {
        // Special case for tables that might not have created_at but have 'date'
        String dateColumn = 'created_at';
        if (table == 'bank_accounts' ||
            table == 'credit_payments' ||
            table == 'supplier_paybacks') {
          dateColumn = 'date';
        }

        try {
          final count = await txn.delete(
            table,
            where: 'is_synced = 1 AND $dateColumn < ?',
            whereArgs: [dateThreshold],
          );
          totalDeleted += count;
        } catch (e) {
          print('Cleanup error for table $table: $e');
        }
      }
    });

    return totalDeleted;
  }
}
