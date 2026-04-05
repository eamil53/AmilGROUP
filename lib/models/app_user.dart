class AppRole {
  final String id;
  final String name;
  final List<String> allowedModules;
  final List<String> allowedCategories; // e.g., ['phone', 'modem']

  AppRole({
    required this.id,
    required this.name,
    required this.allowedModules,
    this.allowedCategories = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'allowedModules': allowedModules,
      'allowedCategories': allowedCategories,
    };
  }

  factory AppRole.fromMap(Map<String, dynamic> map) {
    return AppRole(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      allowedModules: List<String>.from(map['allowedModules'] ?? []),
      allowedCategories: List<String>.from(map['allowedCategories'] ?? []),
    );
  }
}

class AppUser {
  final String id;
  final String name;
  final String code; // B123456
  final List<String> roles; // Changed from roleIds to roles as requested
  final String password;
  final bool isAdmin; 

  // Transient roles objects loaded from DB
  List<AppRole>? rolesObjects;

  AppUser({
    required this.id,
    required this.name,
    required this.code,
    required this.roles,
    required this.password,
    this.isAdmin = false,
    this.rolesObjects,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'roles': roles,
      'password': password,
      'isAdmin': isAdmin,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    List<String> extractedRoles = [];
    if (map['roles'] is List) {
      extractedRoles = List<String>.from(map['roles']);
    } else if (map['role'] is String) {
      extractedRoles = [map['role']];
    } else if (map['roleIds'] is List) {
      extractedRoles = List<String>.from(map['roleIds']);
    }

    return AppUser(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      roles: extractedRoles,
      password: map['password'] ?? '123',
      isAdmin: map['isAdmin'] ?? false,
    );
  }

  bool canAccess(String menuKey) {
    if (isAdmin) return true;
    if (rolesObjects == null) return false;
    
    for (var role in rolesObjects!) {
      if (role.allowedModules.contains(menuKey)) return true;
    }
    return false;
  }

  bool canViewProfits() {
    if (isAdmin) return true;
    if (rolesObjects == null) return false;
    
    for (var role in rolesObjects!) {
      if (role.allowedModules.contains('profits_view')) return true;
    }
    return false;
  }

  bool canAccessCategory(String categoryKey) {
    if (isAdmin) return true;
    if (rolesObjects == null) return false;
    
    for (var role in rolesObjects!) {
      if (role.allowedCategories.contains(categoryKey)) return true;
    }
    return false;
  }
}
