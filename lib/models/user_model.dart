class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String role;
  final String plantCapacity;
  final String userRoleLabel;
  final DateTime? updatedAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.address = '',
    this.plantCapacity = '',
    this.userRoleLabel = 'Solar Plant Owner',
    this.updatedAt,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      role: map['role'] ?? 'user',
      plantCapacity: map['plantCapacity'] ?? '',
      userRoleLabel: map['userRoleLabel'] ?? 'Solar Plant Owner',
      updatedAt: map['updatedAt'] != null 
          ? DateTime.tryParse(map['updatedAt']) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'role': role,
      'plantCapacity': plantCapacity,
      'userRoleLabel': userRoleLabel,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? name,
    String? phone,
    String? address,
    String? role,
    String? plantCapacity,
    String? userRoleLabel,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      role: role ?? this.role,
      plantCapacity: plantCapacity ?? this.plantCapacity,
      userRoleLabel: userRoleLabel ?? this.userRoleLabel,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
