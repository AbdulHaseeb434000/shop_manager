enum UtilityType { electricity, water, gas, rent, internet, phone, other }

enum BillStatus { pending, paid, overdue }

class UtilityBill {
  final int? id;
  final UtilityType type;
  final String title;
  final double amount;
  final DateTime billDate;
  final DateTime dueDate;
  final DateTime? paidDate;
  final BillStatus status;
  final String? notes;
  final String? receiptNumber;

  UtilityBill({
    this.id,
    required this.type,
    required this.title,
    required this.amount,
    required this.billDate,
    required this.dueDate,
    this.paidDate,
    this.status = BillStatus.pending,
    this.notes,
    this.receiptNumber,
  });

  bool get isOverdue =>
      status != BillStatus.paid && DateTime.now().isAfter(dueDate);

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'title': title,
        'amount': amount,
        'billDate': billDate.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'paidDate': paidDate?.toIso8601String(),
        'status': status.name,
        'notes': notes,
        'receiptNumber': receiptNumber,
      };

  factory UtilityBill.fromMap(Map<String, dynamic> map) => UtilityBill(
        id: map['id'],
        type: UtilityType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () => UtilityType.other,
        ),
        title: map['title'],
        amount: (map['amount'] as num).toDouble(),
        billDate: DateTime.parse(map['billDate']),
        dueDate: DateTime.parse(map['dueDate']),
        paidDate: map['paidDate'] != null ? DateTime.parse(map['paidDate']) : null,
        status: BillStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => BillStatus.pending,
        ),
        notes: map['notes'],
        receiptNumber: map['receiptNumber'],
      );

  UtilityBill copyWith({
    BillStatus? status,
    DateTime? paidDate,
    String? receiptNumber,
  }) =>
      UtilityBill(
        id: id,
        type: type,
        title: title,
        amount: amount,
        billDate: billDate,
        dueDate: dueDate,
        paidDate: paidDate ?? this.paidDate,
        status: status ?? this.status,
        notes: notes,
        receiptNumber: receiptNumber ?? this.receiptNumber,
      );
}
