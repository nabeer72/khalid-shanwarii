import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class DbTables {
  static Future<void> createDB(Database db, int version) async {
    // Businesses
    await db.execute('''
      CREATE TABLE businesses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        business_type TEXT,
        owner_user_id INTEGER,
        status INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Users
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER,
        branch_id INTEGER,
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
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER,
        branch_id INTEGER,
        admin_id INTEGER,
        name TEXT NOT NULL,
        icon TEXT,
        parent_id INTEGER,
        status INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Products
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER,
        admin_id INTEGER,
        user_id INTEGER,
        branch_id INTEGER,
        category_id INTEGER,
        sub_category_id INTEGER,
        brand_id INTEGER,
        name TEXT NOT NULL,
        stock_type TEXT,
        image TEXT,
        description TEXT,
        barcode TEXT,
        price REAL DEFAULT 0,
        purchase_price REAL DEFAULT 0,
        wholesale_price REAL DEFAULT 0,
        stock_quantity REAL DEFAULT 0,
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
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER,
        branch_id INTEGER,
        product_id INTEGER,
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
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER,
        branch_id INTEGER,
        admin_id INTEGER,
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
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER,
        admin_id INTEGER,
        branch_id INTEGER,
        name TEXT NOT NULL,
        email TEXT UNIQUE,
        phone TEXT,
        role TEXT DEFAULT 'cashier',
        pin TEXT,
        permissions TEXT,
        role_id INTEGER,
        status INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Sales
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER,
        branch_id INTEGER,
        admin_id INTEGER,
        customer_id INTEGER,
        user_id INTEGER,
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
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER,
        stock_id INTEGER,
        quantity REAL DEFAULT 1,
        price REAL DEFAULT 0,
        subtotal REAL DEFAULT 0,
        branch_id INTEGER,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (sale_id) REFERENCES sales(id),
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (stock_id) REFERENCES stocks(id)
      )
    ''');

    // Gift Cards
    await db.execute('''
      CREATE TABLE gift_cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER,
        branch_id INTEGER,
        admin_id INTEGER,
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
    await db.execute('''
      CREATE TABLE held_order_items (
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
    await db.execute('''
      CREATE TABLE returns (
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
    await db.execute('''
      CREATE TABLE return_items (
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
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER,
        branch_id INTEGER,
        admin_id INTEGER,
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
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER,
        branch_id INTEGER,
        admin_id INTEGER,
        expense_head_id INTEGER,
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
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER,
        branch_id INTEGER,
        admin_id INTEGER,
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
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER,
        branch_id INTEGER,
        admin_id INTEGER,
        supplier_id INTEGER,
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
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER,
        product_id INTEGER,
        barcode TEXT,
        existing_stock REAL DEFAULT 0,
        quantity REAL DEFAULT 0,
        purchase_price REAL DEFAULT 0,
        wholesale_price REAL DEFAULT 0,
        selling_price REAL DEFAULT 0,
        subtotal REAL DEFAULT 0,
        branch_id INTEGER,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (purchase_id) REFERENCES purchases(id),
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');

    // Credit Sales
    await db.execute('''
      CREATE TABLE credit_sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER,
        branch_id INTEGER,
        admin_id INTEGER,
        customer_id INTEGER NOT NULL,
        sale_id INTEGER NOT NULL,
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
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER,
        branch_id INTEGER,
        admin_id INTEGER,
        credit_sale_id INTEGER,
        customer_id INTEGER NOT NULL,
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
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER,
        branch_id INTEGER,
        admin_id INTEGER,
        supplier_id INTEGER NOT NULL,
        purchase_id INTEGER NOT NULL,
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
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER,
        branch_id INTEGER,
        admin_id INTEGER,
        supplier_credit_purchase_id INTEGER,
        supplier_id INTEGER NOT NULL,
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
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER,
        admin_id INTEGER,
        branch_id INTEGER,
        user_id INTEGER,
        staff_id INTEGER,
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
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER,
        admin_id INTEGER,
        branch_id INTEGER,
        user_id INTEGER,
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
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        business_id INTEGER,
        admin_id INTEGER,
        branch_id INTEGER,
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

    // Permissions Table (Offline reference)
    await db.execute('''
      CREATE TABLE permissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        label TEXT NOT NULL,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // Role Permissions Pivot
    await db.execute('''
      CREATE TABLE role_permissions (
        role_id INTEGER,
        permission_id INTEGER,
        PRIMARY KEY (role_id, permission_id)
      )
    ''');

    if (kDebugMode) print('Database created with all tables including RBAC');
    await DbTables.seedPermissions(db);
  }

  static Future<void> seedPermissions(Database db) async {
    final perms = [
      {'name': 'pos_access', 'label': 'POS Access'},
      {'name': 'new_sale', 'label': 'Create New Sale'},
      {'name': 'reports_view', 'label': 'View Reports'},
      {'name': 'product_manage', 'label': 'Manage Products'},
      {'name': 'customer_manage', 'label': 'Manage Customers'},
      {'name': 'staff_manage', 'label': 'Manage Staff'},
      {'name': 'settings_manage', 'label': 'Manage Settings'},
      {'name': 'expenses_manage', 'label': 'Manage Expenses'},
      {'name': 'suppliers_manage', 'label': 'Manage Suppliers'},
      {'name': 'purchases_manage', 'label': 'Manage Purchases'},
      {'name': 'sales_history', 'label': 'View Sales History'},
      {'name': 'recovery', 'label': 'Credit Recovery'},
      {'name': 'stock_view', 'label': 'View Stock Reports'},
      {'name': 'gift_cards', 'label': 'Manage Gift Cards'},
      {'name': 'loyalty', 'label': 'Manage Loyalty'},
      {'name': 'support_view', 'label': 'Contact Support'},
      {'name': 'payback_manage', 'label': 'Manage Supplier Payback'},
      {'name': 'branches_manage', 'label': 'Manage Branches'},
      {'name': 'bank_manage', 'label': 'Manage Bank'},
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
