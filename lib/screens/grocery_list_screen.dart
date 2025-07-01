import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
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
  MobileScannerController? _scannerController;

  double? _budgetLimit;

  String? _expandedCategory; // Track expanded/collapsed state of categories

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadBudget();
  }

  Future<void> _loadBudget() async {
    final budget = await StorageHelper.getBudget();
    setState(() {
      _budgetLimit = budget;
    });
  }

  Future<void> _setBudget(double value) async {
    await StorageHelper.setBudget(value);
    setState(() {
      _budgetLimit = value;
    });
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
          IconButton(
            icon: Icon(Icons.qr_code),
            onPressed: _showShareOptions,
          ),
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
            child: _buildCategoryListOrEmpty(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        child: Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryListOrEmpty() {
    // Only show the selected category header and its suggestions/items
    if (_selectedCategory == 'All') {
      if (_itemsByCategory.isEmpty) {
        return Center(child: Text('No items in your list. Tap + to add.'));
      } else {
        return ListView.builder(
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
        );
      }
    } else {
      // Show only the selected category header and its suggestions/items
      return ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildCategoryHeader(_selectedCategory),
          ...(_itemsByCategory[_selectedCategory]
                  ?.map((item) => _buildItemCard(item)) ??
              []),
        ],
      );
    }
  }

  Widget _buildBudgetSummary() {
    final overBudget = _budgetLimit != null && _spentAmount > _budgetLimit!;
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
          _budgetTile(
              'Spent', _spentAmount, overBudget ? Colors.red : Colors.red),
          GestureDetector(
            onTap: _showSetBudgetDialog,
            child: Column(
              children: [
                Text('Budget', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  _budgetLimit != null
                      ? 'RM${_budgetLimit!.toStringAsFixed(2)}'
                      : 'Set',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
          _budgetTile(
            'Remaining',
            _budgetLimit != null
                ? _budgetLimit! - _spentAmount
                : _totalBudget - _spentAmount,
            overBudget ? Colors.red : Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _budgetTile(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        Text(
          'RM${value.toStringAsFixed(2)}',
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
        children: _categories.map((c) => _buildCategoryChip(c)).toList(),
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
        onSelected: (_) {
          setState(() {
            _selectedCategory = category;
            // Expand/collapse suggestions for this category
            _expandedCategory = category == 'All' ? null : category;
          });
        },
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          if (category != 'All' && _expandedCategory == category)
            _buildQuickSuggestionsRow(category),
        ],
      ),
    );
  }

  // Suggestion row under each category header
  Widget _buildQuickSuggestionsRow(String category) {
    final Map<String, List<String>> quickItems = {
      'Fruits & Vegetables': [
        'Apple',
        'Banana',
        'Carrot',
        'Tomato',
        'Potato',
        'Spinach'
      ],
      'Dairy & Eggs': ['Milk', 'Eggs', 'Cheese', 'Yogurt', 'Butter'],
      'Meat & Seafood': [
        'Chicken Breast',
        'Salmon',
        'Beef',
        'Shrimp',
        'Sausage'
      ],
      'Pantry': ['Rice', 'Pasta', 'Bread', 'Flour', 'Sugar', 'Salt'],
      'Beverages': ['Water', 'Juice', 'Coffee', 'Tea', 'Soda'],
      'Snacks': ['Chips', 'Chocolate', 'Cookies', 'Nuts', 'Popcorn'],
      'Frozen': [
        'Ice Cream',
        'Frozen Pizza',
        'Frozen Vegetables',
        'Frozen Fries'
      ],
      'Household': ['Toilet Paper', 'Soap', 'Detergent', 'Shampoo'],
      'Other': ['Batteries', 'Pet Food', 'Light Bulb'],
    };
    final items = quickItems[category] ?? [];
    if (items.isEmpty) return SizedBox.shrink();
    return Container(
      margin: EdgeInsets.only(top: 4, left: 32),
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: items.map((itemName) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(itemName),
              avatar: Icon(Icons.add, size: 18, color: Colors.green),
              onPressed: () async {
                final item = GroceryItem(
                  name: itemName,
                  quantity: 1,
                  price: 0.0,
                  category: category,
                  isPurchased: false,
                );
                await _addItem(item);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$itemName added!')),
                );
              },
              backgroundColor: Colors.green[50],
              shape: StadiumBorder(side: BorderSide(color: Colors.green[200]!)),
            ),
          );
        }).toList(),
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
          'Qty: ${item.quantity} • RM${(item.price * item.quantity).toStringAsFixed(2)}',
        ),
        trailing: PopupMenuButton<String>(
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
          onSelected: (value) {
            if (value == 'edit')
              _showItemDialog(item: item);
            else if (value == 'delete') _deleteItem(item);
          },
        ),
      ),
    );
  }

  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share Your List',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.qr_code, color: Colors.green),
              title: Text('Generate QR Code'),
              subtitle: Text('Create QR code to share your list'),
              onTap: () {
                Navigator.pop(context);
                _generateQRCode();
              },
            ),
            ListTile(
              leading: Icon(Icons.qr_code_scanner, color: Colors.blue),
              title: Text('Scan QR Code'),
              subtitle: Text('Import list from QR code'),
              onTap: () {
                Navigator.pop(context);
                _scanQRCode();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _generateQRCode() {
    // Use the new simple format: {'l': [{'n': name, 'q': quantity}, ...]}
    final simpleList = {
      'l': _items.map((item) => {
        'n': item.name,
        'q': item.quantity,
      }).toList(),
    };

    final qrData = json.encode(simpleList);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Share Grocery List'),
        content: Container(
          width: 250,
          height: 250,
          child: QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: 250.0,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _scanQRCode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRScannerScreen(),
      ),
    );
    if (result != null && result is String) {
      _processScannedData(result);
    }
  }

  void _processScannedData(String data) {
    try {
      final Map<String, dynamic> decoded = json.decode(data);
      List<dynamic> items = [];
      String sharedBy = 'Unknown';

      if (decoded.containsKey('items')) {
        // Old format
        items = decoded['items'];
        sharedBy = decoded['sharedBy'] ?? 'Unknown';
      } else if (decoded.containsKey('l')) {
        // New simple format
        items = decoded['l'].map((item) => {
          'name': item['n'],
          'quantity': item['q'],
          'price': 0.0,
          'category': 'Other',
          'isPurchased': false,
          'createdAt': null,
        }).toList();
        sharedBy = 'QR Import';
      } else {
        throw Exception('Unrecognized QR format');
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Import Grocery List'),
          content: Text('Import ${items.length} items shared by $sharedBy?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _importItems(items);
                Navigator.pop(context);
              },
              child: Text('Import'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid QR code')),
      );
    }
  }

  Future<void> _importItems(List<dynamic> itemsData) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final batch = FirebaseFirestore.instance.batch();

    for (var itemData in itemsData) {
      final item = GroceryItem.fromJson(itemData);
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('groceries')
          .doc();

      batch.set(docRef, {
        'name': item.name,
        'quantity': item.quantity,
        'price': item.price,
        'category': item.category,
        'isPurchased': false, // Reset purchase status
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    await _loadItems();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Items imported successfully!')),
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
    String selectedCategory = item?.category ?? _categories[1]; // Skip 'All'

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
                    decoration: InputDecoration(
                      labelText: 'Price (RM)',
                      prefixText: 'RM ',
                    ),
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
              items: _categories.skip(1).map((cat) {
                // Skip 'All'
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

  // Quick add: Show a dialog with common grocery items by category for fast adding
  void _showQuickAddDialog() {
    final Map<String, List<String>> quickItems = {
      'Fruits & Vegetables': [
        'Apple',
        'Banana',
        'Carrot',
        'Tomato',
        'Potato',
        'Spinach'
      ],
      'Dairy & Eggs': ['Milk', 'Eggs', 'Cheese', 'Yogurt', 'Butter'],
      'Meat & Seafood': [
        'Chicken Breast',
        'Salmon',
        'Beef',
        'Shrimp',
        'Sausage'
      ],
      'Pantry': ['Rice', 'Pasta', 'Bread', 'Flour', 'Sugar', 'Salt'],
      'Beverages': ['Water', 'Juice', 'Coffee', 'Tea', 'Soda'],
      'Snacks': ['Chips', 'Chocolate', 'Cookies', 'Nuts', 'Popcorn'],
      'Frozen': [
        'Ice Cream',
        'Frozen Pizza',
        'Frozen Vegetables',
        'Frozen Fries'
      ],
      'Household': ['Toilet Paper', 'Soap', 'Detergent', 'Shampoo'],
      'Other': ['Batteries', 'Pet Food', 'Light Bulb'],
    };
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quick Add Groceries'),
        content: Container(
          width: double.maxFinite,
          child: DefaultTabController(
            length: quickItems.keys.length,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TabBar(
                  isScrollable: true,
                  tabs: quickItems.keys.map((cat) => Tab(text: cat)).toList(),
                  labelColor: Colors.green,
                  unselectedLabelColor: Colors.black,
                ),
                Container(
                  height: 200,
                  child: TabBarView(
                    children: quickItems.entries.map((entry) {
                      return ListView(
                        children: entry.value.map((itemName) {
                          return ListTile(
                            title: Text(itemName),
                            trailing: Icon(Icons.add, color: Colors.green),
                            onTap: () async {
                              final item = GroceryItem(
                                name: itemName,
                                quantity: 1,
                                price: 0.0,
                                category: entry.key,
                                isPurchased: false,
                              );
                              await _addItem(item);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$itemName added!')),
                              );
                            },
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close')),
        ],
      ),
    );
  }

  void _showBudgetDialog() {
    final overBudget = _budgetLimit != null && _spentAmount > _budgetLimit!;
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
            _budgetRow('Total Budget', 'RM${_totalBudget.toStringAsFixed(2)}'),
            _budgetRow('Spent', 'RM${_spentAmount.toStringAsFixed(2)}'),
            _budgetRow(
              'Budget Limit',
              _budgetLimit != null
                  ? 'RM${_budgetLimit!.toStringAsFixed(2)}'
                  : 'Not set',
            ),
            _budgetRow(
              'Remaining',
              _budgetLimit != null
                  ? 'RM${(_budgetLimit! - _spentAmount).toStringAsFixed(2)}'
                  : 'RM${(_totalBudget - _spentAmount).toStringAsFixed(2)}',
            ),
            if (overBudget)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'You have exceeded your budget!',
                  style:
                      TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close')),
          TextButton(
              onPressed: _showSetBudgetDialog, child: Text('Set Budget')),
        ],
      ),
    );
  }

  void _showSetBudgetDialog() {
    final controller = TextEditingController(
      text: _budgetLimit != null ? _budgetLimit!.toStringAsFixed(2) : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Set Budget Limit'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Budget (RM)',
            prefixText: 'RM ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value >= 0) {
                _setBudget(value);
                Navigator.pop(ctx);
              }
            },
            child: Text('Save'),
          ),
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

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }
}

// Separate QR Scanner Screen
class QRScannerScreen extends StatefulWidget {
  // Remove onScanned callback
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  _QRScannerScreenState createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan QR Code'),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        actions: [
          IconButton(
            color: Colors.white,
            icon: ValueListenableBuilder(
              valueListenable: cameraController.torchState,
              builder: (context, state, child) {
                switch (state) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                }
                return child ?? Container();
              },
            ),
            iconSize: 32.0,
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            color: Colors.white,
            icon: ValueListenableBuilder(
              valueListenable: cameraController.cameraFacingState,
              builder: (context, state, child) {
                switch (state) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front);
                  case CameraFacing.back:
                    return const Icon(Icons.camera_rear);
                }
                return child ?? Container();
              },
            ),
            iconSize: 32.0,
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              if (!_isScanned) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    setState(() {
                      _isScanned = true;
                    });
                    Navigator.pop(context, barcode.rawValue!);
                    break;
                  }
                }
              }
            },
          ),
          // Scanning overlay
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: Colors.green,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 250,
              ),
            ),
          ),
          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(16),
              child: Text(
                'Position the QR code within the frame to scan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}

// Custom overlay shape for QR scanner
class QrScannerOverlayShape extends ShapeBorder {
  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    double? cutOutSize,
    double? cutOutWidth,
    double? cutOutHeight,
  })  : cutOutWidth = cutOutWidth ?? cutOutSize ?? 250,
        cutOutHeight = cutOutHeight ?? cutOutSize ?? 250;

  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutWidth;
  final double cutOutHeight;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path();
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final cutOutWidth =
        this.cutOutWidth < width ? this.cutOutWidth : width - borderWidth;
    final cutOutHeight =
        this.cutOutHeight < height ? this.cutOutHeight : height - borderWidth;

    final cutOutRect = Rect.fromLTWH(
      rect.left + (width - cutOutWidth) / 2,
      rect.top + (height - cutOutHeight) / 2,
      cutOutWidth,
      cutOutHeight,
    );

    // Draw only the border corners (no overlay fill)
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final path = Path();
    final double radius = borderRadius;
    final double length = borderLength;

    // Top left corner
    path.moveTo(cutOutRect.left, cutOutRect.top + length);
    path.lineTo(cutOutRect.left, cutOutRect.top + radius);
    path.arcToPoint(
      Offset(cutOutRect.left + radius, cutOutRect.top),
      radius: Radius.circular(radius),
      clockwise: false,
    );
    path.lineTo(cutOutRect.left + length, cutOutRect.top);

    // Top right corner
    path.moveTo(cutOutRect.right - length, cutOutRect.top);
    path.lineTo(cutOutRect.right - radius, cutOutRect.top);
    path.arcToPoint(
      Offset(cutOutRect.right, cutOutRect.top + radius),
      radius: Radius.circular(radius),
      clockwise: false,
    );
    path.lineTo(cutOutRect.right, cutOutRect.top + length);

    // Bottom right corner
    path.moveTo(cutOutRect.right, cutOutRect.bottom - length);
    path.lineTo(cutOutRect.right, cutOutRect.bottom - radius);
    path.arcToPoint(
      Offset(cutOutRect.right - radius, cutOutRect.bottom),
      radius: Radius.circular(radius),
      clockwise: false,
    );
    path.lineTo(cutOutRect.right - length, cutOutRect.bottom);

    // Bottom left corner
    path.moveTo(cutOutRect.left + length, cutOutRect.bottom);
    path.lineTo(cutOutRect.left + radius, cutOutRect.bottom);
    path.arcToPoint(
      Offset(cutOutRect.left, cutOutRect.bottom - radius),
      radius: Radius.circular(radius),
      clockwise: false,
    );
    path.lineTo(cutOutRect.left, cutOutRect.bottom - length);

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}
