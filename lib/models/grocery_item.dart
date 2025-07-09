// models/grocery_item.dart
class GroceryItem {
  final String? id; // Can be null for newly created items before they get an ID, but should be non-null once saved.
  final String name;
  final int quantity;
  final double price;
  final String category;
  final bool isPurchased;
  final DateTime? createdAt;
  final DateTime? deletedAt;

  GroceryItem({
    this.id,
    required this.name,
    required this.quantity,
    required this.price,
    required this.category,
    this.isPurchased = false,
    this.createdAt,
    this.deletedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id, // <--- ADD THIS LINE to save the ID
      'name': name,
      'quantity': quantity,
      'price': price,
      'category': category,
      'isPurchased': isPurchased,
      'createdAt': createdAt?.millisecondsSinceEpoch,
      'deletedAt': deletedAt?.millisecondsSinceEpoch,
    };
  }

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    return GroceryItem(
      id: json['id'] as String?, // <--- ADD THIS LINE to load the ID
      name: json['name'],
      quantity: json['quantity'],
      price: (json['price'] as num).toDouble(),
      category: json['category'],
      isPurchased: json['isPurchased'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
          : null,
      deletedAt: json['deletedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['deletedAt'])
          : null,
    );
  }

  // Helper method to create a copy with updated fields
  GroceryItem copyWith({
    String? id,
    String? name,
    int? quantity,
    double? price,
    String? category,
    bool? isPurchased,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) {
    return GroceryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      category: category ?? this.category,
      isPurchased: isPurchased ?? this.isPurchased,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}