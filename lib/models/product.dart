class Product {
  final int? id;
  final String name;
  final String? description;
  final double buyPrice;
  final double sellPrice;
  final double quantity;
  final String unit;
  final int? categoryId;
  final String? barcode;
  final double lowStockAlert;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    this.id,
    required this.name,
    this.description,
    required this.buyPrice,
    required this.sellPrice,
    required this.quantity,
    required this.unit,
    this.categoryId,
    this.barcode,
    this.lowStockAlert = 5,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'buyPrice': buyPrice,
        'sellPrice': sellPrice,
        'quantity': quantity,
        'unit': unit,
        'categoryId': categoryId,
        'barcode': barcode,
        'lowStockAlert': lowStockAlert,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'],
        name: map['name'],
        description: map['description'],
        buyPrice: (map['buyPrice'] as num).toDouble(),
        sellPrice: (map['sellPrice'] as num).toDouble(),
        quantity: (map['quantity'] as num).toDouble(),
        unit: map['unit'] ?? 'pcs',
        categoryId: map['categoryId'],
        barcode: map['barcode'],
        lowStockAlert: (map['lowStockAlert'] as num?)?.toDouble() ?? 5,
        createdAt: DateTime.parse(map['createdAt']),
        updatedAt: DateTime.parse(map['updatedAt']),
      );

  Product copyWith({
    int? id,
    String? name,
    String? description,
    double? buyPrice,
    double? sellPrice,
    double? quantity,
    String? unit,
    int? categoryId,
    String? barcode,
    double? lowStockAlert,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        buyPrice: buyPrice ?? this.buyPrice,
        sellPrice: sellPrice ?? this.sellPrice,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        categoryId: categoryId ?? this.categoryId,
        barcode: barcode ?? this.barcode,
        lowStockAlert: lowStockAlert ?? this.lowStockAlert,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  bool get isLowStock => quantity <= lowStockAlert;
  bool get isOutOfStock => quantity <= 0;
  double get profit => sellPrice - buyPrice;
  double get profitPercent => buyPrice > 0 ? (profit / buyPrice) * 100 : 0;
}
