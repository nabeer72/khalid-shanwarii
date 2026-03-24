import 'package:mobile_app/db/database_helper.dart';

void debugInspectEmployees() async {
  final db = await DatabaseHelper.instance.database;
  final employees = await db.query('employees');
  print('--- LOCAL EMPLOYEES DUMP ---');
  for (var e in employees) {
    print('ID: ${e['id']}, Name: ${e['name']}, Email: "${e['email']}", Pin: "${e['pin']}", Status: ${e['status']}');
  }
}
