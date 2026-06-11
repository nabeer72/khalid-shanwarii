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

  Future<int> insertReturn(
      Map<String, dynamic> returnData, List<Map<String, dynamic>> items) async {
    final db = await database;
    final businessArgs = getBusinessArgs();
    final brid = returnData['branch_id'] ?? getCurrentBranchId();

    // Check if returns table has shift_id column first
    final tableInfo = await db.rawQuery('PRAGMA table_info(returns)');
    final hasShiftId = tableInfo.any((col) => col['name'] == 'shift_id');

    // Create a copy of returnData and remove shift_id to prevent inserting if column doesn't exist
    final filteredReturnData = Map<String, dynamic>.from(returnData);
    filteredReturnData.remove('shift_id');

    final result = await db.transaction((txn) async {
      final insertData = {
        ...filteredReturnData,
        ...Map.fromIterables(['business_id', 'user_id'], businessArgs),
        'branch_id': brid,
        'status': 1,
        'is_synced': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      // Only add shift_id if column exists and value is not null
      if (hasShiftId && returnData['shift_id'] != null) {
        insertData['shift_id'] = returnData['shift_id'];
      }
      
      final returnId = await txn.insert('returns', insertData);

      // If this return has a sale_id, update that sale's is_return to 1
      final originalSaleId = returnData['sale_id'];
      if (originalSaleId != null) {
        await txn.update(
          'sales',
          {
            'is_return': 1,
            'is_synced': 0,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [originalSaleId],
        );
      }

      for (var item in items) {
        final stockId = item['stock_id'];
        final quantity = (item['quantity'] as num? ?? 0).toDouble();

        await txn.insert('return_items', {
          ...item,
          'return_id': returnId,
        });

        // Update Stock (Batch-specific): Returns add back to stock
        // Use only primary key (id) to match stock — business filter can
        // prevent the row from being found when user_id is NULL or mismatched.
        if (stockId != null) {
          final List<Map<String, dynamic>> stocks = await txn.query(
            'stocks',
            columns: ['quantity'],
            where: 'id = ?',
            whereArgs: [stockId],
          );

          if (stocks.isNotEmpty) {
            final currentStock =
                (stocks.first['quantity'] as num? ?? 0).toDouble();
            final newStock = currentStock + quantity.abs();
            await txn.update(
              'stocks',
              {
                'quantity': newStock,
                'is_synced': 0,
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'id = ?',
              whereArgs: [stockId],
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
    final branchFilter =
        getBranchFilter().replaceAll('branch_id', 'r.branch_id');
    final branchArgs = getBranchArgs();
    final businessArgs = getBusinessArgs();

    return await db.rawQuery('''
      SELECT ri.*
      FROM return_items ri
      INNER JOIN returns r ON ri.return_id = r.id
      WHERE ri.return_id = ?
      ${getBusinessFilter().replaceAll('business_id', 'r.business_id').replaceAll('user_id', 'r.user_id')}
      $branchFilter
    ''', [returnId, ...businessArgs, ...branchArgs]);
  }
}
