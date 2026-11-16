import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_logo.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.form,
    this.maxFormWidth = 440,
    this.badge,
  });

  final Widget form;
  final double maxFormWidth;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final wide = width >= 960;
    final content = SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 56 : 24,
        vertical: wide ? 48 : 28,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxFormWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!wide) ...[
                const _MobileBrand(),
                const SizedBox(height: 32),
              ],
              if (badge != null) ...[badge!, const SizedBox(height: 18)],
              form,
            ],
          ),
        ),
      ),
    );

    if (!wide) {
      return Scaffold(
        body: SafeArea(
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: content,
          ),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          const Expanded(flex: 11, child: _BrandPanel()),
          Expanded(
            flex: 10,
            child: SafeArea(
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: content,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileBrand extends StatelessWidget {
  const _MobileBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AppLogoMark(size: 42, shadow: true),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConfig.appName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'Run the whole business from one place.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      child: Stack(
        children: [
          Positioned(
            right: -90,
            top: -70,
            child: _Orb(size: 340, color: AppColors.teal.withValues(alpha: 0.18)),
          ),
          Positioned(
            left: -110,
            bottom: -140,
            child: _Orb(
              size: 380,
              color: Colors.white.withValues(alpha: 0.045),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(56, 52, 56, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AppLogoMark(size: 46, shadow: true),
                    const SizedBox(width: 13),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppConfig.appName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          'Business OS',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.55),
                                letterSpacing: 1.6,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'One workspace for\nevery part of your business.',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 40,
                    height: 1.12,
                    letterSpacing: -1.6,
                  ),
                ),
                const SizedBox(height: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Text(
                    'Billing, inventory, Khata accounts and courier tracking — '
                    'securely isolated for every organisation.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.68),
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 34),
                const _FeatureRow(
                  icon: Icons.bolt_rounded,
                  title: 'POS that keeps up',
                  description: 'Barcode checkout, invoices and receipts.',
                ),
                const _FeatureRow(
                  icon: Icons.inventory_2_rounded,
                  title: 'Stock you can trust',
                  description: 'Live levels, movements and low-stock alerts.',
                ),
                const _FeatureRow(
                  icon: Icons.local_shipping_rounded,
                  title: 'Deliveries reconciled',
                  description: 'Courier tracking with COD accounting.',
                ),
                const Spacer(),
                Row(
                  children: [
                    _Pill(
                      icon: Icons.shield_outlined,
                      label: 'RLS isolated',
                    ),
                    const SizedBox(width: 10),
                    _Pill(
                      icon: Icons.devices_rounded,
                      label: 'Six platforms',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '© ${DateTime.now().year} Afraz Studio · ${AppConfig.packageName}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.38),
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

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Icon(icon, size: 18, color: AppColors.teal),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.55),
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

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.75)),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

/// Compact inline error banner used by auth forms.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.red),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.red,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
