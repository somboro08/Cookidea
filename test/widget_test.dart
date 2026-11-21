import 'package:cookidea/features/dashboard/presentation/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cookidea/core/theme.dart';

void main() {
  testWidgets('workspace renders on desktop', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: const DashboardPage(supabaseEnabled: false)));
    await tester.pumpAndSettle();
    expect(find.text('Bonjour 👋'), findsOneWidget);
    expect(find.text('Vos projets'), findsOneWidget);
    expect(find.text('Créer ma première idée'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('workspace adapts to a narrow mobile viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: DashboardPage(supabaseEnabled: false)));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.text('Bonjour 👋'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}