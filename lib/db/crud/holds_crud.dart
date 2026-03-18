import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:mobile_app/db/mock_data.dart';
import 'common_crud.dart';

mixin HoldsCrud on CommonCrud {
  Future<List<Map<String, dynamic>>> getHeldOrders() async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final args = [bid, aid, ...branchArgs];

    return await db.rawQuery(
      'SELECT * FROM held_orders WHERE business_id = ? AND admin_id = ?$branchFilter ORDER BY created_at DESC',
      args,
    );
  }

  Future<int> insertHeldOrder(Map<String, dynamic> order, List<Map<String, dynamic>> items) async {
    final db = await database;
    final bid = getSafeInt(BusinessConfig.instance.businessId);
    final aid = getSafeInt(BusinessConfig.instance.adminId);
    final brid = order['branch_id'] ?? getCurrentBranchId();
    
    return await db.transaction((txn) async {
      final heldOrderId = await txn.insert('held_orders', {
        ...order,
        'business_id': bid,
        'admin_id': aid,
        'branch_id': brid,
        'created_at': DateTime.now().toIso8601String(),
      });

      for (var item in items) {
        await txn.insert('held_order_items', {
          ...item,
          'held_order_id': heldOrderId,
        });
      }
      return heldOrderId;
    });
  }

  Future<void> deleteHeldOrder(dynamic id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('held_order_items', where: 'held_order_id = ?', whereArgs: [id]);
      await txn.delete('held_orders', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<Map<String, dynamic>>> getHeldOrderItems(dynamic heldOrderId) async {
    final db = await database;
    return await db.query('held_order_items', where: 'held_order_id = ?', whereArgs: [heldOrderId]);
  }
}
