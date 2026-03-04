import 'package:intl/intl.dart';

class CurrencyFormat {
  static String _currency = 'PKR';

  static void setCurrency(String currency) => _currency = currency;

  static String format(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '$_currency ${formatter.format(amount)}';
  }

  static String formatCompact(double amount) {
    if (amount >= 1000000) {
      return '$_currency ${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '$_currency ${(amount / 1000).toStringAsFixed(1)}K';
    }
    return format(amount);
  }

  static String get symbol => _currency;
}

class DateFormat2 {
  static String format(DateTime dt) =>
      DateFormat('dd MMM yyyy').format(dt);

  static String formatWithTime(DateTime dt) =>
      DateFormat('dd MMM yyyy, hh:mm a').format(dt);

  static String formatShort(DateTime dt) =>
      DateFormat('dd/MM/yy').format(dt);

  static String formatMonth(DateTime dt) =>
      DateFormat('MMM yyyy').format(dt);
}
