import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/customer.dart';
import '../models/invoice.dart';
import '../models/utility_bill.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _db;

  factory DBHelper() => _instance;
  DBHelper._internal();

  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'shop_manager.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT DEFAULT '🏷️',
        colorHex TEXT DEFAULT '#6C63FF'
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        buyPrice REAL NOT NULL DEFAULT 0,
        sellPrice REAL NOT NULL DEFAULT 0,
        quantity REAL NOT NULL DEFAULT 0,
        unit TEXT DEFAULT 'pcs',
        categoryId INTEGER,
        barcode TEXT,
        lowStockAlert REAL DEFAULT 5,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY(categoryId) REFERENCES categories(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        creditLimit REAL DEFAULT 0,
        totalPurchases REAL DEFAULT 0,
        balance REAL DEFAULT 0,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceNumber TEXT NOT NULL UNIQUE,
        customerId INTEGER,
        customerName TEXT,
        customerPhone TEXT,
        subtotal REAL NOT NULL,
        discountAmount REAL DEFAULT 0,
        taxPercent REAL DEFAULT 0,
        taxAmount REAL DEFAULT 0,
        totalAmount REAL NOT NULL,
        paidAmount REAL NOT NULL,
        paymentMethod TEXT DEFAULT 'cash',
        status TEXT DEFAULT 'paid',
        notes TEXT,
        createdAt TEXT NOT NULL,
        FOREIGN KEY(customerId) REFERENCES customers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoiceId INTEGER NOT NULL,
        productId INTEGER NOT NULL,
        productName TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT DEFAULT 'pcs',
        price REAL NOT NULL,
        discount REAL DEFAULT 0,
        FOREIGN KEY(invoiceId) REFERENCES invoices(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE utility_bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        billDate TEXT NOT NULL,
        dueDate TEXT NOT NULL,
        paidDate TEXT,
        status TEXT DEFAULT 'pending',
        notes TEXT,
        receiptNumber TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE shop_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Default categories
    final defaultCategories = [
      {'name': 'Food & Beverages', 'icon': '🍔', 'colorHex': '#FF6584'},
      {'name': 'Electronics', 'icon': '📱', 'colorHex': '#6C63FF'},
      {'name': 'Clothing', 'icon': '👕', 'colorHex': '#43E97B'},
      {'name': 'Groceries', 'icon': '🛒', 'colorHex': '#FFB74D'},
      {'name': 'Medicines', 'icon': '💊', 'colorHex': '#4FC3F7'},
      {'name': 'Others', 'icon': '📦', 'colorHex': '#9093A4'},
    ];
    for (final cat in defaultCategories) {
      await db.insert('categories', cat);
    }

    // Default settings
    await db.insert('shop_settings', {'key': 'shopName', 'value': 'My Shop'});
    await db.insert('shop_settings', {'key': 'shopAddress', 'value': ''});
    await db.insert('shop_settings', {'key': 'shopPhone', 'value': ''});
    await db.insert('shop_settings', {'key': 'currency', 'value': 'PKR'});
    await db.insert('shop_settings', {'key': 'taxPercent', 'value': '0'});
    await db.insert('shop_settings', {'key': 'invoiceCounter', 'value': '1000'});
  }

  // ==================== SETTINGS ====================
  Future<String?> getSetting(String key) async {
    final db = await database;
    final result = await db.query('shop_settings', where: 'key = ?', whereArgs: [key]);
    return result.isNotEmpty ? result.first['value'] as String? : null;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('shop_settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final rows = await db.query('shop_settings');
    return {for (final r in rows) r['key'] as String: r['value'] as String? ?? ''};
  }

  // ==================== CATEGORIES ====================
  Future<List<Category>> getCategories() async {
    final db = await database;
    final maps = await db.query('categories', orderBy: 'name ASC');
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  Future<int> insertCategory(Category cat) async {
    final db = await database;
    return await db.insert('categories', cat.toMap()..remove('id'));
  }

  Future<void> updateCategory(Category cat) async {
    final db = await database;
    await db.update('categories', cat.toMap(), where: 'id = ?', whereArgs: [cat.id]);
  }

  Future<void> deleteCategory(int id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== PRODUCTS ====================
  Future<List<Product>> getProducts({String? search, int? categoryId}) async {
    final db = await database;
    String? where;
    List<dynamic> whereArgs = [];
    if (search != null && search.isNotEmpty) {
      where = 'name LIKE ?';
      whereArgs.add('%$search%');
    }
    if (categoryId != null) {
      where = where != null ? '$where AND categoryId = ?' : 'categoryId = ?';
      whereArgs.add(categoryId);
    }
    final maps = await db.query('products',
        where: where, whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'name ASC');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<Product?> getProductById(int id) async {
    final db = await database;
    final maps = await db.query('products', where: 'id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? Product.fromMap(maps.first) : null;
  }

  Future<List<Product>> getLowStockProducts() async {
    final db = await database;
    final maps = await db.rawQuery(
        'SELECT * FROM products WHERE quantity <= lowStockAlert ORDER BY quantity ASC');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<int> insertProduct(Product p) async {
    final db = await database;
    final map = p.toMap()..remove('id');
    return await db.insert('products', map);
  }

  Future<void> updateProduct(Product p) async {
    final db = await database;
    await db.update('products', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  Future<void> updateProductQuantity(int id, double newQty) async {
    final db = await database;
    await db.update('products', {
      'quantity': newQty,
      'updatedAt': DateTime.now().toIso8601String()
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteProduct(int id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== CUSTOMERS ====================
  Future<List<Customer>> getCustomers({String? search}) async {
    final db = await database;
    final maps = await db.query('customers',
        where: search != null && search.isNotEmpty ? 'name LIKE ? OR phone LIKE ?' : null,
        whereArgs: search != null && search.isNotEmpty ? ['%$search%', '%$search%'] : null,
        orderBy: 'name ASC');
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<Customer?> getCustomerById(int id) async {
    final db = await database;
    final maps = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? Customer.fromMap(maps.first) : null;
  }

  Future<int> insertCustomer(Customer c) async {
    final db = await database;
    final map = c.toMap()..remove('id');
    return await db.insert('customers', map);
  }

  Future<void> updateCustomer(Customer c) async {
    final db = await database;
    await db.update('customers', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> deleteCustomer(int id) async {
    final db = await database;
    await db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== INVOICES ====================
  Future<String> generateInvoiceNumber() async {
    final db = await database;
    final result = await db.query('shop_settings',
        where: 'key = ?', whereArgs: ['invoiceCounter']);
    int counter = int.tryParse(result.first['value'] as String? ?? '1000') ?? 1000;
    counter++;
    await db.update('shop_settings', {'value': counter.toString()},
        where: 'key = ?', whereArgs: ['invoiceCounter']);
    final now = DateTime.now();
    return 'INV-${now.year}${now.month.toString().padLeft(2, '0')}-$counter';
  }

  Future<int> insertInvoice(Invoice inv) async {
    final db = await database;
    final map = inv.toMap()..remove('id');
    final invId = await db.insert('invoices', map);

    for (final item in inv.items) {
      final itemMap = item.toMap()
        ..remove('id')
        ..['invoiceId'] = invId;
      await db.insert('invoice_items', itemMap);

      // Reduce product stock
      final product = await getProductById(item.productId);
      if (product != null) {
        await updateProductQuantity(
            item.productId, product.quantity - item.quantity);
      }
    }

    // Update customer stats
    if (inv.customerId != null) {
      final customer = await getCustomerById(inv.customerId!);
      if (customer != null) {
        await updateCustomer(customer.copyWith(
          totalPurchases: customer.totalPurchases + inv.totalAmount,
          balance: customer.balance + inv.dueAmount,
        ));
      }
    }

    return invId;
  }

  Future<List<Invoice>> getInvoices({
    DateTime? from,
    DateTime? to,
    InvoiceStatus? status,
    int? customerId,
    String? search,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (from != null) {
      conditions.add('createdAt >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      conditions.add('createdAt <= ?');
      args.add(to.add(const Duration(days: 1)).toIso8601String());
    }
    if (status != null) {
      conditions.add('status = ?');
      args.add(status.name);
    }
    if (customerId != null) {
      conditions.add('customerId = ?');
      args.add(customerId);
    }
    if (search != null && search.isNotEmpty) {
      conditions.add('(invoiceNumber LIKE ? OR customerName LIKE ?)');
      args.addAll(['%$search%', '%$search%']);
    }

    final where = conditions.isNotEmpty ? conditions.join(' AND ') : null;
    final maps = await db.query('invoices',
        where: where, whereArgs: args.isNotEmpty ? args : null,
        orderBy: 'createdAt DESC');

    final invoices = <Invoice>[];
    for (final m in maps) {
      final itemMaps = await db.query('invoice_items',
          where: 'invoiceId = ?', whereArgs: [m['id']]);
      invoices.add(Invoice.fromMap(m, itemMaps.map(InvoiceItem.fromMap).toList()));
    }
    return invoices;
  }

  Future<Invoice?> getInvoiceById(int id) async {
    final db = await database;
    final maps = await db.query('invoices', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    final itemMaps = await db.query('invoice_items',
        where: 'invoiceId = ?', whereArgs: [id]);
    return Invoice.fromMap(maps.first, itemMaps.map(InvoiceItem.fromMap).toList());
  }

  Future<void> updateInvoiceStatus(int id, InvoiceStatus status, double paid) async {
    final db = await database;
    await db.update('invoices',
        {'status': status.name, 'paidAmount': paid},
        where: 'id = ?', whereArgs: [id]);
  }

  // ==================== REPORTS ====================
  Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await database;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();

    final todaySales = await db.rawQuery(
        'SELECT COALESCE(SUM(totalAmount),0) as total FROM invoices WHERE createdAt >= ?',
        [todayStart]);
    final monthSales = await db.rawQuery(
        'SELECT COALESCE(SUM(totalAmount),0) as total FROM invoices WHERE createdAt >= ?',
        [monthStart]);
    final totalProducts = await db.rawQuery('SELECT COUNT(*) as cnt FROM products');
    final lowStock = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM products WHERE quantity <= lowStockAlert AND quantity > 0');
    final outOfStock = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM products WHERE quantity <= 0');
    final totalCustomers = await db.rawQuery('SELECT COUNT(*) as cnt FROM customers');
    final pendingBills = await db.rawQuery(
        'SELECT COALESCE(SUM(amount),0) as total FROM utility_bills WHERE status != ?',
        ['paid']);
    final unpaidInvoices = await db.rawQuery(
        'SELECT COALESCE(SUM(totalAmount - paidAmount),0) as total FROM invoices WHERE status != ?',
        ['paid']);

    return {
      'todaySales': (todaySales.first['total'] as num).toDouble(),
      'monthSales': (monthSales.first['total'] as num).toDouble(),
      'totalProducts': totalProducts.first['cnt'],
      'lowStock': lowStock.first['cnt'],
      'outOfStock': outOfStock.first['cnt'],
      'totalCustomers': totalCustomers.first['cnt'],
      'pendingBills': (pendingBills.first['total'] as num).toDouble(),
      'unpaidInvoices': (unpaidInvoices.first['total'] as num).toDouble(),
    };
  }

  Future<List<Map<String, dynamic>>> getSalesByDay(int days) async {
    final db = await database;
    final from = DateTime.now().subtract(Duration(days: days));
    return await db.rawQuery('''
      SELECT
        strftime('%Y-%m-%d', createdAt) as date,
        COALESCE(SUM(totalAmount), 0) as total,
        COUNT(*) as count
      FROM invoices
      WHERE createdAt >= ?
      GROUP BY date
      ORDER BY date ASC
    ''', [from.toIso8601String()]);
  }

  Future<List<Map<String, dynamic>>> getTopProducts(int limit) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        productName,
        SUM(quantity) as totalQty,
        SUM(quantity * price) as totalRevenue
      FROM invoice_items
      GROUP BY productName
      ORDER BY totalRevenue DESC
      LIMIT ?
    ''', [limit]);
  }

  // ==================== UTILITY BILLS ====================
  Future<List<UtilityBill>> getUtilityBills({BillStatus? status}) async {
    final db = await database;
    final maps = await db.query('utility_bills',
        where: status != null ? 'status = ?' : null,
        whereArgs: status != null ? [status.name] : null,
        orderBy: 'dueDate ASC');
    return maps.map((m) => UtilityBill.fromMap(m)).toList();
  }

  Future<int> insertUtilityBill(UtilityBill bill) async {
    final db = await database;
    final map = bill.toMap()..remove('id');
    return await db.insert('utility_bills', map);
  }

  Future<void> updateUtilityBill(UtilityBill bill) async {
    final db = await database;
    await db.update('utility_bills', bill.toMap(),
        where: 'id = ?', whereArgs: [bill.id]);
  }

  Future<void> deleteUtilityBill(int id) async {
    final db = await database;
    await db.delete('utility_bills', where: 'id = ?', whereArgs: [id]);
  }
}
