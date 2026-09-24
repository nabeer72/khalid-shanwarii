import 'package:flutter/material.dart';
import 'package:mobile_app/db/database_helper.dart';
import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/models/deal.dart';
import 'package:mobile_app/models/deal_item.dart';
import 'package:mobile_app/models/stock.dart';

class CreateDealController with ChangeNotifier {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController descCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController();

  List<DealItem> _items = [];
  bool _isLoading = false;
  Deal? _initialDeal;

  List<DealItem> get items => _items;
  bool get isLoading => _isLoading;
  bool get isEditMode => _initialDeal != null;
  String get screenTitle => isEditMode ? 'Edit Deal' : 'Create Deal';

  CreateDealController([this._initialDeal]) {
    if (isEditMode) {
      nameCtrl.text = _initialDeal!.name;
      descCtrl.text = _initialDeal!.description ?? '';
      priceCtrl.text = _initialDeal!.dealPrice.toString();
    }
  }

  Future<void> loadInitialItems() async {
    if (!isEditMode) return;
    _isLoading = true;
    notifyListeners();
    try {
      debugPrint(
          'CreateDealController loading items for deal id: ${_initialDeal!.id}');
      final itemsData =
          await DatabaseHelper.instance.getDealItems(_initialDeal!.id);
      debugPrint('CreateDealController loaded raw items: ${itemsData.length}');
      _items = itemsData.map((e) {
        final di = DealItem.fromMap(e);
        debugPrint(
            '  -> item productId=${di.productId} name=${di.productName} qty=${di.quantity} price=${di.unitPrice} stock=${di.currentStock}');
        return di;
      }).toList();
    } catch (e) {
      debugPrint('Error loading deal items: $e');
      _items = [];
    } finally {
      debugPrint('CreateDealController final items count: ${_items.length}');
      _isLoading = false;
      notifyListeners();
    }
  }

  double get normalTotal {
    return _items.fold(
        0.0, (sum, item) => sum + (item.unitPrice * item.quantity));
  }

  double get savings {
    final dealPrice = double.tryParse(priceCtrl.text) ?? 0.0;
    return normalTotal > dealPrice ? normalTotal - dealPrice : 0.0;
  }

  void addProduct(Product product, Stock stock) {
    // Check if already added
    final existingIndex = _items.indexWhere((i) => i.productId == product.id);
    if (existingIndex >= 0) {
      _items[existingIndex] = DealItem(
        id: _items[existingIndex].id,
        dealId: 0,
        productId: product.id,
        quantity: _items[existingIndex].quantity + 1,
        unitPrice: _items[existingIndex].unitPrice,
        productName: product.name,
        currentStock: stock.quantity,
      );
    } else {
      _items.add(DealItem(
        id: 0,
        dealId: 0,
        productId: product.id,
        quantity: 1,
        unitPrice: product.latestPrice,
        productName: product.name,
        currentStock: stock.quantity,
      ));
    }
    notifyListeners();
  }

  void updateQuantity(int productId, double newQty) {
    if (newQty <= 0) {
      _items.removeWhere((i) => i.productId == productId);
    } else {
      final idx = _items.indexWhere((i) => i.productId == productId);
      if (idx >= 0) {
        _items[idx] = DealItem(
          id: _items[idx].id,
          dealId: 0,
          productId: _items[idx].productId,
          quantity: newQty,
          unitPrice: _items[idx].unitPrice,
          productName: _items[idx].productName,
          currentStock: _items[idx].currentStock,
        );
      }
    }
    notifyListeners();
  }

  Future<bool> saveDeal() async {
    if (nameCtrl.text.trim().isEmpty) return false;
    if (priceCtrl.text.trim().isEmpty) return false;
    if (_items.isEmpty) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final dealData = {
        'name': nameCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'deal_price': double.tryParse(priceCtrl.text.trim()) ?? 0.0,
        'status': 1,
      };

      final itemsData = _items
          .map((i) => {
                'product_id': i.productId,
                'quantity': i.quantity,
                'unit_price': i.unitPrice,
              })
          .toList();

      int? dealId;
      if (isEditMode) {
        await DatabaseHelper.instance
            .updateDeal(_initialDeal!.id, dealData, itemsData);
        dealId = _initialDeal!.id;
        debugPrint('Deal updated with ID: $dealId');
      } else {
        dealId = await DatabaseHelper.instance.insertDeal(dealData, itemsData);
        debugPrint('Deal inserted with ID: $dealId');
      }
      // Clear input fields after saving
      nameCtrl.clear();
      descCtrl.clear();
      priceCtrl.clear();
      _items.clear();
      // Notify listeners to refresh UI
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving deal: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    descCtrl.dispose();
    priceCtrl.dispose();
    super.dispose();
  }
}
