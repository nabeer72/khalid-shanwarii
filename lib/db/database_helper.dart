import 'dart:async';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'db_initializer.dart';
import 'crud/categories_crud.dart';
import 'crud/products_crud.dart';
import 'crud/customers_crud.dart';
import 'crud/sales_crud.dart';
import 'crud/employees_crud.dart';
import 'crud/common_crud.dart';
import 'crud/settings_crud.dart';
import 'crud/suppliers_crud.dart';
import 'crud/purchases_crud.dart';
import 'crud/expenses_crud.dart';
import 'crud/credit_crud.dart';
import 'crud/shifts_crud.dart';

import 'crud/holds_crud.dart';
import 'crud/returns_crud.dart';
import 'crud/currency_notes_crud.dart';
import 'crud/units_crud.dart';
import 'crud/payment_types_crud.dart';
import 'crud/brands_crud.dart';
import 'crud/banks_crud.dart';
import 'crud/deals_crud.dart';

class DatabaseHelper
    with
        CommonCrud,
        CategoriesCrud,
        ProductsCrud,
        CustomersCrud,
        SalesCrud,
        EmployeesCrud,
        SettingsCrud,
        SuppliersCrud,
        PurchasesCrud,
        ExpensesCrud,
        CreditCrud,
        ShiftsCrud,

        HoldsCrud,
        ReturnsCrud,
        CurrencyNotesCrud,
        UnitsCrud,
        PaymentTypesCrud,
        BrandsCrud,
        BanksCrud,
        DealsCrud {
  static final DatabaseHelper instance = DatabaseHelper._init();

  // Stream for data changes (to trigger immediate UI refreshes)
  static final _dataChangeController = StreamController<void>.broadcast();
  static Stream<void> get dataStream => _dataChangeController.stream;

  DatabaseHelper._init();

  @override
  Future<Database> get database async {
    return await DbInitializer.getDatabase();
  }

  /// Notify listeners that local data has changed.
  static void notifyDataChanged() {
    _dataChangeController.add(null);
  }

  // Ensure stream is closed if helper is ever destroyed (singleton, so unlikely)
  static void dispose() {
    _dataChangeController.close();
  }
}
