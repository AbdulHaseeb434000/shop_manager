class Customer {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final double creditLimit;
  final double totalPurchases;
  final double balance;
  final String? notes;
  final DateTime createdAt;

  Customer({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.creditLimit = 0,
    this.totalPurchases = 0,
    this.balance = 0,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
        'creditLimit': creditLimit,
        'totalPurchases': totalPurchases,
        'balance': balance,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id: map['id'],
        name: map['name'],
        phone: map['phone'],
        email: map['email'],
        address: map['address'],
        creditLimit: (map['creditLimit'] as num?)?.toDouble() ?? 0,
        totalPurchases: (map['totalPurchases'] as num?)?.toDouble() ?? 0,
        balance: (map['balance'] as num?)?.toDouble() ?? 0,
        notes: map['notes'],
        createdAt: DateTime.parse(map['createdAt']),
      );

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    double? creditLimit,
    double? totalPurchases,
    double? balance,
    String? notes,
  }) =>
      Customer(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        creditLimit: creditLimit ?? this.creditLimit,
        totalPurchases: totalPurchases ?? this.totalPurchases,
        balance: balance ?? this.balance,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}
