import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';

void showAppMessage(
  String message, {
  bool error = false,
  String? title,
}) {
  Get.snackbar(
    title ?? (error ? 'Something went wrong' : 'Done'),
    message,
    snackPosition: SnackPosition.BOTTOM,
    margin: const EdgeInsets.all(16),
    maxWidth: 440,
    duration: const Duration(seconds: 4),
    backgroundColor: error ? AppColors.red : AppColors.navy,
    colorText: Colors.white,
    icon: Icon(
      error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
      color: Colors.white,
    ),
    borderRadius: 12,
    isDismissible: true,
    forwardAnimationCurve: Curves.easeOutCubic,
  );
}

Future<void> showSuccess(String message) async {
  showAppMessage(message);
}

class AppDialogs {
  const AppDialogs._();

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          icon ?? (destructive
              ? Icons.warning_amber_rounded
              : Icons.help_outline_rounded),
          color: destructive ? AppColors.red : AppColors.teal,
          size: 32,
        ),
        title: Text(title),
        content: Text(message),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.red)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Future<T?> showForm<T>(
    BuildContext context, {
    required String title,
    String? subtitle,
    required Widget child,
    double maxWidth = 540,
    bool dismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
