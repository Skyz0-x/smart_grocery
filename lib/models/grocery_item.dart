// models/grocery_item.dart
class GroceryItem {
  final String? id;
  final String name;
  final int quantity;
  final double price;
  final String category;
  final bool isPurchased;
  final DateTime? createdAt;

  GroceryItem({
    this.id,
    required this.name,
    required this.quantity,
    required this.price,
    required this.category,
    this.isPurchased = false,
    this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price,
      'category': category,
      'isPurchased': isPurchased,
      'createdAt': createdAt?.millisecondsSinceEpoch,
    };
  }

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    return GroceryItem(
      name: json['name'],
      quantity: json['quantity'],
      price: (json['price'] as num).toDouble(),
      category: json['category'],
      isPurchased: json['isPurchased'] ?? false,
      createdAt: json['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
          : null,
    );
  }
}