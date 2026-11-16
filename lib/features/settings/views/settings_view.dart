import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/feedback.dart';
import '../controllers/settings_controller.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final SettingsController controller = Get.find<SettingsController>();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    if (controller.tenant == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: ErrorState(
          message:
              'Your workspace details could not be loaded. '
              'Please sign in again.',
          title: 'No workspace found',
        ),
      );
    }
    return SingleChildScrollView(
      padding: EdgeInsets.all(wide ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox.shrink(),
          const SizedBox(height: 20),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildBusinessCard(context)),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _buildSideColumn(context)),
              ],
            )
          else ...[
            _buildBusinessCard(context),
            const SizedBox(height: 16),
            _buildSideColumn(context),
          ],
        ],
      ),
    );
  }

  Widget _buildSideColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBriefingCard(context),
        const SizedBox(height: 16),
        _buildAppearanceCard(context),
        const SizedBox(height: 16),
        _buildAccountCard(context),
        const SizedBox(height: 16),
        _buildAboutCard(context),
      ],
    );
  }

  Widget _buildBusinessCard(BuildContext context) {
    final canEdit = controller.canEdit;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialsAvatar(
                  name: controller.tenant?.name ?? 'AF',
                  size: 46,
                  background: AppColors.navy,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Business profile',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Shown on invoices, receipts and in the workspace.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canEdit)
                  Obx(
                    () => FilledButton.icon(
                      onPressed: controller.saving.value ? null : _save,
                      icon: controller.saving.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text('Save'.tr),
                    ),
                  ),
              ],
            ),
            if (!canEdit) ...[
              const SizedBox(height: 14),
              _Notice(
                icon: Icons.lock_outline_rounded,
                color: AppColors.blue,
                message:
                    'Only an admin can change business settings. You can view '
                    'the current configuration below.',
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoUp = constraints.maxWidth >= 560;
                return Column(
                  children: [
                    _row(
                      twoUp,
                      _textField(
                        label: 'Business name',
                        controller: controller.nameController,
                        icon: Icons.storefront_outlined,
                        enabled: canEdit,
                        validator: (value) =>
                            Validators.required(value, field: 'Business name'),
                      ),
                      Obx(
                        () => DropdownButtonFormField<String>(
                          value: controller.businessType.value,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Business type',
                            prefixIcon: Icon(Icons.category_outlined, size: 20),
                          ),
                          items: [
                            for (final type in AppConfig.businessTypes)
                              DropdownMenuItem(
                                value: type,
                                child: Text(
                                  type,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: canEdit
                              ? (value) {
                                  if (value != null) {
                                    controller.businessType.value = value;
                                  }
                                }
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _row(
                      twoUp,
                      Obx(
                        () => DropdownButtonFormField<String>(
                          value: controller.currency.value,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Currency',
                            prefixIcon: Icon(Icons.payments_outlined, size: 20),
                          ),
                          items: [
                            for (final code in AppConfig.currencies)
                              DropdownMenuItem(
                                value: code,
                                child: Text(
                                  '$code · ${AppConfig.symbolFor(code)}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: canEdit
                              ? (value) {
                                  if (value != null) {
                                    controller.currency.value = value;
                                  }
                                }
                              : null,
                        ),
                      ),
                      _textField(
                        label: 'Tax rate (%)',
                        controller: controller.taxRateController,
                        icon: Icons.percent_rounded,
                        enabled: canEdit,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _taxRateValidator,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _textField(
                      label: 'Low stock alert threshold',
                      controller: controller.lowStockController,
                      icon: Icons.inventory_2_outlined,
                      enabled: canEdit,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final parsed = int.tryParse((value ?? '').trim());
                        if (parsed == null) return 'Enter a whole number';
                        if (parsed < 0) return 'Cannot be negative';
                        if (parsed > 100000) return 'Value is too large';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _row(
                      twoUp,
                      _textField(
                        label: 'Phone',
                        controller: controller.phoneController,
                        icon: Icons.phone_outlined,
                        enabled: canEdit,
                        keyboardType: TextInputType.phone,
                        validator: (value) =>
                            Validators.phone(value, optional: true),
                      ),
                      _textField(
                        label: 'Email',
                        controller: controller.emailController,
                        icon: Icons.alternate_email_rounded,
                        enabled: canEdit,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) return null;
                          return Validators.email(value);
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    _textField(
                      label: 'Address',
                      controller: controller.addressController,
                      icon: Icons.location_on_outlined,
                      enabled: canEdit,
                      maxLines: 3,
                    ),
                  ],
                );
              },
            ),
            if (canEdit) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Tax rate is applied to new sales. Currency and threshold '
                      'updates apply immediately across the workspace.',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBriefingCard(BuildContext context) {
    final canEdit = controller.canEdit;
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Notifications & daily briefing',
            subtitle: 'Choose when notifications and the daily briefing arrive.',
          ),
          const SizedBox(height: 8),
          Obx(
            () => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(
                Icons.notifications_active_outlined,
                size: 21,
              ),
              title: const Text('Daily briefing notifications'),
              subtitle: const Text(
                'Compile sales, profit, stock and next steps',
              ),
              value: controller.briefingEnabled.value,
              onChanged: canEdit
                  ? (value) => controller.setBriefingEnabled(value)
                  : null,
            ),
          ),
          Divider(color: theme.colorScheme.outlineVariant),
          Obx(
            () => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded, size: 21),
              title: const Text('Notification time'),
              subtitle: Text(controller.briefingTimeOfDay.format(context)),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              enabled: canEdit,
              onTap: canEdit ? () => _pickBriefingTime(context) : null,
            ),
          ),
          const SizedBox(height: 8),
          Obx(() {
            final zones = <String>{
              ...AppConfig.briefingTimezones,
              controller.briefingTimezone.value,
            }.toList(growable: false);
            return DropdownButtonFormField<String>(
              value: controller.briefingTimezone.value,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Timezone',
                prefixIcon: Icon(Icons.public_rounded, size: 20),
              ),
              items: [
                for (final zone in zones)
                  DropdownMenuItem(
                    value: zone,
                    child: Text(zone, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: canEdit
                  ? (value) {
                      if (value != null) controller.setBriefingTimezone(value);
                    }
                  : null,
            );
          }),
          const SizedBox(height: 10),
          Text(
            'The summary is prepared at this local time every day and appears '
            'in your notification bell.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (canEdit) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: Obx(
                () => FilledButton.icon(
                  onPressed: controller.savingBriefing.value
                      ? null
                      : _saveBriefing,
                  icon: controller.savingBriefing.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text('Save schedule'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppearanceCard(BuildContext context) {
    final theme = controller.theme;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Appearance',
            subtitle: 'Choose how Afraz Flow looks on this device.',
          ),
          const SizedBox(height: 16),
          Obx(
            () => SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined, size: 18),
                  label: Text('System'.tr),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined, size: 18),
                  label: Text('Light'.tr),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined, size: 18),
                  label: Text('Dark'.tr),
                ),
              ],
              selected: {theme.mode.value},
              onSelectionChanged: (value) => theme.setMode(value.first),
            ),
          ),
          const SizedBox(height: 16),
          Obx(
            () => DropdownButtonFormField<Locale>(
              value: controller.language.locale.value,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Language',
                prefixIcon: Icon(Icons.language_rounded, size: 20),
              ),
              items: [
                for (final locale in AppConfig.supportedLocales)
                  DropdownMenuItem(
                    value: locale,
                    child: Text(
                      AppConfig.languageName(locale),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) controller.setLanguage(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context) {
    final session = controller.session;
    final user = session.user;
    final isDemo = controller.isDemo;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Your account',
            subtitle: 'The profile and access level for this session.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              InitialsAvatar(
                name: user?.fullName ?? 'AF',
                size: 46,
                background: AppColors.teal,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'Account',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      user?.email ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(
                label: session.role.label,
                color: AppColors.teal,
                icon: Icons.verified_user_outlined,
                dense: true,
              ),
              StatusPill(
                label: isDemo ? 'Demo workspace' : 'Cloud connected',
                color: isDemo ? AppColors.amber : AppColors.green,
                icon: isDemo
                    ? Icons.science_outlined
                    : Icons.cloud_done_outlined,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout_rounded, size: 20),
            title: Text('Sign out'.tr),
            subtitle: Text('End this session on this device'.tr),
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: _confirmSignOut,
          ),
          if (isDemo) ...[
            if (controller.cloudAvailable) ...[
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_outlined, size: 20),
                title: Text('Switch to cloud sign-in'.tr),
                subtitle: Text('Return to your Supabase workspace'.tr),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: _confirmUseCloud,
              ),
            ],
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.restart_alt_rounded,
                size: 20,
                color: AppColors.red,
              ),
              title: const Text(
                'Reset demo data',
                style: TextStyle(color: AppColors.red),
              ),
              subtitle: const Text(
                'Restore the sample catalog, sales and ledger',
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: _confirmReset,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'About',
            subtitle: 'Afraz Flow business & courier management.',
          ),
          const SizedBox(height: 12),
          const InfoRow(
            label: 'Version',
            value: AppConfig.version,
            icon: Icons.tag_rounded,
          ),
          const InfoRow(
            label: 'App ID',
            value: AppConfig.packageName,
            icon: Icons.fingerprint_rounded,
          ),
          const InfoRow(
            label: 'Support',
            value: AppConfig.supportEmail,
            icon: Icons.support_agent_outlined,
          ),
          InfoRow(
            label: 'Data mode',
            value: controller.isDemo ? 'Local demo' : 'Supabase cloud',
            icon: Icons.storage_outlined,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await controller.save();
  }

  Future<void> _pickBriefingTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: controller.briefingTimeOfDay,
    );
    if (picked != null) controller.setBriefingTime(picked);
  }

  Future<void> _saveBriefing() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await controller.saveBriefingSchedule();
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Sign out?',
      message: 'You will need your email and password to sign back in.',
      confirmLabel: 'Sign out',
      destructive: true,
      icon: Icons.logout_rounded,
    );
    if (!confirmed) return;
    await controller.signOut();
  }

  Future<void> _confirmUseCloud() async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Switch to cloud sign-in?',
      message:
          'You will leave the local demo workspace. Demo data stays on this '
          'device and your real Supabase workspace is not changed.',
      confirmLabel: 'Switch back',
      icon: Icons.cloud_outlined,
    );
    if (!confirmed) return;
    await controller.useCloud();
  }

  Future<void> _confirmReset() async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Reset demo data?',
      message:
          'This replaces the sample products, sales, expenses and courier '
          'orders with a fresh demo workspace. Your current changes will be '
          'lost.',
      confirmLabel: 'Reset data',
      destructive: true,
      icon: Icons.restart_alt_rounded,
    );
    if (!confirmed) return;
    await controller.resetDemo();
  }

  String? _taxRateValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter a tax rate';
    final parsed = double.tryParse(text);
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 0 || parsed > 100) return 'Use a value between 0 and 100';
    return null;
  }

  Widget _row(bool twoUp, Widget first, Widget second) {
    if (!twoUp) {
      return Column(children: [first, const SizedBox(height: 14), second]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 14),
        Expanded(child: second),
      ],
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = true,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: maxLines > 1
          ? TextCapitalization.sentences
          : TextCapitalization.words,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
