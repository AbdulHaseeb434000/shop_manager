enum PaymentMethod { cash, card, upi, credit }

enum InvoiceStatus { paid, unpaid, partial }

class InvoiceItem {
  final int? id;
  final int? invoiceId;
  final int productId;
  final String productName;
  final double quantity;
  final String unit;
  final double price;
  final double discount;
  final double buyPrice;

  InvoiceItem({
    this.id,
    this.invoiceId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.price,
    this.discount = 0,
    this.buyPrice = 0,
  });

  double get subtotal => quantity * price;
  double get discountAmount => subtotal * discount / 100;
  double get total => subtotal - discountAmount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'invoiceId': invoiceId,
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'unit': unit,
        'price': price,
        'discount': discount,
        'buyPrice': buyPrice,
      };

  factory InvoiceItem.fromMap(Map<String, dynamic> map) => InvoiceItem(
        id: map['id'],
        invoiceId: map['invoiceId'],
        productId: map['productId'],
        productName: map['productName'],
        quantity: (map['quantity'] as num).toDouble(),
        unit: map['unit'] ?? 'pcs',
        price: (map['price'] as num).toDouble(),
        discount: (map['discount'] as num?)?.toDouble() ?? 0,
        buyPrice: (map['buyPrice'] as num?)?.toDouble() ?? 0,
      );

  InvoiceItem copyWith({int? invoiceId, double? quantity, double? discount}) =>
      InvoiceItem(
        id: id,
        invoiceId: invoiceId ?? this.invoiceId,
        productId: productId,
        productName: productName,
        quantity: quantity ?? this.quantity,
        unit: unit,
        price: price,
        discount: discount ?? this.discount,
        buyPrice: buyPrice,
      );
}

class Invoice {
  final int? id;
  final String invoiceNumber;
  final int? customerId;
  final String? customerName;
  final String? customerPhone;
  final List<InvoiceItem> items;
  final double subtotal;
  final double discountAmount;
  final double taxPercent;
  final double taxAmount;
  final double totalAmount;
  final double paidAmount;
  final PaymentMethod paymentMethod;
  final InvoiceStatus status;
  final String? notes;
  final DateTime createdAt;

  Invoice({
    this.id,
    required this.invoiceNumber,
    this.customerId,
    this.customerName,
    this.customerPhone,
    required this.items,
    required this.subtotal,
    this.discountAmount = 0,
    this.taxPercent = 0,
    this.taxAmount = 0,
    required this.totalAmount,
    required this.paidAmount,
    this.paymentMethod = PaymentMethod.cash,
    this.status = InvoiceStatus.paid,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get dueAmount => totalAmount - paidAmount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'invoiceNumber': invoiceNumber,
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'subtotal': subtotal,
        'discountAmount': discountAmount,
        'taxPercent': taxPercent,
        'taxAmount': taxAmount,
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'paymentMethod': paymentMethod.name,
        'status': status.name,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Invoice.fromMap(Map<String, dynamic> map, List<InvoiceItem> items) =>
      Invoice(
        id: map['id'],
        invoiceNumber: map['invoiceNumber'],
        customerId: map['customerId'],
        customerName: map['customerName'],
        customerPhone: map['customerPhone'],
        items: items,
        subtotal: (map['subtotal'] as num).toDouble(),
        discountAmount: (map['discountAmount'] as num?)?.toDouble() ?? 0,
        taxPercent: (map['taxPercent'] as num?)?.toDouble() ?? 0,
        taxAmount: (map['taxAmount'] as num?)?.toDouble() ?? 0,
        totalAmount: (map['totalAmount'] as num).toDouble(),
        paidAmount: (map['paidAmount'] as num).toDouble(),
        paymentMethod: PaymentMethod.values.firstWhere(
          (e) => e.name == map['paymentMethod'],
          orElse: () => PaymentMethod.cash,
        ),
        status: InvoiceStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => InvoiceStatus.paid,
        ),
        notes: map['notes'],
        createdAt: DateTime.parse(map['createdAt']),
      );
}
