import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/json_helpers.dart';

enum CourierStatus {
  pending,
  shipped,
  delivered,
  returned,
  cancelled;

  static CourierStatus fromValue(dynamic value) {
    switch (value?.toString().toLowerCase()) {
      case 'shipped':
        return CourierStatus.shipped;
      case 'delivered':
        return CourierStatus.delivered;
      case 'returned':
        return CourierStatus.returned;
      case 'cancelled':
        return CourierStatus.cancelled;
      default:
        return CourierStatus.pending;
    }
  }

  String get value => name;

  String get label => switch (this) {
    CourierStatus.pending => 'Pending',
    CourierStatus.shipped => 'Shipped',
    CourierStatus.delivered => 'Delivered',
    CourierStatus.returned => 'Returned',
    CourierStatus.cancelled => 'Cancelled',
  };

  Color get color => switch (this) {
    CourierStatus.pending => AppColors.amber,
    CourierStatus.shipped => AppColors.blue,
    CourierStatus.delivered => AppColors.green,
    CourierStatus.returned => AppColors.red,
    CourierStatus.cancelled => AppColors.inkMuted,
  };

  IconData get icon => switch (this) {
    CourierStatus.pending => Icons.schedule_rounded,
    CourierStatus.shipped => Icons.local_shipping_rounded,
    CourierStatus.delivered => Icons.check_circle_rounded,
    CourierStatus.returned => Icons.undo_rounded,
    CourierStatus.cancelled => Icons.cancel_rounded,
  };

  bool get isOpen => this == pending || this == shipped;

  static const List<CourierStatus> flow = [
    CourierStatus.pending,
    CourierStatus.shipped,
    CourierStatus.delivered,
  ];

  CourierStatus? get next => switch (this) {
    CourierStatus.pending => CourierStatus.shipped,
    CourierStatus.shipped => CourierStatus.delivered,
    _ => null,
  };
}

class CourierOrder {
  const CourierOrder({
    required this.id,
    required this.tenantId,
    required this.orderNo,
    this.saleId,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.city,
    required this.courierPartner,
    this.trackingNumber,
    required this.status,
    required this.codAmount,
    required this.codCollected,
    required this.shippingFee,
    this.notes,
    this.dispatchedAt,
    this.deliveredAt,
    required this.createdAt,
    required this.updatedAt,
    this.events = const [],
  });

  final String id;
  final String tenantId;
  final String orderNo;
  final String? saleId;
  final String customerName;
  final String customerPhone;
  final String address;
  final String city;
  final String courierPartner;
  final String? trackingNumber;
  final CourierStatus status;
  final double codAmount;
  final bool codCollected;
  final double shippingFee;
  final String? notes;
  final DateTime? dispatchedAt;
  final DateTime? deliveredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<CourierEvent> events;

  static const List<String> partners = [
    'TCS',
    'Leopards Courier',
    'M&P',
    'Pakistan Post',
    'BlueEX',
    'Trax',
    'Other',
  ];

  factory CourierOrder.fromJson(
    Map<String, dynamic> json, {
    List<CourierEvent> events = const [],
  }) {
    final rawEvents = json['courier_events'];
    final nested = rawEvents is List
        ? rawEvents
              .whereType<Map>()
              .map((row) => CourierEvent.fromJson(Map<String, dynamic>.from(row)))
              .toList()
        : <CourierEvent>[];
    return CourierOrder(
      id: asString(json['id']),
      tenantId: asString(json['tenant_id']),
      orderNo: asString(json['order_no']),
      saleId: asNullableString(json['sale_id']),
      customerName: asString(json['customer_name'], 'Customer'),
      customerPhone: asString(json['customer_phone']),
      address: asString(json['address']),
      city: asString(json['city']),
      courierPartner: asString(json['courier_partner'], 'TCS'),
      trackingNumber: asNullableString(json['tracking_number']),
      status: CourierStatus.fromValue(json['status']),
      codAmount: asDouble(json['cod_amount']),
      codCollected: asBool(json['cod_collected']),
      shippingFee: asDouble(json['shipping_fee']),
      notes: asNullableString(json['notes']),
      dispatchedAt: asDateOrNull(json['dispatched_at']),
      deliveredAt: asDateOrNull(json['delivered_at']),
      createdAt: asDate(json['created_at']),
      updatedAt: asDate(json['updated_at']),
      events: events.isNotEmpty ? events : nested,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'order_no': orderNo,
    'sale_id': saleId,
    'customer_name': customerName.trim(),
    'customer_phone': customerPhone.trim(),
    'address': address.trim(),
    'city': city.trim(),
    'courier_partner': courierPartner,
    'tracking_number': trackingNumber,
    'status': status.value,
    'cod_amount': codAmount,
    'cod_collected': codCollected,
    'shipping_fee': shippingFee,
    'notes': notes,
    'dispatched_at': dispatchedAt == null ? null : toIso(dispatchedAt),
    'delivered_at': deliveredAt == null ? null : toIso(deliveredAt),
    'created_at': toIso(createdAt),
    'updated_at': toIso(updatedAt),
  };

  CourierOrder copyWith({
    String? trackingNumber,
    CourierStatus? status,
    bool? codCollected,
    DateTime? dispatchedAt,
    DateTime? deliveredAt,
    List<CourierEvent>? events,
  }) => CourierOrder(
    id: id,
    tenantId: tenantId,
    orderNo: orderNo,
    saleId: saleId,
    customerName: customerName,
    customerPhone: customerPhone,
    address: address,
    city: city,
    courierPartner: courierPartner,
    trackingNumber: trackingNumber ?? this.trackingNumber,
    status: status ?? this.status,
    codAmount: codAmount,
    codCollected: codCollected ?? this.codCollected,
    shippingFee: shippingFee,
    notes: notes,
    dispatchedAt: dispatchedAt ?? this.dispatchedAt,
    deliveredAt: deliveredAt ?? this.deliveredAt,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
    events: events ?? this.events,
  );

  bool get hasCod => codAmount > 0;
  bool get codPending => codAmount > 0 && !codCollected;
  String get location => [city, address].where((v) => v.isNotEmpty).join(' · ');
  String get shortAddress => address.length > 48
      ? '${address.substring(0, 48)}…'
      : address;
}

class CourierEvent {
  const CourierEvent({
    required this.id,
    required this.status,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final CourierStatus status;
  final String note;
  final DateTime createdAt;

  factory CourierEvent.fromJson(Map<String, dynamic> json) => CourierEvent(
    id: asString(json['id']),
    status: CourierStatus.fromValue(json['status']),
    note: asString(json['note']),
    createdAt: asDate(json['created_at']),
  );

  Map<String, dynamic> toJson(String tenantId, String orderId) => {
    'id': id,
    'tenant_id': tenantId,
    'courier_order_id': orderId,
    'status': status.value,
    'note': note,
    'created_at': toIso(createdAt),
  };

  String get timeLabel => Formats.dateTime(createdAt);
}
