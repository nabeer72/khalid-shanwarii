import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import '../database_helper.dart';
import 'package:bcrypt/bcrypt.dart';

mixin CommonCrud {
  Future<Database> get database;

  // Branch filter removed - single-store app
  String getBranchFilter() => '';
  List<dynamic> getBranchArgs() => [];

  // Business Isolation Helpers
  String getBusinessFilter() {
    return ' AND business_id IS ? AND user_id IS ?';
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

  dynamic getCurrentBranchId() => null;

  int? getSafeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  // Users
  Future<int> insertUser(Map<String, dynamic> user) async {
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

  Future<void> updateUserPin(dynamic id, String pin) async {
    final db = await database;
    await db.update(
        'users',
        {
          'pin': pin,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND business_id = ?',
        whereArgs: [id, getSafeInt(BusinessConfig.instance.businessId)]);
  }

  Future<void> updateUserFields(dynamic id, Map<String, dynamic> fields) async {
    final db = await database;
    await db.update(
        'users',
        {
          ...fields,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND business_id = ?',
        whereArgs: [id, getSafeInt(BusinessConfig.instance.businessId)]);
    DatabaseHelper.notifyDataChanged();
  }

  // Businesses
  Future<int> insertBusiness(Map<String, dynamic> business) async {
    final db = await database;
    // Sanitize business data to match schema
    final sanitized = {
      'id': business['id'],
      'name': business['name'] ?? '',
      'business_type_id': business['business_type_id'],
      'owner_user_id': business['owner_user_id'] ?? business['user_id'],
      'status': (business['status'] == true || business['status'] == 1) ? 1 : 0,
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

  /// Persist a business row from the API and link it to the admin user.
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

        'max_branches': b['max_branches'],
        'max_products': b['max_products'],
        'status': active ? 1 : 0,
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
      await db.update('bank_accounts', {'status': 0},
          where: 'id = ?', whereArgs: [id]);
    }
    DatabaseHelper.notifyDataChanged();
  }

}
