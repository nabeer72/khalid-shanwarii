
import 'common_crud.dart';

mixin HoldsCrud on CommonCrud {
  Future<List<Map<String, dynamic>>> getHeldOrders() async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final args = [...getBusinessArgs(), ...branchArgs];

    return await db.rawQuery(
      'SELECT * FROM held_orders WHERE 1=1 ${getBusinessFilter()}$branchFilter ORDER BY created_at DESC',
      args,
    );
  }

  Future<int> insertHeldOrder(Map<String, dynamic> order, List<Map<String, dynamic>> items) async {
    final db = await database;
    final businessArgs = getBusinessArgs();
    final brid = order['branch_id'] ?? getCurrentBranchId();
    
    return await db.transaction((txn) async {
      final heldOrderId = await txn.insert('held_orders', {
        ...order,
        ...Map.fromIterables(['business_id', 'admin_id'], businessArgs),
        'branch_id': brid,
        'created_at': DateTime.now().toIso8601String(),
      });

      for (var item in items) {
        await txn.insert('held_order_items', {
          'held_order_id': heldOrderId,
          'product_id': item['product_id'] ?? item['id'],
          'stock_id': item['stock_id'],
          'quantity': item['quantity'],
          'price': item['price'],
          'subtotal': item['subtotal'],
          'discount': item['discount'] ?? 0,
          'category_id': item['category_id'],
        });
      }
      return heldOrderId;
    });
  }

  Future<void> deleteHeldOrder(dynamic id) async {
    final db = await database;
    final businessArgs = getBusinessArgs();
    await db.transaction((txn) async {
      // First ensure the held order belongs to this business
      final results = await txn.query('held_orders', where: 'id = ?${getBusinessFilter()}', whereArgs: [id, ...businessArgs]);
      if (results.isNotEmpty) {
        await txn.delete('held_order_items', where: 'held_order_id = ?', whereArgs: [id]);
        await txn.delete('held_orders', where: 'id = ?${getBusinessFilter()}', whereArgs: [id, ...businessArgs]);
      }
    });
  }

  Future<List<Map<String, dynamic>>> getHeldOrderItems(dynamic heldOrderId) async {
    final db = await database;
    return await db.query('held_order_items', where: 'held_order_id = ?', whereArgs: [heldOrderId]);
  }
}
