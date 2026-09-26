import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/models/deal.dart';

class DealsController with ChangeNotifier {
  List<Deal> _deals = [];
  bool _isLoading = true;

  List<Deal> get deals => _deals;
  bool get isLoading => _isLoading;

  DealsController() {
    loadDeals();
    // Listen to global data change stream to refresh deals automatically
    DatabaseHelper.dataStream.listen((_) async {
      await loadDeals();
    });
  }

  Future<void> loadDeals() async {
    _isLoading = true;
    notifyListeners();

    try {
      final dealsData = await DatabaseHelper.instance.getAllDeals();
      _deals = dealsData.map((d) => Deal.fromMap(d)).toList();
    } catch (e) {
      debugPrint('Error loading deals: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleStatus(Deal deal) async {
    final newStatus = deal.status == 1 ? 0 : 1;
    await DatabaseHelper.instance.toggleDealStatus(deal.id, newStatus);
    await loadDeals();
  }

  Future<void> deleteDeal(int dealId) async {
    await DatabaseHelper.instance.deleteDeal(dealId);
    await loadDeals();
  }
}
