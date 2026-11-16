import 'package:afraz_flow/core/theme/app_colors.dart';
import 'package:afraz_flow/core/theme/app_theme.dart';
import 'package:afraz_flow/core/widgets/app_widgets.dart';
import 'package:afraz_flow/features/scanner/views/scanner_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  testWidgets('shared widgets render brand content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Column(
            children: [
              AppCard(child: Text('Revenue this week')),
              StatusPill(
                label: 'Delivered',
                color: AppColors.green,
                icon: Icons.check_circle_outline_rounded,
              ),
              InitialsAvatar(name: 'Afraz Malik'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Revenue this week'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text('AM'), findsOneWidget);
  });

  testWidgets('scanner uses manual entry on desktop platforms', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(const GetMaterialApp(home: ScannerView()));
      await tester.pumpAndSettle();

      expect(find.text('Manual code entry'), findsOneWidget);
      expect(find.text('Use this code'), findsOneWidget);
      expect(
        find.textContaining('Camera scanning is available'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).first, 'SKU-1042');
      expect(find.text('SKU-1042'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
