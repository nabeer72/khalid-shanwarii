import 'package:mobile_app/models/product.dart';
import 'package:mobile_app/models/stock.dart';

class POSCartItem {
  final String cartItemId; // product_id + "_" + stock_id
  final Product product;
  final Stock stock;
  double quantity;
  double price;
  double _discount = 0;
  double _discountRate = 0; // Discount per unit
  double subtotal;
  final bool isWeight;

  double get discount => _discount;
  set discount(double value) {
    _discount = value;
    _discountRate = quantity > 0 ? value / quantity : 0;
    updateSubtotal();
  }

  POSCartItem({
    required this.cartItemId,
    required this.product,
    required this.stock,
    this.quantity = 1,
    this.price = 0,
    double discount = 0,
    this.subtotal = 0,
    this.isWeight = false,
  }) : _discount = discount {
    _discountRate = quantity > 0 ? _discount / quantity : 0;
    if (subtotal == 0 && price != 0) {
      updateSubtotal();
    }
  }

  // Calculate subtotal automatically
  void updateSubtotal() {
    subtotal = (quantity * price) - _discount;
    if (subtotal < 0) subtotal = 0;
  }

  // Update quantity and scale discount proportionally
  void setQuantity(double newQty) {
    quantity = newQty;
    _discount = _discountRate * quantity;
    updateSubtotal();
  }

  // Convert to Map for database/receipt compatibility
  Map<String, dynamic> toMap() {
    return {
      'cart_item_id': cartItemId,
      'product_id': product.id,
      'id': product.id,
      'stock_id': stock.id,
      'name': product.name,
      'price': price,
      'quantity': quantity,
      'subtotal': subtotal,
      'isWeight': isWeight,
      'emoji': product.image,
      'barcode': stock.barcode,
      'discount': discount,
    };
  }

  // For easy state updates
  POSCartItem copyWith({
    double? quantity,
    double? price,
    double? discount,
  }) {
    final newItem = POSCartItem(
      cartItemId: cartItemId,
      product: product,
      stock: stock,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      discount: discount ?? this.discount,
      isWeight: isWeight,
    );
    newItem.updateSubtotal();
    return newItem;
  }
}
