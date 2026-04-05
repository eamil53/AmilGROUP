import 'dart:convert';

class CustomerID {
  final String id;
  final String name;
  final String surname;
  final DateTime? birthDate;
  final String frontImagePath;
  final String backImagePath;
  final DateTime createdAt;

  CustomerID({
    required this.id,
    required this.name,
    required this.surname,
    this.birthDate,
    required this.frontImagePath,
    required this.backImagePath,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'surname': surname,
      'birthDate': birthDate?.toIso8601String(),
      'frontImagePath': frontImagePath,
      'backImagePath': backImagePath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CustomerID.fromMap(Map<String, dynamic> map) {
    return CustomerID(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      surname: map['surname'] ?? '',
      birthDate: map['birthDate'] != null ? DateTime.parse(map['birthDate']) : null,
      frontImagePath: map['frontImagePath'] ?? '',
      backImagePath: map['backImagePath'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  String toJson() => json.encode(toMap());

  factory CustomerID.fromJson(String source) => CustomerID.fromMap(json.decode(source));
}
