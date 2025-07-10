import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/grocery_item.dart';

class StorageHelper {
  static const String _itemsKey = 'grocery_items';
  static const String _budgetKey = 'budget_limit';

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
    items.removeWhere((item) => item.id == id);
    await saveItems(items);
  }

  static Future<double?> getBudget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_budgetKey);
  }

  static Future<void> setBudget(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_budgetKey, value);
  }
}
