import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/db_helper.dart';

class BackupManager {
  static final _db = DBHelper();

  /// Exports all shop data to a JSON file and shares it.
  static Future<String> exportData() async {
    final products = await _db.getProducts();
    final customers = await _db.getCustomers();
    final invoices = await _db.getInvoices();
    final bills = await _db.getUtilityBills();
    final settings = await _db.getAllSettings();

    final backup = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': settings,
      'products': products.map((p) => p.toMap()).toList(),
      'customers': customers.map((c) => c.toMap()).toList(),
      'invoices': invoices.map((inv) => {
        ...inv.toMap(),
        'items': inv.items.map((i) => i.toMap()).toList(),
      }).toList(),
      'utilityBills': bills.map((b) => b.toMap()).toList(),
    };

    final json = const JsonEncoder.withIndent('  ').convert(backup);
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/shop_backup_$date.json');
    await file.writeAsString(json);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Shop Manager Backup - $date',
      text: 'Shop Manager data backup. Save this file to restore your data.',
    );

    return file.path;
  }

  /// Picks a backup JSON file and restores all data.
  /// Returns a summary string of what was restored.
  static Future<String> importData() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) {
      throw Exception('No file selected');
    }

    final path = result.files.single.path;
    if (path == null) throw Exception('Could not read file');

    final content = await File(path).readAsString();
    final Map<String, dynamic> backup = jsonDecode(content);

    // Validate it's a shop backup
    if (backup['version'] == null || backup['products'] == null) {
      throw Exception('Invalid backup file');
    }

    // Restore settings
    final settings = backup['settings'] as Map<String, dynamic>? ?? {};
    for (final entry in settings.entries) {
      await _db.setSetting(entry.key, entry.value.toString());
    }

    // Restore products
    final productsData = backup['products'] as List<dynamic>;
    for (final p in productsData) {
      final map = Map<String, dynamic>.from(p as Map);
      map.remove('id'); // let DB assign new ID
      await _db.insertProductMap(map);
    }

    // Restore customers
    final customersData = backup['customers'] as List<dynamic>;
    for (final c in customersData) {
      final map = Map<String, dynamic>.from(c as Map);
      map.remove('id');
      await _db.insertCustomerMap(map);
    }

    // Restore invoices
    final invoicesData = backup['invoices'] as List<dynamic>;
    for (final inv in invoicesData) {
      final invMap = Map<String, dynamic>.from(inv as Map);
      final items = invMap.remove('items') as List<dynamic>? ?? [];
      invMap.remove('id');
      final invId = await _db.insertInvoiceMap(invMap);
      int actualInvId = invId;
      if (actualInvId == 0) {
        final existing = await _db.getInvoiceByNumber(invMap['invoiceNumber'] as String);
        actualInvId = existing?.id ?? 0;
      }
      if (actualInvId > 0) {
        for (final item in items) {
          final itemMap = Map<String, dynamic>.from(item as Map);
          itemMap['invoiceId'] = actualInvId;
          itemMap.remove('id');
          await _db.insertInvoiceItemMap(itemMap);
        }
      }
    }

    // Restore utility bills
    final billsData = backup['utilityBills'] as List<dynamic>;
    for (final b in billsData) {
      final map = Map<String, dynamic>.from(b as Map);
      map.remove('id');
      await _db.insertUtilityBillMap(map);
    }

    return 'Restored: ${productsData.length} products, '
        '${customersData.length} customers, '
        '${invoicesData.length} invoices, '
        '${billsData.length} utility bills.';
  }
}
