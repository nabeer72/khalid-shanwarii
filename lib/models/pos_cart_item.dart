import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/models/stock.dart';
import 'package:mobile_app/models/deal.dart';
import 'package:mobile_app/models/deal_item.dart';

class POSCartItem {
  final String cartItemId; // product_id + "_" + stock_id or "deal_" + deal_id
  final int? saleItemId; // ID from sale_items table for returns
  final Product? product;
  final Stock? stock;
  
  // Deal support
  final bool isDeal;
  final Deal? deal;
  final List<DealItem>? dealItems;
  double quantity;
  double price;
  double _discount = 0;
  double subtotal;
  final bool isWeight;
  String discountType = 'fixed'; // 'fixed' or 'percentage'
  double discountValue = 0; // The rate (%) or amount ($) entered
  bool isManual = false;
  bool isNew = false; // true briefly after first being added to cart

  double get discount => _discount;
  set discount(double value) {
    _discount = value;
    if (discountType == 'fixed') {
      discountValue = value;
    }
    updateSubtotal();
  }

  POSCartItem({
    required this.cartItemId,
    this.saleItemId,
    this.product,
    this.stock,
    this.isDeal = false,
    this.deal,
    this.dealItems,
    this.quantity = 1,
    this.price = 0,
    double discount = 0,
    this.subtotal = 0,
    this.isWeight = false,
    this.discountType = 'fixed',
    this.discountValue = 0,
  }) : _discount = discount {
    if (discountValue == 0 && _discount != 0) discountValue = _discount;
    if (subtotal == 0 && price != 0) {
      updateSubtotal();
    }
  }

  // Calculate subtotal automatically
  void updateSubtotal() {
    if (discountType == 'percentage') {
      _discount = (quantity * price) * (discountValue / 100);
    } else {
      // For fixed, we might want to scale it per unit if we want it to be a "per unit" fixed discount?
      // But user said "currency", usually means total for that line or per unit.
      // If it's a fixed amount for the WHOLE line, it shouldn't scale.
      // But the current system has _discountRate.
      // Let's assume 'fixed' means total for this line item.
      _discount = discountValue;
    }
    subtotal = (quantity * price) - _discount;
    if (quantity >= 0 && subtotal < 0) subtotal = 0;
  }

  // Update quantity and scale discount proportionally
  void setQuantity(double newQty) {
    quantity = newQty;
    updateSubtotal();
  }

  // Convert to Map for database/receipt compatibility
  Map<String, dynamic> toMap() {
    return {
      'cart_item_id': cartItemId,
      'sale_item_id': saleItemId,
      'product_id': isDeal ? null : product?.id,
      'id': isDeal ? deal?.id : product?.id,
      'stock_id': isDeal ? null : stock?.id,
      'name': isDeal ? deal?.name : product?.name,
      'price': price,
      'quantity': quantity,
      'subtotal': subtotal,
      'isWeight': isWeight,
      'emoji': isDeal ? '🎁' : product?.image,
      'barcode': isDeal ? '' : stock?.barcode,
      'discount': discount,
      'discount_limit': isDeal ? 0 : stock?.discountLimit,
      'is_deal': isDeal ? 1 : 0,
      'deal_id': deal?.id,
    };
  }

  // For easy state updates
  POSCartItem copyWith({
    double? quantity,
    double? price,
    double? discount,
    int? saleItemId,
  }) {
    final newItem = POSCartItem(
      cartItemId: cartItemId,
      saleItemId: saleItemId ?? this.saleItemId,
      product: product,
      stock: stock,
      isDeal: isDeal,
      deal: deal,
      dealItems: dealItems,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      discount: discount ?? this.discount,
      isWeight: isWeight,
    );
    newItem.updateSubtotal();
    return newItem;
  }
}
