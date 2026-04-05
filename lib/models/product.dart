import 'dart:convert';

enum ProductCategory {
  phone,
  headset,
  watch,
  modem,
  demo,
  returned,
  other,
}

enum PaymentType {
  nakit,
  temlikli,
}

enum HakedisStatus {
  bekliyor,
  faturaKesildi,
  odemeAlindi,
}

enum PurchaseType {
  nakit,
  vadeli,
}

class Product {
  final String id;
  final String brand;
  final String model;
  final String? color;
  final String? imei1;
  final String? imei2;
  final String? serialNumber;
  final ProductCategory category;
  int quantity;
  final double purchasePrice; 
  final double salePrice;     
  final DateTime createdAt;
  final PurchaseType purchaseType;

  Product({
    required this.id,
    required this.brand,
    required this.model,
    this.color,
    this.imei1,
    this.imei2,
    this.serialNumber,
    required this.category,
    this.quantity = 1,
    required this.purchasePrice,
    required this.salePrice,
    required this.createdAt,
    this.purchaseType = PurchaseType.vadeli,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'brand': brand,
      'model': model,
      'color': color,
      'imei1': imei1,
      'imei2': imei2,
      'serialNumber': serialNumber,
      'category': category.index,
      'quantity': quantity,
      'purchasePrice': purchasePrice,
      'salePrice': salePrice,
      'createdAt': createdAt.toIso8601String(),
      'purchaseType': purchaseType.index,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    // Robust parsing for categorical values
    ProductCategory cat = ProductCategory.other;
    try {
      if (map['category'] != null) {
        int index = (map['category'] as num).toInt();
        if (index >= 0 && index < ProductCategory.values.length) {
          cat = ProductCategory.values[index];
        }
      }
    } catch (_) {}

    PurchaseType pType = PurchaseType.vadeli;
    try {
      if (map['purchaseType'] != null) {
        int index = (map['purchaseType'] as num).toInt();
        if (index >= 0 && index < PurchaseType.values.length) {
          pType = PurchaseType.values[index];
        }
      }
    } catch (_) {}

    return Product(
      id: map['id'] ?? '',
      brand: map['brand'] ?? 'Bilinmiyor',
      model: map['model'] ?? 'Bilinmiyor',
      color: map['color'],
      imei1: map['imei1'],
      imei2: map['imei2'],
      serialNumber: map['serialNumber'],
      category: cat,
      quantity: (map['quantity'] ?? 0) as int,
      purchasePrice: (map['purchasePrice'] ?? 0.0).toDouble(),
      salePrice: (map['salePrice'] ?? 0.0).toDouble(),
      createdAt: map['createdAt'] != null 
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now() 
          : DateTime.now(),
      purchaseType: pType,
    );
  }
}

class Sale {
  final String id;
  final String productId;
  final String brand;
  final String model;
  final String? color;
  final int quantity;
  final double salePrice;
  final double purchasePrice;
  final double hakedisAmount; // New field to store the specific hakediş from Excel or default
  final DateTime soldAt;
  final PaymentType paymentType;
  HakedisStatus hakedisStatus;

  Sale({
    required this.id,
    required this.productId,
    required this.brand,
    required this.model,
    this.color,
    required this.quantity,
    required this.salePrice,
    required this.purchasePrice,
    required this.hakedisAmount,
    required this.soldAt,
    required this.paymentType,
    this.hakedisStatus = HakedisStatus.bekliyor,
  });

  double get turnover => salePrice * quantity;
  double get profit => hakedisAmount * quantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'brand': brand,
      'model': model,
      'color': color,
      'quantity': quantity,
      'salePrice': salePrice,
      'purchasePrice': purchasePrice,
      'hakedisAmount': hakedisAmount,
      'soldAt': soldAt.toIso8601String(),
      'paymentType': paymentType.index,
      'hakedisStatus': hakedisStatus.index,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] ?? '',
      productId: map['productId'] ?? '',
      brand: map['brand'] ?? '',
      model: map['model'] ?? '',
      color: map['color'],
      quantity: map['quantity'] ?? 1,
      salePrice: (map['salePrice'] ?? 0.0).toDouble(),
      purchasePrice: (map['purchasePrice'] ?? 0.0).toDouble(),
      hakedisAmount: (map['hakedisAmount'] ?? 0.0).toDouble(),
      soldAt: DateTime.parse(map['soldAt']),
      paymentType: PaymentType.values[map['paymentType'] ?? 0],
      hakedisStatus: HakedisStatus.values[map['hakedisStatus'] ?? 0],
    );
  }
}

class DebtPayment {
  final String id;
  final double amount;
  final DateTime date;
  final String? description;

  DebtPayment({
    required this.id,
    required this.amount,
    required this.date,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'date': date.toIso8601String(),
      'description': description,
    };
  }

  factory DebtPayment.fromMap(Map<String, dynamic> map) {
    return DebtPayment(
      id: map['id'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      date: DateTime.parse(map['date']),
      description: map['description'],
    );
  }
}
