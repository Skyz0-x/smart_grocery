import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// FIX: Use correct import paths for your app
import '../models/grocery_item.dart';
import '../utils/storage_helper.dart';
import '../utils/auth_service.dart';
import 'login_screen.dart';

class GroceryListScreen extends StatefulWidget {
  @override
  _GroceryListScreenState createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  List<GroceryItem> _items = [];
  // FIX: Add 'All' to the categories list
  List<String> _categories = [
    'All',
    'Fruits & Vegetables',
    'Dairy & Eggs',
    'Meat & Seafood',
    'Pantry',
    'Beverages',
    'Snacks',
    'Frozen',
    'Household',
    'Other',
  ];
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('groceries')
        .orderBy('createdAt', descending: true)
        .get();

    setState(() {
      _items = snapshot.docs.map((doc) {
        final data = doc.data();
        return GroceryItem(
          id: doc.id,
          name: data['name'],
          quantity: data['quantity'],
          price: (data['price'] as num).toDouble(),
          category: data['category'],
          isPurchased: data['isPurchased'] ?? false,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        );
      }).toList();
    });
  }

  List<GroceryItem> get _filteredItems {
    if (_selectedCategory == 'All') return _items;
    return _items.where((item) => item.category == _selectedCategory).toList();
  }

  Map<String, List<GroceryItem>> get _itemsByCategory {
    Map<String, List<GroceryItem>> map = {};
    for (var item in _filteredItems) {
      map.putIfAbsent(item.category, () => []).add(item);
    }
    return map;
  }

  double get _totalBudget =>
      _items.fold(0.0, (sum, i) => sum + i.price * i.quantity);
  double get _spentAmount => _items
      .where((i) => i.isPurchased)
      .fold(0.0, (sum, i) => sum + i.price * i.quantity);

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
          IconButton(icon: Icon(Icons.analytics), onPressed: _showBudgetDialog),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await AuthService.logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBudgetSummary(),
          _buildCategoryChips(),
          Expanded(
            child: _items.isEmpty
                ? _buildEmptyMessage()
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _itemsByCategory.keys.length,
                    itemBuilder: (context, index) {
                      final category = _itemsByCategory.keys.elementAt(index);
                      final items = _itemsByCategory[category]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCategoryHeader(category),
                          ...items.map((item) => _buildItemCard(item)),
                          SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildBudgetSummary() {
    return Container(
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
          _budgetTile('Total', _totalBudget, Colors.green),
          _budgetTile('Spent', _spentAmount, Colors.red),
          _budgetTile('Remaining', _totalBudget - _spentAmount, Colors.blue),
        ],
      ),
    );
  }

  Widget _budgetTile(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: TextStyle(fontSize: 18, color: color),
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildCategoryChip('All'),
          ..._categories.map((c) => _buildCategoryChip(c)),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    final isSelected = _selectedCategory == category;
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(category),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedCategory = category),
        selectedColor: Colors.green[200],
        checkmarkColor: Colors.green[700],
      ),
    );
  }

  Widget _buildEmptyMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No items in your list',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          Text('Tap + to add your first item'),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String category) {
    return Padding(
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
    );
  }

  Widget _buildItemCard(GroceryItem item) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: ListTile(
        leading: Checkbox(
          value: item.isPurchased,
          onChanged: (_) => _toggleItemPurchased(item),
          activeColor: Colors.green[600],
        ),
        title: Text(
          item.name,
          style: TextStyle(
            decoration: item.isPurchased ? TextDecoration.lineThrough : null,
            color: item.isPurchased ? Colors.grey[600] : null,
          ),
        ),
        subtitle: Text(
          'Qty: ${item.quantity} • \$${(item.price * item.quantity).toStringAsFixed(2)}',
        ),
        trailing: PopupMenuButton<String>(
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
          onSelected: (value) {
            if (value == 'edit')
              _showItemDialog(item: item);
            else if (value == 'delete')
              _deleteItem(item);
          },
        ),
      ),
    );
  }

  void _showAddItemDialog() {
    _showItemDialog();
  }

  void _showItemDialog({GroceryItem? item}) {
    final nameController = TextEditingController(text: item?.name ?? '');
    final qtyController = TextEditingController(
      text: item?.quantity.toString() ?? '1',
    );
    final priceController = TextEditingController(
      text: item?.price.toString() ?? '0.0',
    );
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
              decoration: InputDecoration(labelText: 'Name'),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyController,
                    decoration: InputDecoration(labelText: 'Quantity'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: priceController,
                    decoration: InputDecoration(labelText: 'Price'),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: InputDecoration(labelText: 'Category'),
              items: _categories.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Row(
                    children: [
                      Icon(_getCategoryIcon(cat), size: 20),
                      SizedBox(width: 8),
                      Text(cat),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) => selectedCategory = val!,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            child: Text(item == null ? 'Add' : 'Update'),
            onPressed: () {
              if (nameController.text.isEmpty) return;
              final newItem = GroceryItem(
                id: item?.id,
                name: nameController.text.trim(),
                quantity: int.tryParse(qtyController.text) ?? 1,
                price: double.tryParse(priceController.text) ?? 0.0,
                category: selectedCategory,
                isPurchased: item?.isPurchased ?? false,
                createdAt: item?.createdAt,
              );
              item == null ? _addItem(newItem) : _updateItem(newItem);
              Navigator.pop(ctx);
            },
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
          children: [
            _budgetRow('Total Items', _items.length.toString()),
            _budgetRow(
              'Purchased',
              _items.where((i) => i.isPurchased).length.toString(),
            ),
            _budgetRow(
              'Remaining',
              _items.where((i) => !i.isPurchased).length.toString(),
            ),
            Divider(),
            _budgetRow('Total Budget', '\$${_totalBudget.toStringAsFixed(2)}'),
            _budgetRow('Spent', '\$${_spentAmount.toStringAsFixed(2)}'),
            _budgetRow(
              'Remaining',
              '\$${(_totalBudget - _spentAmount).toStringAsFixed(2)}',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close')),
        ],
      ),
    );
  }

  Widget _budgetRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('groceries')
          .add({
            'name': item.name,
            'quantity': item.quantity,
            'price': item.price,
            'category': item.category,
            'isPurchased': item.isPurchased,
            'createdAt': FieldValue.serverTimestamp(),
          });
      _loadItems();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add item: $e')));
    }
  }

  Future<void> _updateItem(GroceryItem item) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('groceries')
        .doc(item.id)
        .update({
          'name': item.name,
          'quantity': item.quantity,
          'price': item.price,
          'category': item.category,
          'isPurchased': item.isPurchased,
          // Don't update createdAt
        });
    _loadItems();
  }

  Future<void> _deleteItem(GroceryItem item) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('groceries')
        .doc(item.id)
        .delete();
    _loadItems();
  }

  Future<void> _toggleItemPurchased(GroceryItem item) async {
    final updatedItem = GroceryItem(
      id: item.id,
      name: item.name,
      quantity: item.quantity,
      category: item.category,
      price: item.price,
      isPurchased: !item.isPurchased,
      createdAt: item.createdAt,
    );
    await _updateItem(updatedItem);
  }

  Future<void> _firebaseTest() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('groceries')
        .get();

    final groceries = snapshot.docs.map((doc) => doc.data()).toList();
  }
}
