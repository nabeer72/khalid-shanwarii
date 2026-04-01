import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'tables.dart';

class DbMigrations {
  static Future<void> upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 29) {
      if (kDebugMode) print('Upgrading DB to version 29: Adding branch_id to isolated tables...');
      final tables = [
        'categories', 'stocks', 'customers', 'sales', 
        'expense_heads', 'expenses', 'suppliers', 
        'purchases', 'credit_sales', 'credit_payments',
        'products', 'employees' // Added missing tables
      ];
      for (var table in tables) {
        try {
          await db.execute('ALTER TABLE $table ADD COLUMN branch_id TEXT');
        } catch (e) {
          if (kDebugMode) print('branch_id column already exists in $table: $e');
        }
      }
    }

    if (oldVersion < 30) {
      if (kDebugMode) print('Upgrading DB to version 30: Ensuring branch_id columns exist...');
      
      // 1. Ensure all relevant tables have branch_id
      final tables = [
        'categories', 'products', 'stocks', 'customers', 'sales', 
        'expense_heads', 'expenses', 'suppliers', 'purchases', 
        'credit_sales', 'credit_payments', 'employees'
      ];
      
      for (var table in tables) {
        try {
          await db.execute('ALTER TABLE $table ADD COLUMN branch_id TEXT');
        } catch (e) {}
      }

      // 2. [REMOVED] Automatic local backfill is unsafe on shared devices.
      // Legacy data is now hidden until synced from server with correct branch IDs.
    }

    if (oldVersion < 31) {
      if (kDebugMode) print('Upgrading DB to version 31: Adding RBAC tables...');
      
      // 1. Create Roles Table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS roles (
          id TEXT PRIMARY KEY,
          business_id TEXT,
          name TEXT NOT NULL,
          description TEXT,
          status INTEGER DEFAULT 1,
          is_synced INTEGER DEFAULT 0,
          updated_at TEXT
        )
      ''');

      // 2. Create Permissions Table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS permissions (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          label TEXT NOT NULL,
          updated_at TEXT
        )
      ''');

      // 3. Create Role Permissions Pivot
      await db.execute('''
        CREATE TABLE IF NOT EXISTS role_permissions (
          role_id TEXT,
          permission_id TEXT,
          PRIMARY KEY (role_id, permission_id)
        )
      ''');

      // 4. Add role_id to employees
      try {
        await db.execute('ALTER TABLE employees ADD COLUMN role_id TEXT');
      } catch (e) {}
    }

    if (oldVersion < 32) {
      if (kDebugMode) print('Upgrading DB to version 32: Adding branch_id to roles and seeding permissions...');
      try {
        await db.execute('ALTER TABLE roles ADD COLUMN branch_id TEXT');
      } catch (e) {}
      await DbTables.seedPermissions(db);
    }
    if (oldVersion < 33) {
      if (kDebugMode) print('Upgrading DB to version 33: Adding business, admin, and branch IDs to bank_accounts...');
      try {
        await db.execute('ALTER TABLE bank_accounts ADD COLUMN business_id TEXT');
        await db.execute('ALTER TABLE bank_accounts ADD COLUMN admin_id TEXT');
        await db.execute('ALTER TABLE bank_accounts ADD COLUMN branch_id TEXT');
      } catch (e) {}
    }
    if (oldVersion < 28) {
      if (kDebugMode) print('Upgrading DB to version 28: Standardizing stocks schema...');
      final columns = await db.rawQuery('PRAGMA table_info(stocks)');
      final columnNames = columns.map((c) => c['name'] as String).toList();
      
      if (!columnNames.contains('wholesale_price')) {
        await db.execute('ALTER TABLE stocks ADD COLUMN wholesale_price REAL DEFAULT 0');
        if (columnNames.contains('whole_sale_price')) {
          await db.execute('UPDATE stocks SET wholesale_price = whole_sale_price');
        }
      }
    }
    if (oldVersion < 27) {
      if (kDebugMode) print('Upgrading DB to version 27: Adding missing columns to products...');
      final columns = await db.rawQuery('PRAGMA table_info(products)');
      final columnNames = columns.map((c) => c['name'] as String).toList();
      
      if (!columnNames.contains('barcode')) {
        await db.execute('ALTER TABLE products ADD COLUMN barcode TEXT');
      }
      if (!columnNames.contains('stock_limit')) {
        await db.execute('ALTER TABLE products ADD COLUMN stock_limit INTEGER DEFAULT 5');
      }
      if (!columnNames.contains('discount_limit')) {
        await db.execute('ALTER TABLE products ADD COLUMN discount_limit REAL');
      }
    }
    if (oldVersion < 26) {
      if (kDebugMode) print('Upgrading DB to version 26: Moving products to stocks...');
      
      // 1. Create stocks table if not exists
      await db.execute('''
        CREATE TABLE IF NOT EXISTS stocks (
          id TEXT PRIMARY KEY,
          business_id TEXT,
          product_id TEXT,
          barcode TEXT,
          manufacture_date TEXT,
          expire_date TEXT,
          quantity REAL DEFAULT 0,
          packing TEXT,
          pieces_per_pack TEXT,
          cost_price REAL DEFAULT 0,
          sale_price REAL DEFAULT 0,
          wholesale_price REAL DEFAULT 0,
          alert_quantity REAL DEFAULT 0,
          alert_status TEXT,
          discount REAL DEFAULT 0,
          discount_limit REAL DEFAULT 0,
          tax REAL DEFAULT 0,
          trade_off TEXT,
          carry_expense REAL DEFAULT 0,
          status INTEGER DEFAULT 1,
          is_synced INTEGER DEFAULT 0,
          created_at TEXT,
          updated_at TEXT,
          deleted_at TEXT,
          FOREIGN KEY (product_id) REFERENCES products(id)
        )
      ''');

      // 2. Add new columns to products if they don't exist
      final columns = await db.rawQuery('PRAGMA table_info(products)');
      final columnNames = columns.map((c) => c['name'] as String).toList();
      
      final newProductColumns = {
        'user_id': 'TEXT',
        'branch_id': 'TEXT',
        'sub_category_id': 'TEXT',
        'brand_id': 'TEXT',
        'stock_type': 'TEXT',
        'deleted_at': 'TEXT',
        'barcode': 'TEXT',
        'stock_limit': 'INTEGER DEFAULT 5',
        'discount_limit': 'REAL'
      };

      for (var entry in newProductColumns.entries) {
        if (!columnNames.contains(entry.key)) {
          await db.execute('ALTER TABLE products ADD COLUMN ${entry.key} ${entry.value}');
        }
      }

      // Add stock_id to sale_items
      try {
        await db.execute('ALTER TABLE sale_items ADD COLUMN stock_id TEXT');
      } catch (e) {
        if (kDebugMode) print('Column stock_id already exists in sale_items: $e');
      }
      
      // Add stock_id to purchase_items 
      try {
        await db.execute('ALTER TABLE purchase_items ADD COLUMN stock_id TEXT');
      } catch (e) {
        if (kDebugMode) print('Column stock_id already exists in purchase_items: $e');
      }

      // 3. Migrate existing data: Create a stock entry for each product that has stock or pricing
      final products = await db.query('products');
      for (var p in products) {
        final productId = p['id'] as String;
        final stockQty = (p['stock_quantity'] as num? ?? 0).toDouble();
        
          // Even if stock is 0, if it has prices, we create an initial stock batch
          if (stockQty > 0 || (p['price'] as num? ?? 0) > 0) {
            final now = DateTime.now().toIso8601String();
            
            await db.insert('stocks', {
              'business_id': p['business_id'],
              'product_id': productId,
              'barcode': p['barcode'],
              'quantity': stockQty,
              'cost_price': (p['purchase_price'] as num? ?? 0).toDouble(),
              'sale_price': (p['price'] as num? ?? 0).toDouble(),
              'wholesale_price': (p['wholesale_price'] as num? ?? 0).toDouble(),
              'status': 1,
              'created_at': now,
              'updated_at': now,
            });
          }
      }
    }
    if (oldVersion < 25) {
      try {
        await db.execute('ALTER TABLE suppliers ADD COLUMN credit_balance REAL DEFAULT 0');
      } catch (e) {
        if (kDebugMode) print('Column credit_balance already exists in suppliers: $e');
      }
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS supplier_credit_purchases (
            id TEXT PRIMARY KEY,
            business_id TEXT,
            admin_id TEXT,
            supplier_id TEXT NOT NULL,
            purchase_id TEXT NOT NULL,
            amount REAL NOT NULL,
            remaining_balance REAL NOT NULL,
            status INTEGER DEFAULT 1,
            is_synced INTEGER DEFAULT 0,
            created_at TEXT,
            updated_at TEXT,
            FOREIGN KEY (supplier_id) REFERENCES suppliers(id),
            FOREIGN KEY (purchase_id) REFERENCES purchases(id)
          )
        ''');
      } catch (e) {
        if (kDebugMode) print('Error creating supplier_credit_purchases: $e');
      }
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS supplier_paybacks (
            id TEXT PRIMARY KEY,
            business_id TEXT,
            admin_id TEXT,
            supplier_credit_purchase_id TEXT,
            supplier_id TEXT NOT NULL,
            amount REAL NOT NULL,
            paid_by TEXT,
            payment_date TEXT,
            notes TEXT,
            is_synced INTEGER DEFAULT 0,
            created_at TEXT,
            updated_at TEXT,
            FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
          )
        ''');
      } catch (e) {
        if (kDebugMode) print('Error creating supplier_paybacks: $e');
      }
    }
    if (oldVersion < 20) {
      try {
        await db.execute('ALTER TABLE credit_payments ADD COLUMN updated_at TEXT');
      } catch (e) {
        if (kDebugMode) print('Column updated_at already exists in credit_payments: $e');
      }
      try {
        await db.execute('ALTER TABLE credit_payments ADD COLUMN is_synced INTEGER DEFAULT 0');
      } catch (e) {
        if (kDebugMode) print('Column is_synced already exists in credit_payments: $e');
      }
    }
    if (oldVersion < 19) {
      try {
        await db.execute('ALTER TABLE purchase_items ADD COLUMN barcode TEXT');
        await db.execute('ALTER TABLE purchase_items ADD COLUMN existing_stock REAL DEFAULT 0');
      } catch (e) {
        if (kDebugMode) print('Column already exists: $e');
      }
    }
    if (oldVersion < 18) {
      try {
        await db.execute('ALTER TABLE purchases ADD COLUMN payment_reference TEXT');
        await db.execute('ALTER TABLE purchases ADD COLUMN is_synced INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE purchase_items ADD COLUMN is_synced INTEGER DEFAULT 0');
      } catch (e) {
        if (kDebugMode) print('Column already exists: $e');
      }
    }
    if (oldVersion < 14) {
      try {
        await db.execute('ALTER TABLE purchase_items ADD COLUMN wholesale_price REAL DEFAULT 0');
      } catch (e) {
        if (kDebugMode) print('Column already exists: $e');
      }
    }

    if (oldVersion < 13) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN wholesale_price REAL DEFAULT 0');
      } catch (e) {
        if (kDebugMode) print('Column already exists: $e');
      }
    }
    
    if (oldVersion < 12) {
      try {
        await db.execute('ALTER TABLE customers ADD COLUMN discount REAL DEFAULT 0');
      } catch (e) {
        if (kDebugMode) print('Column already exists: $e');
      }
    }
    
    if (oldVersion < 2) {
      // Add new columns if upgrading from version 1
      try {
        await db.execute('ALTER TABLE products ADD COLUMN is_price_per_weight INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE products ADD COLUMN is_favorite INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE customers ADD COLUMN loyalty_points INTEGER DEFAULT 0');
      } catch (e) {
        if (kDebugMode) print('Column already exists: $e');
      }
    }
    
    if (oldVersion < 3) {
      // Add businesses table and update users table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS businesses (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            business_type TEXT,
            owner_user_id TEXT,
            status INTEGER DEFAULT 1,
            is_synced INTEGER DEFAULT 0,
            created_at TEXT,
            updated_at TEXT
          )
        ''');
        
        // Add new columns to users table
        await db.execute('ALTER TABLE users ADD COLUMN password TEXT');
        await db.execute('ALTER TABLE users ADD COLUMN role TEXT DEFAULT "admin"');
        await db.execute('ALTER TABLE users ADD COLUMN is_synced INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE users ADD COLUMN created_at TEXT');
      } catch (e) {
        if (kDebugMode) print('Upgrade to v3 error: $e');
      }
    }

    if (oldVersion < 4) {
      // Add purchase_price to products
      try {
        await db.execute('ALTER TABLE products ADD COLUMN purchase_price REAL DEFAULT 0');
      } catch (e) {
        if (kDebugMode) print('Upgrade to v4 error: $e');
      }
    }

    if (oldVersion < 5) {
      // Add admin_id to all relevant tables
      final tables = ['categories', 'products', 'customers', 'employees', 'sales', 'gift_cards', 'held_orders'];
      for (var table in tables) {
        try {
          await db.execute('ALTER TABLE $table ADD COLUMN admin_id TEXT');
        } catch (e) {
          if (kDebugMode) print('Admin-ID column already exists in $table: $e');
        }
      }
    }
    
    if (oldVersion < 6) {
      // Add permissions to employees
      try {
        await db.execute('ALTER TABLE employees ADD COLUMN permissions TEXT');
      } catch (e) {
        if (kDebugMode) print('Permissions column already exists in employees: $e');
      }
    }
    
    if (oldVersion < 7) {
      // Logic removed here and combined into v8 for safety
    }

    if (oldVersion < 8) {
      // Ensure phone and email exist in employees (safety check)
      try {
        await db.execute('ALTER TABLE employees ADD COLUMN email TEXT');
      } catch (e) {
        if (kDebugMode) print('Email column already exists in employees: $e');
      }
      try {
        await db.execute('ALTER TABLE employees ADD COLUMN phone TEXT');
      } catch (e) {
        if (kDebugMode) print('Phone column already exists in employees: $e');
      }
    }

    if (oldVersion < 9) {
      // Add expense_heads table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS expense_heads (
            id TEXT PRIMARY KEY,
            business_id TEXT,
            admin_id TEXT,
            name TEXT NOT NULL,
            status INTEGER DEFAULT 1,
            created_at TEXT,
            updated_at TEXT
          )
        ''');
      } catch (e) {
        if (kDebugMode) print('expense_heads table already exists: $e');
      }
      // Add expenses table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS expenses (
            id TEXT PRIMARY KEY,
            business_id TEXT,
            admin_id TEXT,
            expense_head_id TEXT,
            amount REAL DEFAULT 0,
            description TEXT,
            date TEXT,
            status INTEGER DEFAULT 1,
            created_at TEXT,
            updated_at TEXT,
            FOREIGN KEY (expense_head_id) REFERENCES expense_heads(id)
          )
        ''');
      } catch (e) {
        if (kDebugMode) print('expenses table already exists: $e');
      }
    }
    if (oldVersion < 10) {
      // Add suppliers table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS suppliers (
            id TEXT PRIMARY KEY,
            business_id TEXT,
            admin_id TEXT,
            name TEXT NOT NULL,
            contact_person TEXT,
            phone TEXT,
            email TEXT,
            address TEXT,
            status INTEGER DEFAULT 1,
            created_at TEXT,
            updated_at TEXT
          )
        ''');
      } catch (e) {
        if (kDebugMode) print('suppliers table already exists: $e');
      }
      
      // Add purchases table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS purchases (
            id TEXT PRIMARY KEY,
            business_id TEXT,
            admin_id TEXT,
            supplier_id TEXT,
            invoice_number TEXT,
            purchase_date TEXT,
            notes TEXT,
            payment_type TEXT,
            total_amount REAL DEFAULT 0,
            status INTEGER DEFAULT 1,
            created_at TEXT,
            updated_at TEXT,
            FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
          )
        ''');
      } catch (e) {
        if (kDebugMode) print('purchases table already exists: $e');
      }

      // Add purchase_items table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS purchase_items (
            id TEXT PRIMARY KEY,
            purchase_id TEXT,
            product_id TEXT,
            quantity REAL DEFAULT 0,
            purchase_price REAL DEFAULT 0,
            selling_price REAL DEFAULT 0,
            subtotal REAL DEFAULT 0,
            FOREIGN KEY (purchase_id) REFERENCES purchases(id),
            FOREIGN KEY (product_id) REFERENCES products(id)
          )
        ''');
      } catch (e) {
        if (kDebugMode) print('purchase_items table already exists: $e');
      }
    }

    if (oldVersion < 11) {
      // Add payment_reference to purchases
      try {
        await db.execute('ALTER TABLE purchases ADD COLUMN payment_reference TEXT');
      } catch (e) {
        if (kDebugMode) print('payment_reference column already exists in purchases: $e');
      }
    }

    if (oldVersion < 15) {
      // Add credit_balance to customers
      try {
        await db.execute('ALTER TABLE customers ADD COLUMN credit_balance REAL DEFAULT 0');
      } catch (e) {
        if (kDebugMode) print('credit_balance column already exists in customers: $e');
      }

      // Add credit_sales table
      try {
        await db.execute('''\n          CREATE TABLE IF NOT EXISTS credit_sales (
            id TEXT PRIMARY KEY,
            business_id TEXT,
            admin_id TEXT,
            customer_id TEXT NOT NULL,
            sale_id TEXT NOT NULL,
            amount REAL NOT NULL,
            remaining_balance REAL NOT NULL,
            status INTEGER DEFAULT 1,
            created_at TEXT,
            updated_at TEXT,
            FOREIGN KEY (customer_id) REFERENCES customers(id),
            FOREIGN KEY (sale_id) REFERENCES sales(id)
          )
        ''');
      } catch (e) {
        if (kDebugMode) print('credit_sales table already exists: $e');
      }

      // Add credit_payments table
      try {
        await db.execute('''\n          CREATE TABLE IF NOT EXISTS credit_payments (
            id TEXT PRIMARY KEY,
            business_id TEXT,
            admin_id TEXT,
            credit_sale_id TEXT,
            customer_id TEXT NOT NULL,
            amount REAL NOT NULL,
            received_by TEXT,
            payment_date TEXT,
            notes TEXT,
            is_synced INTEGER DEFAULT 0,
            created_at TEXT,
            updated_at TEXT,
            FOREIGN KEY (customer_id) REFERENCES customers(id)
          )
        ''');
      } catch (e) {
        if (kDebugMode) print('credit_payments table already exists: $e');
      }
    }

    if (oldVersion < 16) {
      // Add stock_limit to products
      try {
        await db.execute('ALTER TABLE products ADD COLUMN stock_limit INTEGER DEFAULT 5');
      } catch (e) {
        if (kDebugMode) print('stock_limit column already exists in products: $e');
      }
    }

    if (oldVersion < 17) {
      // Add is_synced to missing tables
      final tables = ['expense_heads', 'expenses', 'suppliers', 'credit_sales', 'credit_payments'];
      for (var table in tables) {
        try {
          await db.execute('ALTER TABLE $table ADD COLUMN is_synced INTEGER DEFAULT 0');
        } catch (e) {
          if (kDebugMode) print('is_synced column already exists in $table: $e');
        }
      }
    }

    if (oldVersion < 21) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS shifts (
            id TEXT PRIMARY KEY,
            business_id TEXT,
            admin_id TEXT,
            user_id TEXT,
            staff_id TEXT,
            start_time TEXT,
            end_time TEXT,
            opening_cash REAL DEFAULT 0,
            opening_denominations TEXT,
            closing_cash REAL DEFAULT 0,
            closing_denominations TEXT,
            total_sales REAL DEFAULT 0,
            total_cash_received REAL DEFAULT 0,
            total_online_received REAL DEFAULT 0,
            total_credit_received REAL DEFAULT 0,
            status INTEGER DEFAULT 1,
            is_synced INTEGER DEFAULT 0,
            created_at TEXT,
            updated_at TEXT
          )
        ''');
      } catch (e) {
        if (kDebugMode) print('Upgrade to v21 error: $e');
      }
    }

    if (oldVersion < 22) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS branches (
            id TEXT PRIMARY KEY,
            business_id TEXT,
            user_id TEXT,
            branch_title TEXT NOT NULL,
            branch_code TEXT,
            branch_address TEXT,
            contact_number INTEGER,
            status INTEGER DEFAULT 1,
            is_synced INTEGER DEFAULT 0,
            created_at TEXT,
            updated_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS bank_accounts (
            id TEXT PRIMARY KEY,
            bank_name TEXT NOT NULL,
            account_type TEXT,
            account_title TEXT,
            account_number TEXT,
            amount REAL DEFAULT 0,
            transaction_type TEXT,
            remarks TEXT,
            date TEXT,
            status INTEGER DEFAULT 1,
            is_synced INTEGER DEFAULT 0,
            created_at TEXT,
            updated_at TEXT
          )
        ''');
      } catch (e) {
        if (kDebugMode) print('Upgrade to v22 error: $e');
      }
    }

    if (oldVersion < 23) {
      try {
        await db.execute('ALTER TABLE employees ADD COLUMN branch_id TEXT');
      } catch (e) {
        if (kDebugMode) print('Upgrade to v23 error: $e');
      }
    }

    if (oldVersion < 24) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN discount_limit REAL');
      } catch (e) {
        if (kDebugMode) print('Upgrade to v24 error: $e');
      }
    }

    if (oldVersion < 34) {
      if (kDebugMode) print('Upgrading DB to v34: Seeding new permissions (payback, branches, bank)...');
      final newPerms = [
        {'id': 'gift_cards', 'name': 'gift_cards', 'label': 'Manage Gift Cards'},
        {'id': 'loyalty', 'name': 'loyalty', 'label': 'Manage Loyalty'},
        {'id': 'support_view', 'name': 'support_view', 'label': 'Contact Support'},
        {'id': 'payback_manage', 'name': 'payback_manage', 'label': 'Manage Supplier Payback'},
        {'id': 'branches_manage', 'name': 'branches_manage', 'label': 'Manage Branches'},
        {'id': 'bank_manage', 'name': 'bank_manage', 'label': 'Manage Bank'},
      ];
      final now = DateTime.now().toIso8601String();
      for (var p in newPerms) {
        try {
          await db.insert('permissions', {...p, 'updated_at': now},
              conflictAlgorithm: ConflictAlgorithm.ignore);
        } catch (e) {
          if (kDebugMode) print('v34 permission insert error: $e');
        }
      }
    }

    if (oldVersion < 35) {
      if (kDebugMode) print('Upgrading DB to v35: Adding branch_id to shifts table...');
      try {
        await db.execute('ALTER TABLE shifts ADD COLUMN branch_id TEXT');
      } catch (e) {
        if (kDebugMode) print('v35 shifts branch_id error: $e');
      }
    }

    if (oldVersion < 36) {
      if (kDebugMode) print('Upgrading DB to v36: Adding created_at to various tables...');
      final tables = ['categories', 'customers', 'employees', 'roles', 'permissions'];
      for (var table in tables) {
        try {
          await db.execute('ALTER TABLE $table ADD COLUMN created_at TEXT');
        } catch (e) {
          if (kDebugMode) print('v36 $table error: $e');
        }
      }
    }

    if (oldVersion < 37) {
      if (kDebugMode) print('Upgrading DB to v37: Adding branch_id to pivot tables...');
      final pivotTables = ['sale_items', 'purchase_items'];
      for (var table in pivotTables) {
        try {
          await db.execute('ALTER TABLE $table ADD COLUMN branch_id TEXT');
        } catch (e) {
          if (kDebugMode) print('v37 $table error: $e');
        }
      }
    }

    if (oldVersion < 39) {
      if (kDebugMode) print('Upgrading DB to v39: Adding pricing and stock columns to products...');
      try {
        await db.execute('ALTER TABLE products ADD COLUMN price REAL DEFAULT 0');
        await db.execute('ALTER TABLE products ADD COLUMN purchase_price REAL DEFAULT 0');
        await db.execute('ALTER TABLE products ADD COLUMN wholesale_price REAL DEFAULT 0');
        await db.execute('ALTER TABLE products ADD COLUMN stock_quantity REAL DEFAULT 0');
      } catch (e) {
        if (kDebugMode) print('v39 products schema error: $e');
      }
    }
    if (oldVersion < 41) {
      if (kDebugMode) print('Upgrading DB to v41: Adding missing columns for backfill...');
      try {
        await db.execute('ALTER TABLE roles ADD COLUMN admin_id INTEGER');
        await db.execute('ALTER TABLE branches ADD COLUMN admin_id INTEGER');
        await db.execute('ALTER TABLE branches ADD COLUMN branch_id INTEGER');
      } catch (e) {
        if (kDebugMode) print('v41 schema error: $e');
      }
    }
    
    if (oldVersion < 42) {
      if (kDebugMode) print('Upgrading DB to v42: Recreating roles and permissions tables for INTEGER normalization...');
      try {
        await db.transaction((txn) async {
          // 1. Rename old tables
          await txn.execute('ALTER TABLE roles RENAME TO old_roles');
          await txn.execute('ALTER TABLE permissions RENAME TO old_permissions');
          await txn.execute('ALTER TABLE role_permissions RENAME TO old_role_permissions');

          // 2. Create new tables
          await txn.execute('''
            CREATE TABLE roles (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              business_id INTEGER,
              admin_id INTEGER,
              branch_id INTEGER,
              name TEXT NOT NULL,
              description TEXT,
              status INTEGER DEFAULT 1,
              is_synced INTEGER DEFAULT 0,
              created_at TEXT,
              updated_at TEXT
            )
          ''');

          await txn.execute('''
            CREATE TABLE permissions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              label TEXT NOT NULL,
              created_at TEXT,
              updated_at TEXT
            )
          ''');

          await txn.execute('''
            CREATE TABLE role_permissions (
              role_id INTEGER,
              permission_id INTEGER,
              PRIMARY KEY (role_id, permission_id)
            )
          ''');

          // 3. Copy data
          await txn.execute('''
            INSERT INTO roles (id, business_id, admin_id, branch_id, name, description, status, is_synced, created_at, updated_at)
            SELECT CAST(id AS INTEGER), CAST(business_id AS INTEGER), CAST(admin_id AS INTEGER), CAST(branch_id AS INTEGER), name, description, status, is_synced, created_at, updated_at
            FROM old_roles WHERE CAST(id AS INTEGER) > 0
          ''');
          
          await txn.execute('''
            INSERT INTO permissions (id, name, label, updated_at)
            SELECT CAST(id AS INTEGER), name, label, updated_at
            FROM old_permissions WHERE CAST(id AS INTEGER) > 0
          ''');

          await txn.execute('''
            INSERT INTO role_permissions (role_id, permission_id)
            SELECT CAST(role_id AS INTEGER), CAST(permission_id AS INTEGER)
            FROM old_role_permissions WHERE CAST(role_id AS INTEGER) > 0 AND CAST(permission_id AS INTEGER) > 0
          ''');

          // 4. Drop old tables
          await txn.execute('DROP TABLE old_roles');
          await txn.execute('DROP TABLE old_permissions');
          await txn.execute('DROP TABLE old_role_permissions');
        });
      } catch (e) {
        if (kDebugMode) print('v42 roles migration error: $e');
      }
    }

    if (oldVersion < 43) {
      if (kDebugMode) print('Upgrading DB to v43: Adding parent_id to categories...');
      try {
        await db.execute('ALTER TABLE categories ADD COLUMN parent_id INTEGER');
      } catch (e) {
        if (kDebugMode) print('v43 categories parent_id error: $e');
      }
    }

    if (oldVersion < 44) {
      if (kDebugMode) print('Upgrading DB to v44: Creating persistent holds and returns tables...');
      await db.transaction((txn) async {
        // Held Orders
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS held_orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            business_id INTEGER,
            branch_id INTEGER,
            admin_id INTEGER,
            name TEXT,
            customer_id INTEGER,
            total REAL DEFAULT 0,
            created_at TEXT
          )
        ''');

        // Held Order Items
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS held_order_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            held_order_id INTEGER NOT NULL,
            product_id INTEGER,
            stock_id INTEGER,
            quantity REAL DEFAULT 1,
            price REAL DEFAULT 0,
            subtotal REAL DEFAULT 0,
            discount REAL DEFAULT 0,
            brand_id INTEGER,
            category_id INTEGER,
            FOREIGN KEY (held_order_id) REFERENCES held_orders(id),
            FOREIGN KEY (product_id) REFERENCES products(id),
            FOREIGN KEY (stock_id) REFERENCES stocks(id)
          )
        ''');

        // Returns
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS returns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            business_id INTEGER,
            branch_id INTEGER,
            admin_id INTEGER,
            sale_id INTEGER,
            customer_id INTEGER,
            user_id INTEGER,
            total_amount REAL DEFAULT 0,
            reason TEXT,
            status INTEGER DEFAULT 1,
            is_synced INTEGER DEFAULT 0,
            created_at TEXT,
            updated_at TEXT,
            FOREIGN KEY (sale_id) REFERENCES sales(id),
            FOREIGN KEY (customer_id) REFERENCES customers(id)
          )
        ''');

        // Return Items
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS return_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            return_id INTEGER NOT NULL,
            sale_item_id INTEGER,
            product_id INTEGER,
            stock_id INTEGER,
            quantity REAL DEFAULT 0,
            price REAL DEFAULT 0,
            subtotal REAL DEFAULT 0,
            FOREIGN KEY (return_id) REFERENCES returns(id),
            FOREIGN KEY (product_id) REFERENCES products(id),
            FOREIGN KEY (stock_id) REFERENCES stocks(id)
          )
        ''');
      });
    }
    if (oldVersion < 45) {
      if (kDebugMode) print('Upgrading DB to v45: Adding shift_id to sales...');
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN shift_id INTEGER');
      } catch (e) {
        if (kDebugMode) print('v45 sales shift_id error: $e');
      }
    }
    if (oldVersion < 46) {
      if (kDebugMode) print('Upgrading DB to v46: Creating subcategories table...');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS subcategories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category_id INTEGER,
          business_id INTEGER,
          branch_id INTEGER,
          admin_id INTEGER,
          name TEXT NOT NULL,
          code TEXT,
          status INTEGER DEFAULT 1,
          is_synced INTEGER DEFAULT 0,
          created_at TEXT,
          updated_at TEXT,
          FOREIGN KEY (category_id) REFERENCES categories(id)
        )
      ''');
      
      // Optional: Migrate existing subcategories (where parent_id is not null)
      try {
          final subCats = await db.query('categories', where: 'parent_id IS NOT NULL');
          for (var sc in subCats) {
              await db.insert('subcategories', {
                  'id': sc['id'],
                  'category_id': sc['parent_id'],
                  'business_id': sc['business_id'],
                  'branch_id': sc['branch_id'],
                  'admin_id': sc['admin_id'],
                  'name': sc['name'],
                  'status': sc['status'],
                  'is_synced': sc['is_synced'],
                  'created_at': sc['created_at'],
                  'updated_at': sc['updated_at'],
              }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
          // Remove from categories table
          await db.delete('categories', where: 'parent_id IS NOT NULL');
      } catch (e) {
          if (kDebugMode) print('v46 migration data move error: $e');
      }
    }
    if (oldVersion < 47) {
      if (kDebugMode) print('Upgrading DB to v47: Ensuring shift_id exists in sales...');
      try {
        var columns = await db.rawQuery('PRAGMA table_info(sales)');
        bool hasShiftId = columns.any((c) => c['name'] == 'shift_id');
        if (!hasShiftId) {
          await db.execute('ALTER TABLE sales ADD COLUMN shift_id INTEGER');
        }
      } catch (e) {
        if (kDebugMode) print('v47 sales shift_id error: $e');
      }
    }
    if (oldVersion < 48) {
      if (kDebugMode) print('Upgrading DB to v48: Adding discount column to sale_items and return_items...');
      try {
        await db.execute('ALTER TABLE sale_items ADD COLUMN discount REAL DEFAULT 0');
      } catch (e) {
        if (kDebugMode) print('v48 sale_items discount error: $e');
      }
      try {
        await db.execute('ALTER TABLE return_items ADD COLUMN discount REAL DEFAULT 0');
      } catch (e) {
        if (kDebugMode) print('v48 return_items discount error: $e');
      }
    }

    if (oldVersion < 49) {
      if (kDebugMode) print('Upgrading DB to v49: Creating currency_notes table...');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS currency_notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          business_id INTEGER,
          value REAL NOT NULL,
          label TEXT,
          status INTEGER DEFAULT 1,
          is_synced INTEGER DEFAULT 0,
          created_at TEXT,
          updated_at TEXT
        )
      ''');
    }

    if (oldVersion < 50) {
      if (kDebugMode) print('Upgrading DB to v50: Adding opening_amount to suppliers...');
      try {
        await db.execute('ALTER TABLE suppliers ADD COLUMN opening_amount REAL DEFAULT 0');
      } catch (e) {
        if (kDebugMode) print('v50 suppliers opening_amount error: $e');
      }
    }

    if (oldVersion < 51) {
      if (kDebugMode) print('Upgrading DB to v51: Creating user_businesses table...');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_businesses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          business_id INTEGER NOT NULL,
          created_at TEXT,
          updated_at TEXT,
          FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
          FOREIGN KEY (business_id) REFERENCES businesses(id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 52) {
      if (kDebugMode) print('Upgrading DB to v52: Adding is_synced to user_businesses...');
      try {
        await db.execute('ALTER TABLE user_businesses ADD COLUMN is_synced INTEGER DEFAULT 0');
      } catch (e) {
        if (kDebugMode) print('v52 user_businesses is_synced error: $e');
      }
    }

    if (oldVersion < 53) {
      if (kDebugMode) print('Upgrading DB to v53: Creating employee_roles table...');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS employee_roles (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          employee_id INTEGER NOT NULL,
          role_id INTEGER NOT NULL,
          FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE,
          FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE
        )
      ''');
    }
  }
}


