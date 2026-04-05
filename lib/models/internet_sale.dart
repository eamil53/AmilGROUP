import 'package:uuid/uuid.dart';

enum InternetSaleStatus {
  aktif,
  beklemede,
  iptal,
}

class InternetSale {
  final String id;
  final String customerTc;
  final String customerFullName;
  final DateTime date;
  final String campaign;
  final String xdslNo;
  final String accountNo;
  final String phoneNo;
  final String sellerName;
  final String soldUser;
  final String speed;
  InternetSaleStatus status;
  final bool hasOldInternet;
  bool isOldInternetCanceled;
  final String description;
  final DateTime createdAt;

  InternetSale({
    required this.id,
    required this.customerTc,
    required this.customerFullName,
    required this.date,
    required this.campaign,
    required this.xdslNo,
    required this.accountNo,
    required this.phoneNo,
    required this.sellerName,
    required this.soldUser,
    required this.speed,
    this.status = InternetSaleStatus.beklemede,
    required this.hasOldInternet,
    this.isOldInternetCanceled = false,
    required this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerTc': customerTc,
      'customerFullName': customerFullName,
      'date': date.toIso8601String(),
      'campaign': campaign,
      'xdslNo': xdslNo,
      'accountNo': accountNo,
      'phoneNo': phoneNo,
      'sellerName': sellerName,
      'soldUser': soldUser,
      'speed': speed,
      'status': status.index,
      'hasOldInternet': hasOldInternet,
      'isOldInternetCanceled': isOldInternetCanceled,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory InternetSale.fromMap(Map<String, dynamic> map) {
    return InternetSale(
      id: map['id'] ?? const Uuid().v4(),
      customerTc: map['customerTc'] ?? '',
      customerFullName: map['customerFullName'] ?? '',
      date: DateTime.parse(map['date']),
      campaign: map['campaign'] ?? '',
      xdslNo: map['xdslNo'] ?? '',
      accountNo: map['accountNo'] ?? '',
      phoneNo: map['phoneNo'] ?? '',
      sellerName: map['sellerName'] ?? '',
      soldUser: map['soldUser'] ?? '',
      speed: map['speed'] ?? '',
      status: InternetSaleStatus.values[map['status'] ?? 1],
      hasOldInternet: map['hasOldInternet'] ?? false,
      isOldInternetCanceled: map['isOldInternetCanceled'] ?? false,
      description: map['description'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? map['date']),
    );
  }
}
