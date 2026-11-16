import 'package:uuid/uuid.dart';

import '../../../../core/data/data_store.dart';
import '../../../../core/services/app_services.dart';
import '../../../../core/utils/app_failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/json_helpers.dart';
import '../data/courier_order.dart';

class CourierRepository {
  CourierRepository(this._store, this._session);

  static const Uuid _uuid = Uuid();

  final DataStore _store;
  final SessionService _session;

  Future<List<CourierOrder>> all({int limit = 300}) async {
    final rows = await _store.select(
      'courier_orders',
      eq: {'tenant_id': _session.requireTenantId()},
      orderBy: 'created_at',
      limit: limit,
    );
    return rows.map((row) => CourierOrder.fromJson(row)).toList();
  }

  Future<CourierOrder?> byId(String id) async {
    final row = await _store.findById('courier_orders', id);
    if (row == null) return null;
    final events = await this.events(id);
    return CourierOrder.fromJson(row, events: events);
  }

  Future<List<CourierEvent>> events(String orderId) async {
    final rows = await _store.select(
      'courier_events',
      eq: {
        'tenant_id': _session.requireTenantId(),
        'courier_order_id': orderId,
      },
      orderBy: 'created_at',
      limit: 200,
    );
    return rows.map(CourierEvent.fromJson).toList();
  }

  Future<CourierOrder> create({
    required String customerName,
    required String customerPhone,
    required String address,
    required String city,
    required String courierPartner,
    required double codAmount,
    double shippingFee = 0,
    String? trackingNumber,
    String? notes,
    String? saleId,
  }) async {
    if (customerName.trim().isEmpty) {
      throw const AppFailure('Customer name is required.');
    }
    if (customerPhone.trim().isEmpty) {
      throw const AppFailure('Customer phone is required.');
    }
    if (address.trim().isEmpty) {
      throw const AppFailure('Delivery address is required.');
    }
    if (codAmount < 0 || shippingFee < 0) {
      throw const AppFailure('COD and shipping amounts cannot be negative.');
    }
    final now = DateTime.now();
    final order = CourierOrder(
      id: _uuid.v4(),
      tenantId: _session.requireTenantId(),
      orderNo: Formats.orderNumber(now),
      saleId: saleId,
      customerName: customerName.trim(),
      customerPhone: customerPhone.trim(),
      address: address.trim(),
      city: city.trim().isEmpty ? '—' : city.trim(),
      courierPartner: courierPartner,
      trackingNumber: trackingNumber?.trim().isEmpty == true
          ? null
          : trackingNumber?.trim(),
      status: CourierStatus.pending,
      codAmount: codAmount,
      codCollected: false,
      shippingFee: shippingFee,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    final row = await _store.insert('courier_orders', order.toJson());
    await _addEvent(
      order.id,
      CourierStatus.pending,
      'Order created and queued for dispatch.',
    );
    return CourierOrder.fromJson(row);
  }

  Future<CourierOrder> updateTracking({
    required CourierOrder order,
    required String courierPartner,
    String? trackingNumber,
  }) async {
    final updated = order.copyWith(trackingNumber: trackingNumber?.trim());
    final row = await _store.update('courier_orders', order.id, {
      ...updated.toJson(),
      'courier_partner': courierPartner,
      'tracking_number': trackingNumber?.trim().isEmpty == true
          ? null
          : trackingNumber?.trim(),
      'updated_at': toIso(DateTime.now()),
    });
    return CourierOrder.fromJson(row, events: order.events);
  }

  Future<CourierOrder> changeStatus({
    required CourierOrder order,
    required CourierStatus status,
    String? note,
  }) async {
    if (order.status == status) return order;
    final now = DateTime.now();
    final changes = <String, dynamic>{
      'status': status.value,
      'updated_at': toIso(now),
      if (status == CourierStatus.shipped) 'dispatched_at': toIso(now),
      if (status == CourierStatus.delivered) 'delivered_at': toIso(now),
    };
    final row = await _store.update('courier_orders', order.id, changes);
    await _addEvent(
      order.id,
      status,
      (note?.trim().isEmpty ?? true)
          ? _defaultNote(status, order)
          : note!.trim(),
    );
    final events = await this.events(order.id);
    return CourierOrder.fromJson(row, events: events);
  }

  Future<CourierOrder> collectCod(CourierOrder order) async {
    if (!order.hasCod) {
      throw const AppFailure('This order has no cash on delivery amount.');
    }
    if (order.codCollected) return order;
    if (order.status != CourierStatus.delivered) {
      throw const AppFailure(
        'COD can only be reconciled after the order is delivered.',
      );
    }
    final row = await _store.update('courier_orders', order.id, {
      'cod_collected': true,
      'updated_at': toIso(DateTime.now()),
    });
    await _addEvent(
      order.id,
      order.status,
      'COD of ${Formats.currency(order.codAmount, symbol: _session.currencySymbol)} reconciled.',
    );
    final events = await this.events(order.id);
    return CourierOrder.fromJson(row, events: events);
  }

  Future<void> delete(CourierOrder order) async {
    await _store.deleteWhere('courier_events', {
      'courier_order_id': order.id,
      'tenant_id': order.tenantId,
    });
    await _store.delete('courier_orders', order.id);
  }

  Future<void> _addEvent(
    String orderId,
    CourierStatus status,
    String note,
  ) async {
    await _store.insert(
      'courier_events',
      CourierEvent(
        id: _uuid.v4(),
        status: status,
        note: note,
        createdAt: DateTime.now(),
      ).toJson(_session.requireTenantId(), orderId),
    );
  }

  String _defaultNote(
    CourierStatus status,
    CourierOrder order,
  ) => switch (status) {
    CourierStatus.shipped =>
      'Handed to ${order.courierPartner}${order.trackingNumber == null ? '' : ' · ${order.trackingNumber}'}.',
    CourierStatus.delivered => 'Delivered to ${order.customerName}.',
    CourierStatus.returned => 'Parcel returned to the business.',
    CourierStatus.cancelled => 'Order cancelled.',
    CourierStatus.pending => 'Order moved back to pending.',
  };
}
