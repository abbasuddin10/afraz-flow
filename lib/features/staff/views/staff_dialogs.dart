import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/app_user.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_widgets.dart';
import '../controllers/staff_controller.dart';

class InviteStaffDialog extends StatefulWidget {
  const InviteStaffDialog({super.key});

  @override
  State<InviteStaffDialog> createState() => _InviteStaffDialogState();
}

class _InviteStaffDialogState extends State<InviteStaffDialog> {
  final StaffController _controller = Get.find<StaffController>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  MemberRole _role = MemberRole.cashier;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final saved = await _controller.invite(
      fullName: _name.text.trim(),
      email: _email.text.trim(),
      memberRole: _role,
      password: _password.text.trim().isEmpty ? null : _password.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.of(context).pop(true);
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
                  TextFormField(
                    controller: _name,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) =>
                        Validators.required(value, field: 'Full name'),
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                    decoration: const InputDecoration(
                      labelText: 'Work email',
                      prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ROLE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<MemberRole>(
                    segments: [
                      for (final role in MemberRole.values)
                        ButtonSegment(
                          value: role,
                          label: Text(role.label),
                        ),
                    ],
                    selected: {_role},
                    showSelectedIcon: false,
                    onSelectionChanged: (values) {
                      if (values.isNotEmpty) {
                        setState(() => _role = values.first);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _role.description,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      return Validators.password(value);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Temporary password',
                      hintText: 'Optional',
                      helperText:
                          'Leave empty to use Welcome123. The account is created '
                          'with this password (or Welcome123) and can sign in '
                          '(or Welcome123) and can sign in immediately.',
                      helperMaxLines: 2,
                      prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          DialogActions(
            cancelLabel: 'Cancel',
            submitLabel: 'Create account',
            loading: _saving,
            submitIcon: Icons.person_add_alt_1_rounded,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

class ChangeRoleDialog extends StatefulWidget {
  const ChangeRoleDialog({super.key, required this.member});

  final Membership member;

  @override
  State<ChangeRoleDialog> createState() => _ChangeRoleDialogState();
}

class _ChangeRoleDialogState extends State<ChangeRoleDialog> {
  final StaffController _controller = Get.find<StaffController>();
  late MemberRole _role = widget.member.role;
  bool _saving = false;

  Future<void> _submit() async {
    if (_role == widget.member.role) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _saving = true);
    final saved = await _controller.changeRole(widget.member, _role);
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
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
                  InitialsAvatar(
                    name: widget.member.fullName,
                    size: 42,
                    background: AppColors.navySoft,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.member.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          widget.member.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 18),
              SegmentedButton<MemberRole>(
                segments: [
                  for (final role in MemberRole.values)
                    ButtonSegment(value: role, label: Text(role.label)),
                ],
                selected: {_role},
                showSelectedIcon: false,
                onSelectionChanged: (values) {
                  if (values.isNotEmpty) setState(() => _role = values.first);
                },
              ),
              const SizedBox(height: 10),
              Text(
                _role.description,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              if (_role == MemberRole.cashier) ...[
                const SizedBox(height: 8),
                Text(
                  'Cashiers cannot open the ledger, staff or settings screens.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.amber,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        DialogActions(
          cancelLabel: 'Cancel',
          submitLabel: 'Save role',
          loading: _saving,
          submitIcon: Icons.verified_user_outlined,
          onSubmit: _submit,
        ),
      ],
    );
  }
}
