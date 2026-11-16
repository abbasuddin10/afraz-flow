import 'data_store.dart';

/// Deterministic demo dataset for the local backend.
///
/// It is intentionally rich enough to exercise every screen: low-stock alerts,
/// receivables/payables, a 14-day sales curve, credit sales and COD deliveries.
class DemoSeed {
  const DemoSeed._();

  static const String tenantId = '11111111-1111-4111-8111-111111111111';
  static const String userId = '22222222-2222-4222-8222-222222222222';
  static const String demoEmail = 'demo@afrazflow.app';
  static const String demoPassword = 'demo1234';

  static Map<String, List<Row>> build() {
    final now = DateTime.now();
    String iso(DateTime value) => value.toUtc().toIso8601String();
    String daysAgo(int days, [int hour = 11, int minute = 30]) => iso(
      DateTime(
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      ).subtract(Duration(days: days)),
    );

    final tenant = <String, dynamic>{
      'id': tenantId,
      'name': 'Northwind Traders',
      'business_type': 'Retail & General Store',
      'currency': 'USD',
      'currency_symbol': r'$',
      'tax_rate': 5.0,
      'low_stock_threshold': 10,
      'phone': '+92 300 1234567',
      'email': 'hello@northwind.example',
      'address': 'Shop 14, Gulberg Main Boulevard, Lahore',
      'logo_url': null,
      'created_at': daysAgo(120, 9, 0),
      'daily_briefing_enabled': true,
      'daily_briefing_time': '22:00',
      'daily_briefing_timezone': 'Asia/Karachi',
    };

    final profile = <String, dynamic>{
      'id': userId,
      'email': demoEmail,
      'full_name': 'Afraz Malik',
      'phone': '+92 300 1234567',
      'avatar_url': null,
      'created_at': daysAgo(120, 9, 0),
    };

    final demoAccount = <String, dynamic>{
      'id': 'demo-account',
      'user_id': userId,
      'email': demoEmail,
      'password': demoPassword,
      'created_at': daysAgo(120, 9, 0),
    };

    final membership = <String, dynamic>{
      'id': '44444444-4444-4444-8444-444444444444',
      'tenant_id': tenantId,
      'user_id': userId,
      'role': 'admin',
      'is_active': true,
      'created_at': daysAgo(120, 9, 0),
    };

    final products = <String, dynamic>{
      'prod-001': {
        'id': 'prod-001',
        'tenant_id': tenantId,
        'name': 'Basmati Rice 5kg',
        'sku': 'RIC-0001',
        'barcode': '8901001000011',
        'category': 'Grocery',
        'unit': 'bag',
        'cost_price': 1100.0,
        'sale_price': 1350.0,
        'stock_qty': 42.0,
        'low_stock_threshold': 10,
        'is_active': true,
        'image_url': null,
        'created_at': daysAgo(90),
        'updated_at': daysAgo(1),
      },
      'prod-002': {
        'id': 'prod-002',
        'tenant_id': tenantId,
        'name': 'Sunflower Oil 1L',
        'sku': 'OIL-0002',
        'barcode': '8901001000028',
        'category': 'Grocery',
        'unit': 'bottle',
        'cost_price': 420.0,
        'sale_price': 520.0,
        'stock_qty': 8.0,
        'low_stock_threshold': 12,
        'is_active': true,
        'image_url': null,
        'created_at': daysAgo(88),
        'updated_at': daysAgo(2),
      },
      'prod-003': {
        'id': 'prod-003',
        'tenant_id': tenantId,
        'name': 'Green Tea 200g',
        'sku': 'TEA-0003',
        'barcode': '8901001000035',
        'category': 'Beverages',
        'unit': 'box',
        'cost_price': 280.0,
        'sale_price': 390.0,
        'stock_qty': 25.0,
        'low_stock_threshold': 8,
        'is_active': true,
        'image_url': null,
        'created_at': daysAgo(84),
        'updated_at': daysAgo(3),
      },
      'prod-004': {
        'id': 'prod-004',
        'tenant_id': tenantId,
        'name': 'Laundry Detergent 2kg',
        'sku': 'DET-0004',
        'barcode': '8901001000042',
        'category': 'Household',
        'unit': 'pack',
        'cost_price': 520.0,
        'sale_price': 680.0,
        'stock_qty': 3.0,
        'low_stock_threshold': 10,
        'is_active': true,
        'image_url': null,
        'created_at': daysAgo(80),
        'updated_at': daysAgo(1),
      },
      'prod-005': {
        'id': 'prod-005',
        'tenant_id': tenantId,
        'name': 'Mineral Water 1.5L',
        'sku': 'WAT-0005',
        'barcode': '8901001000059',
        'category': 'Beverages',
        'unit': 'bottle',
        'cost_price': 45.0,
        'sale_price': 80.0,
        'stock_qty': 120.0,
        'low_stock_threshold': 24,
        'is_active': true,
        'image_url': null,
        'created_at': daysAgo(75),
        'updated_at': daysAgo(1),
      },
      'prod-006': {
        'id': 'prod-006',
        'tenant_id': tenantId,
        'name': 'Chocolate Bar 100g',
        'sku': 'CHO-0006',
        'barcode': '8901001000066',
        'category': 'Snacks',
        'unit': 'bar',
        'cost_price': 90.0,
        'sale_price': 140.0,
        'stock_qty': 64.0,
        'low_stock_threshold': 20,
        'is_active': true,
        'image_url': null,
        'created_at': daysAgo(70),
        'updated_at': daysAgo(4),
      },
      'prod-007': {
        'id': 'prod-007',
        'tenant_id': tenantId,
        'name': 'Toothpaste 150g',
        'sku': 'TOO-0007',
        'barcode': '8901001000073',
        'category': 'Personal Care',
        'unit': 'tube',
        'cost_price': 180.0,
        'sale_price': 250.0,
        'stock_qty': 18.0,
        'low_stock_threshold': 10,
        'is_active': true,
        'image_url': null,
        'created_at': daysAgo(66),
        'updated_at': daysAgo(5),
      },
      'prod-008': {
        'id': 'prod-008',
        'tenant_id': tenantId,
        'name': 'Chicken Eggs (Dozen)',
        'sku': 'EGG-0008',
        'barcode': '8901001000080',
        'category': 'Grocery',
        'unit': 'dozen',
        'cost_price': 260.0,
        'sale_price': 330.0,
        'stock_qty': 30.0,
        'low_stock_threshold': 12,
        'is_active': true,
        'image_url': null,
        'created_at': daysAgo(62),
        'updated_at': daysAgo(2),
      },
      'prod-009': {
        'id': 'prod-009',
        'tenant_id': tenantId,
        'name': 'Coffee Beans 500g',
        'sku': 'COF-0009',
        'barcode': '8901001000097',
        'category': 'Beverages',
        'unit': 'bag',
        'cost_price': 1200.0,
        'sale_price': 1750.0,
        'stock_qty': 12.0,
        'low_stock_threshold': 6,
        'is_active': true,
        'image_url': null,
        'created_at': daysAgo(58),
        'updated_at': daysAgo(6),
      },
      'prod-010': {
        'id': 'prod-010',
        'tenant_id': tenantId,
        'name': 'Notebook A5',
        'sku': 'NOT-0010',
        'barcode': '8901001000103',
        'category': 'Stationery',
        'unit': 'pcs',
        'cost_price': 70.0,
        'sale_price': 120.0,
        'stock_qty': 55.0,
        'low_stock_threshold': 15,
        'is_active': true,
        'image_url': null,
        'created_at': daysAgo(54),
        'updated_at': daysAgo(8),
      },
      'prod-011': {
        'id': 'prod-011',
        'tenant_id': tenantId,
        'name': 'Hand Sanitiser 250ml',
        'sku': 'SAN-0011',
        'barcode': '8901001000110',
        'category': 'Personal Care',
        'unit': 'bottle',
        'cost_price': 210.0,
        'sale_price': 300.0,
        'stock_qty': 6.0,
        'low_stock_threshold': 10,
        'is_active': true,
        'image_url': null,
        'created_at': daysAgo(50),
        'updated_at': daysAgo(2),
      },
      'prod-012': {
        'id': 'prod-012',
        'tenant_id': tenantId,
        'name': 'Masala Mix 100g',
        'sku': 'MAS-0012',
        'barcode': '8901001000127',
        'category': 'Grocery',
        'unit': 'pack',
        'cost_price': 150.0,
        'sale_price': 220.0,
        'stock_qty': 38.0,
        'low_stock_threshold': 10,
        'is_active': true,
        'image_url': null,
        'created_at': daysAgo(45),
        'updated_at': daysAgo(7),
      },
    };

    final accounts = <String, dynamic>{
      'acc-001': {
        'id': 'acc-001',
        'tenant_id': tenantId,
        'name': 'Ayesha Khan',
        'account_type': 'customer',
        'opening_balance': 0.0,
        'balance': 4200.0,
        'phone': '+92 321 4455667',
        'email': 'ayesha@example.com',
        'address': 'Model Town, Lahore',
        'created_at': daysAgo(45),
        'updated_at': daysAgo(2),
      },
      'acc-002': {
        'id': 'acc-002',
        'tenant_id': tenantId,
        'name': 'Bilal Ahmed',
        'account_type': 'customer',
        'opening_balance': 0.0,
        'balance': 0.0,
        'phone': '+92 333 7788990',
        'email': null,
        'address': 'Johar Town, Lahore',
        'created_at': daysAgo(40),
        'updated_at': daysAgo(5),
      },
      'acc-003': {
        'id': 'acc-003',
        'tenant_id': tenantId,
        'name': 'Green Valley Hotel',
        'account_type': 'customer',
        'opening_balance': 0.0,
        'balance': 18500.0,
        'phone': '+92 42 35761234',
        'email': 'purchasing@greenvalley.example',
        'address': 'MM Alam Road, Lahore',
        'created_at': daysAgo(38),
        'updated_at': daysAgo(1),
      },
      'acc-004': {
        'id': 'acc-004',
        'tenant_id': tenantId,
        'name': 'FreshMart Wholesale',
        'account_type': 'supplier',
        'opening_balance': 0.0,
        'balance': 26000.0,
        'phone': '+92 300 9988776',
        'email': 'orders@freshmart.example',
        'address': 'Badami Bagh, Lahore',
        'created_at': daysAgo(60),
        'updated_at': daysAgo(3),
      },
      'acc-005': {
        'id': 'acc-005',
        'tenant_id': tenantId,
        'name': 'Prime Distributors',
        'account_type': 'supplier',
        'opening_balance': 0.0,
        'balance': 9800.0,
        'phone': '+92 301 2233445',
        'email': 'accounts@primedist.example',
        'address': 'Shahdara, Lahore',
        'created_at': daysAgo(55),
        'updated_at': daysAgo(6),
      },
    };

    final ledgerEntries = <String, dynamic>{
      'led-001': {
        'id': 'led-001',
        'tenant_id': tenantId,
        'account_id': 'acc-001',
        'entry_type': 'charge',
        'amount': 5000.0,
        'description': 'Credit sale — groceries',
        'reference': 'INV-20261028-0912',
        'entry_date': daysAgo(16).substring(0, 10),
        'created_at': daysAgo(16),
      },
      'led-002': {
        'id': 'led-002',
        'tenant_id': tenantId,
        'account_id': 'acc-001',
        'entry_type': 'payment',
        'amount': 800.0,
        'description': 'Cash payment received',
        'reference': null,
        'entry_date': daysAgo(4).substring(0, 10),
        'created_at': daysAgo(4),
      },
      'led-003': {
        'id': 'led-003',
        'tenant_id': tenantId,
        'account_id': 'acc-002',
        'entry_type': 'charge',
        'amount': 2500.0,
        'description': 'Credit sale — household items',
        'reference': 'INV-20261101-1030',
        'entry_date': daysAgo(12).substring(0, 10),
        'created_at': daysAgo(12),
      },
      'led-004': {
        'id': 'led-004',
        'tenant_id': tenantId,
        'account_id': 'acc-002',
        'entry_type': 'payment',
        'amount': 2500.0,
        'description': 'Paid in full via bank transfer',
        'reference': null,
        'entry_date': daysAgo(6).substring(0, 10),
        'created_at': daysAgo(6),
      },
      'led-005': {
        'id': 'led-005',
        'tenant_id': tenantId,
        'account_id': 'acc-003',
        'entry_type': 'charge',
        'amount': 22000.0,
        'description': 'Monthly pantry supply order',
        'reference': 'INV-20261025-0801',
        'entry_date': daysAgo(19).substring(0, 10),
        'created_at': daysAgo(19),
      },
      'led-006': {
        'id': 'led-006',
        'tenant_id': tenantId,
        'account_id': 'acc-003',
        'entry_type': 'payment',
        'amount': 3500.0,
        'description': 'Partial payment — bank',
        'reference': null,
        'entry_date': daysAgo(7).substring(0, 10),
        'created_at': daysAgo(7),
      },
      'led-007': {
        'id': 'led-007',
        'tenant_id': tenantId,
        'account_id': 'acc-004',
        'entry_type': 'charge',
        'amount': 30000.0,
        'description': 'Stock purchase on credit',
        'reference': 'PO-8842',
        'entry_date': daysAgo(24).substring(0, 10),
        'created_at': daysAgo(24),
      },
      'led-008': {
        'id': 'led-008',
        'tenant_id': tenantId,
        'account_id': 'acc-004',
        'entry_type': 'payment',
        'amount': 4000.0,
        'description': 'Supplier payment — cash',
        'reference': null,
        'entry_date': daysAgo(9).substring(0, 10),
        'created_at': daysAgo(9),
      },
      'led-009': {
        'id': 'led-009',
        'tenant_id': tenantId,
        'account_id': 'acc-005',
        'entry_type': 'charge',
        'amount': 15000.0,
        'description': 'Beverage restock',
        'reference': 'PO-8861',
        'entry_date': daysAgo(20).substring(0, 10),
        'created_at': daysAgo(20),
      },
      'led-010': {
        'id': 'led-010',
        'tenant_id': tenantId,
        'account_id': 'acc-005',
        'entry_type': 'payment',
        'amount': 5200.0,
        'description': 'Supplier payment — bank',
        'reference': null,
        'entry_date': daysAgo(3).substring(0, 10),
        'created_at': daysAgo(3),
      },
    };

    final sales = <String, dynamic>{};
    final saleItems = <String, dynamic>{};
    var saleSeq = 0;

    void addSale({
      required int daysAgoValue,
      required String customer,
      String? accountId,
      required List<(String, double)> lines,
      String paymentMethod = 'cash',
      double discount = 0,
      double? paidOverride,
    }) {
      saleSeq++;
      final id = 'sale-${saleSeq.toString().padLeft(3, '0')}';
      final createdAt = daysAgo(
        daysAgoValue,
        10 + (saleSeq % 8),
        (saleSeq * 7) % 60,
      );
      var subtotal = 0.0;
      var itemSeq = 0;
      for (final line in lines) {
        final product = products[line.$1] as Map<String, dynamic>;
        final qty = line.$2;
        final unitPrice = (product['sale_price'] as num).toDouble();
        final unitCost = (product['cost_price'] as num).toDouble();
        final lineTotal = unitPrice * qty;
        subtotal += lineTotal;
        itemSeq++;
        final itemId = '$id-item-$itemSeq';
        saleItems[itemId] = {
          'id': itemId,
          'tenant_id': tenantId,
          'sale_id': id,
          'product_id': product['id'],
          'product_name': product['name'],
          'sku': product['sku'],
          'quantity': qty,
          'unit_price': unitPrice,
          'cost_price': unitCost,
          'line_total': lineTotal,
          'created_at': createdAt,
        };
      }
      final taxable = (subtotal - discount).clamp(0, double.infinity);
      final tax = double.parse((taxable * 0.05).toStringAsFixed(2));
      final total = double.parse((taxable + tax).toStringAsFixed(2));
      final paid = paidOverride ?? total;
      final due = double.parse((total - paid).toStringAsFixed(2));
      sales[id] = {
        'id': id,
        'tenant_id': tenantId,
        'invoice_no':
            'INV-${createdAt.substring(0, 10).replaceAll('-', '')}'
            '-${saleSeq.toString().padLeft(3, '0')}',
        'account_id': accountId,
        'customer_name': customer,
        'subtotal': subtotal,
        'discount': discount,
        'tax': tax,
        'total': total,
        'paid_amount': paid,
        'due_amount': due,
        'payment_method': paymentMethod,
        'status': 'completed',
        'note': null,
        'created_by': userId,
        'created_at': createdAt,
        'updated_at': createdAt,
      };
    }

    addSale(
      daysAgoValue: 13,
      customer: 'Walk-in customer',
      lines: [('prod-001', 2), ('prod-005', 4), ('prod-006', 3)],
      paymentMethod: 'cash',
    );
    addSale(
      daysAgoValue: 12,
      customer: 'Green Valley Hotel',
      accountId: 'acc-003',
      lines: [('prod-005', 48), ('prod-003', 6), ('prod-009', 4)],
      paymentMethod: 'credit',
      paidOverride: 0,
    );
    addSale(
      daysAgoValue: 10,
      customer: 'Walk-in customer',
      lines: [('prod-002', 3), ('prod-004', 2), ('prod-007', 2)],
      paymentMethod: 'card',
    );
    addSale(
      daysAgoValue: 9,
      customer: 'Ayesha Khan',
      accountId: 'acc-001',
      lines: [('prod-001', 1), ('prod-002', 2), ('prod-008', 2)],
      paymentMethod: 'cash',
    );
    addSale(
      daysAgoValue: 7,
      customer: 'Walk-in customer',
      lines: [('prod-006', 10), ('prod-005', 12)],
      paymentMethod: 'cash',
      discount: 100,
    );
    addSale(
      daysAgoValue: 6,
      customer: 'Bilal Ahmed',
      accountId: 'acc-002',
      lines: [('prod-004', 2), ('prod-011', 3)],
      paymentMethod: 'bank',
    );
    addSale(
      daysAgoValue: 5,
      customer: 'Walk-in customer',
      lines: [('prod-009', 2), ('prod-003', 3), ('prod-010', 4)],
      paymentMethod: 'card',
    );
    addSale(
      daysAgoValue: 4,
      customer: 'Green Valley Hotel',
      accountId: 'acc-003',
      lines: [('prod-009', 6), ('prod-005', 36), ('prod-008', 5)],
      paymentMethod: 'credit',
      paidOverride: 10000,
    );
    addSale(
      daysAgoValue: 3,
      customer: 'Walk-in customer',
      lines: [('prod-001', 3), ('prod-012', 5)],
      paymentMethod: 'cash',
    );
    addSale(
      daysAgoValue: 2,
      customer: 'Ayesha Khan',
      accountId: 'acc-001',
      lines: [('prod-003', 2), ('prod-006', 4), ('prod-007', 1)],
      paymentMethod: 'cash',
    );
    addSale(
      daysAgoValue: 1,
      customer: 'Walk-in customer',
      lines: [('prod-002', 4), ('prod-008', 3), ('prod-005', 10)],
      paymentMethod: 'card',
      discount: 150,
    );
    addSale(
      daysAgoValue: 0,
      customer: 'Bilal Ahmed',
      accountId: 'acc-002',
      lines: [('prod-001', 2), ('prod-010', 6), ('prod-011', 2)],
      paymentMethod: 'cash',
    );

    final expenses = <String, dynamic>{};
    final expenseSeed = [
      ('Rent', 'Shop rent — current month', 45000.0, 12),
      ('Utilities', 'Electricity and water bill', 12400.0, 8),
      ('Salaries', 'Sales staff salaries', 52000.0, 6),
      ('Logistics', 'Delivery fuel and bike maintenance', 6800.0, 4),
      ('Packaging', 'Bags, boxes and receipt rolls', 3200.0, 3),
      ('Marketing', 'Local flyers and social media boost', 8000.0, 2),
      ('Maintenance', 'Air conditioner servicing', 4500.0, 1),
    ];
    var expenseSeq = 0;
    for (final item in expenseSeed) {
      expenseSeq++;
      final id = 'exp-${expenseSeq.toString().padLeft(3, '0')}';
      expenses[id] = {
        'id': id,
        'tenant_id': tenantId,
        'category': item.$1,
        'description': item.$2,
        'amount': item.$3,
        'payment_method': expenseSeq.isEven ? 'cash' : 'bank',
        'expense_date': daysAgo(item.$4).substring(0, 10),
        'reference': null,
        'created_by': userId,
        'created_at': daysAgo(item.$4),
      };
    }

    final couriers = <String, dynamic>{
      'ord-001': {
        'id': 'ord-001',
        'tenant_id': tenantId,
        'order_no': 'AF-260113-1042',
        'sale_id': null,
        'customer_name': 'Ayesha Khan',
        'customer_phone': '+92 321 4455667',
        'address': 'House 24, Street 7, Model Town',
        'city': 'Lahore',
        'courier_partner': 'Leopards Courier',
        'tracking_number': 'LP-88231045',
        'status': 'pending',
        'cod_amount': 3200.0,
        'cod_collected': false,
        'shipping_fee': 250.0,
        'notes': 'Call before delivery. Gate code 4471.',
        'created_at': daysAgo(0, 9, 15),
        'updated_at': daysAgo(0, 9, 15),
      },
      'ord-002': {
        'id': 'ord-002',
        'tenant_id': tenantId,
        'order_no': 'AF-260112-0931',
        'sale_id': null,
        'customer_name': 'Green Valley Hotel',
        'customer_phone': '+92 42 35761234',
        'address': 'Reception desk, MM Alam Road',
        'city': 'Lahore',
        'courier_partner': 'TCS',
        'tracking_number': 'TCS-44210987',
        'status': 'shipped',
        'cod_amount': 18500.0,
        'cod_collected': false,
        'shipping_fee': 0.0,
        'notes': 'Bulk order — deliver to loading bay.',
        'created_at': daysAgo(1, 14, 20),
        'updated_at': daysAgo(1, 18, 5),
      },
      'ord-003': {
        'id': 'ord-003',
        'tenant_id': tenantId,
        'order_no': 'AF-260111-0817',
        'sale_id': null,
        'customer_name': 'Hamza Saeed',
        'customer_phone': '+92 345 1122334',
        'address': 'Flat 3B, Askari 11',
        'city': 'Lahore',
        'courier_partner': 'M&P',
        'tracking_number': 'MP-77120045',
        'status': 'delivered',
        'cod_amount': 2450.0,
        'cod_collected': false,
        'shipping_fee': 200.0,
        'notes': null,
        'dispatched_at': daysAgo(2, 10, 0),
        'delivered_at': daysAgo(1, 16, 30),
        'created_at': daysAgo(2, 9, 0),
        'updated_at': daysAgo(1, 16, 30),
      },
      'ord-004': {
        'id': 'ord-004',
        'tenant_id': tenantId,
        'order_no': 'AF-260110-0742',
        'sale_id': null,
        'customer_name': 'Sadia Noor',
        'customer_phone': '+92 300 5566778',
        'address': 'House 12, DHA Phase 5',
        'city': 'Lahore',
        'courier_partner': 'Leopards Courier',
        'tracking_number': 'LP-88229901',
        'status': 'returned',
        'cod_amount': 5600.0,
        'cod_collected': false,
        'shipping_fee': 300.0,
        'notes': 'Customer refused — address incomplete.',
        'dispatched_at': daysAgo(4, 11, 0),
        'created_at': daysAgo(4, 9, 30),
        'updated_at': daysAgo(3, 17, 15),
      },
      'ord-005': {
        'id': 'ord-005',
        'tenant_id': tenantId,
        'order_no': 'AF-260113-1108',
        'sale_id': null,
        'customer_name': 'Usman Tariq',
        'customer_phone': '+92 322 8899001',
        'address': 'Office 9, Arfa Software Technology Park',
        'city': 'Lahore',
        'courier_partner': 'TCS',
        'tracking_number': null,
        'status': 'pending',
        'cod_amount': 1750.0,
        'cod_collected': false,
        'shipping_fee': 250.0,
        'notes': 'Awaiting pickup confirmation.',
        'created_at': daysAgo(0, 10, 40),
        'updated_at': daysAgo(0, 10, 40),
      },
      'ord-006': {
        'id': 'ord-006',
        'tenant_id': tenantId,
        'order_no': 'AF-260109-0655',
        'sale_id': null,
        'customer_name': 'Fatima Riaz',
        'customer_phone': '+92 336 4433221',
        'address': 'House 88, Bahria Town',
        'city': 'Rawalpindi',
        'courier_partner': 'Pakistan Post',
        'tracking_number': 'PP-33445566',
        'status': 'shipped',
        'cod_amount': 8600.0,
        'cod_collected': false,
        'shipping_fee': 450.0,
        'notes': null,
        'dispatched_at': daysAgo(1, 12, 0),
        'created_at': daysAgo(2, 15, 0),
        'updated_at': daysAgo(1, 12, 0),
      },
    };

    final courierEvents = <String, dynamic>{
      'evt-001': {
        'id': 'evt-001',
        'tenant_id': tenantId,
        'courier_order_id': 'ord-001',
        'status': 'pending',
        'note': 'Order created and awaiting dispatch.',
        'created_at': daysAgo(0, 9, 15),
      },
      'evt-002': {
        'id': 'evt-002',
        'tenant_id': tenantId,
        'courier_order_id': 'ord-002',
        'status': 'pending',
        'note': 'Order created.',
        'created_at': daysAgo(1, 14, 20),
      },
      'evt-003': {
        'id': 'evt-003',
        'tenant_id': tenantId,
        'courier_order_id': 'ord-002',
        'status': 'shipped',
        'note': 'Picked up by TCS. Tracking TCS-44210987.',
        'created_at': daysAgo(1, 18, 5),
      },
      'evt-004': {
        'id': 'evt-004',
        'tenant_id': tenantId,
        'courier_order_id': 'ord-003',
        'status': 'delivered',
        'note': 'Delivered successfully, COD pending reconciliation.',
        'created_at': daysAgo(1, 16, 30),
      },
      'evt-005': {
        'id': 'evt-005',
        'tenant_id': tenantId,
        'courier_order_id': 'ord-004',
        'status': 'returned',
        'note': 'Returned to shop. Restock required.',
        'created_at': daysAgo(3, 17, 15),
      },
    };

    final stockMovements = <String, dynamic>{
      'mov-001': {
        'id': 'mov-001',
        'tenant_id': tenantId,
        'product_id': 'prod-001',
        'product_name': 'Basmati Rice 5kg',
        'movement_type': 'in',
        'quantity': 50.0,
        'note': 'Purchase from FreshMart Wholesale',
        'reference': 'PO-8842',
        'created_by': userId,
        'created_at': daysAgo(24, 10, 0),
      },
      'mov-002': {
        'id': 'mov-002',
        'tenant_id': tenantId,
        'product_id': 'prod-004',
        'product_name': 'Laundry Detergent 2kg',
        'movement_type': 'out',
        'quantity': 6.0,
        'note': 'Damaged packaging written off',
        'reference': null,
        'created_by': userId,
        'created_at': daysAgo(5, 12, 0),
      },
      'mov-003': {
        'id': 'mov-003',
        'tenant_id': tenantId,
        'product_id': 'prod-002',
        'product_name': 'Sunflower Oil 1L',
        'movement_type': 'in',
        'quantity': 24.0,
        'note': 'Restock from Prime Distributors',
        'reference': 'PO-8861',
        'created_by': userId,
        'created_at': daysAgo(20, 9, 0),
      },
    };

    // --- Daily executive briefings -------------------------------------------
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const weekdayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    String dayKey(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';

    String localDateKey(String value) {
      final local = DateTime.parse(value).toLocal();
      return dayKey(local);
    }

    String longDate(DateTime value) =>
        '${weekdayNames[value.weekday - 1]}, ${value.day} '
        '${monthNames[value.month - 1]} ${value.year}';

    final today = DateTime(now.year, now.month, now.day);
    final todayKey = dayKey(today);
    final currencySymbol = tenant['currency_symbol'] as String;

    String money(num value) => value % 1 == 0
        ? '$currencySymbol${value.toStringAsFixed(0)}'
        : '$currencySymbol${value.toStringAsFixed(2)}';

    final lowStockProducts = products.values
        .cast<Map<String, dynamic>>()
        .where(
          (product) =>
              product['is_active'] == true &&
              (product['stock_qty'] as num) <=
                  (product['low_stock_threshold'] as num),
        )
        .toList(growable: false);

    final reorderRows = <Row>[];
    for (final product in lowStockProducts) {
      final threshold = (product['low_stock_threshold'] as num).toDouble();
      final stock = (product['stock_qty'] as num).toDouble();
      final quantity = ((threshold * 2) - stock).ceilToDouble();
      reorderRows.add({
        'id': 'reorder-${product['id']}-$todayKey',
        'tenant_id': tenantId,
        'product_id': product['id'],
        'product_name': product['name'],
        'sku': product['sku'],
        'quantity': quantity < 1 ? 1.0 : quantity,
        'status': 'pending',
        'source': 'auto',
        'note': 'Auto-reorder: stock is at or below the alert threshold',
        'reorder_date': todayKey,
        'created_at': iso(today.add(const Duration(hours: 22))),
        'updated_at': iso(today.add(const Duration(hours: 22))),
      });
    }

    final metricsByOffset = <int, Map<String, dynamic>>{};
    final statsByOffset = <int, Map<String, double>>{};
    for (var offset = 0; offset <= 3; offset++) {
      final day = today.subtract(Duration(days: offset));
      final key = dayKey(day);

      final daySales = sales.values
          .cast<Map<String, dynamic>>()
          .where(
            (sale) =>
                sale['status'] == 'completed' &&
                localDateKey(sale['created_at'] as String) == key,
          )
          .toList(growable: false);
      final saleIds = daySales.map((sale) => sale['id']).toSet();

      final dayItems = saleItems.values
          .cast<Map<String, dynamic>>()
          .where((item) => saleIds.contains(item['sale_id']))
          .toList(growable: false);

      var revenue = 0.0;
      var paid = 0.0;
      var credit = 0.0;
      for (final sale in daySales) {
        revenue += (sale['total'] as num).toDouble();
        paid += (sale['paid_amount'] as num).toDouble();
        credit += (sale['due_amount'] as num).toDouble();
      }

      var cost = 0.0;
      final topTotals = <String, Map<String, dynamic>>{};
      for (final item in dayItems) {
        final quantity = (item['quantity'] as num).toDouble();
        final lineTotal = (item['line_total'] as num).toDouble();
        cost += (item['cost_price'] as num).toDouble() * quantity;
        final name = item['product_name'] as String;
        final entry = topTotals.putIfAbsent(
          name,
          () => {'name': name, 'quantity': 0.0, 'revenue': 0.0},
        );
        entry['quantity'] = (entry['quantity'] as double) + quantity;
        entry['revenue'] = (entry['revenue'] as double) + lineTotal;
      }
      final topProducts = topTotals.values.toList()
        ..sort(
          (a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double),
        );

      final dayExpenses = expenses.values
          .cast<Map<String, dynamic>>()
          .where((expense) => expense['expense_date'] == key)
          .fold<double>(
            0,
            (sum, expense) => sum + (expense['amount'] as num).toDouble(),
          );
      final ledgerCollected = ledgerEntries.values
          .cast<Map<String, dynamic>>()
          .where(
            (entry) =>
                entry['entry_type'] == 'payment' &&
                localDateKey(entry['created_at'] as String) == key,
          )
          .fold<double>(
            0,
            (sum, entry) => sum + (entry['amount'] as num).toDouble(),
          );

      final netProfit = revenue - cost - dayExpenses;
      final dayReorders = offset == 0 ? reorderRows : const <Row>[];
      final lowStock = offset == 0
          ? lowStockProducts
                .map((product) => Map<String, dynamic>.from(product))
                .toList(growable: false)
          : const <Map<String, dynamic>>[];

      statsByOffset[offset] = {
        'revenue': revenue,
        'paid': paid,
        'credit': credit,
        'expenses': dayExpenses,
        'net_profit': netProfit,
        'ledger_collected': ledgerCollected,
        'sales_count': daySales.length.toDouble(),
      };

      metricsByOffset[offset] = <String, dynamic>{
        'business_name': tenant['name'],
        'currency': tenant['currency'],
        'currency_symbol': currencySymbol,
        'sales': {
          'count': daySales.length,
          'revenue': revenue,
          'cost_of_goods': cost,
          'gross_profit': revenue - cost,
        },
        'expenses': {'total': dayExpenses},
        'net_profit': netProfit,
        'cash_collected': paid + ledgerCollected,
        'new_credit': credit,
        'receivables': accounts.values
            .cast<Map<String, dynamic>>()
            .where((account) => account['account_type'] == 'customer')
            .fold<double>(
              0,
              (sum, account) => sum + (account['balance'] as num).toDouble(),
            ),
        'payables': accounts.values
            .cast<Map<String, dynamic>>()
            .where((account) => account['account_type'] == 'supplier')
            .fold<double>(
              0,
              (sum, account) => sum + (account['balance'] as num).toDouble(),
            ),
        'reorder_count': dayReorders.length,
        'top_products': topProducts.take(5).toList(growable: false),
        'low_stock': lowStock.take(20).toList(growable: false),
        'reorders': [
          for (final reorder in dayReorders)
            {
              'id': reorder['id'],
              'product_id': reorder['product_id'],
              'product_name': reorder['product_name'],
              'sku': reorder['sku'],
              'quantity': reorder['quantity'],
              'status': reorder['status'],
              'source': reorder['source'],
            },
        ],
        'previous': {'revenue': 0.0, 'net_profit': 0.0},
      };
    }

    final summaryRows = <Row>[];
    for (var offset = 0; offset < 3; offset++) {
      final day = today.subtract(Duration(days: offset));
      final key = dayKey(day);
      final metrics = metricsByOffset[offset]!;
      final stats = statsByOffset[offset]!;
      final previous = statsByOffset[offset + 1]!;

      final previousMetrics = metrics['previous'] as Map<String, dynamic>;
      previousMetrics['revenue'] = previous['revenue'];
      previousMetrics['net_profit'] = previous['net_profit'];

      final count = stats['sales_count']!.toInt();
      final plural = count == 1 ? '' : 's';
      final revenue = stats['revenue']!;
      final expenses = stats['expenses']!;
      final netProfit = stats['net_profit']!;
      final cashCollected = stats['paid']! + stats['ledger_collected']!;
      final credit = stats['credit']!;
      final topProducts = (metrics['top_products'] as List)
          .cast<Map<String, dynamic>>();
      final lowStock = (metrics['low_stock'] as List)
          .cast<Map<String, dynamic>>();
      final dayReorders = metrics['reorders'] as List;
      final receivables = metrics['receivables'] as double;
      final payables = metrics['payables'] as double;

      final summary = count == 0
          ? 'No completed sales were recorded for this business day. '
                'Expenses were ${money(expenses)}, leaving a net result of '
                '${money(netProfit)}.'
          : 'You completed $count sale$plural for ${money(revenue)} in '
                'revenue. After ${money(expenses)} in expenses, net profit '
                'was ${money(netProfit)}.';

      final highlights = <String>[
        '$count sale$plural · ${money(revenue)} revenue',
        'Cash collected ${money(cashCollected)} · '
            'new credit ${money(credit)}',
        '${lowStock.length} product'
            '${lowStock.length == 1 ? '' : 's'} low on stock'
            '${dayReorders.isEmpty ? '' : ' · ${dayReorders.length} '
                      'reorder${dayReorders.length == 1 ? '' : 's'} created'}',
        if (topProducts.isNotEmpty)
          'Best sellers: ${topProducts.take(3).map((product) => product['name']).join(', ')}',
        if (previous['revenue']! > 0)
          'Previous day: ${money(previous['revenue']!)} revenue · '
              '${money(previous['net_profit']!)} net profit',
      ];

      final recommendations = <String>[
        if (lowStock.isNotEmpty)
          'Confirm the auto-reorders for low-stock products.',
        if (receivables > 0)
          'Collect part of the ${money(receivables)} outstanding from customers.',
        if (payables > 0) 'Plan for ${money(payables)} payable to suppliers.',
      ];
      if (recommendations.isEmpty) {
        recommendations.add(
          "Keep the momentum going and prepare tomorrow's stock.",
        );
      }

      final headline = count == 0
          ? 'A quiet day with no sales'
          : '${money(netProfit)} net profit for the day';
      final generatedAt = offset == 0
          ? now
          : day.add(const Duration(hours: 22));

      summaryRows.add({
        'id': 'summary-$key',
        'tenant_id': tenantId,
        'summary_date': key,
        'timezone': tenant['daily_briefing_timezone'],
        'headline': headline,
        'summary': summary,
        'highlights': highlights,
        'recommendations': recommendations,
        'metrics': metrics,
        'source': 'local',
        'model': null,
        'is_manual': true,
        'generated_at': iso(generatedAt),
        'created_by': userId,
        'created_at': iso(generatedAt),
        'updated_at': iso(generatedAt),
      });
    }

    final notificationRows = <Row>[
      {
        'id': 'notification-$todayKey',
        'tenant_id': tenantId,
        'user_id': userId,
        'title': 'Daily AI Briefing',
        'body':
            'Your Daily Business Briefing for ${longDate(today)} is ready. '
            'Tap to view.',
        'kind': 'daily_briefing',
        'reference_id': 'summary-$todayKey',
        'dedupe_key': 'daily_briefing:$tenantId:$todayKey',
        'read_at': null,
        'created_at': iso(now),
        'updated_at': iso(now),
      },
    ];

    return {
      'tenants': [tenant],
      'profiles': [profile],
      'demo_accounts': [demoAccount],
      'tenant_members': [membership],
      'products': products.values.cast<Row>().toList(),
      'stock_movements': stockMovements.values.cast<Row>().toList(),
      'ledger_accounts': accounts.values.cast<Row>().toList(),
      'ledger_entries': ledgerEntries.values.cast<Row>().toList(),
      'sales': sales.values.cast<Row>().toList(),
      'sale_items': saleItems.values.cast<Row>().toList(),
      'expenses': expenses.values.cast<Row>().toList(),
      'courier_orders': couriers.values.cast<Row>().toList(),
      'courier_events': courierEvents.values.cast<Row>().toList(),
      'daily_summaries': summaryRows,
      'app_notifications': notificationRows,
      'inventory_reorders': reorderRows,
    };
  }
}
