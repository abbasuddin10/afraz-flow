import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../controllers/auth_controller.dart';
import 'auth_layout.dart';

class LoginView extends GetView<AuthController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AuthLayout(
        badge: controller.isDemoMode
            ? _ModeBadge(
                icon: Icons.science_outlined,
                title: 'Local demo workspace',
                message: controller.cloudAvailable
                    ? 'Showing sample data stored only on this device. Switch '
                          'back to cloud sign-in to use your real workspace.'
                    : 'Supabase is unavailable, so the sample workspace is '
                          'running on this device. '
                          '${controller.cloudError ?? ''}',
              )
            : null,
        form: Form(
          key: controller.loginFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: 32,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to your organization and pick up where you left off.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              if (controller.error.value != null) ...[
                AuthErrorBanner(message: controller.error.value!),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: controller.emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: Validators.email,
                decoration: const InputDecoration(
                  labelText: 'Work email',
                  hintText: 'you@business.com',
                  prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller.passwordController,
                obscureText: controller.obscurePassword.value,
                autofillHints: [AutofillHints.password],
                textInputAction: TextInputAction.done,
                validator: Validators.loginPassword,
                onFieldSubmitted: (_) => controller.login(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    onPressed: controller.togglePassword,
                    icon: Icon(
                      controller.obscurePassword.value
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: controller.loading.value
                      ? null
                      : controller.login,
                  child: controller.loading.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('Sign in'.tr),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: controller.loading.value
                      ? null
                      : controller.useDemoAccount,
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                  label: Text(
                    controller.isDemoMode
                        ? 'Sign in to the demo workspace'
                        : 'Explore the demo workspace',
                  ),
                ),
              ),
              if (controller.isDemoMode && controller.cloudAvailable) ...[
                const SizedBox(height: 4),
                Center(
                  child: TextButton.icon(
                    onPressed: controller.loading.value
                        ? null
                        : controller.useCloudAccount,
                    icon: const Icon(Icons.cloud_outlined, size: 16),
                    label: Text('Back to cloud sign-in'.tr),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Demo: ${AppConfig.demoEmail} · ${AppConfig.demoPassword}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OR',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'New to Afraz Flow?',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton(
                    onPressed: controller.goToRegister,
                    child: Text('Create your business'.tr),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: AppColors.teal,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.isDemoMode
                            ? 'Demo data stays on this device and is never '
                                  'uploaded. Your real workspace is stored in '
                                  'Supabase with row-level security.'
                            : 'Your organization’s data is isolated with row-level '
                                  'security. Nobody outside your team can read it.',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegisterView extends GetView<AuthController> {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AuthLayout(
        maxFormWidth: 520,
        form: Form(
          key: controller.registerFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: controller.goToLogin,
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLow,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Set up your workspace',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Create your organization. You will be the admin and can invite '
                'managers and cashiers later.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              if (controller.error.value != null) ...[
                AuthErrorBanner(message: controller.error.value!),
                const SizedBox(height: 16),
              ],
              _SectionLabel(label: 'Your details'),
              const SizedBox(height: 10),
              TextFormField(
                controller: controller.ownerNameController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                validator: (value) =>
                    Validators.required(value, field: 'Your name'),
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller.emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: Validators.email,
                decoration: const InputDecoration(
                  labelText: 'Work email',
                  prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller.phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: Validators.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+92 300 1234567',
                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 22),
              _SectionLabel(label: 'Business'),
              const SizedBox(height: 10),
              TextFormField(
                controller: controller.businessNameController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                validator: (value) =>
                    Validators.required(value, field: 'Business name'),
                decoration: const InputDecoration(
                  labelText: 'Business name',
                  hintText: 'e.g. Northwind Traders',
                  prefixIcon: Icon(Icons.storefront_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: controller.businessType.value,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Business type',
                  prefixIcon: Icon(Icons.category_outlined, size: 20),
                ),
                items: [
                  for (final type in AppConfig.businessTypes)
                    DropdownMenuItem(value: type, child: Text(type)),
                ],
                onChanged: (value) {
                  if (value != null) controller.businessType.value = value;
                },
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: controller.currency.value,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Currency'),
                      items: [
                        for (final code in AppConfig.currencies)
                          DropdownMenuItem(
                            value: code,
                            child: Text(
                              '$code · ${AppConfig.symbolFor(code)}',
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) controller.currency.value = value;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: controller.taxRateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) => Validators.amount(
                        value,
                        allowZero: true,
                        field: 'Tax rate',
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Tax rate (%)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller.lowStockController,
                keyboardType: TextInputType.number,
                validator: (value) => Validators.amount(
                  value,
                  allowZero: true,
                  field: 'Low stock alert',
                ),
                decoration: const InputDecoration(
                  labelText: 'Low stock alert level',
                  helperText: 'Products at or below this quantity are flagged.',
                ),
              ),
              const SizedBox(height: 22),
              _SectionLabel(label: 'Security'),
              const SizedBox(height: 10),
              TextFormField(
                controller: controller.passwordController,
                obscureText: controller.obscurePassword.value,
                textInputAction: TextInputAction.next,
                validator: Validators.password,
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: 'At least 8 characters, with letters and numbers.',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    onPressed: controller.togglePassword,
                    icon: Icon(
                      controller.obscurePassword.value
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller.confirmPasswordController,
                obscureText: controller.obscureConfirm.value,
                textInputAction: TextInputAction.done,
                validator: (value) =>
                    confirmPasswordValidator(value, controller),
                onFieldSubmitted: (_) => controller.register(),
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    onPressed: controller.toggleConfirm,
                    icon: Icon(
                      controller.obscureConfirm.value
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: controller.loading.value
                      ? null
                      : controller.register,
                  icon: controller.loading.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text('Create organization'.tr),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: controller.goToLogin,
                  child: Text('I already have an account'.tr),
                ),
              ),
              Text(
                'By creating an organization you agree to keep your account '
                'credentials secure. Every record is scoped to your business.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
        color: AppColors.teal,
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.amberSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF8A6100)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF6B4B00),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF7A5A0A),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
