import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UIProvider extends ChangeNotifier {
  List<String> _menuOrder = [
    'internet_sale_entry',
    'internet_sale_list',
    'internet_sale_report',
    'all_stock',
    'critical_stock',
    'hakedis_excel',
    'hakedis_takip',
    'sales_report',
    'target_report',
    'id_archive',
    'add_product_camera',
    'personnel_management',
  ];

  List<String> get menuOrder => _menuOrder;

  UIProvider() {
    _loadMenuOrder();
  }

  Future<void> _loadMenuOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedOrder = prefs.getStringList('menu_order');
    if (savedOrder != null) {
      // Sadece eksik olanları ekle (migration)
      for (var key in ['internet_sale_entry', 'internet_sale_list', 'internet_sale_report', 'all_stock', 'personnel_management']) {
        if (!savedOrder.contains(key)) {
          savedOrder.insert(0, key);
        }
      }
      _menuOrder = savedOrder;
    }
    notifyListeners();
  }

  Future<void> updateMenuOrder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final String item = _menuOrder.removeAt(oldIndex);
    _menuOrder.insert(newIndex, item);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('menu_order', _menuOrder);
    notifyListeners();
  }
}
