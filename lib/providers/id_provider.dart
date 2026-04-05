import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/customer_id.dart';

enum IDFilterType { all, age7to25, age18to25 }

class IDProvider extends ChangeNotifier {
  List<CustomerID> _customerIDs = [];
  bool _isLoading = true;
  IDFilterType _currentFilter = IDFilterType.all;

  List<CustomerID> get customerIDs => _customerIDs;
  bool get isLoading => _isLoading;
  IDFilterType get currentFilter => _currentFilter;

  void setFilter(IDFilterType filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  IDProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? idsJson = prefs.getString('customer_ids');
    if (idsJson != null) {
      final List<dynamic> decoded = json.decode(idsJson);
      _customerIDs = decoded.map((e) => CustomerID.fromMap(e)).toList();
    }
    // Newest first
    _customerIDs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'customer_ids',
      json.encode(_customerIDs.map((e) => e.toMap()).toList()),
    );
  }

  Future<void> addCustomerID(CustomerID id) async {
    _customerIDs.add(id);
    _customerIDs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _saveData();
    notifyListeners();
  }

  int _calculateAge(DateTime birthDate) {
    DateTime now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> deleteCustomerID(String id) async {
    final item = _customerIDs.firstWhere((e) => e.id == id);
    
    // Also delete image files from local storage if they exist
    try {
      if (File(item.frontImagePath).existsSync()) {
        await File(item.frontImagePath).delete();
      }
      if (File(item.backImagePath).existsSync()) {
        await File(item.backImagePath).delete();
      }
    } catch (e) {
      print("Error deleting ID files: $e");
    }

    _customerIDs.removeWhere((e) => e.id == id);
    await _saveData();
    notifyListeners();
  }

  List<CustomerID> searchIDs(String query) {
    List<CustomerID> filteredList = _customerIDs;

    // Apply age filter
    if (_currentFilter != IDFilterType.all) {
      filteredList = filteredList.where((id) {
        if (id.birthDate == null) return false;
        final age = _calculateAge(id.birthDate!);
        if (_currentFilter == IDFilterType.age7to25) {
          return age >= 7 && age <= 25;
        } else if (_currentFilter == IDFilterType.age18to25) {
          return age >= 18 && age <= 25;
        }
        return true;
      }).toList();
    }

    if (query.isEmpty) return filteredList;
    
    final lowercaseQuery = query.toLowerCase();
    return filteredList.where((e) {
      return e.name.toLowerCase().contains(lowercaseQuery) ||
             e.surname.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }
}
