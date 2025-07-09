import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/grocery_item.dart';

class StorageHelper {
  static const String _itemsKey = 'grocery_items';
  static const String _budgetKey = 'budget_limit';
  static const String _deletedItemsKey = 'deleted_grocery_items'; // New key for deleted items

  static Future<List<GroceryItem>> getItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String? itemsJson = prefs.getString(_itemsKey);
    if (itemsJson == null) return [];
    final List<dynamic> itemsList = json.decode(itemsJson);
    return itemsList.map((item) => GroceryItem.fromJson(item)).toList();
  }

  static Future<void> saveItems(List<GroceryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final String itemsJson =
        json.encode(items.map((item) => item.toJson()).toList());
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
    final itemToDelete = items.firstWhere((item) => item.id == id);
    items.removeWhere((item) => item.id == id);
    await saveItems(items);

    // Add to deleted items history
    await _addDeletedItemToHistory(itemToDelete.copyWith(deletedAt: DateTime.now()));
  }

  // New methods for deleted items history
  static Future<List<GroceryItem>> getDeletedItemsHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? deletedItemsJson = prefs.getString(_deletedItemsKey);
    if (deletedItemsJson == null) return [];
    final List<dynamic> itemsList = json.decode(deletedItemsJson);
    return itemsList.map((item) => GroceryItem.fromJson(item)).toList();
  }

  static Future<void> _saveDeletedItemsHistory(List<GroceryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final String itemsJson =
        json.encode(items.map((item) => item.toJson()).toList());
    await prefs.setString(_deletedItemsKey, itemsJson);
  }

  static Future<void> _addDeletedItemToHistory(GroceryItem item) async {
    final deletedItems = await getDeletedItemsHistory();
    deletedItems.add(item);
    await _saveDeletedItemsHistory(deletedItems);
  }

  static Future<void> restoreDeletedItem(String id) async {
    final deletedItems = await getDeletedItemsHistory();
    final itemToRestore = deletedItems.firstWhere((item) => item.id == id);
    deletedItems.removeWhere((item) => item.id == id);
    await _saveDeletedItemsHistory(deletedItems);

    // Restore to active grocery list (clear deletedAt)
    await addItem(itemToRestore.copyWith(deletedAt: null));
  }

  static Future<void> clearDeletedItemsHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deletedItemsKey);
  }


  static Future<double?> getBudget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_budgetKey);
  }

  static Future<void> saveBudget(double budget) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_budgetKey, budget);
  }
}