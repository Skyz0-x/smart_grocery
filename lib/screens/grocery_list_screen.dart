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
  List<GroceryItem> _deletedItems = []; // To store deleted items for history
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
    _loadDeletedItems(); // Load deleted items when screen initializes
  }

  Future<void> _loadItems() async {
    final items = await StorageHelper.getItems();
    setState(() {
      _items = items;
    });
  }

  Future<void> _loadDeletedItems() async {
    final deletedItems = await StorageHelper.getDeletedItemsHistory();
    setState(() {
      _deletedItems = deletedItems;
    });
  }

  Future<void> _loadBudget() async {
    final budget = await StorageHelper.getBudget();
    setState(() {
      _budgetLimit = budget;
    });
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? Colors.blue,
      ),
    );
  }

  double get _totalSpent {
    return _items.fold(
        0.0, (sum, item) => sum + (item.isPurchased ? (item.quantity * item.price) : 0));
  }

  void _addItem() {
    String name = '';
    int quantity = 1;
    double price = 0.0;
    String category = _categories[1]; // Default to first actual category

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add New Grocery Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(labelText: 'Item Name'),
                  onChanged: (value) => name = value,
                ),
                TextField(
                  decoration: InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => quantity = int.tryParse(value) ?? 1,
                ),
                TextField(
                  decoration: InputDecoration(labelText: 'Price per item'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) => price = double.tryParse(value) ?? 0.0,
                ),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: InputDecoration(labelText: 'Category'),
                  items: _categories.skip(1).map((String cat) {
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Text(cat),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      category = newValue;
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (name.isNotEmpty && quantity > 0) {
                  final newItem = GroceryItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    quantity: quantity,
                    price: price,
                    category: category,
                    createdAt: DateTime.now(),
                  );
                  await StorageHelper.addItem(newItem);
                  _loadItems();
                  Navigator.pop(context);
                } else {
                  _showSnackBar('Please enter valid item details.');
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _editItem(GroceryItem itemToEdit) {
    String name = itemToEdit.name;
    int quantity = itemToEdit.quantity;
    double price = itemToEdit.price;
    String category = itemToEdit.category;
    bool isPurchased = itemToEdit.isPurchased;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Grocery Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(labelText: 'Item Name'),
                  controller: TextEditingController(text: name),
                  onChanged: (value) => name = value,
                ),
                TextField(
                  decoration: InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: quantity.toString()),
                  onChanged: (value) => quantity = int.tryParse(value) ?? 1,
                ),
                TextField(
                  decoration: InputDecoration(labelText: 'Price per item'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  controller: TextEditingController(text: price.toStringAsFixed(2)),
                  onChanged: (value) => price = double.tryParse(value) ?? 0.0,
                ),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: InputDecoration(labelText: 'Category'),
                  items: _categories.skip(1).map((String cat) {
                    return DropdownMenuItem<String>(
                      value: cat,
                      child: Text(cat),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      category = newValue;
                    }
                  },
                ),
                CheckboxListTile(
                  title: Text('Purchased'),
                  value: isPurchased,
                  onChanged: (bool? newValue) {
                    if (newValue != null) {
                      setState(() {
                        isPurchased = newValue;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (name.isNotEmpty && quantity > 0) {
                  final updatedItem = itemToEdit.copyWith(
                    name: name,
                    quantity: quantity,
                    price: price,
                    category: category,
                    isPurchased: isPurchased,
                  );
                  await StorageHelper.updateItem(updatedItem);
                  _loadItems();
                  Navigator.pop(context);
                } else {
                  _showSnackBar('Please enter valid item details.');
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteItem(String id) async {
    await StorageHelper.deleteItem(id);
    _loadItems();
    _loadDeletedItems(); // Reload deleted items after deletion
    _showSnackBar('Item deleted and moved to history.');
  }

  void _toggleItemPurchased(GroceryItem item) async {
    final updatedItem = item.copyWith(isPurchased: !item.isPurchased);
    await StorageHelper.updateItem(updatedItem);
    _loadItems();
  }

  void _setBudget() {
    String budgetInput = (_budgetLimit ?? 0.0).toStringAsFixed(2);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Set Budget Limit'),
          content: TextField(
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            controller: TextEditingController(text: budgetInput),
            decoration: InputDecoration(labelText: 'Budget Amount'),
            onChanged: (value) => budgetInput = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newBudget = double.tryParse(budgetInput);
                if (newBudget != null && newBudget >= 0) {
                  await StorageHelper.saveBudget(newBudget);
                  _loadBudget();
                  Navigator.pop(context);
                } else {
                  _showSnackBar('Please enter a valid budget amount.');
                }
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showGenerateQrCodeDialog() {
    final String currentGroceryListJson = json.encode(_items.map((item) => item.toJson()).toList());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Share Grocery List (QR Code)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: currentGroceryListJson,
                version: QrVersions.auto,
                size: 200.0,
                gapless: false,
              ),
              SizedBox(height: 20),
              Text('Scan this QR code to share your grocery list.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showScanQrCodeDialog() {
    bool _isScanning = true;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Scan QR Code for Grocery List'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 250,
                    height: 250,
                    child: MobileScanner(
                      controller: _scannerController,
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty && _isScanning) {
                          final String? result = barcodes.first.rawValue;
                          if (result != null) {
                            try {
                              List<dynamic> decodedList = json.decode(result);
                              List<GroceryItem> scannedItems = decodedList.map((itemJson) => GroceryItem.fromJson(itemJson)).toList();
                              _mergeScannedItems(scannedItems);
                              _showSnackBar('Grocery list imported successfully!');
                              setState(() {
                                _isScanning = false; // Stop scanning after successful read
                              });
                              Navigator.pop(context); // Close dialog
                            } catch (e) {
                              _showSnackBar('Invalid QR code format.', backgroundColor: Colors.red);
                              print('QR Code scan error: $e');
                            } finally {
                              _scannerController?.stop(); // Stop scanner regardless of success/failure
                            }
                          }
                        }
                      },
                    ),
                  ),
                  SizedBox(height: 20),
                  Text('Align the QR code within the frame.'),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                _scannerController?.stop();
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    ).then((_) {
      _scannerController = null; // Clear controller after dialog closes
    });
  }

  void _mergeScannedItems(List<GroceryItem> scannedItems) async {
    List<GroceryItem> currentItems = await StorageHelper.getItems();
    for (var scannedItem in scannedItems) {
      // Check if item already exists to avoid duplicates (based on name and category)
      final existingItemIndex = currentItems.indexWhere(
            (item) =>
        item.name == scannedItem.name && item.category == scannedItem.category,
      );

      if (existingItemIndex != -1) {
        // If item exists, update its quantity and price
        final existingItem = currentItems[existingItemIndex];
        currentItems[existingItemIndex] = existingItem.copyWith(
          quantity: existingItem.quantity + scannedItem.quantity,
          price: (existingItem.price + scannedItem.price) / 2, // Average price
        );
      } else {
        // If item doesn't exist, add it to the list
        currentItems.add(scannedItem.copyWith(id: DateTime.now().millisecondsSinceEpoch.toString())); // Assign a new ID
      }
    }
    await StorageHelper.saveItems(currentItems);
    _loadItems();
  }

  void _logout() async {
    await AuthService.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginScreen()),
          (Route<dynamic> route) => false,
    );
  }

  // --- New: History Screen for Deleted Items ---
  void _showHistoryScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DeletedItemsHistoryScreen(
          deletedItems: _deletedItems,
          onRestore: (item) async {
            await StorageHelper.restoreDeletedItem(item.id!);
            _loadItems();
            _loadDeletedItems();
            _showSnackBar('Item "${item.name}" restored successfully!');
          },
          onClearHistory: () async {
            await StorageHelper.clearDeletedItemsHistory();
            _loadDeletedItems();
            _showSnackBar('History cleared!');
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _selectedCategory == 'All'
        ? _items
        : _items.where((item) => item.category == _selectedCategory).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Smart Grocery List', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: Colors.white),
            onPressed: _showHistoryScreen,
            tooltip: 'View History',
          ),
          IconButton(
            icon: Icon(Icons.qr_code_scanner, color: Colors.white),
            onPressed: _showScanQrCodeDialog,
            tooltip: 'Scan QR',
          ),
          IconButton(
            icon: Icon(Icons.qr_code, color: Colors.white),
            onPressed: _showGenerateQrCodeDialog,
            tooltip: 'Generate QR',
          ),
          IconButton(
            icon: Icon(Icons.account_circle, color: Colors.white),
            onPressed: () {
              // TODO: Navigate to profile or show user info
              _showSnackBar('Logged in as: ${AuthService.currentUser?.email ?? 'Guest'}');
            },
            tooltip: 'Profile',
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade50, Colors.lightGreen.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Budget Overview',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Spent:',
                              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                            ),
                            Text(
                              'RM${_totalSpent.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _totalSpent > (_budgetLimit ?? double.infinity)
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Budget Limit:',
                              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                            ),
                            GestureDetector(
                              onTap: _setBudget,
                              child: Text(
                                _budgetLimit == null
                                    ? 'Set Budget'
                                    : 'RM${_budgetLimit!.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Filter by Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                items: _categories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue!;
                  });
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return Dismissible(
                    key: Key(item.id!), // Unique key for Dismissible
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Icon(Icons.delete, color: Colors.white),
                    ),
                    secondaryBackground: Container(
                      color: Colors.blue,
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Icon(Icons.edit, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) { // Swiped to left for delete
                        return await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text("Confirm Delete"),
                              content: Text(
                                  "Are you sure you want to delete \"${item.name}\"? It will be moved to history."),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text("Cancel"),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text("Delete", style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            );
                          },
                        );
                      } else if (direction == DismissDirection.endToStart) { // Swiped to right for edit
                        _editItem(item);
                        return false; // Don't dismiss, just perform the edit action
                      }
                      return false; // Default to not dismissing
                    },
                    onDismissed: (direction) {
                      if (direction == DismissDirection.startToEnd) {
                        _deleteItem(item.id!);
                      }
                    },
                    child: Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        leading: Checkbox(
                          value: item.isPurchased,
                          onChanged: (bool? value) {
                            if (value != null) {
                              _toggleItemPurchased(item);
                            }
                          },
                          activeColor: Colors.green,
                        ),
                        title: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            decoration: item.isPurchased
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            color: item.isPurchased
                                ? Colors.grey
                                : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          '${item.quantity} x RM${item.price.toStringAsFixed(2)} - ${item.category}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            decoration: item.isPurchased
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        trailing: Text(
                          'RM${(item.quantity * item.price).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: item.isPurchased
                                ? Colors.grey
                                : Colors.green.shade700,
                          ),
                        ),
                        onTap: () => _editItem(item), // Tap to edit
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        label: Text('Add Item', style: TextStyle(color: Colors.white)),
        icon: Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.green,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// Custom Paint for QR Code border (from original code, keeping it)
class QrScannerOverlayShape extends ShapeBorder {
  QrScannerOverlayShape({
    this.borderColor = Colors.green,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 10,
    this.borderLength = 30,
    this.cutOutWidth = 250,
    this.cutOutHeight,
    this.cutOutBottomOffset = 0,
  });

  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutWidth;
  final double? cutOutHeight;
  final double cutOutBottomOffset;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

 @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(
        RRect.fromRectAndRadius(
          _getCutOutRect(rect), // Corrected: Removed space between _get and CutOutRect
          Radius.circular(borderRadius),
        ),
      );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final path = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect),
      Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            _getCutOutRect(rect),
            Radius.circular(borderRadius),
          ),
        ),
    );
    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final cutOutRect = _getCutOutRect(rect);

    // Draw the corners
    final double length = borderLength;
    final double radius = borderRadius;

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
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
      borderRadius: borderRadius * t,
      borderLength: borderLength * t,
      cutOutWidth: cutOutWidth * t,
      cutOutHeight: cutOutHeight != null ? cutOutHeight! * t : null,
      cutOutBottomOffset: cutOutBottomOffset * t,
    );
  }

  Rect _getCutOutRect(Rect rect) {
    final double cutOutHeight = this.cutOutHeight ?? cutOutWidth;
    final double cutOutLeft = (rect.width - cutOutWidth) / 2;
    final double cutOutTop = (rect.height - cutOutHeight) / 2 - cutOutBottomOffset;
    return Rect.fromLTWH(cutOutLeft, cutOutTop, cutOutWidth, cutOutHeight);
  }
}

// --- New: DeletedItemsHistoryScreen ---
class DeletedItemsHistoryScreen extends StatefulWidget {
  final List<GroceryItem> deletedItems;
  final Function(GroceryItem) onRestore;
  final VoidCallback onClearHistory;

  DeletedItemsHistoryScreen({
    required this.deletedItems,
    required this.onRestore,
    required this.onClearHistory,
  });

  @override
  State<DeletedItemsHistoryScreen> createState() => _DeletedItemsHistoryScreenState();
}

class _DeletedItemsHistoryScreenState extends State<DeletedItemsHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Deleted Items History', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: Icon(Icons.clear_all, color: Colors.white),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Clear History?'),
                  content: Text('Are you sure you want to clear all deleted items from history? This action cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: Text('Clear', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                widget.onClearHistory();
                setState(() {
                  // Update local state if the clear operation is successful
                  widget.deletedItems.clear();
                });
              }
            },
            tooltip: 'Clear History',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade50, Colors.red.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: widget.deletedItems.isEmpty
            ? Center(
          child: Text(
            'No deleted items in history.',
            style: TextStyle(fontSize: 18, color: Colors.grey[700]),
          ),
        )
            : ListView.builder(
          itemCount: widget.deletedItems.length,
          itemBuilder: (context, index) {
            final item = widget.deletedItems[index];
            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.all(16),
                title: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.quantity} x \$${item.price.toStringAsFixed(2)} - ${item.category}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (item.deletedAt != null)
                      Text(
                        'Deleted: ${item.deletedAt!.toLocal().toString().split(' ')[0]}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(Icons.restore, color: Colors.green),
                  onPressed: () {
                    widget.onRestore(item);
                    setState(() {
                      widget.deletedItems.removeAt(index); // Remove from local list after restoring
                    });
                  },
                  tooltip: 'Restore Item',
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}