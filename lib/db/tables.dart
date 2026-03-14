import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

class DbTables {
  static Future<void> createDB(Database db, int version) async {
    // Businesses
    await db.execute('''
      CREATE TABLE businesses (
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

    // Users
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        business_id TEXT,
        branch_id TEXT,
        name TEXT NOT NULL,
        email TEXT UNIQUE,
        password TEXT,
        role TEXT DEFAULT 'admin',
        status INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (business_id) REFERENCES businesses(id)
      )
    ''');

    // Categories
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        business_id TEXT,
        branch_id TEXT,
        admin_id TEXT,
        name TEXT NOT NULL,
        icon TEXT,
        status INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Products
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        business_id TEXT,
        admin_id TEXT,
        user_id TEXT,
        branch_id TEXT,
        category_id TEXT,
        sub_category_id TEXT,
        brand_id TEXT,
        name TEXT NOT NULL,
        stock_type TEXT,
        image TEXT,
        description TEXT,
        barcode TEXT,
        stock_limit INTEGER DEFAULT 5,
        discount_limit REAL,
        is_price_per_weight INTEGER DEFAULT 0,
        is_favorite INTEGER DEFAULT 0,
        status INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        updated_at TEXT,
        deleted_at TEXT,
        FOREIGN KEY (category_id) REFERENCES categories(id)
      )
    ''');

    // Stocks
    await db.execute('''
      CREATE TABLE stocks (
        id TEXT PRIMARY KEY,
        business_id TEXT,
        branch_id TEXT,
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

    // Customers
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        business_id TEXT,
        branch_id TEXT,
        admin_id TEXT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        notes TEXT,
        total_spent REAL DEFAULT 0,
        visit_count INTEGER DEFAULT 0,
        loyalty_points INTEGER DEFAULT 0,
        discount REAL DEFAULT 0,
        credit_balance REAL DEFAULT 0,
        status INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Employees
    await db.execute('''
      CREATE TABLE employees (
        id TEXT PRIMARY KEY,
        business_id TEXT,
        admin_id TEXT,
        branch_id TEXT,
        name TEXT NOT NULL,
        email TEXT UNIQUE,
        phone TEXT,
        role TEXT DEFAULT 'cashier',
        pin TEXT,
        permissions TEXT,
        role_id TEXT,
        status INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Sales
    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        business_id TEXT,
        branch_id TEXT,
        admin_id TEXT,
        customer_id TEXT,
        user_id TEXT,
        subtotal REAL DEFAULT 0,
        tax REAL DEFAULT 0,
        discount REAL DEFAULT 0,
        total REAL DEFAULT 0,
        payment_method TEXT DEFAULT 'cash',
        is_return INTEGER DEFAULT 0,
        tip REAL DEFAULT 0,
        status INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');

    // Sale Items
    await db.execute('''
      CREATE TABLE sale_items (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        product_id TEXT,
        stock_id TEXT,
        quantity REAL DEFAULT 1,
        price REAL DEFAULT 0,
        subtotal REAL DEFAULT 0,
        branch_id TEXT,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (sale_id) REFERENCES sales(id),
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (stock_id) REFERENCES stocks(id)
      )
    ''');

    // Gift Cards
    await db.execute('''
      CREATE TABLE gift_cards (
        id TEXT PRIMARY KEY,
        business_id TEXT,
        branch_id TEXT,
        admin_id TEXT,
        code TEXT UNIQUE,
        initial_balance REAL DEFAULT 0,
        current_balance REAL DEFAULT 0,
        status INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Held Orders
    await db.execute('''
      CREATE TABLE held_orders (
        id TEXT PRIMARY KEY,
        business_id TEXT,
        branch_id TEXT,
        admin_id TEXT,
        name TEXT,
        customer_id TEXT,
        items TEXT,
        total REAL DEFAULT 0,
        created_at TEXT
      )
    ''');

    // Settings
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Expense Heads
    await db.execute('''
      CREATE TABLE expense_heads (
        id TEXT PRIMARY KEY,
        business_id TEXT,
        branch_id TEXT,
        admin_id TEXT,
        name TEXT NOT NULL,
        status INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Expenses
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        business_id TEXT,
        branch_id TEXT,
        admin_id TEXT,
        expense_head_id TEXT,
        amount REAL DEFAULT 0,
        description TEXT,
        date TEXT,
        status INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (expense_head_id) REFERENCES expense_heads(id)
      )
    ''');

    // Suppliers
    await db.execute('''
      CREATE TABLE suppliers (
        id TEXT PRIMARY KEY,
        business_id TEXT,
        branch_id TEXT,
        admin_id TEXT,
        name TEXT NOT NULL,
        contact_person TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        credit_balance REAL DEFAULT 0,
        status INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Purchases
    await db.execute('''
      CREATE TABLE purchases (
        id TEXT PRIMARY KEY,
        business_id TEXT,
        branch_id TEXT,
        admin_id TEXT,
        supplier_id TEXT,
        invoice_number TEXT,
        purchase_date TEXT,
        notes TEXT,
        payment_type TEXT,
        payment_reference TEXT,
        total_amount REAL DEFAULT 0,
        status INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      )
    ''');

    // Purchase Items
    await db.execute('''
      CREATE TABLE purchase_items (
        id TEXT PRIMARY KEY,
        purchase_id TEXT,
        product_id TEXT,
        barcode TEXT,
        existing_stock REAL DEFAULT 0,
        quantity REAL DEFAULT 0,
        purchase_price REAL DEFAULT 0,
        wholesale_price REAL DEFAULT 0,
        selling_price REAL DEFAULT 0,
        subtotal REAL DEFAULT 0,
        branch_id TEXT,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (purchase_id) REFERENCES purchases(id),
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');

    // Credit Sales
    await db.execute('''
      CREATE TABLE credit_sales (
        id TEXT PRIMARY KEY,
        business_id TEXT,
        branch_id TEXT,
        admin_id TEXT,
        customer_id TEXT NOT NULL,
        sale_id TEXT NOT NULL,
        amount REAL NOT NULL,
        remaining_balance REAL NOT NULL,
        status INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        FOREIGN KEY (customer_id) REFERENCES customers(id),
        FOREIGN KEY (sale_id) REFERENCES sales(id)
      )
    ''');

    // Credit Payments
    await db.execute('''
      CREATE TABLE credit_payments (
        id TEXT PRIMARY KEY,
        business_id TEXT,
        branch_id TEXT,
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

    // Supplier Credit Purchases
    await db.execute('''
      CREATE TABLE supplier_credit_purchases (
        id TEXT PRIMARY KEY,
        business_id TEXT,
        branch_id TEXT,
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

    // Supplier Paybacks
    await db.execute('''
      CREATE TABLE supplier_paybacks (
        id TEXT PRIMARY KEY,
        business_id TEXT,
        branch_id TEXT,
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

    // Shifts
    await db.execute('''
      CREATE TABLE shifts (
        id TEXT PRIMARY KEY,
        business_id TEXT,
        admin_id TEXT,
        branch_id TEXT,
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

    // Branches
    await db.execute('''
      CREATE TABLE branches (
        id TEXT PRIMARY KEY,
        business_id TEXT,
        user_id TEXT,
        name TEXT,
        address TEXT,
        cell_number TEXT,
        email TEXT,
        is_main_branch TEXT,
        logo TEXT,
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

    // Bank Accounts/Transactions
    await db.execute('''
      CREATE TABLE bank_accounts (
        id TEXT PRIMARY KEY,
        business_id TEXT,
        admin_id TEXT,
        branch_id TEXT,
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

    // Roles Table
    await db.execute('''
      CREATE TABLE roles (
        id TEXT PRIMARY KEY,
        business_id TEXT,
        branch_id TEXT,
        name TEXT NOT NULL,
        description TEXT,
        status INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Permissions Table (Offline reference)
    await db.execute('''
      CREATE TABLE permissions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        label TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Role Permissions Pivot
    await db.execute('''
      CREATE TABLE role_permissions (
        role_id TEXT,
        permission_id TEXT,
        PRIMARY KEY (role_id, permission_id)
      )
    ''');

    if (kDebugMode) print('Database created with all tables including RBAC');
    await DbTables.seedPermissions(db);
  }

  static Future<void> seedPermissions(Database db) async {
    final perms = [
      {'id': 'pos_access', 'name': 'pos_access', 'label': 'POS Access'},
      {'id': 'new_sale', 'name': 'new_sale', 'label': 'Create New Sale'},
      {'id': 'reports_view', 'name': 'reports_view', 'label': 'View Reports'},
      {'id': 'product_manage', 'name': 'product_manage', 'label': 'Manage Products'},
      {'id': 'customer_manage', 'name': 'customer_manage', 'label': 'Manage Customers'},
      {'id': 'staff_manage', 'name': 'staff_manage', 'label': 'Manage Staff'},
      {'id': 'settings_manage', 'name': 'settings_manage', 'label': 'Manage Settings'},
      {'id': 'expenses_manage', 'name': 'expenses_manage', 'label': 'Manage Expenses'},
      {'id': 'suppliers_manage', 'name': 'suppliers_manage', 'label': 'Manage Suppliers'},
      {'id': 'purchases_manage', 'name': 'purchases_manage', 'label': 'Manage Purchases'},
      {'id': 'sales_history', 'name': 'sales_history', 'label': 'View Sales History'},
      {'id': 'recovery', 'name': 'recovery', 'label': 'Credit Recovery'},
      {'id': 'stock_view', 'name': 'stock_view', 'label': 'View Stock Reports'},
      {'id': 'gift_cards', 'name': 'gift_cards', 'label': 'Manage Gift Cards'},
      {'id': 'loyalty', 'name': 'loyalty', 'label': 'Manage Loyalty'},
      {'id': 'support_view', 'name': 'support_view', 'label': 'Contact Support'},
      {'id': 'payback_manage', 'name': 'payback_manage', 'label': 'Manage Supplier Payback'},
      {'id': 'branches_manage', 'name': 'branches_manage', 'label': 'Manage Branches'},
      {'id': 'bank_manage', 'name': 'bank_manage', 'label': 'Manage Bank'},
    ];

    await db.transaction((txn) async {
      for (var p in perms) {
        await txn.insert('permissions', {
          ...p,
          'updated_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }
}
