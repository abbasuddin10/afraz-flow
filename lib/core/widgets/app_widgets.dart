import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';

/// A bordered, elevated-free surface used across every module.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.borderColor,
    this.onTap,
    this.radius = 16,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? theme.cardTheme.color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? theme.colorScheme.outlineVariant,
        ),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.eyebrow,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 720;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.teal,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    if (narrow && actions.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: actions),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: heading),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Wrap(spacing: 10, runSpacing: 10, children: actions),
          ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.background,
    this.foreground,
  });

  final String name;
  final double size;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? AppColors.navySoft,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(
        Formats.initials(name),
        style: TextStyle(
          color: foreground ?? Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.34,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// Decoded demo-mode data URLs, cached by their full URL so repeated rebuilds
/// reuse the same [Uint8List] (and therefore Flutter's decoded image cache).
final Map<String, Uint8List> _dataImageCache = <String, Uint8List>{};

/// Shows a product photo when one is available and a tidy placeholder icon
/// otherwise. The widget always occupies exactly [size] x [size] so it can be
/// dropped into compact cards, tables and lists without affecting layout.
class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 40,
    this.background,
    this.foreground,
    this.radius,
    this.icon = Icons.inventory_2_outlined,
  });

  final String name;
  final String? imageUrl;
  final double size;
  final Color? background;
  final Color? foreground;
  final BorderRadius? radius;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final corners = radius ?? BorderRadius.circular(size * 0.3);
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return _placeholder(corners);
    }
    return Semantics(
      label: name,
      image: true,
      child: ClipRRect(
        borderRadius: corners,
        child: url.startsWith('data:image')
            ? _memoryImage(url, corners)
            : Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(corners),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _loading();
                },
              ),
      ),
    );
  }

  Widget _memoryImage(String url, BorderRadius corners) {
    try {
      final bytes = _dataImageCache.putIfAbsent(
        url,
        () => base64Decode(url.substring(url.indexOf(',') + 1)),
      );
      return Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(corners),
      );
    } catch (_) {
      return _placeholder(corners);
    }
  }

  Widget _loading() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: background ?? AppColors.navySoft.withValues(alpha: 0.12),
      child: SizedBox(
        width: size * 0.32,
        height: size * 0.32,
        child: const CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _placeholder(BorderRadius corners) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? AppColors.navySoft.withValues(alpha: 0.12),
        borderRadius: corners,
      ),
      child: Icon(
        icon,
        size: size * 0.48,
        color: foreground ?? AppColors.navySoft,
      ),
    );
  }
}

/// A full-bleed product photo for cards and tiles.
///
/// Unlike [ProductThumbnail] this widget fills whatever space its parent gives
/// it, which makes it suitable for the large image area at the top of the POS
/// product cards. When no photo exists it renders a quiet placeholder icon so
/// the card never collapses or shows a broken image.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.name,
    this.imageUrl,
    this.fit = BoxFit.cover,
    this.background,
    this.foreground,
    this.icon = Icons.inventory_2_outlined,
  });

  final String name;
  final String? imageUrl;
  final BoxFit fit;
  final Color? background;
  final Color? foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) return _placeholder(context);
    return Semantics(
      label: name,
      image: true,
      child: url.startsWith('data:image')
          ? _memoryImage(context, url)
          : Image.network(
              url,
              width: double.infinity,
              height: double.infinity,
              fit: fit,
              errorBuilder: (_, _, _) => _placeholder(context),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _loading(context);
              },
            ),
    );
  }

  Widget _memoryImage(BuildContext context, String url) {
    try {
      final bytes = _dataImageCache.putIfAbsent(
        url,
        () => base64Decode(url.substring(url.indexOf(',') + 1)),
      );
      return Image.memory(
        bytes,
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        errorBuilder: (_, _, _) => _placeholder(context),
      );
    } catch (_) {
      return _placeholder(context);
    }
  }

  Widget _placeholder(BuildContext context) {
    final theme = Theme.of(context);
    final color = background ?? theme.colorScheme.surfaceContainerHigh;
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortest = constraints.biggest.shortestSide;
        final iconSize = shortest.isFinite
            ? (shortest * 0.34).clamp(18.0, 42.0)
            : 28.0;
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: color,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: iconSize,
            color:
                foreground ??
                theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
          ),
        );
      },
    );
  }

  Widget _loading(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _placeholder(context),
        Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.5 : 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: color),
            SizedBox(width: dense ? 4 : 5),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            SizedBox(width: dense ? 4 : 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: dense ? 10 : 11,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 24,
          vertical: compact ? 24 : 48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: AppColors.teal, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.label = 'Loading your workspace…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'Could not load this view',
  });

  final String message;
  final VoidCallback? onRetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.red,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('Try again'.tr),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.hint,
    this.onChanged,
    this.controller,
    this.width = 280,
    this.autofocus = false,
  });

  final String hint;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final double width;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        autofocus: autofocus,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}

class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.title,
    required this.children,
    this.description,
  });

  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        if (description != null) ...[
          const SizedBox(height: 3),
          Text(
            description!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

class DialogActions extends StatelessWidget {
  const DialogActions({
    super.key,
    required this.cancelLabel,
    required this.submitLabel,
    required this.onSubmit,
    this.onCancel,
    this.loading = false,
    this.submitIcon,
    this.destructive = false,
  });

  final String cancelLabel;
  final String submitLabel;
  final VoidCallback? onSubmit;
  final VoidCallback? onCancel;
  final bool loading;
  final IconData? submitIcon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: loading
                ? null
                : (onCancel ?? () => Navigator.of(context).pop()),
            child: Text(cancelLabel),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: loading ? null : onSubmit,
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.red)
                : null,
            icon: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(submitIcon ?? Icons.check_rounded, size: 18),
            label: Text(submitLabel),
          ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.trailing,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A responsive grid that avoids computing item aspect ratios by hand.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 260,
    this.spacing = 16,
    this.maxColumns = 4,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        var columns = ((available + spacing) / (minItemWidth + spacing))
            .floor();
        columns = columns.clamp(1, maxColumns);
        final width = (available - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
