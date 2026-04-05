import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/internet_sale.dart';

class InternetSaleProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  List<InternetSale> _sales = [];
  bool _isLoading = true;

  List<InternetSale> get sales => _sales;
  bool get isLoading => _isLoading;

  InternetSaleProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    
    // First try to load from Firestore for real-time sync
    try {
      final snapshot = await _db.collection('internet_sales').get();
      _sales = snapshot.docs.map((doc) => InternetSale.fromMap(doc.data())).toList();
      
      // Update local storage
      await prefs.setString('internet_sales', json.encode(_sales.map((e) => e.toMap()).toList()));
    } catch (e) {
      debugPrint("Firestore load failed, using local: $e");
      // Fallback to local
      final String? jsonStr = prefs.getString('internet_sales');
      if (jsonStr != null) {
        final List<dynamic> decoded = json.decode(jsonStr);
        _sales = decoded.map((e) => InternetSale.fromMap(e)).toList();
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('internet_sales', json.encode(_sales.map((e) => e.toMap()).toList()));
  }

  Future<void> addSale(InternetSale sale) async {
    _sales.add(sale);
    await _saveToLocal();
    notifyListeners();

    try {
      await _db.collection('internet_sales').doc(sale.id).set(sale.toMap());
    } catch (e) {
      debugPrint("Firebase sync failed: $e");
    }
  }

  Future<void> updateSale(InternetSale sale) async {
    final index = _sales.indexWhere((s) => s.id == sale.id);
    if (index != -1) {
      _sales[index] = sale;
      await _saveToLocal();
      notifyListeners();

      try {
        await _db.collection('internet_sales').doc(sale.id).set(sale.toMap());
      } catch (e) {
        debugPrint("Firebase update failed: $e");
      }
    }
  }

  Future<void> deleteSale(String id) async {
    _sales.removeWhere((s) => s.id == id);
    await _saveToLocal();
    notifyListeners();

    try {
      await _db.collection('internet_sales').doc(id).delete();
    } catch (e) {
      debugPrint("Firebase delete failed: $e");
    }
  }

  // Reporting helpers
  int countByStatus(InternetSaleStatus status) => _sales.where((s) => s.status == status).length;
  
  Map<String, int> salesBySellsman() {
    final map = <String, int>{};
    for (var sale in _sales) {
      map[sale.sellerName] = (map[sale.sellerName] ?? 0) + 1;
    }
    return map;
  }

  double monthlyGrowth() {
    // Basic placeholder for growth logic
    return 15.5; 
  }
}
