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
import 'crud/branches_crud.dart';
import 'crud/holds_crud.dart';
import 'crud/returns_crud.dart';

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
        BranchesCrud,
        HoldsCrud,
        ReturnsCrud {
          
  static final DatabaseHelper instance = DatabaseHelper._init();

  DatabaseHelper._init();

  @override
  Future<Database> get database async {
    return await DbInitializer.getDatabase();
  }
}
