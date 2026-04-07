
import 'package:flutter/foundation.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class DebugInspect {
  /// Scans every table and reports record counts per business_id.
  /// Also flags any records with NULL isolation IDs.
  static Future<void> runIsolationAudit() async {
    if (!kDebugMode) return;

    final db = await DatabaseHelper.instance.database;
    final tables = [
      'businesses', 'branches', 'users', 'user_businesses', 'employees', 'roles',
      'categories', 'subcategories', 'products', 'stocks', 'customers', 'sales',
      'sale_items', 'credit_sales', 'credit_payments', 'suppliers', 'purchases',
      'purchase_items', 'expense_heads', 'expenses', 'shifts', 'bank_accounts',
      'gift_cards', 'returns', 'return_items'
    ];

    print('--------------- 🛡️ BUSINESS ISOLATION AUDIT 🛡️ ---------------');
    print('Current Session: Business=${BusinessConfig.instance.businessId}, Owner=${BusinessConfig.instance.userId}, Branch=${BusinessConfig.instance.branchId}');
    print('');

    for (var table in tables) {
      try {
        // 1. Total Count
        final totalCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $table')) ?? 0;
        if (totalCount == 0) continue;

        // 2. Breakdown by business_id
        final List<Map<String, dynamic>> breakdown = await db.rawQuery('''
          SELECT business_id, admin_id, COUNT(*) as count 
          FROM $table 
          GROUP BY business_id, admin_id
        ''');

        // 3. Check for NULLs
        final nullCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $table WHERE business_id IS NULL OR admin_id IS NULL')) ?? 0;

        print('📊 Table: $table ($totalCount total)');
        for (var row in breakdown) {
          final bid = row['business_id'];
          final aid = row['admin_id'];
          final count = row['count'];
          final isCurrent = (bid == BusinessConfig.instance.businessId && aid == BusinessConfig.instance.userId);
          print('   - [${isCurrent ? '✅ CURRENT' : '⚠️ OTHER'}] Business=$bid, Admin=$aid: $count records');
        }

        if (nullCount > 0) {
          print('   - ❌ DETECTED: $nullCount records with MISSING isolation IDs!');
        }
      } catch (e) {
        // Table might be missing some columns (like users or user_businesses which are global-ish)
        if (kDebugMode) print('ℹ️ Table: $table - Skipping (Schema differs or table missing)');
      }
    }
    print('-------------------------------------------------------------');
  }

  static Future<void> dumpEmployees() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('employees');
    print('--- LOCAL EMPLOYEES DUMP ---');
    for (var row in maps) {
      print(row);
    }
    print('----------------------------');
  }
}
