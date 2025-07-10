import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'package:flutter/scheduler.dart';

// FIX: Use correct import paths for your app
import '../models/grocery_item.dart';
import '../utils/storage_helper.dart';
import '../utils/auth_service.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class GroceryListScreen extends StatefulWidget {
  @override
  _GroceryListScreenState createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen>
    with SingleTickerProviderStateMixin {
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

  // Animation controllers
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;
  late Animation<double> _fabRotateAnimation;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _loadBudget();

    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabScaleAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeOutBack,
    ));
    _fabRotateAnimation =
        Tween<double>(begin: 0.0, end: 0.125).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    ));

    // Start FAB animation after the first frame is rendered
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _fabAnimationController.forward();
    });
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
        return Icons.local_florist;
      case 'Dairy & Eggs':
        return Icons.egg_alt;
      case 'Meat & Seafood':
        return Icons.fastfood;
      case 'Pantry':
        return Icons.storage;
      case 'Beverages':
        return Icons.local_drink;
      case 'Snacks':
        return Icons.cookie;
      case 'Frozen':
        return Icons.icecream;
      case 'Household':
        return Icons.cleaning_services;
      default:
        return Icons.shopping_basket;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: _buildCustomAppBar(),
      ),
      body: Column(
        children: [
          // Quick Add Button (Moved to top)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _showQuickAddDialog,
                      icon: Icon(Icons.flash_on, color: Colors.black87),
                      label: Text('Quick Add',
                          style: TextStyle(color: Colors.black87)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10), // Spacing between buttons
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _removeAllItems,
                      icon: Icon(Icons.delete_sweep, color: Colors.white),
                      label: Text('Clear All',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildBudgetSummary(),
          _buildCategoryChips(),
          Expanded(
            child: _buildCategoryListOrEmpty(),
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabScaleAnimation,
        child: FloatingActionButton(
          heroTag: 'addItemFab',
          onPressed: _showAddItemDialog,
          child: Icon(Icons.add),
          backgroundColor: Colors.teal[600],
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return AppBar(
      title: Text('Smart Grocery List', style: TextStyle(color: Colors.white)),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal[700]!, Colors.teal[500]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      actions: [
        
        IconButton(
          icon: Icon(Icons.qr_code_scanner, color: Colors.white),
          onPressed: _scanQRCode,
          tooltip: 'Scan QR Code',
        ),
        IconButton(
          icon: Icon(Icons.qr_code, color: Colors.white),
          onPressed: _generateQRCode,
          tooltip: 'Generate QR Code',
        ),
        // Removed the budget analytics button as requested
        // IconButton(
        //   icon: Icon(Icons.analytics, color: Colors.white),
        //   onPressed: _showBudgetDialog,
        //   tooltip: 'Budget Analytics',
        // ),
        IconButton(
          icon: Icon(Icons.account_circle, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProfileScreen()),
            );
          },
          tooltip: 'Profile',
        ),
      ],
    );
  }

  Widget _buildCategoryListOrEmpty() {
    if (_selectedCategory == 'All') {
      if (_itemsByCategory.isEmpty) {
        return _buildEmptyMessage();
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
      if (_itemsByCategory[_selectedCategory]?.isEmpty ?? true) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getCategoryIcon(_selectedCategory),
                  size: 60, color: Colors.blueGrey[300]),
              SizedBox(height: 16),
              Text(
                'No items in "${_selectedCategory}"',
                style: TextStyle(fontSize: 18, color: Colors.blueGrey[600]),
                textAlign: TextAlign.center,
              ),
              Text(
                'Tap the "Quick Add" or "+" button to add some!',
                style: TextStyle(color: Colors.blueGrey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }
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
    final budgetProgress = _budgetLimit != null
        ? (_spentAmount / _budgetLimit!).clamp(0.0, 1.0)
        : 0.0;
    Color progressColor;
    if (overBudget) {
      progressColor = Colors.red;
    } else if (budgetProgress > 0.75) {
      progressColor = Colors.amber;
    } else {
      progressColor = Colors.teal;
    }

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.15),
            spreadRadius: 2,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budget Overview',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[800]),
              ),
              GestureDetector(
                onTap: _showSetBudgetDialog,
                child: Chip(
                  label: Text(
                    _budgetLimit != null
                        ? 'RM${_budgetLimit!.toStringAsFixed(2)}'
                        : 'Set Budget',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Colors.teal[500],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          LinearProgressIndicator(
            value: budgetProgress,
            backgroundColor: Colors.blueGrey[200],
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _budgetDetail('Total Cost', _totalBudget, Colors.teal),
              _budgetDetail('Spent', _spentAmount, progressColor),
              _budgetDetail(
                'Remaining',
                _budgetLimit != null
                    ? _budgetLimit! - _spentAmount
                    : 0.0, // Show 0 if no budget set
                progressColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _budgetDetail(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.blueGrey[600]),
        ),
        Text(
          'RM${value.toStringAsFixed(2)}',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category;
                  _expandedCategory = category == 'All' ? null : category;
                });
              },
              selectedColor: Colors.amber[700],
              backgroundColor: Colors.blueGrey[200],
              labelStyle: TextStyle(
                color: isSelected ? Colors.black87 : Colors.blueGrey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              elevation: isSelected ? 4 : 0,
              shadowColor: Colors.amber[100],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
                side: BorderSide(
                  color: isSelected ? Colors.amber[800]! : Colors.transparent,
                  width: 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
            'https://placehold.co/150x150/E0F2F7/263238?text=Empty+List', // Placeholder image
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.shopping_cart_outlined,
              size: 100,
              color: Colors.blueGrey[300],
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Your grocery list is empty!',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[700]),
          ),
          SizedBox(height: 8),
          Text(
            'Start by adding your first item using the buttons below.',
            style: TextStyle(fontSize: 16, color: Colors.blueGrey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String category) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedCategory = _expandedCategory == category ? null : category;
        });
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getCategoryIcon(category),
                    color: Colors.teal[600], size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal[800],
                    ),
                  ),
                ),
                Icon(
                  _expandedCategory == category
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.blueGrey[600],
                ),
              ],
            ),
            AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return SizeTransition(sizeFactor: animation, child: child);
              },
              child:
                  (_selectedCategory == 'All' || _expandedCategory == category)
                      ? _buildQuickSuggestionsRow(category)
                      : SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

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
      margin: EdgeInsets.only(top: 8, left: 32),
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: items.map((itemName) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(itemName),
              avatar: Icon(Icons.add, size: 18, color: Colors.teal[700]),
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
              backgroundColor: Colors.amber[100],
              shape: StadiumBorder(side: BorderSide(color: Colors.amber[400]!)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildItemCard(GroceryItem item) {
    return Dismissible(
      key: Key(item.id!),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20),
        color: Colors.red[600],
        child: Icon(Icons.delete_forever, color: Colors.white, size: 30),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Confirm Deletion"),
              content: Text("Are you sure you want to delete '${item.name}'?"),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text("Delete"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        _deleteItem(item);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.name} dismissed')),
        );
      },
      child: Card(
        margin: EdgeInsets.only(bottom: 10),
        elevation: item.isPurchased ? 2 : 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
            color: item.isPurchased ? Colors.blueGrey[300]! : Colors.teal[100]!,
            width: item.isPurchased ? 1 : 2,
          ),
        ),
        color: item.isPurchased ? Colors.blueGrey[100] : Colors.white,
        child: InkWell(
          onTap: () => _toggleItemPurchased(item),
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(
                  item.isPurchased ? Icons.check_circle : Icons.circle_outlined,
                  color: item.isPurchased
                      ? Colors.teal[600]
                      : Colors.blueGrey[500],
                  size: 28,
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          decoration: item.isPurchased
                              ? TextDecoration.lineThrough
                              : null,
                          color: item.isPurchased
                              ? Colors.blueGrey[600]
                              : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Qty: ${item.quantity} • RM${(item.price * item.quantity).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: item.isPurchased
                              ? Colors.blueGrey[500]
                              : Colors.blueGrey[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blueGrey[400]),
                  onPressed: () => _showItemDialog(item: item),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _generateQRCode() {
    final simpleList = {
      'l': _items
          .map((item) => {
                'n': item.name,
                'q': item.quantity,
              })
          .toList(),
    };

    final qrData = json.encode(simpleList);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Share Grocery List',
            style: TextStyle(color: Colors.teal[700])),
        content: Container(
          width: 250,
          height: 250,
          child: QrImageView(
            data: qrData,
            version: QrVersions.auto,
            size: 250.0,
            eyeStyle: QrEyeStyle(
                eyeShape: QrEyeShape.square, color: Colors.teal[800]!),
            dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.teal[700]!),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Colors.teal[700])),
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
        items = decoded['items'];
        sharedBy = decoded['sharedBy'] ?? 'Unknown';
      } else if (decoded.containsKey('l')) {
        items = decoded['l']
            .map((item) => {
                  'name': item['n'],
                  'quantity': item['q'],
                  'price': 0.0,
                  'category': 'Other',
                  'isPurchased': false,
                  'createdAt': null,
                })
            .toList();
        sharedBy = 'QR Import';
      } else {
        throw Exception('Unrecognized QR format');
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Import Grocery List',
              style: TextStyle(color: Colors.teal[700])),
          content: Text('Import ${items.length} items shared by $sharedBy?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  Text('Cancel', style: TextStyle(color: Colors.blueGrey[600])),
            ),
            ElevatedButton(
              onPressed: () async {
                await _importItems(items);
                Navigator.pop(context);
              },
              child: Text('Import'),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.teal[600]),
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
    String selectedCategory = item?.category ?? _categories[1];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'Add Item' : 'Edit Item',
            style: TextStyle(color: Colors.teal[700])),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  prefixIcon: Icon(Icons.shopping_bag, color: Colors.teal[600]),
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyController,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        prefixIcon: Icon(Icons.format_list_numbered,
                            color: Colors.teal[600]),
                      ),
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
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        prefixIcon:
                            Icon(Icons.attach_money, color: Colors.teal[600]),
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
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  prefixIcon: Icon(Icons.category, color: Colors.teal[600]),
                ),
                items: _categories.skip(1).map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Row(
                      children: [
                        Icon(_getCategoryIcon(cat),
                            size: 20, color: Colors.teal[600]),
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: TextStyle(color: Colors.blueGrey[600])),
          ),
          ElevatedButton(
            child: Text(item == null ? 'Add Item' : 'Update Item'),
            onPressed: () {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Item name cannot be empty!')),
                );
                return;
              }
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[600]),
          ),
        ],
      ),
    );
  }

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
        title: Text('Quick Add Groceries',
            style: TextStyle(color: Colors.teal[700])),
        content: Container(
          width: double.maxFinite,
          child: DefaultTabController(
            length: quickItems.keys.length,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TabBar(
                  isScrollable: true,
                  tabs: quickItems.keys
                      .map((cat) => Tab(
                            text: cat,
                            icon: Icon(_getCategoryIcon(cat)),
                          ))
                      .toList(),
                  labelColor: Colors.teal[700],
                  unselectedLabelColor: Colors.blueGrey[600],
                  indicatorColor: Colors.teal[700],
                ),
                Container(
                  height: 300,
                  child: TabBarView(
                    children: quickItems.entries.map((entry) {
                      return GridView.builder(
                        padding: const EdgeInsets.all(8.0),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: entry.value.length,
                        itemBuilder: (context, index) {
                          final itemName = entry.value[index];
                          return Card(
                            elevation: 2,
                            child: InkWell(
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
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.add_circle_outline,
                                        color: Colors.teal),
                                    SizedBox(width: 8),
                                    Expanded(
                                        child: Text(itemName,
                                            overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('Close', style: TextStyle(color: Colors.blueGrey[600]))),
        ],
      ),
    );
  }

  void _showBudgetDialog() {
    final overBudget = _budgetLimit != null && _spentAmount > _budgetLimit!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            Text('Budget Summary', style: TextStyle(color: Colors.teal[700])),
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
            _budgetRow(
                'Total Cost of List', 'RM${_totalBudget.toStringAsFixed(2)}'),
            _budgetRow('Amount Spent', 'RM${_spentAmount.toStringAsFixed(2)}'),
            _budgetRow(
              'Budget Limit',
              _budgetLimit != null
                  ? 'RM${_budgetLimit!.toStringAsFixed(2)}'
                  : 'Not set',
            ),
            _budgetRow(
              'Remaining Budget',
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
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  Text('Close', style: TextStyle(color: Colors.blueGrey[600]))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Close current dialog
              _showSetBudgetDialog(); // Open set budget dialog
            },
            child: Text('Set Budget'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[600]),
          ),
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
        title:
            Text('Set Budget Limit', style: TextStyle(color: Colors.teal[700])),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Budget (RM)',
            prefixText: 'RM ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: TextStyle(color: Colors.blueGrey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value >= 0) {
                _setBudget(value);
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Please enter a valid budget amount.')),
                );
              }
            },
            child: Text('Save'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[600]),
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

  // New function to remove all items
  Future<void> _removeAllItems() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Clear All Items?"),
          content: const Text(
              "Are you sure you want to remove all items from your grocery list? This action cannot be undone."),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Remove All"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        final userId = FirebaseAuth.instance.currentUser!.uid;
        final collectionRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('groceries');

        final snapshot = await collectionRef.get();
        for (DocumentSnapshot doc in snapshot.docs) {
          await doc.reference.delete();
        }
        _loadItems(); // Reload the list to reflect changes
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('All items removed successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove all items: $e')),
        );
      }
    }
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
    _fabAnimationController.dispose();
    super.dispose();
  }
}

class QRScannerScreen extends StatefulWidget {
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
        title: Text('Scan QR Code', style: TextStyle(color: Colors.white)),
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
                    return const Icon(Icons.flash_off, color: Colors.blueGrey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.amber);
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
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: Colors.teal,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 250,
              ),
            ),
          ),
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

class QrScannerOverlayShape extends ShapeBorder {
  const QrScannerOverlayShape({
    this.borderColor = Colors.teal,
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
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(rect),
      Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              rect.left + (rect.width - cutOutWidth) / 2,
              rect.top + (rect.height - cutOutHeight) / 2,
              cutOutWidth,
              cutOutHeight,
            ),
            Radius.circular(borderRadius),
          ),
        )
        ..close(),
    );
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

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect),
        Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              cutOutRect,
              Radius.circular(borderRadius),
            ),
          )
          ..close(),
      ),
      Paint()..color = overlayColor,
    );

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final path = Path();
    final double radius = borderRadius;
    final double length = borderLength;

    path.moveTo(cutOutRect.left, cutOutRect.top + length);
    path.lineTo(cutOutRect.left, cutOutRect.top + radius);
    path.arcToPoint(
      Offset(cutOutRect.left + radius, cutOutRect.top),
      radius: Radius.circular(radius),
      clockwise: false,
    );
    path.lineTo(cutOutRect.left + length, cutOutRect.top);

    path.moveTo(cutOutRect.right - length, cutOutRect.top);
    path.lineTo(cutOutRect.right - radius, cutOutRect.top);
    path.arcToPoint(
      Offset(cutOutRect.right, cutOutRect.top + radius),
      radius: Radius.circular(radius),
      clockwise: false,
    );
    path.lineTo(cutOutRect.right, cutOutRect.top + length);

    path.moveTo(cutOutRect.right, cutOutRect.bottom - length);
    path.lineTo(cutOutRect.right, cutOutRect.bottom - radius);
    path.arcToPoint(
      Offset(cutOutRect.right - radius, cutOutRect.bottom),
      radius: Radius.circular(radius),
      clockwise: false,
    );
    path.lineTo(cutOutRect.right - length, cutOutRect.bottom);

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
