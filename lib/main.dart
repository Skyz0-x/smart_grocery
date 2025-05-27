import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(GroceryApp());
}

class GroceryApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Grocery List',
      theme: ThemeData(
        primarySwatch: Colors.green,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.green[600],
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.green[600],
          foregroundColor: Colors.white,
        ),
      ),
      home: GroceryListScreen(),
    );
  }
}

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
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
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
      quantity: json['quantity'],
      category: json['category'],
      price: json['price'],
      isPurchased: json['isPurchased'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
    );
  }
}

class StorageHelper {
  static const String _itemsKey = 'grocery_items';

  static Future<List<GroceryItem>> getItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String? itemsJson = prefs.getString(_itemsKey);
    
    if (itemsJson == null) return [];
    
    final List<dynamic> itemsList = json.decode(itemsJson);
    return itemsList.map((item) => GroceryItem.fromJson(item)).toList();
  }

  static Future<void> saveItems(List<GroceryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final String itemsJson = json.encode(items.map((item) => item.toJson()).toList());
    await prefs.setString(_itemsKey, itemsJson);
  }

  static Future<void> addItem(GroceryItem item) async {
    final items = await getItems();
    items.add(item);
    await saveItems(items);
  }

  static Future<void> updateItem(GroceryItem updatedItem) async {
    final items = await getItems();
    final index = items.indexWhere((item) => item.id == updatedItem.id);
    if (index != -1) {
      items[index] = updatedItem;
      await saveItems(items);
    }
  }

  static Future<void> deleteItem(String id) async {
    final items = await getItems();
    items.removeWhere((item) => item.id == id);
    await saveItems(items);
  }
}

class GroceryListScreen extends StatefulWidget {
  @override
  _GroceryListScreenState createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  List<GroceryItem> _items = [];
  List<String> _categories = [
    'Fruits & Vegetables',
    'Dairy & Eggs',
    'Meat & Seafood',
    'Pantry',
    'Beverages',
    'Snacks',
    'Frozen',
    'Household',
    'Other'
  ];
  
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final items = await StorageHelper.getItems();
    setState(() {
      _items = items;
    });
  }

  List<GroceryItem> get _filteredItems {
    if (_selectedCategory == 'All') {
      return _items;
    }
    return _items.where((item) => item.category == _selectedCategory).toList();
  }

  Map<String, List<GroceryItem>> get _itemsByCategory {
    Map<String, List<GroceryItem>> categoryMap = {};
    for (var item in _filteredItems) {
      if (!categoryMap.containsKey(item.category)) {
        categoryMap[item.category] = [];
      }
      categoryMap[item.category]!.add(item);
    }
    return categoryMap;
  }

  double get _totalBudget {
    return _items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  double get _spentAmount {
    return _items
        .where((item) => item.isPurchased)
        .fold(0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Fruits & Vegetables':
        return Icons.eco;
      case 'Dairy & Eggs':
        return Icons.egg;
      case 'Meat & Seafood':
        return Icons.set_meal;
      case 'Pantry':
        return Icons.kitchen;
      case 'Beverages':
        return Icons.local_drink;
      case 'Snacks':
        return Icons.cookie;
      case 'Frozen':
        return Icons.ac_unit;
      case 'Household':
        return Icons.home;
      default:
        return Icons.shopping_basket;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Smart Grocery List'),
        actions: [
          IconButton(
            icon: Icon(Icons.analytics),
            onPressed: _showBudgetDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Budget Summary Card
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('Total Budget', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('\$${_totalBudget.toStringAsFixed(2)}', 
                         style: TextStyle(fontSize: 18, color: Colors.green[700])),
                  ],
                ),
                Column(
                  children: [
                    Text('Spent', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('\$${_spentAmount.toStringAsFixed(2)}', 
                         style: TextStyle(fontSize: 18, color: Colors.red[700])),
                  ],
                ),
                Column(
                  children: [
                    Text('Remaining', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('\$${(_totalBudget - _spentAmount).toStringAsFixed(2)}', 
                         style: TextStyle(fontSize: 18, color: Colors.blue[700])),
                  ],
                ),
              ],
            ),
          ),
          
          // Category Filter
          Container(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryChip('All'),
                ..._categories.map((category) => _buildCategoryChip(category)),
              ],
            ),
          ),
          
          // Items List
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart, size: 80, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text('No items in your list', 
                             style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                        Text('Tap + to add your first item'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _itemsByCategory.keys.length,
                    itemBuilder: (context, index) {
                      String category = _itemsByCategory.keys.elementAt(index);
                      List<GroceryItem> categoryItems = _itemsByCategory[category]!;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Icon(_getCategoryIcon(category), color: Colors.green[600]),
                                SizedBox(width: 8),
                                Text(
                                  category,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...categoryItems.map((item) => _buildItemCard(item)),
                          SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemDialog(),
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    bool isSelected = _selectedCategory == category;
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(category),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = category;
          });
        },
        selectedColor: Colors.green[200],
        checkmarkColor: Colors.green[700],
      ),
    );
  }

  Widget _buildItemCard(GroceryItem item) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: ListTile(
        leading: Checkbox(
          value: item.isPurchased,
          onChanged: (value) => _toggleItemPurchased(item),
          activeColor: Colors.green[600],
        ),
        title: Text(
          item.name,
          style: TextStyle(
            decoration: item.isPurchased ? TextDecoration.lineThrough : null,
            color: item.isPurchased ? Colors.grey[600] : null,
          ),
        ),
        subtitle: Text('Qty: ${item.quantity} • \$${(item.price * item.quantity).toStringAsFixed(2)}'),
        trailing: PopupMenuButton(
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _showEditItemDialog(item);
            } else if (value == 'delete') {
              _deleteItem(item);
            }
          },
        ),
      ),
    );
  }

  void _showAddItemDialog() {
    _showItemDialog();
  }

  void _showEditItemDialog(GroceryItem item) {
    _showItemDialog(item: item);
  }

  void _showItemDialog({GroceryItem? item}) {
    final nameController = TextEditingController(text: item?.name ?? '');
    final quantityController = TextEditingController(text: item?.quantity.toString() ?? '1');
    final priceController = TextEditingController(text: item?.price.toString() ?? '0.00');
    String selectedCategory = item?.category ?? _categories.first;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'Add Item' : 'Edit Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: quantityController,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: priceController,
                    decoration: InputDecoration(
                      labelText: 'Price (\$)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Row(
                    children: [
                      Icon(_getCategoryIcon(category), size: 20),
                      SizedBox(width: 8),
                      Text(category),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                selectedCategory = value!;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                final newItem = GroceryItem(
                  id: item?.id,
                  name: nameController.text,
                  quantity: int.tryParse(quantityController.text) ?? 1,
                  category: selectedCategory,
                  price: double.tryParse(priceController.text) ?? 0.0,
                  isPurchased: item?.isPurchased ?? false,
                  createdAt: item?.createdAt,
                );
                
                if (item == null) {
                  _addItem(newItem);
                } else {
                  _updateItem(newItem);
                }
                Navigator.pop(ctx);
              }
            },
            child: Text(item == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  void _showBudgetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Budget Summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBudgetRow('Total Items:', '${_items.length}'),
            _buildBudgetRow('Purchased Items:', '${_items.where((i) => i.isPurchased).length}'),
            _buildBudgetRow('Remaining Items:', '${_items.where((i) => !i.isPurchased).length}'),
            Divider(),
            _buildBudgetRow('Total Budget:', '\$${_totalBudget.toStringAsFixed(2)}'),
            _buildBudgetRow('Amount Spent:', '\$${_spentAmount.toStringAsFixed(2)}'),
            _buildBudgetRow('Remaining Budget:', '\$${(_totalBudget - _spentAmount).toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Future<void> _addItem(GroceryItem item) async {
    await StorageHelper.addItem(item);
    _loadItems();
  }

  Future<void> _updateItem(GroceryItem item) async {
    await StorageHelper.updateItem(item);
    _loadItems();
  }

  Future<void> _deleteItem(GroceryItem item) async {
    await StorageHelper.deleteItem(item.id);
    _loadItems();
  }

  Future<void> _toggleItemPurchased(GroceryItem item) async {
    item.isPurchased = !item.isPurchased;
    await StorageHelper.updateItem(item);
    _loadItems();
  }
}