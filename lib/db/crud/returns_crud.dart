
import '../database_helper.dart';
import 'common_crud.dart';

mixin ReturnsCrud on CommonCrud {
  Future<List<Map<String, dynamic>>> getReturns({int? limit}) async {
    final db = await database;
    final branchFilter = getBranchFilter();
    final branchArgs = getBranchArgs();
    
    final args = [...getBusinessArgs(), ...branchArgs];

    return await db.rawQuery(
      'SELECT * FROM returns WHERE 1=1 ${getBusinessFilter()}$branchFilter ORDER BY created_at DESC${limit != null ? ' LIMIT $limit' : ''}',
      args,
    );
  }

  Future<int> insertReturn(Map<String, dynamic> returnData, List<Map<String, dynamic>> items) async {
    final db = await database;
    final businessArgs = getBusinessArgs();
    final brid = returnData['branch_id'] ?? getCurrentBranchId();
    
    final result = await db.transaction((txn) async {
      final returnId = await txn.insert('returns', {
        ...returnData,
        ...Map.fromIterables(['business_id', 'user_id'], businessArgs),
        'branch_id': brid,
        'status': 1,
        'is_synced': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      for (var item in items) {
        final stockId = item['stock_id'];
        final quantity = (item['quantity'] as num? ?? 0).toDouble();

        await txn.insert('return_items', {
          ...item,
          'return_id': returnId,
        });

        // Update Stock (Batch-specific): Returns add back to stock
        if (stockId != null) {
          final List<Map<String, dynamic>> stocks = await txn.query(
            'stocks',
            columns: ['quantity'],
            where: 'id = ?${getBusinessFilter()}',
            whereArgs: [stockId, ...businessArgs],
          );

          if (stocks.isNotEmpty) {
            final currentStock = (stocks.first['quantity'] as num? ?? 0).toDouble();
            final newStock = currentStock + quantity;

            await txn.update(
              'stocks',
              {
                'quantity': newStock,
                'is_synced': 0,
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?${getBusinessFilter()}',
              whereArgs: [stockId, ...businessArgs],
            );
          }
        }
      }
      return returnId;
    });
    
    DatabaseHelper.notifyDataChanged();
    return result;
  }

  Future<List<Map<String, dynamic>>> getReturnItems(dynamic returnId) async {
    final db = await database;
    return await db.query('return_items', where: 'return_id = ?', whereArgs: [returnId]);
  }
}
