class GroceryItem {
  String id;
  String name;
  int quantity;
  String category;
  double price;
  bool isPurchased;
  DateTime createdAt;

  GroceryItem({
    String? id,
    required this.name,
    required this.quantity,
    required this.category,
    required this.price,
    this.isPurchased = false,
    DateTime? createdAt,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'category': category,
      'price': price,
      'isPurchased': isPurchased,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    return GroceryItem(
      id: json['id'],
      name: json['name'],
      quantity: json['quantity'] is int
          ? json['quantity']
          : int.tryParse(json['quantity'].toString()) ?? 1,
      category: json['category'],
      price: json['price'] is double
          ? json['price']
          : double.tryParse(json['price'].toString()) ?? 0.0,
      isPurchased: json['isPurchased'] ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
    );
  }
}
