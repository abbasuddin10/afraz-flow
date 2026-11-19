import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_widgets.dart';
import '../controllers/courier_controller.dart';
import '../data/courier_order.dart';

class CourierFormDialog extends StatefulWidget {
  const CourierFormDialog({super.key});

  @override
  State<CourierFormDialog> createState() => _CourierFormDialogState();
}

class _CourierFormDialogState extends State<CourierFormDialog> {
  final CourierController _controller = Get.find<CourierController>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _cod = TextEditingController();
  final TextEditingController _shipping = TextEditingController();
  final TextEditingController _tracking = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  String _partner = CourierOrder.partners.first;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _cod.dispose();
    _shipping.dispose();
    _tracking.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final order = await _controller.createOrder(
      customerName: _name.text.trim(),
      customerPhone: _phone.text.trim(),
      address: _address.text.trim(),
      city: _city.text.trim(),
      courierPartner: _partner,
      codAmount: Formats.parseAmount(_cod.text),
      shippingFee: Formats.parseAmount(_shipping.text),
      trackingNumber: _tracking.text.trim(),
      notes: _notes.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (order != null) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _name,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) =>
                              Validators.required(value, field: 'Customer name'),
                          decoration: const InputDecoration(
                            labelText: 'Customer name',
                            prefixIcon: Icon(
                              Icons.person_outline_rounded,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          validator: (value) => Validators.phone(value),
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            prefixIcon: Icon(Icons.phone_outlined, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _address,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (value) =>
                        Validators.required(value, field: 'Delivery address'),
                    decoration: const InputDecoration(
                      labelText: 'Delivery address',
                      prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _city,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) =>
                              Validators.required(value, field: 'City'),
                          decoration: const InputDecoration(
                            labelText: 'City',
                            prefixIcon: Icon(
                              Icons.location_city_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _partner,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Courier',
                            prefixIcon: Icon(
                              Icons.local_shipping_outlined,
                              size: 20,
                            ),
                          ),
                          items: [
                            for (final partner in CourierOrder.partners)
                              DropdownMenuItem(
                                value: partner,
                                child: Text(
                                  partner,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _partner = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'PAYMENT',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cod,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) => Validators.amount(
                            value,
                            allowZero: true,
                            field: 'COD amount',
                          ),
                          decoration: InputDecoration(
                            labelText: 'COD amount',
                            hintText: '0',
                            prefixIcon: const Icon(
                              Icons.payments_outlined,
                              size: 20,
                            ),
                            suffixText: _controller.currency,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _shipping,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) => Validators.amount(
                            value,
                            allowZero: true,
                            field: 'Shipping fee',
                          ),
                          decoration: InputDecoration(
                            labelText: 'Shipping fee',
                            hintText: '0',
                            prefixIcon: const Icon(
                              Icons.delivery_dining_outlined,
                              size: 20,
                            ),
                            suffixText: _controller.currency,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _tracking,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Tracking number',
                      hintText: 'Can be added after dispatch',
                      prefixIcon: Icon(Icons.confirmation_number_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notes,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      hintText: 'Optional instructions for the rider',
                      prefixIcon: Icon(Icons.notes_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          DialogActions(
            cancelLabel: 'Cancel',
            submitLabel: 'Create delivery',
            loading: _saving,
            submitIcon: Icons.local_shipping_outlined,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

class CourierTrackingDialog extends StatefulWidget {
  const CourierTrackingDialog({
    super.key,
    required this.order,
    required this.onSubmit,
  });

  final CourierOrder order;
  final Future<bool> Function(String partner, String? tracking) onSubmit;

  @override
  State<CourierTrackingDialog> createState() => _CourierTrackingDialogState();
}

class _CourierTrackingDialogState extends State<CourierTrackingDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _tracking = TextEditingController(
    text: widget.order.trackingNumber ?? '',
  );
  late String _partner = CourierOrder.partners.contains(
    widget.order.courierPartner,
  )
      ? widget.order.courierPartner
      : 'Other';
  bool _saving = false;

  @override
  void dispose() {
    _tracking.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final saved = await widget.onSubmit(_partner, _tracking.text.trim());
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _partner,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Courier partner',
                    prefixIcon: Icon(
                      Icons.local_shipping_outlined,
                      size: 20,
                    ),
                  ),
                  items: [
                    for (final partner in CourierOrder.partners)
                      DropdownMenuItem(
                        value: partner,
                        child: Text(partner, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _partner = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tracking,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Tracking number',
                    hintText: 'Leave empty if not issued yet',
                    prefixIcon: Icon(
                      Icons.confirmation_number_outlined,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Tracking details are shown to whoever opens this delivery, '
                  'including cashiers updating its status.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          DialogActions(
            cancelLabel: 'Cancel',
            submitLabel: 'Save tracking',
            loading: _saving,
            submitIcon: Icons.save_outlined,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

class CourierStatusDialog extends StatefulWidget {
  const CourierStatusDialog({
    super.key,
    required this.order,
    required this.status,
    required this.onSubmit,
  });

  final CourierOrder order;
  final CourierStatus status;
  final Future<bool> Function(String note) onSubmit;

  @override
  State<CourierStatusDialog> createState() => _CourierStatusDialogState();
}

class _CourierStatusDialogState extends State<CourierStatusDialog> {
  final TextEditingController _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final saved = await widget.onSubmit(_note.text.trim());
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: status.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(status.icon, color: status.color, size: 21),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mark as ${status.label}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          '${widget.order.orderNo} · ${widget.order.customerName}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                autofocus: true,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Status note',
                  hintText: 'Optional — e.g. rider picked up at 4pm',
                  prefixIcon: Icon(Icons.notes_rounded, size: 20),
                ),
              ),
              if (status == CourierStatus.delivered) ...[
                const SizedBox(height: 10),
                Text(
                  'COD reconciliation becomes available once the delivery is '
                  'marked as delivered.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        DialogActions(
          cancelLabel: 'Cancel',
          submitLabel: 'Mark ${status.label.toLowerCase()}',
          loading: _saving,
          submitIcon: status.icon,
          onSubmit: _submit,
        ),
      ],
    );
  }
}
